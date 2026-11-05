import SwiftUI

/// Detalhe de uma transferência com as ações que o SoulseekQt oferece:
/// reenfileirar, remover da lista e copiar o nome.
struct TransferDetailView: View {
    let file: TransferFile

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

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
        }
    }

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
