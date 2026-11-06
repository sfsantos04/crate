import Foundation

struct FileEntry: Identifiable {
    let name: String
    let isDirectory: Bool
    let size: Int64
    var id: String { name }
}

extension SlskdClient {
    func listFiles(path: String) async throws -> (path: String, root: String, entries: [FileEntry]) {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        let data = try await send("/api/v0/files?path=\(encoded)")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let raw = (object["entries"] as? [[String: Any]]) ?? []
        let entries = raw.compactMap { item -> FileEntry? in
            guard let name = item["name"] as? String else { return nil }
            return FileEntry(name: name,
                             isDirectory: (item["type"] as? String) == "directory",
                             size: (item["size"] as? Int64) ?? Int64((item["size"] as? Int) ?? 0))
        }
        return ((object["path"] as? String) ?? "", (object["root"] as? String) ?? "", entries)
    }

    func destinationPattern() async throws -> String {
        let data = try await send("/api/v0/config/destination")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (object["subdirectory"] as? String) ?? "${SOURCE_DIRECTORY}"
    }

    func setDestinationPattern(_ pattern: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["subdirectory": pattern])
        let data = try await send("/api/v0/config/destination", method: "PUT", body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return (object["backup"] as? String) ?? ""
    }
}
