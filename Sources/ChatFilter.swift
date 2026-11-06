import Foundation

/// Filtro de palavras compartilhado entre busca e chat (mesma lista salva).
enum ChatFilter {
    static func terms(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            .filter { !$0.isEmpty }
    }

    static func isBlocked(_ text: String?, raw: String) -> Bool {
        let list = terms(raw)
        guard !list.isEmpty, let text else { return false }
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return list.contains { folded.contains($0) }
    }
}
