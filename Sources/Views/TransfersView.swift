import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Baixando", value: "\(store.activeDownloads.count)")
                    LabeledContent("Velocidade", value: Fmt.speed(store.totalSpeed))
                    LabeledContent("Concluídos", value: "\(store.finishedDownloads.count)")
                }

                if store.downloads.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Nenhuma transferência",
                            systemImage: "arrow.down.circle",
                            description: Text("Busque alguma coisa e mande baixar. A transferência roda no servidor, não no telefone.")
                        )
                    }
                } else {
                    ForEach(store.downloads) { user in
                        Section(user.username ?? "peer") {
                            ForEach(user.directories ?? []) { directory in
                                ForEach(directory.files ?? []) { file in
                                    row(file)
                                }
                            }
                        }
                    }
                }

                if let message = store.errorMessage {
                    Section { ErrorBanner(message: message) }
                }
            }
            .navigationTitle("Transferências")
            .refreshable { await store.refresh() }
        }
    }

    @ViewBuilder
    private func row(_ file: TransferFile) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(file.displayNameLabel).font(.subheadline).lineLimit(2)
            ProgressView(value: file.progress)
                .tint(file.isFailed ? .red : (file.isFinished ? .green : .accentColor))
            HStack(spacing: 10) {
                Text(Fmt.stateLabel(file.state)).font(.caption2).foregroundStyle(.secondary)
                Text(Fmt.speed(file.averageSpeed)).font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(file.progress * 100))%").font(.caption2).foregroundStyle(.secondary)
                Text(Fmt.bytes(file.size)).font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                if !file.isFinished {
                    Text(Fmt.eta(file)).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions {
            if !file.isFinished {
                Button(role: .destructive) {
                    Task { await store.cancel(file: file) }
                } label: {
                    Label("Cancelar", systemImage: "xmark")
                }
            }
        }
    }
}

private extension TransferFile {
    var displayNameLabel: String {
        guard let raw = filename else { return "?" }
        return raw.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? raw
    }
}
