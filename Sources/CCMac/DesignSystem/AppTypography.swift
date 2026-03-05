import SwiftUI

// MARK: - CCMac Design System: Typography
// SF Pro Display / SF Pro Text — macOS system fonts

struct AppFont {
    // Display / Hero  — 40px Bold
    static let hero          = Font.system(size: 40, weight: .bold, design: .default)
    // Heading 1       — 28px Semibold
    static let heading1      = Font.system(size: 28, weight: .semibold, design: .default)
    // Heading 2       — 20px Semibold
    static let heading2      = Font.system(size: 20, weight: .semibold, design: .default)
    // Heading 3       — 16px Semibold
    static let heading3      = Font.system(size: 16, weight: .semibold, design: .default)
    // Body Large      — 15px Regular
    static let bodyLarge     = Font.system(size: 15, weight: .regular, design: .default)
    // Body Default    — 13px Regular
    static let bodyDefault   = Font.system(size: 13, weight: .regular, design: .default)
    // Body Small      — 11px Regular
    static let bodySmall     = Font.system(size: 11, weight: .regular, design: .default)
    // Mono            — 12px Regular
    static let mono          = Font.system(size: 12, weight: .regular, design: .monospaced)
    // Label Badge     — 11px Bold
    static let labelBadge    = Font.system(size: 11, weight: .bold, design: .default)
    // Number Hero     — 48px Bold
    static let numberHero    = Font.system(size: 48, weight: .bold, design: .default)
}

// MARK: - Spacing Tokens
struct AppSpacing {
    static let micro: CGFloat  = 2
    static let tiny: CGFloat   = 4
    static let base: CGFloat   = 8
    static let compact: CGFloat = 12
    static let standard: CGFloat = 16
    static let section: CGFloat  = 24
    static let major: CGFloat    = 32
    static let hero: CGFloat     = 48
}

// MARK: - Border Radius
struct AppRadius {
    static let small:  CGFloat = 6
    static let medium: CGFloat = 10
    static let large:  CGFloat = 16
    static let xLarge: CGFloat = 24
}
