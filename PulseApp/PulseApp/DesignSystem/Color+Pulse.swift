import SwiftUI

extension Color {
    /// Creates a `Color` from a hex string such as `"#49B9F9"` or `"49B9F9"`.
    /// Supports 6-digit (RGB) and 8-digit (RGBA) forms.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 8:
            r = (value >> 24) & 0xFF
            g = (value >> 16) & 0xFF
            b = (value >> 8) & 0xFF
            a = value & 0xFF
        default:
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
            a = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Pulse design system color tokens. Values are the exact hex constants from
/// the product spec so the app and the widget extension render identically.
enum PulseColor {
    static let backgroundBase = Color(hex: "#07080B")
    static let backgroundSurface = Color(hex: "#161B22")
    static let backgroundElevated = Color(hex: "#21262D")

    static let primaryAccent = Color(hex: "#49B9F9")
    static let primaryDark = Color(hex: "#1A9EE0")
    static let secondaryAccent = Color(hex: "#7B61FF")

    static let border = Color(hex: "#202838")
    static let borderStrong = Color(hex: "#30363D")

    static let textPrimary = Color(hex: "#F8FAFC")
    static let textMuted = Color(hex: "#717B8F")

    static let success = Color(hex: "#3FB950")
    static let warning = Color(hex: "#D29922")
    static let danger = Color(hex: "#F85149")
}
