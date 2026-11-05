import Foundation

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    // Sessão
    @Published var host: String = UserDefaults.standard.string(forKey: "host") ?? ""
    @Published var username: String = UserDefaults.standard.string(forKey: "username") ?? ""
    @Published var isSignedIn = false
    @Published var busy = false
    @Published var errorMessage: String?

    // Estado do servidor
    @Published var server: ServerState?
    @Published var snapshot: ApplicationSnapshot?
    @Published var downloads: [TransferUser] = []
    @Published var uploads: [TransferUser] = []
    @Published var lastUpdate: Date?

    // Busca
    @Published var query = ""
    @Published var search: SearchResultSet?
    @Published var searching = false
    @Published var searchMessage: String?

    // Social, navegação e diagnóstico
    @Published var conversations: [Conversation] = []
    @Published var activePeer: String?
    @Published var thread: [ChatMessage] = []
    @Published var rooms: [RoomInfo] = []
    @Published var joinedRooms: [RoomInfo] = []
    @Published var activeRoom: String?
    @Published var roomThread: [RoomMessage] = []
    @Published var browsePeer: String?
    @Published var browseDirectories: [BrowseDirectory] = []
    @Published var browseProgress: Double = 0
    @Published var events: [EventItem] = []
    @Published var positions: [String: Int] = [:]
    @Published var socialBusy = false
    @Published var realtimeConnected = false

    // Recursos do fork (detectados em runtime)
    @Published var forkMode = false
    @Published var myLikes: [String] = []
    @Published var myHates: [String] = []
    @Published var similar: [SimilarUser] = []
    @Published var globalRecommendations: [Recommendation] = []
    @Published var personalRecommendations: [Recommendation] = []
    @Published var privilegesDays: Int?
    @Published var profileNote: String?
    @Published var profileLoading = false

    /// Mensagem curta de retorno de ação (enfileirou, falhou, entrou na sala).
    @Published var actionMessage: String?

    // Listas e wishlist (fork)
    @Published var buddies: [Buddy] = []
    @Published var ignoredUsers: [String] = []
    @Published var wishlist: [WishlistItem] = []
    @Published var wishlistBusy = false

    let realtime = RealtimeClient()

    let client = SlskdClient()
    private var monitor: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    // MARK: Ciclo de vida

    func bootstrap() async {
        guard !isSignedIn else { return }
        guard let password = Keychain.get("password"), !username.isEmpty else { return }
        await signIn(host: host, username: username, password: password, quiet: true)
    }

    func signIn(host: String, username: String, password: String, quiet: Bool = false) async {
        busy = true
        errorMessage = nil
        do {
            try await client.configure(host: host, username: username, password: password)
            _ = try await client.login(host: host, username: username, password: password)
            self.host = host
            self.username = username
            UserDefaults.standard.set(host, forKey: "host")
            UserDefaults.standard.set(username, forKey: "username")
            Keychain.set(password, for: "password")
            isSignedIn = true
            await refresh()
            startMonitoring()
            startRealtime()
            await detectFork()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isSignedIn = false
            if !quiet { Keychain.remove("password") }
        }
        busy = false
    }

    func signOut() {
        monitor?.cancel()
        monitor = nil
        stopRealtime()
        searchTask?.cancel()
        searchTask = nil
        Keychain.remove("password")
        Task { await client.clear() }
        isSignedIn = false
        server = nil
        snapshot = nil
        downloads = []
        uploads = []
        search = nil
        lastUpdate = nil
    }

    // MARK: Monitoramento

    func startMonitoring() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }

    func refresh() async {
        do {
            server = try await client.serverState()
            snapshot = try await client.application()
            downloads = try await client.downloads()
            uploads = try await client.uploads()
            if let recentEvents = try? await client.events() {
                events = Array(recentEvents.suffix(40).reversed())
            }
            if let list = try? await client.conversations() {
                conversations = list.filter { ($0.isActive ?? true) || ($0.unread > 0) }
            }
            lastUpdate = Date()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func toggleConnection() async {
        guard let current = server else { return }
        do {
            try await client.setConnected(!current.connected)
            await refresh()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Busca

    func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            searchMessage = "Digite ao menos dois caracteres."
            return
        }
        searchTask?.cancel()
        searching = true
        searchMessage = "Consultando a rede…"
        do {
            let started = try await client.startSearch(text: text)
            guard let id = started.id else {
                searchMessage = "O slskd não devolveu id de busca."
                searching = false
                return
            }
            searchTask = Task { [weak self] in
                guard let self else { return }
                for _ in 0..<20 {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    do {
                        let current = try await self.client.search(id: id)
                        await MainActor.run {
                            self.search = current
                            self.searchMessage = current.complete
                                ? "\(current.fileCount ?? 0) arquivos de \(current.responseCount ?? 0) peers"
                                : "Recebendo resultados…"
                        }
                        if current.complete { break }
                    } catch {
                        await MainActor.run {
                            self.searchMessage = (error as? LocalizedError)?.errorDescription
                                ?? error.localizedDescription
                        }
                    }
                }
                await MainActor.run { self.searching = false }
            }
        } catch {
            searchMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            searching = false
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        if let id = search?.id {
            Task { try? await client.deleteSearch(id: id) }
        }
        search = nil
        searchMessage = nil
        searching = false
    }

    // MARK: Ações em arquivos

    func download(file: SearchFile, from peer: String) async {
        guard let filename = file.filename else { return }
        do {
            try await client.enqueue(username: peer, files: [(filename: filename, size: file.size ?? 0)])
            flash("Na fila: \(file.displayName)")
            await refresh()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            flash("Falhou: \(message)")
        }
    }

    func downloadFolder(_ files: [SearchFile], from peer: String) async {
        let payload = files.compactMap { file -> (filename: String, size: Int64)? in
            guard let name = file.filename else { return nil }
            return (filename: name, size: file.size ?? 0)
        }
        guard !payload.isEmpty else { return }
        do {
            try await client.enqueue(username: peer, files: payload)
            flash("\(payload.count) arquivos na fila de \(peer)")
            await refresh()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            flash("Falhou: \(message)")
        }
    }

    /// Mensagem curta que se apaga sozinha.
    func flash(_ text: String) {
        actionMessage = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if self?.actionMessage == text {
                self?.actionMessage = nil
            }
        }
    }

    func cancel(file: TransferFile) async {
        guard let transferID = file.transferID, let user = file.username else { return }
        do {
            try await client.cancel(username: user, transferID: transferID)
            await refresh()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Derivados

    var activeDownloads: [TransferFile] {
        downloads.flatMap { $0.files }.filter { !$0.isFinished }
    }

    var finishedDownloads: [TransferFile] {
        downloads.flatMap { $0.files }.filter { $0.isFinished && !$0.isFailed }
    }

    var totalSpeed: Double {
        activeDownloads.reduce(0) { $0 + ($1.averageSpeed ?? 0) }
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }
}
