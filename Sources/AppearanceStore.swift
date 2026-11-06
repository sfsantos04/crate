import SwiftUI

enum ThemeAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Resolve "sistema" para claro/escuro na hora de escolher a paleta.
    var resolved: ThemeAppearance {
        guard self == .system else { return self }
        return UITraitCollection.current.userInterfaceStyle == .light ? .light : .dark
    }
}

/// Guarda o tema escolhido, aplica na paleta global e força o app a redesenhar.
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published private(set) var appearance: ThemeAppearance
    @Published private(set) var revision = 0

    private let appearanceKey = "themeAppearance"

    private init() {
        appearance = ThemeAppearance(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "") ?? .system
        apply()
    }

    func set(appearance newAppearance: ThemeAppearance) {
        guard newAppearance != appearance else { return }
        appearance = newAppearance
        UserDefaults.standard.set(newAppearance.rawValue, forKey: appearanceKey)
        apply()
    }

    private func apply() {
        Theme.current = Palettes.sonda(appearance.resolved)
        revision += 1
    }
}
