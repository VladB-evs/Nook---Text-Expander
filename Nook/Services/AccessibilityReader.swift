import AppKit
import ApplicationServices

/// Read-only Accessibility queries against the focused UI element.
@MainActor
enum AccessibilityReader {
    private static var focusedElement: AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        return (value as! AXUIElement)
    }

    /// The currently selected text in the focused element, for `{{selection}}`.
    static func selectedText() -> String {
        guard let element = focusedElement else { return "" }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String
        else { return "" }
        return text
    }

    /// True when the focused element is a password-style field. Used as a
    /// second line of defense next to the global secure-input flag.
    static func focusedElementIsSecure() -> Bool {
        guard let element = focusedElement else { return false }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success,
              let role = value as? String
        else { return false }
        return role == "AXSecureTextField"
    }

    /// Screen rectangle of the insertion caret, in AppKit (bottom-left origin)
    /// coordinates. Used to place the suggestion popover.
    static func caretRect() -> CGRect? {
        guard let element = focusedElement else { return nil }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue
        else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success, let boundsValue else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue((boundsValue as! AXValue), .cgRect, &rect), rect.width.isFinite, rect.height.isFinite
        else { return nil }

        // AX coordinates are top-left origin; convert to AppKit screen space.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
