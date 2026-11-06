import SwiftUI

/// Paleta de um tema. Cada estilo tem versão clara e escura.
struct ThemePalette {
    let heroTop: Color
    let heroBottom: Color
    let accent: Color
    let ok: Color
    let warn: Color
    let danger: Color
}

/// Tokens visuais do Sonda: o tema atual decide as cores, o resto do app não muda.
enum Theme {
    static var current: ThemePalette = Palettes.sonda(.dark)

    static var ink: Color { current.heroBottom }
    static var deep: Color { current.heroTop }
    static var accent: Color { current.accent }
    static var accentSoft: Color { current.accent.opacity(0.16) }
    static var ok: Color { current.ok }
    static var warn: Color { current.warn }
    static var danger: Color { current.danger }

    static var hero: LinearGradient {
        LinearGradient(colors: [current.heroTop, current.heroBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var markGradient: LinearGradient {
        LinearGradient(colors: [current.accent, .white], startPoint: .top, endPoint: .bottom)
    }
}

/// Estilos disponíveis, com as cores de cada um em claro e escuro.
enum Palettes {
    static func sonda(_ appearance: ThemeAppearance) -> ThemePalette {
        switch appearance {
        case .light:
            return ThemePalette(heroTop: Color(red: 0.13, green: 0.33, blue: 0.55),
                                heroBottom: Color(red: 0.06, green: 0.12, blue: 0.22),
                                accent: Color(red: 0.05, green: 0.55, blue: 0.78),
                                ok: Color(red: 0.10, green: 0.62, blue: 0.38),
                                warn: Color(red: 0.85, green: 0.55, blue: 0.10),
                                danger: Color(red: 0.82, green: 0.22, blue: 0.22))
        default:
            return ThemePalette(heroTop: Color(red: 0.07, green: 0.16, blue: 0.31),
                                heroBottom: Color(red: 0.05, green: 0.08, blue: 0.15),
                                accent: Color(red: 0.357, green: 0.906, blue: 1.000),
                                ok: Color(red: 0.29, green: 0.85, blue: 0.55),
                                warn: Color(red: 1.00, green: 0.75, blue: 0.31),
                                danger: Color(red: 1.00, green: 0.42, blue: 0.42))
        }
    }

    static func soulseek(_ appearance: ThemeAppearance) -> ThemePalette {
        switch appearance {
        case .light:
            return ThemePalette(heroTop: Color(red: 0.16, green: 0.26, blue: 0.52),
                                heroBottom: Color(red: 0.07, green: 0.13, blue: 0.30),
                                accent: Color(red: 0.09, green: 0.32, blue: 0.63),
                                ok: Color(red: 0.16, green: 0.55, blue: 0.24),
                                warn: Color(red: 0.79, green: 0.50, blue: 0.05),
                                danger: Color(red: 0.72, green: 0.13, blue: 0.13))
        default:
            return ThemePalette(heroTop: Color(red: 0.14, green: 0.22, blue: 0.44),
                                heroBottom: Color(red: 0.05, green: 0.09, blue: 0.20),
                                accent: Color(red: 0.45, green: 0.66, blue: 0.94),
                                ok: Color(red: 0.36, green: 0.78, blue: 0.45),
                                warn: Color(red: 0.95, green: 0.72, blue: 0.30),
                                danger: Color(red: 0.93, green: 0.40, blue: 0.40))
        }
    }

    static func nicotine(_ appearance: ThemeAppearance) -> ThemePalette {
        switch appearance {
        case .light:
            return ThemePalette(heroTop: Color(red: 0.30, green: 0.26, blue: 0.60),
                                heroBottom: Color(red: 0.14, green: 0.11, blue: 0.32),
                                accent: Color(red: 0.36, green: 0.29, blue: 0.78),
                                ok: Color(red: 0.13, green: 0.60, blue: 0.45),
                                warn: Color(red: 0.84, green: 0.52, blue: 0.12),
                                danger: Color(red: 0.80, green: 0.20, blue: 0.33))
        default:
            return ThemePalette(heroTop: Color(red: 0.20, green: 0.18, blue: 0.42),
                                heroBottom: Color(red: 0.09, green: 0.08, blue: 0.20),
                                accent: Color(red: 0.62, green: 0.55, blue: 0.98),
                                ok: Color(red: 0.38, green: 0.82, blue: 0.62),
                                warn: Color(red: 0.98, green: 0.72, blue: 0.36),
                                danger: Color(red: 0.96, green: 0.42, blue: 0.55))
        }
    }
}

struct HeroCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CountPill: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct EmptyState: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.accent.opacity(0.8))
            Text(title).font(.headline)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
