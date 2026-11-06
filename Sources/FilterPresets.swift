import Foundation

/// Conjunto de filtros salvos com nome, guardado no aparelho.
struct FilterPreset: Codable, Identifiable {
    var name: String
    var filters: SearchFilters

    var id: String { name }
}

enum FilterPresetStore {
    private static let key = "searchFilterPresets"

    static func load() -> [FilterPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([FilterPreset].self, from: data) else {
            return []
        }
        return list
    }

    static func save(_ presets: [FilterPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
