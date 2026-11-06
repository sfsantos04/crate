import Foundation

extension SlskdClient {
    private func segX(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // Operadores e convite de sala
    func addRoomOperator(_ room: String, _ username: String) async throws {
        _ = try await send("/api/v0/rooms/\(segX(room))/operators/\(segX(username))", method: "PUT")
    }

    func removeRoomOperator(_ room: String, _ username: String) async throws {
        _ = try await send("/api/v0/rooms/\(segX(room))/operators/\(segX(username))", method: "DELETE")
    }

    func inviteRoomMember(_ room: String, _ username: String) async throws {
        _ = try await send("/api/v0/rooms/\(segX(room))/members/\(segX(username))", method: "PUT")
    }

    // Status de usuário (para saber quem da buddy list está online)
    func userStatus(_ username: String) async throws -> String {
        let data = try await send("/api/v0/users/\(segX(username))/status")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let online = object["presence"] as? String { return online }
        if let status = object["status"] as? String { return status }
        return "unknown"
    }

    // Logs
    func logFiles() async throws -> [String] {
        let data = try await send("/api/v0/logs/files")
        if let list = try JSONSerialization.jsonObject(with: data) as? [String] { return list }
        if let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return list.compactMap { $0["filename"] as? String ?? $0["name"] as? String }
        }
        return []
    }

    func logContent(_ filename: String) async throws -> String {
        let data = try await send("/api/v0/logs/files/\(segX(filename))")
        return String(data: data, encoding: .utf8) ?? ""
    }
}
