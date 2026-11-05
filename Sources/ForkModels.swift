import Foundation

/// Modelos dos recursos que só existem no fork (Soulseek.NET master).
struct InterestPair: Decodable {
    var liked: [String]?
    var hated: [String]?

    var likes: [String] { liked ?? [] }
    var hates: [String] { hated ?? [] }
}

struct SimilarUser: Decodable, Identifiable {
    var username: String?
    var rating: Int?

    var id: String { username ?? UUID().uuidString }
}

struct Recommendation: Decodable, Identifiable {
    var interest: String?
    var count: Int?

    var id: String { interest ?? UUID().uuidString }
}

struct RecommendationSet: Decodable {
    var recommended: [Recommendation]?
    var notRecommended: [Recommendation]?

    var yes: [Recommendation] { recommended ?? [] }
    var no: [Recommendation] { notRecommended ?? [] }
}

struct PrivilegeStatus: Decodable {
    var daysRemaining: Int?
}

struct WatchedUser: Decodable {
    var username: String?
    var countryCode: String?
    var status: String?
    var fileCount: Int?
    var directoryCount: Int?
    var averageSpeed: Double?
    var uploadCount: Int?

    var countryName: String? {
        guard let code = countryCode, code.count == 2 else { return nil }
        return Locale.current.localizedString(forRegionCode: code.uppercased())
    }

    var flag: String? {
        guard let code = countryCode, code.count == 2 else { return nil }
        return CountryFlag.emoji(for: code)
    }
}
