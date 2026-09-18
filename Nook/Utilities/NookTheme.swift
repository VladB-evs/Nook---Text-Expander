import SwiftUI

/// App-wide theme palette centered on #151514 (dark background) and #EDA101 (warm amber accent).
extension Color {
    /// Main background color: #151514
    static let nookBackground = Color(red: 21 / 255.0, green: 21 / 255.0, blue: 20 / 255.0)

    /// Main accent color: #EDA101
    static let nookAccent = Color(red: 237 / 255.0, green: 161 / 255.0, blue: 1 / 255.0)

    /// Card / input surface: #1E1E1C
    static let nookCard = Color(red: 30 / 255.0, green: 30 / 255.0, blue: 28 / 255.0)

    /// Hover / selection surface: #2A2A26
    static let nookCardHover = Color(red: 42 / 255.0, green: 42 / 255.0, blue: 38 / 255.0)

    /// Subtle border / divider: #363632
    static let nookBorder = Color(red: 54 / 255.0, green: 54 / 255.0, blue: 50 / 255.0)

    /// Primary foreground text: #F2F2F2
    static let nookText = Color(white: 0.95)

    /// Secondary / caption text: #9E9E9C
    static let nookSecondaryText = Color(red: 158 / 255.0, green: 158 / 255.0, blue: 156 / 255.0)
}
