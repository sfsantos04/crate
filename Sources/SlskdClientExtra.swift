import Foundation

extension SlskdClient {
    private func esc(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    // MARK: Uploads

    func cancelUpload(username: String, id: String) async throws {
        _ = try await send("/api/v0/transfers/uploads/\(esc(username))/\(esc(id))?remove=true",
                           method: "DELETE")
    }

    func uploadPosition(username: String, id: String) async throws -> Int? {
        let data = try await send("/api/v0/transfers/uploads/\(esc(username))/\(esc(id))/position")
        if let number = try? JSONDecoder().decode(Int.self, from: data) { return number }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object["position"] as? Int
        }
        return nil
    }

    // MARK: Shares

    func sharesRaw() async throws -> Data {
        try await send("/api/v0/shares")
    }

    func rescanShares() async throws {
        _ = try await send("/api/v0/shares", method: "PUT")
    }

    func cancelShareScan() async throws {
        _ = try await send("/api/v0/shares", method: "DELETE")
    }
}
