import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Servidor") {
                    if let server = store.server {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.label).font(.headline)
                                StatusBadge(connected: server.connected, loggedIn: server.loggedIn)
                            }
                            Spacer()
                            Button(server.connected ? "Desconectar" : "Conectar") {
                                Task { await store.toggleConnection() }
                            }
                            .buttonStyle(.bordered)
                        }
                        LabeledContent("Endereço", value: server.address ?? "—")
                        LabeledContent("Endpoint", value: server.ipEndPoint ?? "—")
                    } else {
                        HStack { ProgressView(); Text("Sem resposta do slskd") }
                    }
                }

                Section("Conta") {
                    LabeledContent("Usuário", value: store.snapshot?.username ?? "—")
                    LabeledContent("Privilegiado", value: (store.snapshot?.privileged ?? false) ? "sim" : "não")
                    LabeledContent("Versão do slskd", value: store.snapshot?.version ?? "—")
                    LabeledContent("Reinício pendente", value: (store.snapshot?.pendingRestart ?? false) ? "sim" : "não")
                }

                Section("Compartilhamento") {
                    LabeledContent("Pastas", value: "\(store.snapshot?.shareDirectories ?? 0)")
                    LabeledContent("Arquivos", value: "\(store.snapshot?.shareFiles ?? 0)")
                }

                Section("Rede distribuída") {
                    LabeledContent("Nível", value: "\(store.snapshot?.branchLevel ?? 0)")
                    LabeledContent("Pai", value: (store.snapshot?.parent ?? "").isEmpty ? "—" : (store.snapshot?.parent ?? "—"))
                }

                Section("Tráfego") {
                    LabeledContent("Baixando agora", value: "\(store.activeDownloads.count)")
                    LabeledContent("Velocidade", value: Fmt.speed(store.totalSpeed))
                    LabeledContent("Concluídos", value: "\(store.finishedDownloads.count)")
                    LabeledContent("Enviando", value: "\(store.uploads.flatMap { $0.files }.count)")
                }

                if let message = store.errorMessage {
                    Section { ErrorBanner(message: message) }
                }

                if let update = store.lastUpdate {
                    Section {
                        Text("Atualizado \(update.formatted(date: .omitted, time: .standard))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Servidor")
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}
