import Foundation

/// Filtro de status da lista de transferências.
enum TransferFilter: Int, CaseIterable, Identifiable {
    case all = 0
    case active = 1
    case queued = 2
    case done = 3
    case failed = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .all: return "Todos"
        case .active: return "Ativos"
        case .queued: return "Fila"
        case .done: return "Concluídos"
        case .failed: return "Falhas"
        }
    }

    func matches(_ file: TransferFile) -> Bool {
        let state = (file.state ?? "").lowercased()

        switch self {
        case .all:
            return true
        case .active:
            return state.contains("inprogress") || state.contains("initializing")
        case .queued:
            return state.contains("queued") || state.contains("requested")
        case .done:
            return state.contains("succeeded")
        case .failed:
            return state.contains("errored") || state.contains("timedout") || state.contains("rejected")
                || state.contains("failed")
        }
    }
}
