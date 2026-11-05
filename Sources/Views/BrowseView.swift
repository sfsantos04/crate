import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let action = store.actionMessage {
                    Section {
                        Label(action, systemImage: action.hasPrefix("Falhou") ? "exclamationmark.triangle" : "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(action.hasPrefix("Falhou") ? Theme.danger : Theme.ok)
                    }
                }
                if store.browseDirectories.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Nada carregado",
                            systemImage: "folder",
                            description: Text("Toque em atualizar para pedir a lista de arquivos ao peer.")
                        )
                    }
                }
                ForEach(store.browseDirectories) { directory in
                    Section {
                        ForEach((directory.files ?? []).prefix(200)) { file in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.displayName).font(.subheadline).lineLimit(2)
                                    Text(Fmt.bytes(file.size)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task { await store.downloadBrowse(file, peer: store.browsePeer ?? "") }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        if (directory.files ?? []).isEmpty {
                            Text("pasta vazia ou restrita").font(.caption).foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack {
                            Text(directory.name ?? "?")
                            Spacer()
                            Button("abrir") {
                                Task { await store.browseSubdirectory(directory.name ?? "") }
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                            Button("baixar pasta") {
                                Task { await store.downloadBrowseDirectory(directory, peer: store.browsePeer ?? "") }
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle(store.browsePeer ?? "Browse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") {
                        store.closeBrowse()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await store.browse(store.browsePeer ?? "")
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await store.browse(store.browsePeer ?? "")
            }
        }
    }
}
