import Foundation

// MARK: - Servidor

struct ServerState: Decodable {
    var address: String?
    var ipEndPoint: String?
    var state: String?
    var isConnected: Bool?
    var isConnecting: Bool?
    var isLoggedIn: Bool?
    var isLoggingIn: Bool?
    var isTransitioning: Bool?

    var connected: Bool { isConnected ?? false }
    var loggedIn: Bool { isLoggedIn ?? false }
    var label: String { state ?? "Desconhecido" }
}

/// Resumo montado a partir de /api/v0/application sem tipagem rígida,
/// porque o objeto muda entre versões do slskd.
struct ApplicationSnapshot: Equatable {
    var version: String = "—"
    var username: String = "—"
    var privileged: Bool = false
    var shareDirectories: Int = 0
    var shareFiles: Int = 0
    var branchLevel: Int = 0
    var parent: String = ""
    var distributedConnected: Bool = false
    var pendingRestart: Bool = false
}

// MARK: - Transferências

struct TransferUser: Decodable, Identifiable {
    var username: String?
    var directories: [TransferDirectory]?

    var id: String { username ?? "?" }

    var files: [TransferFile] {
        (directories ?? []).flatMap { $0.files ?? [] }
    }
}

struct TransferDirectory: Decodable, Identifiable {
    var directory: String?
    var fileCount: Int?
    var files: [TransferFile]?

    var id: String { directory ?? "?" }
}

struct TransferFile: Decodable, Identifiable {
    var transferID: String?
    var username: String?
    var filename: String?
    var size: Int64?
    var bytesTransferred: Int64?
    var bytesRemaining: Int64?
    var averageSpeed: Double?
    var percentComplete: Double?
    var state: String?
    var direction: String?
    var attempts: Int?

    enum CodingKeys: String, CodingKey {
        case transferID = "id"
        case username, filename, size, bytesTransferred, bytesRemaining
        case averageSpeed, percentComplete, state, direction, attempts
    }

    var id: String { transferID ?? "\(username ?? "")|\(filename ?? "")" }

    var progress: Double {
        max(0, min(1, (percentComplete ?? 0) / 100))
    }

    var isFinished: Bool {
        (state ?? "").contains("Succeeded") || (state ?? "").contains("Failed")
            || (state ?? "").contains("Cancelled")
    }

    var isFailed: Bool {
        let s = state ?? ""
        return s.contains("Failed") || s.contains("Cancelled") || s.contains("Rejected")
    }
}

// MARK: - Busca

struct SearchResultSet: Decodable, Identifiable {
    var id: String?
    var searchText: String?
    var state: String?
    var isComplete: Bool?
    var fileCount: Int?
    var responseCount: Int?
    var responses: [SearchResponse]?

    var ident: String { id ?? "" }
    var complete: Bool { isComplete ?? false }

    var allFiles: [SearchFile] {
        (responses ?? []).flatMap { $0.files ?? [] }
    }
}

struct SearchResponse: Decodable, Identifiable {
    var token: Int?
    var username: String?
    var hasFreeUploadSlot: Bool?
    var queueLength: Int?
    var uploadSpeed: Int?
    var fileCount: Int?
    var files: [SearchFile]?

    var id: String { "\(token ?? 0)|\(username ?? "")" }
}

struct SearchFile: Decodable, Identifiable {
    var filename: String?
    var size: Int64?
    var fileExtension: String?
    var bitRate: Int?
    var length: Int?
    var isLocked: Bool?
    var code: Int?

    enum CodingKeys: String, CodingKey {
        case filename, size, bitRate, length, isLocked, code
        case fileExtension = "extension"
    }

    var id: String { "\(filename ?? "")|\(size ?? 0)" }

    var displayName: String { PathTail.of(filename) }
    var folder: String { PathTail.folder(of: filename) }
}

enum PathTail {
    static func of(_ path: String?) -> String {
        guard let p = path, !p.isEmpty else { return "?" }
        return p.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? p
    }

    static func folder(of path: String?) -> String {
        guard let p = path else { return "" }
        let parts = p.split(whereSeparator: { $0 == "\\" || $0 == "/" })
        guard parts.count > 1 else { return "" }
        return parts.dropLast().joined(separator: "/")
    }
}

// MARK: - Formatação

enum Fmt {
    static func bytes(_ value: Int64?) -> String {
        guard let v = value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }

    static func speed(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "—" }
        let mb = v / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB/s", mb) }
        return String(format: "%.0f KB/s", v / 1024)
    }

    static func eta(_ file: TransferFile) -> String {
        guard let remaining = file.bytesRemaining, let speed = file.averageSpeed, speed > 1, remaining > 0 else {
            return "—"
        }
        let seconds = Int(Double(remaining) / speed)
        if seconds >= 3600 { return "\(seconds / 3600)h \((seconds % 3600) / 60)m" }
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }

    static func duration(_ seconds: Int?) -> String {
        guard let s = seconds, s > 0 else { return "" }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func stateLabel(_ state: String?) -> String {
        guard let s = state, !s.isEmpty else { return "—" }
        if s.contains("Succeeded") { return "concluído" }
        if s.contains("InProgress") { return "baixando" }
        if s.contains("Queued") || s.contains("Requested") { return "na fila" }
        if s.contains("Initializing") { return "iniciando" }
        if s.contains("Cancelled") { return "cancelado" }
        if s.contains("Failed") || s.contains("Rejected") { return "falhou" }
        return s
    }
}
