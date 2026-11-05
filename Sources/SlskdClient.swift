import Foundation

enum SlskdError: LocalizedError, Equatable {
    case badHost
    case unauthorized
    case http(Int, String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .badHost:
            return "Endereço inválido. Use host:porta, por exemplo 10.0.0.10:5030."
        case .unauthorized:
            return "Usuário ou senha recusados pelo slskd."
        case .http(let code, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "O slskd respondeu HTTP \(code)." : "HTTP \(code): \(trimmed)"
        case .malformed(let detail):
            return "Resposta inesperada do slskd: \(detail)"
        }
    }
}

/// Cliente fino sobre a API v0 do slskd.
/// Autentica por JWT em /api/v0/session e renova sozinho quando o token expira.
actor SlskdClient {
    private var baseURL: URL?
    private var token: String?
    private var username = ""
    private var password = ""

    // MARK: Configuração

    static func normalizeHost(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }

    func configure(host: String, username: String, password: String) throws {
        guard let url = Self.normalizeHost(host) else { throw SlskdError.badHost }
        self.baseURL = url
        self.username = username
        self.password = password
        self.token = nil
    }

    func clear() {
        token = nil
        username = ""
        password = ""
    }

    // MARK: Sessão

    @discardableResult
    func login(host: String, username: String, password: String) async throws -> String {
        try configure(host: host, username: username, password: password)
        return try await fetchToken()
    }

    private func fetchToken() async throws -> String {
        guard let base = baseURL else { throw SlskdError.badHost }
        guard let url = URL(string: "/api/v0/session", relativeTo: base) else { throw SlskdError.badHost }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: String] = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SlskdError.malformed("sem resposta HTTP") }
        if http.statusCode == 401 { throw SlskdError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw SlskdError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["token"] as? String else {
            throw SlskdError.malformed("session sem campo token")
        }
        token = value
        return value
    }

    private func ensureToken() async throws {
        if token == nil {
            _ = try await fetchToken()
        }
    }

    // MARK: Transporte

    private func raw(_ path: String, method: String, body: Data?) async throws -> Data {
        guard let base = baseURL else { throw SlskdError.badHost }
        guard let url = URL(string: path, relativeTo: base) else { throw SlskdError.badHost }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SlskdError.malformed("sem resposta HTTP") }
        if http.statusCode == 401 { throw SlskdError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw SlskdError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// Uma repetição em caso de 401: renova o token e repete.
    private func send(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        try await ensureToken()
        do {
            return try await raw(path, method: method, body: body)
        } catch SlskdError.unauthorized {
            token = nil
            _ = try await fetchToken()
            return try await raw(path, method: method, body: body)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SlskdError.malformed(String(describing: error))
        }
    }

    // MARK: Estado

    func serverState() async throws -> ServerState {
        let data = try await send("/api/v0/server")
        return try decode(ServerState.self, from: data)
    }

    func setConnected(_ connected: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["isConnected": connected])
        _ = try await send("/api/v0/server", method: "PUT", body: body)
    }

    func application() async throws -> ApplicationSnapshot {
        let data = try await send("/api/v0/application")
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SlskdError.malformed("application não é objeto")
        }
        var snapshot = ApplicationSnapshot()
        if let version = root["version"] as? [String: Any] {
            snapshot.version = (version["full"] as? String) ?? (version["current"] as? String) ?? "—"
        }
        if let user = root["user"] as? [String: Any] {
            snapshot.username = (user["username"] as? String) ?? "—"
            if let privileges = user["privileges"] as? [String: Any] {
                snapshot.privileged = (privileges["isPrivileged"] as? Bool) ?? false
            }
        }
        if let shares = root["shares"] as? [String: Any] {
            snapshot.shareDirectories = (shares["directories"] as? Int) ?? 0
            snapshot.shareFiles = (shares["files"] as? Int) ?? 0
        }
        if let distributed = root["distributedNetwork"] as? [String: Any] {
            snapshot.branchLevel = (distributed["branchLevel"] as? Int) ?? 0
            snapshot.parent = (distributed["parent"] as? String) ?? ""
            snapshot.distributedConnected = (distributed["hasParent"] as? Bool) ?? false
        }
        snapshot.pendingRestart = (root["pendingRestart"] as? Bool) ?? false
        return snapshot
    }

    // MARK: Busca

    func startSearch(text: String) async throws -> SearchResultSet {
        let body = try JSONSerialization.data(withJSONObject: ["searchText": text])
        let data = try await send("/api/v0/searches", method: "POST", body: body)
        return try decode(SearchResultSet.self, from: data)
    }

    func search(id: String, includeResponses: Bool = true) async throws -> SearchResultSet {
        let suffix = includeResponses ? "?includeResponses=true" : ""
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await send("/api/v0/searches/\(escaped)\(suffix)")
        return try decode(SearchResultSet.self, from: data)
    }

    func recentSearches() async throws -> [SearchResultSet] {
        let data = try await send("/api/v0/searches")
        return try decode([SearchResultSet].self, from: data)
    }

    func deleteSearch(id: String) async throws {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await send("/api/v0/searches/\(escaped)", method: "DELETE")
    }

    // MARK: Transferências

    func downloads() async throws -> [TransferUser] {
        let data = try await send("/api/v0/transfers/downloads")
        return try decode([TransferUser].self, from: data)
    }

    func uploads() async throws -> [TransferUser] {
        let data = try await send("/api/v0/transfers/uploads")
        return try decode([TransferUser].self, from: data)
    }

    func enqueue(username: String, files: [(filename: String, size: Int64)]) async throws {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let payload = files.map { ["filename": $0.filename, "size": $0.size] as [String: Any] }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await send("/api/v0/transfers/downloads/\(escaped)", method: "POST", body: body)
    }

    func cancel(username: String, transferID: String) async throws {
        let user = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let id = transferID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? transferID
        _ = try await send("/api/v0/transfers/downloads/\(user)/\(id)?remove=false", method: "DELETE")
    }

    // MARK: Conversas

    func conversations() async throws -> [String] {
        let data = try await send("/api/v0/conversations")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { $0["username"] as? String }
    }
}
