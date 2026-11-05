import Foundation

// Rotas conferidas no código-fonte do slskd 0.26.2 (Controllers de Messaging,
// Transfers, Users, Shares, Searches). Corpo de mensagem e de entrada em sala é
// uma string JSON, não um objeto.

extension SlskdClient {
    private func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func jsonString(_ value: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
    }

    // MARK: Conversas

    func conversations(includeInactive: Bool = true) async throws -> [Conversation] {
        let data = try await send("/api/v0/conversations?includeInactive=\(includeInactive)")
        return try decode([Conversation].self, from: data)
    }

    func chatMessages(with username: String) async throws -> [ChatMessage] {
        let data = try await send("/api/v0/conversations/\(escaped(username))/messages")
        return try decode([ChatMessage].self, from: data)
    }

    func sendChat(_ text: String, to username: String) async throws {
        _ = try await send("/api/v0/conversations/\(escaped(username))",
                           method: "POST", body: try jsonString(text))
    }

    func acknowledgeChat(_ username: String) async throws {
        _ = try await send("/api/v0/conversations/\(escaped(username))", method: "PUT")
    }

    func acknowledgeMessage(_ id: String, from username: String) async throws {
        _ = try await send("/api/v0/conversations/\(escaped(username))/\(escaped(id))", method: "PUT")
    }

    func closeConversation(_ username: String) async throws {
        _ = try await send("/api/v0/conversations/\(escaped(username))", method: "DELETE")
    }

    // MARK: Salas

    func availableRooms() async throws -> [RoomInfo] {
        let data = try await send("/api/v0/rooms/available")
        return try decode([RoomInfo].self, from: data)
    }

    /// A API devolve lista quando vazia e dicionário quando há salas; aceita os dois.
    func joinedRooms() async throws -> [RoomInfo] {
        let data = try await send("/api/v0/rooms/joined")
        if let list = try? JSONDecoder().decode([RoomInfo].self, from: data) {
            return list
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var rooms: [RoomInfo] = []
        for value in root.values {
            guard let inner = value as? [String: Any] else { continue }
            for candidate in inner.values {
                guard let object = candidate as? [String: Any] else { continue }
                guard let encoded = try? JSONSerialization.data(withJSONObject: object) else { continue }
                if let room = try? JSONDecoder().decode(RoomInfo.self, from: encoded) {
                    rooms.append(room)
                }
            }
        }
        return rooms
    }

    func joinRoom(_ name: String) async throws {
        _ = try await send("/api/v0/rooms/joined", method: "POST", body: try jsonString(name))
    }

    func leaveRoom(_ name: String) async throws {
        _ = try await send("/api/v0/rooms/joined/\(escaped(name))", method: "DELETE")
    }

    func roomMessages(_ name: String) async throws -> [RoomMessage] {
        let data = try await send("/api/v0/rooms/joined/\(escaped(name))/messages")
        return try decode([RoomMessage].self, from: data)
    }

    func sendRoom(_ text: String, to name: String) async throws {
        _ = try await send("/api/v0/rooms/joined/\(escaped(name))/messages",
                           method: "POST", body: try jsonString(text))
    }

    func roomUsers(_ name: String) async throws -> [String] {
        let data = try await send("/api/v0/rooms/joined/\(escaped(name))/users")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { $0["username"] as? String }
    }

    // MARK: Usuário

    func userStatus(_ username: String) async throws -> UserStatus {
        let data = try await send("/api/v0/users/\(escaped(username))/status")
        return try decode(UserStatus.self, from: data)
    }

    func userInfo(_ username: String) async throws -> UserInfo {
        let data = try await send("/api/v0/users/\(escaped(username))/info")
        return try decode(UserInfo.self, from: data)
    }

    func browse(_ username: String) async throws -> BrowseResult {
        let data = try await send("/api/v0/users/\(escaped(username))/browse")
        return try decode(BrowseResult.self, from: data)
    }

    func browseStatus(_ username: String) async throws -> BrowseStatus {
        let data = try await send("/api/v0/users/\(escaped(username))/browse/status")
        return try decode(BrowseStatus.self, from: data)
    }

    // MARK: Transferências

    func transferPosition(username: String, id: String) async throws -> Int? {
        let data = try await send("/api/v0/transfers/downloads/\(escaped(username))/\(escaped(id))/position")
        if let number = try? JSONDecoder().decode(Int.self, from: data) { return number }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object["position"] as? Int
        }
        return nil
    }

    func clearCompletedDownloads() async throws {
        _ = try await send("/api/v0/transfers/downloads/all/completed", method: "DELETE")
    }

    func clearCompletedUploads() async throws {
        _ = try await send("/api/v0/transfers/uploads/all/completed", method: "DELETE")
    }

    // MARK: Eventos

    func events() async throws -> [EventItem] {
        let data = try await send("/api/v0/events")
        return try decode([EventItem].self, from: data)
    }
}
