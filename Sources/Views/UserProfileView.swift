import SwiftUI

/// Perfil de outro usuário: estatísticas, interesses, nota, buddy e ignore.
struct UserProfileView: View {
    let username: String

    @EnvironmentObject private var store: AppStore
    @State private var stats: UserStatistics?
    @State private var interests: InterestPair?
    @State private var note = ""
    @State private var loaded = false
    @State private var showBrowse = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Text(username).font(.headline)
                    Spacer()
                    if store.buddies.contains(where: { $0.username == username }) {
                        Tag(text: "buddy", tint: Theme.accent)
                    }
                    if store.ignoredUsers.contains(username) {
                        Tag(text: "ignorado", tint: Theme.danger)
                    }
                }
                if let stats {
                    if let files = stats.fileCount {
                        row("Arquivos", "\(files)")
                    }
                    if let dirs = stats.directoryCount {
                        row("Pastas", "\(dirs)")
                    }
                    if let speed = stats.averageSpeed, speed > 0 {
                        row("Velocidade média", String(format: "%.0f KB/s", speed))
                    }
                    if let uploads = stats.uploadCount {
                        row("Uploads", "\(uploads)")
                    }
                    if let code = stats.countryCode, code.count == 2 {
                        row("País", "\(CountryFlag.emoji(for: code)) \(Locale.current.localizedString(forRegionCode: code.uppercased()) ?? code)")
                    }
                } else {
                    Text("Sem estatísticas (usuário offline ou fora da rede).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                SectionLabel(text: "Resumo")
            }

            Section {
                let likes = interests?.likes ?? []
                let hates = interests?.hates ?? []
                if likes.isEmpty && hates.isEmpty {
                    Text("Sem interesses publicados.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(likes, id: \.self) { term in
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup").font(.caption2).foregroundStyle(Theme.accent)
                        Text(term).font(.subheadline)
                    }
                }
                ForEach(hates, id: \.self) { term in
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown").font(.caption2).foregroundStyle(Theme.danger)
                        Text(term).font(.subheadline)
                    }
                }
            } header: {
                SectionLabel(text: "Interesses")
            }

            Section {
                TextField("o que lembrar desse usuário", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit { saveNote() }
                Button {
                    saveNote()
                } label: {
                    Label("Salvar nota", systemImage: "square.and.arrow.down")
                }
                .disabled(!loaded)
            } header: {
                SectionLabel(text: "Nota")
            } footer: {
                Text("Nota local, guardada no servidor do fork. Não é visível para o outro usuário.")
            }

            Section {
                Button {
                    Task {
                        if store.buddies.contains(where: { $0.username == username }) {
                            await store.removeBuddy(username)
                        } else {
                            await store.addBuddy(username)
                        }
                    }
                } label: {
                    Label(store.buddies.contains(where: { $0.username == username }) ? "Remover da buddy list" : "Adicionar à buddy list",
                          systemImage: "person.crop.circle.badge.checkmark")
                }
                Button {
                    Task {
                        if store.ignoredUsers.contains(username) {
                            await store.removeIgnored(username)
                        } else {
                            await store.addIgnored(username)
                        }
                    }
                } label: {
                    Label(store.ignoredUsers.contains(username) ? "Deixar de ignorar" : "Ignorar usuário",
                          systemImage: "nosign")
                }
                Button {
                    showBrowse = true
                    Task { await store.browse(username) }
                } label: {
                    Label("Ver arquivos compartilhados", systemImage: "folder")
                }
            } header: {
                SectionLabel(text: "Ações")
            }
        }
        .sheet(isPresented: $showBrowse) { BrowseView().environmentObject(store) }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadLists()
            note = await store.loadNote(for: username)
            stats = try? await store.client.statistics(of: username)
            interests = try? await store.client.interests(of: username)
            loaded = true
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline)
        }
    }

    private func saveNote() {
        let text = note
        Task { await store.saveNote(text, for: username) }
    }
}

private struct Tag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}
