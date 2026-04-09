import SwiftUI

struct AppTheme {
    let keyColor: Color
    let titleColor: Color
    let labelColor: Color
    let dimColor: Color
    let accentColor: Color
    let baseFontSize: CGFloat

    static func from(settings: AppSettings) -> AppTheme {
        var key = settings.keyColor.color
        var title = settings.titleColor.color
        var label = settings.labelColor.color
        var accent = settings.accentColor.color

        // Adapt colors for dark mode if enabled
        if settings.adaptToDarkMode {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if !isDark {
                // Darken colors for light backgrounds
                key = darken(settings.keyColor.nsColor)
                title = Color.black
                label = Color(white: 0.35)
                accent = darken(settings.accentColor.nsColor)
            }
        }

        return AppTheme(
            keyColor: key,
            titleColor: title,
            labelColor: label,
            dimColor: label.opacity(0.6),
            accentColor: accent,
            baseFontSize: settings.fontSize
        )
    }

    private static func darken(_ color: NSColor) -> Color {
        let c = color.usingColorSpace(.sRGB) ?? color
        return Color(NSColor(red: c.redComponent * 0.6,
                             green: c.greenComponent * 0.6,
                             blue: c.blueComponent * 0.6,
                             alpha: 1))
    }

    func font(_ style: Font.TextStyle) -> Font {
        let offset: CGFloat
        switch style {
        case .title3: offset = 4
        case .headline: offset = 2
        case .subheadline: offset = 0
        case .body: offset = 1
        case .callout: offset = 0
        case .caption: offset = -2
        case .caption2: offset = -3
        default: offset = 0
        }
        return .system(size: baseFontSize + offset)
    }

    func monoFont(_ style: Font.TextStyle) -> Font {
        let offset: CGFloat
        switch style {
        case .body: offset = 1
        case .callout: offset = 0
        default: offset = 0
        }
        return .system(size: baseFontSize + offset, design: .monospaced)
    }

    /// Material for the panel background
    static func material(adaptToDarkMode: Bool) -> NSVisualEffectView.Material {
        if adaptToDarkMode {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? .hudWindow : .sheet
        }
        return .hudWindow
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(
        keyColor: .cyan,
        titleColor: .white,
        labelColor: .gray,
        dimColor: Color.gray.opacity(0.6),
        accentColor: .yellow,
        baseFontSize: 13
    )
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
