import SwiftUI

/// Tokens visuais do Sonda: um só lugar para cor, tipografia e superfícies.
enum Theme {
    static let ink = Color(red: 0.05, green: 0.08, blue: 0.15)
    static let deep = Color(red: 0.07, green: 0.16, blue: 0.31)
    static let accent = Color(red: 0.357, green: 0.906, blue: 1.000)
    static let accentSoft = Color(red: 0.357, green: 0.906, blue: 1.000).opacity(0.16)
    static let ok = Color(red: 0.29, green: 0.85, blue: 0.55)
    static let warn = Color(red: 1.00, green: 0.75, blue: 0.31)
    static let danger = Color(red: 1.00, green: 0.42, blue: 0.42)

    static var hero: LinearGradient {
        LinearGradient(colors: [deep, ink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var markGradient: LinearGradient {
        LinearGradient(colors: [accent, .white], startPoint: .top, endPoint: .bottom)
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
