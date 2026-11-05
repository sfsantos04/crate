import Foundation

extension SlskdClient {
    /// Token atual (para o WebSocket, que autentica por query).
    func currentToken() -> String? { token }

    /// Negocia o hub e devolve a URL de WebSocket já autenticada.
    func hubURL(path: String = "/hub/application") async throws -> URL? {
        guard let base = baseURL else { return nil }
        let separator = path.contains("?") ? "&" : "?"
        let data = try await send("\(path)/negotiate\(separator)negotiateVersion=1")
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let connectionToken = object["connectionToken"] as? String else {
            return nil
        }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.scheme = (base.scheme == "https") ? "wss" : "ws"
        components?.path = path
        var items = [URLQueryItem(name: "id", value: connectionToken)]
        if let token { items.append(URLQueryItem(name: "access_token", value: token)) }
        components?.queryItems = items
        return components?.url
    }

    // Browse de um diretório específico do peer.
    func browseDirectory(username: String, directory: String) async throws -> [BrowseDirectory] {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let body = try JSONSerialization.data(withJSONObject: ["directory": directory])
        let data = try await send("/api/v0/users/\(escaped)/directory", method: "POST", body: body)
        return try decode([BrowseDirectory].self, from: data)
    }
}
