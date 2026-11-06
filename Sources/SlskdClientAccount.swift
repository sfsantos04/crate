import Foundation

extension SlskdClient {
    private func seg3(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // Conta
    func changePassword(_ password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: password, options: .fragmentsAllowed)
        _ = try await send("/api/v0/profile/password", method: "PUT", body: body)
    }

    // Salas
    func createRoom(_ name: String, isPrivate: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["roomName": name, "isPrivate": isPrivate])
        _ = try await send("/api/v0/rooms/create", method: "POST", body: body)
    }

    // Limites por usuário
    func userLimit(_ username: String) async throws -> (concurrent: Int, maxMB: Int) {
        let data = try await send("/api/v0/limits/\(seg3(username))")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return ((object["maxConcurrent"] as? Int) ?? 0, (object["maxMB"] as? Int) ?? 0)
    }

    func setUserLimit(_ username: String, concurrent: Int, maxMB: Int) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["maxConcurrent": concurrent, "maxMB": maxMB])
        _ = try await send("/api/v0/limits/\(seg3(username))", method: "PUT", body: body)
    }

    // Pastas com download pausado
    func pausedFolders() async throws -> [String] {
        let data = try await send("/api/v0/config/paused-folders")
        return (try JSONSerialization.jsonObject(with: data) as? [String]) ?? []
    }

    func setPausedFolders(_ folders: [String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: folders)
        _ = try await send("/api/v0/config/paused-folders", method: "PUT", body: body)
    }
}
