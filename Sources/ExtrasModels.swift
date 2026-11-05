import Foundation

struct Buddy: Decodable, Identifiable {
    var username: String?
    var addedAt: String?

    var id: String { username ?? UUID().uuidString }
}

struct WishlistItem: Decodable, Identifiable {
    var id: String?
    var text: String?
    var intervalMinutes: Int?
    var createdAt: String?
    var lastRunAt: String?
    var lastHitCount: Int?

    var ident: String { id ?? UUID().uuidString }
}

struct NoteResponse: Decodable {
    var username: String?
    var note: String?
}
