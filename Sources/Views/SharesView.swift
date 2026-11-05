import SwiftUI

struct SharesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var rows: [ShareHostRow] = []
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                if rows.isEmpty {
                    EmptyState(title: "Nenhum host compartilhando",
                               systemImage: "externaldrive",
                               detail: "Configure as pastas no slskd e toque em re-escanear para publicar no Soulseek.")
                        .listRowBackground(Color.clear)
                }
                ForEach(rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.id).font(.subheadline.weight(.medium))
                            Text("\(row.shares) shares")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        CountPill(text: "\(row.files) arquivos", tint: Theme.ok)
                    }
                }
            } header: {
                SectionLabel(text: "Compartilhamento")
            }

            Section {
                Button {
                    Task { await run(rescan: true) }
                } label: {
                    Label("Re-escanear pastas", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(busy)

                Button(role: .destructive) {
                    Task { await run(rescan: false) }
                } label: {
                    Label("Cancelar varredura", systemImage: "stop.circle")
                }
                .disabled(busy)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Re-escanear republica a lista no servidor Soulseek. É a mesma operação que o slskd faz ao iniciar.")
            }
        }
        .navigationTitle("Compartilhamento")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        rows = await store.shareSummary()
    }

    private func run(rescan: Bool) async {
        busy = true
        message = nil
        if rescan {
            await store.rescanShares()
            message = "Varredura solicitada."
        } else {
            await store.cancelShareScan()
            message = "Pedido de cancelamento enviado."
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await load()
        busy = false
    }
}
