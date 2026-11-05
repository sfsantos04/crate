import Foundation

/// Cliente dos endpoints que existem apenas no fork do slskd (ProfileController).
/// O app só chama estes métodos depois que `forkAvailable()` confirma a rota.
extension SlskdClient {
    private func enc(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    /// 404 = slskd original; qualquer outra resposta = fork presente.
    func forkAvailable() async -> Bool {
        do {
            _ = try await send("/api/v0/profile/privileges")
            return true
        } catch let SlskdError.http(code, _) {
            return code != 404
        } catch {
            return false
        }
    }

    // MARK: Interesses locais

    func myInterests() async throws -> InterestPair {
        let data = try await send("/api/v0/profile/interests")
        return try decode(InterestPair.self, from: data)
    }

    func addInterest(_ kind: String, _ text: String) async throws {
        _ = try await send("/api/v0/profile/interests/\(kind)/\(enc(text))", method: "PUT")
    }

    func removeInterest(_ kind: String, _ text: String) async throws {
        _ = try await send("/api/v0/profile/interests/\(kind)/\(enc(text))", method: "DELETE")
    }

    // MARK: Perfil e descoberta

    func privileges() async throws -> PrivilegeStatus {
        let data = try await send("/api/v0/profile/privileges")
        return try decode(PrivilegeStatus.self, from: data)
    }

    func similarUsers() async throws -> [SimilarUser] {
        let data = try await send("/api/v0/recommendations/similar-users")
        return try decode([SimilarUser].self, from: data)
    }

    func recommendations(scope: String) async throws -> RecommendationSet {
        let data = try await send("/api/v0/recommendations/\(scope)")
        return try decode(RecommendationSet.self, from: data)
    }

    func userStatistics(_ username: String) async throws -> WatchedUser {
        let data = try await send("/api/v0/users/\(enc(username))/statistics")
        return try decode(WatchedUser.self, from: data)
    }

    func watchedUser(_ username: String) async throws -> WatchedUser {
        let data = try await send("/api/v0/users/\(enc(username))/watch", method: "PUT")
        return try decode(WatchedUser.self, from: data)
    }

    func unwatchUser(_ username: String) async throws {
        _ = try await send("/api/v0/users/\(enc(username))/watch", method: "DELETE")
    }

    func setStatus(away: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: away ? "away" : "online",
                                              options: .fragmentsAllowed)
        _ = try await send("/api/v0/profile/status", method: "PUT", body: body)
    }
}
