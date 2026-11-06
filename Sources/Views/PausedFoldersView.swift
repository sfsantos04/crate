import SwiftUI

/// Pastas remotas cujo download fica bloqueado (equivalente ao "pausar pasta").
struct PausedFoldersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var folders: [String] = []
    @State private var draft = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                if folders.isEmpty {
                    Text("Nenhuma pasta pausada.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(folders, id: \.self) { folder in
                    HStack {
                        Text(folder).font(.caption)
                        Spacer()
                        Button {
                            folders.removeAll { $0 == folder }
                            save()
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("início do caminho remoto", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Adicionar") {
                        let value = draft.trimmingCharacters(in: .whitespaces)
                        guard !value.isEmpty else { return }
                        folders.append(value)
                        draft = ""
                        save()
                    }
                }
            } header: {
                SectionLabel(text: "Pastas pausadas")
            } footer: {
                Text("Compara com o início do caminho do peer. Arquivo novo nessa pasta é recusado com 409; transferências já em andamento continuam.")
            }
        }
        .navigationTitle("Pastas pausadas")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            folders = (try? await store.client.pausedFolders()) ?? []
            loaded = true
        }
    }

    private func save() {
        let value = folders
        Task {
            do {
                try await store.client.setPausedFolders(value)
                store.flash("Pastas pausadas atualizadas")
            } catch {
                store.flash("Falhou ao salvar")
            }
        }
    }
}
