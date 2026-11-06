import Foundation

extension SlskdClient {
    private func seg2(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: Grupos e banidos

    func groups() async throws -> [String: [String]] {
        let data = try await send("/api/v0/groups")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: [String]]
        return object ?? [:]
    }

    func createGroup(_ name: String) async throws {
        _ = try await send("/api/v0/groups/\(seg2(name))", method: "PUT")
    }

    func deleteGroup(_ name: String) async throws {
        _ = try await send("/api/v0/groups/\(seg2(name))", method: "DELETE")
    }

    func addGroupMember(_ group: String, _ username: String) async throws {
        _ = try await send("/api/v0/groups/\(seg2(group))/members/\(seg2(username))", method: "PUT")
    }

    func removeGroupMember(_ group: String, _ username: String) async throws {
        _ = try await send("/api/v0/groups/\(seg2(group))/members/\(seg2(username))", method: "DELETE")
    }

    func banned() async throws -> [String] {
        let data = try await send("/api/v0/banned")
        return (try JSONSerialization.jsonObject(with: data) as? [String]) ?? []
    }

    func ban(_ username: String) async throws {
        _ = try await send("/api/v0/banned/\(seg2(username))", method: "PUT")
    }

    func unban(_ username: String) async throws {
        _ = try await send("/api/v0/banned/\(seg2(username))", method: "DELETE")
    }

    // MARK: Atividade

    struct ActivityItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let at: String
    }

    private func activity(_ path: String, title: (String) -> String, detail: ([String: Any]) -> String) async throws -> [ActivityItem] {
        let data = try await send(path)
        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return list.map { item in
            ActivityItem(
                title: title(item["username"] as? String ?? "?"),
                detail: detail(item),
                at: item["at"] as? String ?? ""
            )
        }
    }

    func receivedSearches() async throws -> [ActivityItem] {
        try await activity("/api/v0/searches/received", title: { $0 }, detail: { ($0["query"] as? String) ?? "" })
    }

    func chatLog() async throws -> [ActivityItem] {
        try await activity("/api/v0/logs/chat", title: { user in
            user
        }, detail: { item in
            let room = (item["room"] as? String) ?? "privado"
            return "[\(room)] \((item["message"] as? String) ?? "")"
        })
    }

    func deniedLog() async throws -> [ActivityItem] {
        try await activity("/api/v0/logs/denied", title: { $0 }, detail: { item in
            let name = ((item["filename"] as? String) ?? "").split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? ""
            return "\(name) — \((item["reason"] as? String) ?? "")"
        })
    }

    // MARK: Shares e uploads (edição de config com backup)

    func configShares() async throws -> (directories: [String], filters: [String]) {
        let data = try await send("/api/v0/config/shares")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return ((object["directories"] as? [String]) ?? [], (object["filters"] as? [String]) ?? [])
    }

    func applyConfigShares(directories: [String], filters: [String]) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["directories": directories, "filters": filters])
        let data = try await send("/api/v0/config/shares", method: "PUT", body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (object["backup"] as? String) ?? "sem backup informado"
    }

    func uploadsEnabled() async throws -> Bool {
        let data = try await send("/api/v0/config/uploads")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (object["uploadsEnabled"] as? Bool) ?? true
    }

    func setUploads(enabled: Bool) async throws {
        _ = try await send("/api/v0/config/uploads?enabled=\(enabled)", method: "POST")
    }

    // MARK: Porta de escuta

    func listenPort() async throws -> Int? {
        let data = try await send("/api/v0/options")
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let soulseek = root?["soulseek"] as? [String: Any]
        return soulseek?["listenPort"] as? Int
    }

    func setListenPort(_ port: Int) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["soulseek": ["listenPort": port]])
        _ = try await send("/api/v0/options", method: "PATCH", body: body)
    }
}
