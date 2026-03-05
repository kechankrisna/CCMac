import SwiftUI

// MARK: - CCMac Design System: Colors
// Based on Figma Design Guide — Dark Mode Primary

extension Color {
    // Primary
    static let brandBlue      = Color(hex: "#1A6B9A")
    static let brandGreen     = Color(hex: "#2E9C6A")
    static let bgDark         = Color(hex: "#0F1B26")
    static let bgDark2        = Color(hex: "#152230")
    static let surfaceDark    = Color(hex: "#1C2E3E")
    static let surfaceDarkHover = Color(hex: "#223549")

    // Text
    static let textPrimary    = Color.white
    static let textSecondary  = Color(hex: "#8BA8BE")
    static let textDisabled   = Color(hex: "#4A6070")

    // Accent
    static let dangerRed      = Color(hex: "#E05252")
    static let warningOrange  = Color(hex: "#E07A30")
    static let successGreen   = Color(hex: "#3CB875")
    static let infoBlue       = Color(hex: "#4DA6D8")
    static let assistantPurple = Color(hex: "#7B52C8")

    // Light Mode
    static let bgLight        = Color(hex: "#F0F4F8")
    static let surfaceLight   = Color.white
    static let surfaceLight2  = Color(hex: "#E8EFF5")
    static let textLightPrimary = Color(hex: "#1A2B38")

    // Convenience hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Gradient Presets
extension LinearGradient {
    static let brandGradient = LinearGradient(
        colors: [.brandBlue, .brandGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let bgGradient = LinearGradient(
        colors: [Color(hex: "#0F1B26"), Color(hex: "#0A2436")],
        startPoint: .top,
        endPoint: .bottom
    )
    static let greenGlow = LinearGradient(
        colors: [.brandGreen, Color(hex: "#35B57A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
