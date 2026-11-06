import SwiftUI

/// Navegador somente leitura da pasta de downloads do servidor.
struct PlayItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: URL
}

struct FilesBrowserView: View {
    let initialPath: String

    @EnvironmentObject private var store: AppStore
    @State private var path: String = ""
    @State private var root = ""
    @State private var entries: [FileEntry] = []
    @State private var loading = true
    @State private var playing: PlayItem?
    @State private var root = "downloads"

    var body: some View {
        List {
            Section {
                Picker("Origem", selection: $root) {
                    Text("Baixados").tag("downloads")
                    Text("Em andamento").tag("incomplete")
                }
                .pickerStyle(.segmented)
                .onChange(of: root) { _, _ in load("") }
            }

            Section {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive").font(.caption2).foregroundStyle(Theme.accent)
                    Text(root.isEmpty ? "carregando…" : root).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(path.isEmpty ? "/" : path).font(.caption2).foregroundStyle(Theme.accent)
                }
            }

            if loading {
                HStack { ProgressView(); Text("lendo…").font(.footnote) }
            }

            Section {
                if path.isEmpty == false {
                    Button {
                        goUp()
                    } label: {
                        Label("Voltar", systemImage: "arrow.up.left")
                            .font(.footnote)
                    }
                }

                ForEach(entries) { entry in
                    if entry.isDirectory {
                        Button {
                            load(entry.name)
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill").foregroundStyle(Theme.accent)
                                Text(entry.name).font(.subheadline).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Button {
                            play(entry)
                        } label: {
                            HStack {
                                Image(systemName: "play.circle").foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.name).font(.caption).lineLimit(2).foregroundStyle(.primary)
                                    Text(Fmt.bytes(entry.size)).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                if entries.isEmpty && !loading {
                    Text("Pasta vazia.").font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                SectionLabel(text: "Conteúdo")
            }
        }
        .navigationTitle("Arquivos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if path.isEmpty { load(initialPath) }
        }
        .refreshable { load(path) }
        .navigationDestination(item: $playing) { item in
            PlayerView(title: item.title, url: item.url)
        }
    }

    private func load(_ newPath: String) {
        loading = true
        Task {
            defer { loading = false }
            if let result = try? await store.client.listFiles(path: newPath, root: root) {
                path = result.path
                root = result.root
                entries = result.entries
            }
        }
    }

    private func play(_ entry: FileEntry) {
        let full = path.isEmpty ? entry.name : "\(path)/\(entry.name)"
        Task {
            do {
                let url = try await store.client.streamLink(path: full, root: root)
                playing = PlayItem(title: entry.name, url: url)
            } catch {
                store.flash("Não consegui abrir o arquivo")
            }
        }
    }

    private func goUp() {
        var parts = path.split(separator: "/").map(String.init)
        if !parts.isEmpty { parts.removeLast() }
        load(parts.joined(separator: "/"))
    }
}

/// Escolha do padrão de pasta de destino dos downloads.
struct DestinationView: View {
    @EnvironmentObject private var store: AppStore

    @State private var pattern = "${SOURCE_DIRECTORY}"
    @State private var custom = ""
    @State private var loaded = false

    private let presets = ["${SOURCE_DIRECTORY}", "${USERNAME}/${SOURCE_DIRECTORY}"]

    var body: some View {
        Form {
            Section {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        pattern = preset
                    } label: {
                        HStack {
                            Text(preset).font(.system(.caption, design: .monospaced))
                            Spacer()
                            if pattern == preset {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
                HStack {
                    TextField("padrão próprio", text: $custom)
                        .font(.system(.caption, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Usar") {
                        let value = custom.trimmingCharacters(in: .whitespaces)
                        if !value.isEmpty { pattern = value }
                    }
                }
            } header: {
                SectionLabel(text: "Pasta de destino")
            } footer: {
                Text("Vale para downloads novos. ${SOURCE_DIRECTORY} mantém a pasta de quem compartilhou; ${USERNAME} separa por peer.")
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Salvar no servidor", systemImage: "externaldrive.badge.checkmark")
                }
            } footer: {
                Text("O servidor faz backup do slskd.yml antes de gravar.")
            }
        }
        .navigationTitle("Destino")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            pattern = (try? await store.client.destinationPattern()) ?? pattern
            loaded = true
        }
    }

    private func save() {
        Task {
            do {
                let backup = try await store.client.setDestinationPattern(pattern)
                store.flash("Destino salvo. Backup: \(backup)")
            } catch {
                store.flash("Falhou ao salvar destino")
            }
        }
    }
}
