import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct ThemePalette {
    var background: Color
    var panel: Color
    var text: Color
    var secondaryText: Color
    var key: Color
    var string: Color
    var number: Color
    var bool: Color
    var nullColor: Color
    var punctuation: Color
    var accent: Color
    var match: Color
    var currentMatch: Color
    /// 原文编辑器（NSTextView）使用的颜色
    var nsBackground: NSColor
    var nsText: NSColor
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, github, solarized, oneDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return tr(.followSystem)
        case .github: return "GitHub"
        case .solarized: return "Solarized"
        case .oneDark: return "One Dark"
        }
    }

    /// One Dark 固定深色，其余主题跟随系统深浅色
    var forcesDark: Bool { self == .oneDark }

    func palette(for scheme: ColorScheme) -> ThemePalette {
        let dark = forcesDark || scheme == .dark
        switch self {
        case .system:
            if dark {
                // 深色：Nord 大师配色
                return ThemePalette(
                    background: Color(hex: 0x2E3440), panel: Color(hex: 0x3B4252),
                    text: Color(hex: 0xECEFF4), secondaryText: Color(hex: 0x8A94A3),
                    key: Color(hex: 0x88C0D0), string: Color(hex: 0xA3BE8C),
                    number: Color(hex: 0xD08770), bool: Color(hex: 0xB48EAD),
                    nullColor: Color(hex: 0x7B8794), punctuation: Color(hex: 0x616E88),
                    accent: Color(hex: 0x5E81AC),
                    match: Color(hex: 0xEBCB8B, alpha: 0.28), currentMatch: Color(hex: 0xEBCB8B, alpha: 0.5),
                    nsBackground: NSColor(hex: 0x2E3440), nsText: NSColor(hex: 0xECEFF4)
                )
            }
            // 浅色：人民币灵感配色（紫檀 / 松绿 / 黛蓝 / 朱砂 / 鎏金），纯白底
            return ThemePalette(
                background: Color(hex: 0xFFFFFF), panel: Color(hex: 0xF5F5F7),
                text: Color(hex: 0x1D1D1F), secondaryText: Color(hex: 0x86868B),
                key: Color(hex: 0x7A4E91), string: Color(hex: 0x2E7D5B),
                number: Color(hex: 0x2F5DA8), bool: Color(hex: 0xB4443C),
                nullColor: Color(hex: 0x9CA3AF), punctuation: Color(hex: 0xB0B0B6),
                accent: Color(hex: 0x2F5DA8),
                match: Color(hex: 0xF2D649, alpha: 0.4), currentMatch: Color(hex: 0xE8B923, alpha: 0.55),
                nsBackground: .white, nsText: NSColor(hex: 0x1D1D1F)
            )
        case .github:
            return dark
                ? ThemePalette(
                    background: Color(hex: 0x0d1117), panel: Color(hex: 0x161b22),
                    text: Color(hex: 0xe6edf3), secondaryText: Color(hex: 0x8b949e),
                    key: Color(hex: 0x79c0ff), string: Color(hex: 0xa5d6ff),
                    number: Color(hex: 0x79c0ff), bool: Color(hex: 0xff7b72),
                    nullColor: Color(hex: 0x8b949e), punctuation: Color(hex: 0x8b949e),
                    accent: Color(hex: 0x2f81f7),
                    match: Color(hex: 0x9e6a03, alpha: 0.4), currentMatch: Color(hex: 0xbb8009, alpha: 0.55),
                    nsBackground: NSColor(hex: 0x0d1117), nsText: NSColor(hex: 0xe6edf3)
                )
                : ThemePalette(
                    background: Color(hex: 0xffffff), panel: Color(hex: 0xf6f8fa),
                    text: Color(hex: 0x1f2328), secondaryText: Color(hex: 0x59636e),
                    key: Color(hex: 0x0550ae), string: Color(hex: 0x0a3069),
                    number: Color(hex: 0x0550ae), bool: Color(hex: 0xcf222e),
                    nullColor: Color(hex: 0x59636e), punctuation: Color(hex: 0x59636e),
                    accent: Color(hex: 0x0969da),
                    match: Color.yellow.opacity(0.4), currentMatch: Color.orange.opacity(0.45),
                    nsBackground: .white, nsText: NSColor(hex: 0x1f2328)
                )
        case .solarized:
            return dark
                ? ThemePalette(
                    background: Color(hex: 0x002b36), panel: Color(hex: 0x073642),
                    text: Color(hex: 0x839496), secondaryText: Color(hex: 0x586e75),
                    key: Color(hex: 0x268bd2), string: Color(hex: 0x2aa198),
                    number: Color(hex: 0xd33682), bool: Color(hex: 0xcb4b16),
                    nullColor: Color(hex: 0x586e75), punctuation: Color(hex: 0x586e75),
                    accent: Color(hex: 0xb58900),
                    match: Color(hex: 0xb58900, alpha: 0.35), currentMatch: Color(hex: 0xb58900, alpha: 0.55),
                    nsBackground: NSColor(hex: 0x002b36), nsText: NSColor(hex: 0x839496)
                )
                : ThemePalette(
                    background: Color(hex: 0xfdf6e3), panel: Color(hex: 0xeee8d5),
                    text: Color(hex: 0x657b83), secondaryText: Color(hex: 0x93a1a1),
                    key: Color(hex: 0x268bd2), string: Color(hex: 0x2aa198),
                    number: Color(hex: 0xd33682), bool: Color(hex: 0xcb4b16),
                    nullColor: Color(hex: 0x93a1a1), punctuation: Color(hex: 0x93a1a1),
                    accent: Color(hex: 0xb58900),
                    match: Color(hex: 0xb58900, alpha: 0.3), currentMatch: Color(hex: 0xb58900, alpha: 0.5),
                    nsBackground: NSColor(hex: 0xfdf6e3), nsText: NSColor(hex: 0x657b83)
                )
        case .oneDark:
            return ThemePalette(
                background: Color(hex: 0x282c34), panel: Color(hex: 0x21252b),
                text: Color(hex: 0xabb2bf), secondaryText: Color(hex: 0x5c6370),
                key: Color(hex: 0xe06c75), string: Color(hex: 0x98c379),
                number: Color(hex: 0xd19a66), bool: Color(hex: 0x56b6c2),
                nullColor: Color(hex: 0x5c6370), punctuation: Color(hex: 0x5c6370),
                accent: Color(hex: 0x61afef),
                match: Color(hex: 0xd19a66, alpha: 0.3), currentMatch: Color(hex: 0xd19a66, alpha: 0.5),
                nsBackground: NSColor(hex: 0x282c34), nsText: NSColor(hex: 0xabb2bf)
            )
        }
    }
}
