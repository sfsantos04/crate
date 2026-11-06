import SwiftUI

/// Detalhe de uma transferência com as ações que o SoulseekQt oferece:
/// reenfileirar, remover da lista e copiar o nome.
struct TransferDetailView: View {
    let file: TransferFile

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var playing: PlayItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(file.displayNameLabel)
                        .font(.subheadline)
                        .textSelection(.enabled)
                    row("Par", file.username ?? "?")
                    row("Estado", Fmt.stateLabel(file.state))
                    row("Tamanho", Fmt.bytes(file.size))
                    row("Velocidade", Fmt.speed(file.averageSpeed))
                    row("Progresso", "\(Int(file.progress * 100))%")
                    if let path = file.filename {
                        row("Caminho", path)
                    }
                } header: {
                    SectionLabel(text: "Detalhe")
                }

                Section {
                    if let folder = file.sourceFolder {
                        HStack {
                            Text("Pasta").font(.footnote).foregroundStyle(.secondary)
                            Spacer()
                            Text(folder).font(.caption2).lineLimit(1)
                        }
                        NavigationLink {
                            FilesBrowserView(initialPath: folder)
                        } label: {
                            Label("Ver pasta no servidor", systemImage: "folder")
                        }
                        Button {
                            playFile(folder: folder)
                        } label: {
                            Label("Tocar arquivo", systemImage: "play.circle")
                        }
                    }
                } header: {
                    SectionLabel(text: "No servidor")
                }

                Section {
                    Button {
                        Task {
                            await store.retry(file)
                            dismiss()
                        }
                    } label: {
                        Label("Reenfileirar", systemImage: "arrow.clockwise")
                    }

                    Button {
                        UIPasteboard.general.string = file.filename ?? file.displayNameLabel
                        copied = true
                    } label: {
                        Label(copied ? "Nome copiado" : "Copiar nome", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        Task {
                            await store.cancel(file: file)
                            dismiss()
                        }
                    } label: {
                        Label("Remover da lista", systemImage: "trash")
                    }
                } header: {
                    SectionLabel(text: "Ações")
                } footer: {
                    Text("Remover tira o item da lista do servidor. O arquivo já baixado continua no disco.")
                }
            }
            .navigationTitle("Transferência")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .navigationDestination(item: $playing) { item in
                PlayerView(title: item.title, url: item.url)
            }
        }
    }

    private func playFile(folder: String) {
        guard let raw = file.filename else { return }
        let name = raw.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? raw
        Task {
            do {
                let url = try await store.client.streamLink(path: "\(folder)/\(name)")
                playing = PlayItem(title: name, url: url)
            } catch {
                store.flash("Arquivo ainda não está no servidor")
            }
        }
    }

    private var unused: Int { 0 }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

extension TransferFile {
    /// Pasta local criada pelo slskd: o nome da pasta de origem no peer.
    var sourceFolder: String? {
        guard let raw = filename else { return nil }
        let parts = raw.split(whereSeparator: { $0 == "\\" || $0 == "/" }).map(String.init)
        guard parts.count >= 2 else { return nil }
        return parts[parts.count - 2]
    }
}
