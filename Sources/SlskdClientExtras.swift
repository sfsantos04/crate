import Foundation

/// Buddy list, ignore list, notas e wishlist — endpoints do fork (ExtrasController).
extension SlskdClient {
    private func seg(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: Buddy list

    func buddies() async throws -> [Buddy] {
        let data = try await send("/api/v0/buddies")
        return try decode([Buddy].self, from: data)
    }

    func addBuddy(_ username: String) async throws {
        _ = try await send("/api/v0/buddies/\(seg(username))", method: "PUT")
    }

    func removeBuddy(_ username: String) async throws {
        _ = try await send("/api/v0/buddies/\(seg(username))", method: "DELETE")
    }

    // MARK: Ignore list

    func ignoredUsers() async throws -> [String] {
        let data = try await send("/api/v0/ignored")
        return try decode([String].self, from: data)
    }

    func addIgnored(_ username: String) async throws {
        _ = try await send("/api/v0/ignored/\(seg(username))", method: "PUT")
    }

    func removeIgnored(_ username: String) async throws {
        _ = try await send("/api/v0/ignored/\(seg(username))", method: "DELETE")
    }

    // MARK: Notas

    func note(for username: String) async throws -> String {
        let data = try await send("/api/v0/notes/\(seg(username))")
        let decoded = try decode(NoteResponse.self, from: data)
        return decoded.note ?? ""
    }

    func setNote(_ text: String, for username: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: text, options: .fragmentsAllowed)
        _ = try await send("/api/v0/notes/\(seg(username))", method: "PUT", body: body)
    }

    // MARK: Wishlist

    func wishlist() async throws -> [WishlistItem] {
        let data = try await send("/api/v0/wishlist")
        return try decode([WishlistItem].self, from: data)
    }

    func addWishlist(text: String, intervalMinutes: Int) async throws -> WishlistItem {
        let body = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "intervalMinutes": intervalMinutes,
        ])
        let data = try await send("/api/v0/wishlist", method: "POST", body: body)
        return try decode(WishlistItem.self, from: data)
    }

    func removeWishlist(id: String) async throws {
        _ = try await send("/api/v0/wishlist/\(seg(id))", method: "DELETE")
    }

    func runWishlist(id: String) async throws -> WishlistItem {
        // a busca roda no servidor por ~20s antes de responder
        let data = try await send("/api/v0/wishlist/\(seg(id))/run", method: "POST")
        return try decode(WishlistItem.self, from: data)
    }
}
