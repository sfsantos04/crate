import SwiftUI

/// Busca restrita a uma sala (mensagem 120) ou aos arquivos de um usuário (mensagem 42).
struct ScopedSearchView: View {
    let room: String?
    let username: String?

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var running = false
    @State private var summary: String?
    @State private var files: [(peer: String, name: String, size: Int64, path: String)] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("o que procurar", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { run() }
                    Button {
                        run()
                    } label: {
                        HStack {
                            Label(running ? "Buscando…" : "Buscar", systemImage: "magnifyingglass")
                            if running {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(running || text.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    SectionLabel(text: room != nil ? "Dentro da sala \(room ?? "")" : "Arquivos de \(username ?? "")")
                } footer: {
                    Text(room != nil
                         ? "Só responde quem está nesta sala. É a busca que o SoulseekQt faz com o botão direito na sala."
                         : "Pergunta direto ao servidor pelos arquivos daquele usuário, sem varrer a rede inteira.")
                }

                if let summary {
                    Section {
                        Text(summary).font(.footnote)
                    }
                }

                if let message {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(Theme.danger)
                    }
                }

                if !files.isEmpty {
                    Section {
                        ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name).font(.caption).lineLimit(1)
                                HStack {
                                    Text(file.peer).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    Text(Fmt.bytes(file.size)).font(.caption2).foregroundStyle(.tertiary)
                                    Spacer()
                                    Button {
                                        Task {
                                            await store.enqueueFile(peer: file.peer, path: file.path, size: file.size)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    } header: {
                        SectionLabel(text: "\(files.count) primeiros resultados")
                    }
                }
            }
            .navigationTitle(room != nil ? "Buscar na sala" : "Buscar no usuário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func run() {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, !running else { return }
        running = true
        summary = nil
        message = nil
        files = []

        Task {
            defer { running = false }
            do {
                let id: String
                if let room {
                    id = try await store.client.searchRoom(room, text: query)
                } else if let username {
                    id = try await store.client.searchUser(username, text: query)
                } else {
                    return
                }

                var result = try await store.client.search(id: id)
                var waited = 0
                while !result.complete && waited < 30 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    waited += 2
                    result = try await store.client.search(id: id)
                }

                let peers = result.responses ?? []
                summary = "\(peers.count) peers · \(result.fileCount ?? 0) arquivos · estado \(result.state ?? "?")"

                var flat: [(peer: String, name: String, size: Int64, path: String)] = []
                for peer in peers {
                    for file in peer.files ?? [] {
                        let path = file.filename ?? ""
                        let name = path.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? path
                        flat.append((peer: peer.username ?? "?", name: name, size: file.size ?? 0, path: path))
                    }
                }
                files = Array(flat.prefix(50))
                try? await store.client.deleteSearch(id: id)
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
