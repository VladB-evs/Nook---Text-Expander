import AppKit
import Carbon.HIToolbox

/// Receives raw keystrokes from the event tap.
@MainActor
protocol KeyEventHandling: AnyObject {
    /// Called for every real (non-synthetic) key down. Return true to swallow the event.
    func handleKeyDown(keyCode: Int64, characters: String, flags: CGEventFlags) -> Bool
    /// Called on mouse clicks so typing context can be reset.
    func handleMouseDown()
}

/// Thin wrapper around a CGEventTap on the session's keyboard events.
///
/// Runs on the main run loop; the callback does nothing but forward to the
/// handler, keeping per-keystroke overhead negligible. Requires the
/// Accessibility permission (the tap is an active filter so Nook can swallow
/// delimiters that complete a trigger).
@MainActor
@Observable
final class KeyboardMonitor {
    private(set) var isRunning = false
    @ObservationIgnored weak var handler: (any KeyEventHandling)?
    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    /// Attempts to install the tap. Fails (returns false) until the user
    /// grants Accessibility access.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: refcon
        ) else {
            isRunning = false
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    fileprivate func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            guard !EventSynthesizer.isSynthetic(event) else {
                return Unmanaged.passUnretained(event)
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            var length = 0
            var units = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &units)
            let characters = String(utf16CodeUnits: units, count: length)
            let swallow = handler?.handleKeyDown(keyCode: keyCode, characters: characters, flags: event.flags) ?? false
            return swallow ? nil : Unmanaged.passUnretained(event)

        case .leftMouseDown, .rightMouseDown:
            handler?.handleMouseDown()
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

/// C-convention trampoline into the monitor. The tap is scheduled on the main
/// run loop, so hopping onto the main actor here is a no-op assertion.
private nonisolated func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
    nonisolated(unsafe) var result: Unmanaged<CGEvent>?
    MainActor.assumeIsolated {
        result = monitor.process(type: type, event: event)
    }
    return result
}
