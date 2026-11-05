import Foundation

/// id que a API devolve ora como número, ora como string.
struct LooseID: Decodable, Hashable {
    let value: String
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let number = try? container.decode(Int64.self) {
            value = String(number)
        } else {
            value = ""
        }
    }
}

// MARK: - Conversas

struct Conversation: Decodable, Identifiable {
    var username: String?
    var isActive: Bool?
    var unAcknowledgedMessageCount: Int?
    var hasUnAcknowledgedMessages: Bool?

    var id: String { username ?? "?" }
    var unread: Int { unAcknowledgedMessageCount ?? 0 }
}

struct ChatMessage: Decodable, Identifiable {
    var messageID: LooseID?
    var username: String?
    var direction: String?
    var message: String?
    var timestamp: String?
    var isAcknowledged: Bool?
    var wasReplayed: Bool?

    enum CodingKeys: String, CodingKey {
        case messageID = "id"
        case username, direction, message, timestamp, isAcknowledged, wasReplayed
    }

    var id: String { messageID?.value ?? "\(timestamp ?? "")|\(message ?? "")" }
    var incoming: Bool { (direction ?? "In").lowercased() == "in" }
}

// MARK: - Salas

struct RoomInfo: Decodable, Identifiable {
    var name: String?
    var userCount: Int?
    var isPrivate: Bool?
    var isModerated: Bool?
    var isOwned: Bool?

    var id: String { name ?? "?" }
}

struct RoomMessage: Decodable, Identifiable {
    var messageID: LooseID?
    var username: String?
    var message: String?
    var timestamp: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "id"
        case username, message, timestamp
    }

    var id: String { messageID?.value ?? "\(timestamp ?? "")|\(message ?? "")" }
}

// MARK: - Usuário

struct UserStatus: Decodable {
    var isPrivileged: Bool?
    var presence: String?
}

struct UserInfo: Decodable {
    var description: String?
    var hasFreeUploadSlot: Bool?
    var queueLength: Int?
    var uploadSlots: Int?
    var hasPicture: Bool?
}

struct BrowseStatus: Decodable {
    var bytesTransferred: Int64?
    var bytesRemaining: Int64?
    var percentComplete: Double?
    var size: Int64?
    var username: String?

    var progress: Double { max(0, min(1, (percentComplete ?? 0) / 100)) }
    var done: Bool { (bytesRemaining ?? 1) == 0 }
}

struct BrowseFile: Decodable, Identifiable {
    var filename: String?
    var size: Int64?
    var fileExtension: String?

    enum CodingKeys: String, CodingKey {
        case filename, size
        case fileExtension = "extension"
    }

    var id: String { "\(filename ?? "")|\(size ?? 0)" }
    var displayName: String { PathTail.of(filename) }
}

struct BrowseDirectory: Decodable, Identifiable {
    var name: String?
    var fileCount: Int?
    var files: [BrowseFile]?

    var id: String { name ?? "?" }
}

struct BrowseResult: Decodable {
    var directories: [BrowseDirectory]?
    var directoryCount: Int?
    var lockedDirectories: [BrowseDirectory]?
    var lockedDirectoryCount: Int?
}

// MARK: - Eventos

struct EventItem: Decodable, Identifiable {
    var timestamp: String?
    var type: String?
    var data: String?

    var id: String { "\(timestamp ?? "")|\(type ?? "")" }

    var friendly: String {
        let raw = type ?? "evento"
        return raw
            .replacingOccurrences(of: "SoulseekClient", with: "")
            .replacingOccurrences(of: "Transfer", with: "transferência ")
    }
}
