import SwiftUI

struct SearchFilters: Equatable, Codable {
    var minBitrate = 0
    var minSizeMB = 0
    var freeSlotOnly = false
    var onlyUnlocked = false
    var dedupeRepeated = true
    var maxResults = 2000
    var sortMode = SortMode.relevance
    var blockedWords: [String] = []

    enum SortMode: Int, CaseIterable, Identifiable, Codable {
        case relevance = 0
        case size = 1
        case bitrate = 2
        case speed = 3

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .relevance: return "Relevância"
            case .size: return "Tamanho"
            case .bitrate: return "Bitrate"
            case .speed: return "Velocidade"
            }
        }
    }

    var isActive: Bool {
        minBitrate > 0 || minSizeMB > 0 || freeSlotOnly || onlyUnlocked || !dedupeRepeated || maxResults != 2000 || sortMode != .relevance || !blockedWords.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if minBitrate > 0 { parts.append("\(minBitrate)k") }
        if minSizeMB > 0 { parts.append("≥\(minSizeMB)MB") }
        if freeSlotOnly { parts.append("slot livre") }
        if onlyUnlocked { parts.append("sem trava") }
        if !dedupeRepeated { parts.append("com repetidos") }
        if maxResults != 2000 { parts.append("máx \(maxResults)") }
        if sortMode != .relevance { parts.append(sortMode.label.lowercased()) }
        if !blockedWords.isEmpty { parts.append("\(blockedWords.count) bloqueadas") }
        return parts.isEmpty ? "Filtros" : parts.joined(separator: " · ")
    }
}

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showBrowse = false
    @State private var showFilters = false
    @State private var showWishlist = false
    @State private var showHistory = false
    @State private var blockedDraft = ""
    @State private var filters = SearchFilters()

    private func loadBlockedWords() {
        if let saved = UserDefaults.standard.string(forKey: "blockedWords") {
            blockedDraft = saved
            filters.blockedWords = saved
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
                .filter { !$0.isEmpty }
        }
    }

    var body: some View {
        content
            .task { loadBlockedWords() }
    }

    private var content: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        TextField("artista, álbum ou faixa", text: $store.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await store.runSearch() } }
                        if store.searching {
                            ProgressView()
                        } else {
                            Button {
                                Task { await store.runSearch() }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .disabled(store.query.trimmingCharacters(in: .whitespaces).count < 2)
                        }
                    }
                    HStack {
                        Label(filters.summary,
                              systemImage: filters.isActive ? "line.3.horizontal.decrease.circle.fill"
                                                            : "line.3.horizontal.decrease.circle")
                            .font(.caption)
                            .foregroundStyle(filters.isActive ? Theme.accent : .secondary)
                            .onTapGesture { showFilters = true }
                        Spacer()
                        if filters.isActive {
                            Button("limpar") { filters = SearchFilters() }
                                .font(.caption2)
                        }
                    }
                    if let message = store.searchMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let action = store.actionMessage {
                        Label(action, systemImage: action.hasPrefix("Falhou") ? "exclamationmark.triangle" : "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(action.hasPrefix("Falhou") ? Theme.danger : Theme.ok)
                    }
                }

                if !filteredPeers.isEmpty {
                    ForEach(filteredPeers) { peer in
                        Section {
                            ForEach(groupedFiles(peer.files ?? [])) { group in
                                folderHeader(group.id, files: group.files, peer: peer)
                                ForEach(group.files.prefix(40)) { file in
                                    row(file: file, peer: peer)
                                }
                            }
                        } header: {
                            peerHeader(peer)
                        }
                    }
                } else if store.search == nil {
                    Section {
                        EmptyState(title: "Buscar no Soulseek",
                                   systemImage: "magnifyingglass",
                                   detail: "A busca roda no slskd do homelab e o resultado chega em cerca de 30 segundos.")
                            .listRowBackground(Color.clear)
                    }
                } else if store.search?.complete == true {
                    Section {
                        EmptyState(title: "Nada com esses filtros",
                                   systemImage: "line.3.horizontal.decrease.circle",
                                   detail: "Afrouxe os filtros ou tente outro termo.")
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Buscar")
            .sheet(isPresented: $showBrowse) { BrowseView().environmentObject(store) }
            .sheet(isPresented: $showFilters) {
                FiltersSheet(filters: $filters)
                    .presentationDetents([.medium])
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        if store.forkMode {
                            Button {
                                showWishlist = true
                            } label: {
                                Image(systemName: "bookmark")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") { store.clearSearch() }
                        .disabled(store.search == nil)
                }
            }
            .sheet(isPresented: $showHistory) {
                SearchHistoryView().environmentObject(store)
            }
            .sheet(isPresented: $showWishlist) {
                WishlistView().environmentObject(store)
            }
        }
    }

    private var filteredPeers: [SearchResponse] {
        let blocked = Set(store.ignoredUsers.map { $0.lowercased() })
        let peers = (store.search?.responses ?? []).filter { peer in
            !blocked.contains((peer.username ?? "").lowercased())
        }
        let minSize = Int64(filters.minSizeMB) * 1_048_576
        var seen = Set<String>()
        var budget = max(1, filters.maxResults)

        let filtered = peers.compactMap { peer -> SearchResponse? in
            var copy = peer
            copy.files = (peer.files ?? []).filter { file in
                if !filters.blockedWords.isEmpty {
                    let name = (file.filename ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    if filters.blockedWords.contains(where: { name.contains($0) }) { return false }
                }

                guard (file.size ?? 0) >= minSize,
                      (file.bitRate ?? 0) >= filters.minBitrate,
                      !filters.freeSlotOnly || (peer.hasFreeUploadSlot ?? false),
                      !filters.onlyUnlocked || !(file.isLocked ?? false)
                else { return false }

                guard filters.dedupeRepeated, budget > 0 else { return true }

                // mesmo arquivo vindo de vários peers: fica o primeiro, que já é o melhor
                let key = "\((file.filename ?? "").lowercased())|\(file.size ?? 0)"
                if seen.contains(key) { return false }
                seen.insert(key)
                budget -= 1
                return true
            }

            switch filters.sortMode {
            case .size:
                copy.files = copy.files?.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
            case .bitrate:
                copy.files = copy.files?.sorted { ($0.bitRate ?? 0) > ($1.bitRate ?? 0) }
            default:
                break
            }

            return (copy.files?.isEmpty ?? true) ? nil : copy
        }

        return filtered.sorted { lhs, rhs in
            switch filters.sortMode {
            case .speed:
                return (lhs.uploadSpeed ?? 0) > (rhs.uploadSpeed ?? 0)
            case .size:
                let l = (lhs.files ?? []).reduce(Int64(0)) { $0 + ($1.size ?? 0) }
                let r = (rhs.files ?? []).reduce(Int64(0)) { $0 + ($1.size ?? 0) }
                return l > r
            default:
                let l = lhs.hasFreeUploadSlot ?? false
                let r = rhs.hasFreeUploadSlot ?? false
                if l != r { return l && !r }
                return (lhs.uploadSpeed ?? 0) > (rhs.uploadSpeed ?? 0)
            }
        }
    }

    private func groupedFiles(_ files: [SearchFile]) -> [FolderGroup] {
        var order: [String] = []
        var buckets: [String: [SearchFile]] = [:]
        for file in files {
            let key = file.folder.isEmpty ? "—" : file.folder
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(file)
        }
        return order.map { FolderGroup(id: $0, files: buckets[$0] ?? []) }
    }

    @ViewBuilder
    private func peerHeader(_ peer: SearchResponse) -> some View {
        HStack(spacing: 8) {
            Text(peer.username ?? "peer").font(.caption.weight(.semibold))
            Button {
                Task {
                    await store.browse(peer.username ?? "")
                    showBrowse = true
                }
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            Spacer()
            if peer.hasFreeUploadSlot == true {
                CountPill(text: "slot livre", tint: Theme.ok)
            } else {
                Text("fila \(peer.queueLength ?? 0)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func folderHeader(_ folder: String, files: [SearchFile], peer: SearchResponse) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.caption2)
                .foregroundStyle(Theme.accent)
            Text(folder).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
            Spacer()
            Button("baixar \(files.count)") {
                Task { await store.downloadFolder(files, from: peer.username ?? "") }
            }
            .font(.caption2)
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private func row(file: SearchFile, peer: SearchResponse) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(file.displayName).font(.subheadline).lineLimit(2)
                HStack(spacing: 8) {
                    Text(Fmt.bytes(file.size)).font(.caption2).foregroundStyle(.secondary)
                    if let bitRate = file.bitRate, bitRate > 0 {
                        Text("\(bitRate) kbps").font(.caption2).foregroundStyle(.secondary)
                    }
                    if file.isLocked == true {
                        Text("travado").font(.caption2).foregroundStyle(Theme.danger)
                    }
                }
            }
            Spacer()
            Button {
                Task { await store.download(file: file, from: peer.username ?? "") }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct FolderGroup: Identifiable {
    let id: String
    let files: [SearchFile]
}

struct FiltersSheet: View {
    @Binding var filters: SearchFilters
    @State private var blockedDraft = ""
    @State private var presets: [FilterPreset] = FilterPresetStore.load()
    @State private var presetName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if presets.isEmpty {
                        Text("Nenhum filtro salvo ainda.").font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(presets) { preset in
                        Button {
                            filters = preset.filters
                        } label: {
                            HStack {
                                Text(preset.name).font(.subheadline)
                                Spacer()
                                Image(systemName: "arrow.down.left.circle").foregroundStyle(Theme.accent)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                presets.removeAll { $0.name == preset.name }
                                FilterPresetStore.save(presets)
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                        }
                    }
                    HStack {
                        TextField("nome do filtro", text: $presetName)
                        Button("Salvar") {
                            let name = presetName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            presets.removeAll { $0.name == name }
                            presets.append(FilterPreset(name: name, filters: filters))
                            FilterPresetStore.save(presets)
                            presetName = ""
                        }
                        .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    SectionLabel(text: "Filtros salvos")
                } footer: {
                    Text("Toque em um nome para aplicar o conjunto inteiro. Arraste para a esquerda para apagar.")
                }

                Section("Qualidade mínima") {
                    Stepper("Bitrate ≥ \(filters.minBitrate) kbps",
                            value: $filters.minBitrate, in: 0...320, step: 32)
                    Stepper("Tamanho ≥ \(filters.minSizeMB) MB",
                            value: $filters.minSizeMB, in: 0...500, step: 5)
                }
                Section("Disponibilidade") {
                    Toggle("Somente slot livre", isOn: $filters.freeSlotOnly)
                    Toggle("Somente arquivos sem trava", isOn: $filters.onlyUnlocked)
                    Toggle("Descartar resultados repetidos", isOn: $filters.dedupeRepeated)
                    Stepper("Máximo de resultados: \(filters.maxResults)",
                            value: $filters.maxResults, in: 50...2000, step: 50)
                    TextField("bloquear palavras (remix, ao vivo, cover)", text: $blockedDraft)
                        .onAppear {
                            if blockedDraft.isEmpty {
                                blockedDraft = UserDefaults.standard.string(forKey: "blockedWords") ?? ""
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: blockedDraft) { _, value in
                            filters.blockedWords = value
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
                                .filter { !$0.isEmpty }
                            UserDefaults.standard.set(value, forKey: "blockedWords")
                        }
                    Picker("Ordenar por", selection: $filters.sortMode) {
                        ForEach(SearchFilters.SortMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ok") { dismiss() }
                }
            }
        }
    }
}
