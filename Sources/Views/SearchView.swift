import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showBrowse = false

    var body: some View {
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
                    if let message = store.searchMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let peers = store.search?.responses, !peers.isEmpty {
                    ForEach(peers) { peer in
                        Section {
                            ForEach(Array((peer.files ?? []).prefix(25))) { file in
                                row(file: file, peer: peer)
                            }
                        } header: {
                            peerHeader(peer)
                        }
                    }
                } else if store.search == nil {
                    Section {
                        ContentUnavailableView(
                            "Buscar no Soulseek",
                            systemImage: "magnifyingglass",
                            description: Text("A busca roda no slskd do homelab; o resultado chega em cerca de 30 segundos.")
                        )
                    }
                }
            }
            .navigationTitle("Buscar")
            .sheet(isPresented: $showBrowse) {
                BrowseView().environmentObject(store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") { store.clearSearch() }
                        .disabled(store.search == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func peerHeader(_ peer: SearchResponse) -> some View {
        HStack {
            Text(peer.username ?? "peer").font(.caption).bold()
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
                Text("slot livre").font(.caption2).foregroundStyle(.green)
            } else {
                Text("fila \(peer.queueLength ?? 0)").font(.caption2).foregroundStyle(.secondary)
            }
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
                    if !file.folder.isEmpty {
                        Text(file.folder).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
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
