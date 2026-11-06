import SwiftUI

/// Pastas compartilhadas e filtros — edita o YAML do slskd com backup do lado do servidor.
struct SharedFoldersView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var directories: [String] = []
    @State private var filters: [String] = []
    @State private var newDirectory = ""
    @State private var newFilter = ""
    @State private var busy = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                if directories.isEmpty {
                    Text("Nenhuma pasta compartilhada.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(directories, id: \.self) { path in
                    HStack {
                        Text(path).font(.caption)
                        Spacer()
                        Button {
                            directories.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("/caminho/no/servidor", text: $newDirectory)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Adicionar") {
                        let value = newDirectory.trimmingCharacters(in: .whitespaces)
                        guard !value.isEmpty else { return }
                        directories.append(value)
                        newDirectory = ""
                    }
                }
            } header: {
                SectionLabel(text: "Pastas")
            } footer: {
                Text("Caminhos dentro do container do slskd (ex.: /app/downloads). O servidor recusa pasta que não existe.")
            }

            Section {
                ForEach(filters, id: \.self) { filter in
                    HStack {
                        Text(filter).font(.caption)
                        Spacer()
                        Button {
                            filters.removeAll { $0 == filter }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("extensão a excluir (.ini)", text: $newFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Adicionar") {
                        let value = newFilter.trimmingCharacters(in: .whitespaces)
                        guard !value.isEmpty else { return }
                        filters.append(value)
                        newFilter = ""
                    }
                }
            } header: {
                SectionLabel(text: "Filtros")
            } footer: {
                Text("Arquivos com essas extensões não são compartilhados.")
            }

            Section {
                Button {
                    apply()
                } label: {
                    HStack {
                        Label("Salvar no servidor", systemImage: "externaldrive.badge.checkmark")
                        if busy { Spacer(); ProgressView() }
                    }
                }
                .disabled(busy || !loaded)
            } footer: {
                Text("O servidor faz backup do slskd.yml antes de gravar e valida o YAML. Se algo falhar, o backup fica ao lado do arquivo.")
            }
        }
        .navigationTitle("Pastas compartilhadas")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        if let config = try? await store.client.configShares() {
            directories = config.directories
            filters = config.filters
        }
        loaded = true
    }

    private func apply() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let backup = try await store.client.applyConfigShares(directories: directories, filters: filters)
                store.flash("Aplicado. Backup: \(backup)")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                store.flash("Falhou: \(message)")
            }
        }
    }
}
