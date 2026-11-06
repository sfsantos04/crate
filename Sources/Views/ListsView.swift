import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var buddyDraft = ""
    @State private var ignoredDraft = ""
    @State private var groupDraft = ""
    @State private var newGroupDraft = ""
    @State private var banDraft = ""
    @AppStorage("blockedWords") private var blockedRaw = ""
    @State private var presence: [String: Bool] = [:]

    var body: some View {
        List {
            Section {
                if store.buddies.isEmpty {
                    Text("Ninguém na buddy list.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.buddies) { buddy in
                    HStack {
                        Circle()
                            .fill((presence[buddy.username ?? ""] ?? false) ? Theme.ok : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(buddy.username ?? "?").font(.subheadline)
                        Spacer()
                        Button {
                            Task { await store.removeBuddy(buddy.username ?? "") }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("adicionar buddy", text: $buddyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { submit($buddyDraft, buddy: true) }
                    Button {
                        submit($buddyDraft, buddy: true)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(buddyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                SectionLabel(text: "Buddy list")
            } footer: {
                Text("Buddy entra na watch do servidor e recebe acesso a shares restritos de quem usa buddy list.")
            }

            Section {
                if store.ignoredUsers.isEmpty {
                    Text("Nenhum usuário ignorado.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.ignoredUsers, id: \.self) { name in
                    HStack {
                        Text(name).font(.subheadline)
                        Spacer()
                        Button {
                            Task { await store.removeIgnored(name) }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("ignorar usuário", text: $ignoredDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { submit($ignoredDraft, buddy: false) }
                    Button {
                        submit($ignoredDraft, buddy: false)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(ignoredDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                SectionLabel(text: "Ignorados")
            } footer: {
                Text("Lista local do fork: o protocolo do Soulseek não tem ignore, então ela vale para este app e para as telas que filtrarem por ela.")
            }
        Section {
            TextField("remix, ao vivo, cover", text: $blockedRaw)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            SectionLabel(text: "Palavras bloqueadas")
        } footer: {
            Text("Vale na busca e nas mensagens de chat e sala. Separe por vírgula; acento e maiúscula são ignorados.")
        }

        Section {
            ForEach(Array(store.groups.keys).sorted(), id: \.self) { group in
                DisclosureGroup {
                    ForEach(store.groups[group] ?? [], id: \.self) { member in
                        HStack {
                            Text(member).font(.caption)
                            Spacer()
                            Button {
                                Task { await store.removeGroupMember(group, member) }
                            } label: {
                                Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        TextField("adicionar ao grupo", text: $groupDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            let value = groupDraft
                            groupDraft = ""
                            Task { await store.addGroupMember(group, value) }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(groupDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } label: {
                    HStack {
                        Text(group).font(.subheadline)
                        Spacer()
                        Text("\((store.groups[group] ?? []).count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await store.deleteGroup(group) }
                    } label: {
                        Label("Apagar", systemImage: "trash")
                    }
                }
            }
            HStack {
                TextField("novo grupo", text: $newGroupDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    let value = newGroupDraft
                    newGroupDraft = ""
                    Task { await store.createGroup(value) }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newGroupDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            SectionLabel(text: "Grupos")
        } footer: {
            Text("Grupos servem para organizar quem você acompanha e, no futuro, para permissões de upload por grupo.")
        }

        Section {
            if store.bannedUsers.isEmpty {
                Text("Ninguém banido.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.bannedUsers, id: \.self) { name in
                HStack {
                    Text(name).font(.subheadline)
                    Spacer()
                    Button {
                        Task { await store.unban(name) }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("banir usuário", text: $banDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    let value = banDraft
                    banDraft = ""
                    Task { await store.ban(value) }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(banDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            SectionLabel(text: "Banidos")
        } footer: {
            Text("Lista local do fork. O protocolo do Soulseek não tem ban; a recusa acontece no seu cliente.")
        }
        }
        .task {
            await store.loadLists()
            await loadPresence()
            await store.loadGroups()
            await store.loadBanned()
        }
        .refreshable { await store.loadLists() }
    }

    private func loadPresence() async {
        guard store.forkMode else { return }
        var map: [String: Bool] = [:]
        for buddy in store.buddies {
            guard let name = buddy.username else { continue }
            let status = (try? await store.client.userStatus(name)) ?? "unknown"
            map[name] = status.lowercased().contains("online")
        }
        presence = map
    }

    private func submit(_ draft: Binding<String>, buddy: Bool) {
        let name = draft.wrappedValue
        draft.wrappedValue = ""
        Task {
            if buddy {
                await store.addBuddy(name)
            } else {
                await store.addIgnored(name)
            }
        }
    }
}

struct WishlistView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var interval = 30

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.wishlist.isEmpty {
                        EmptyState(title: "Nenhuma busca salva",
                                   systemImage: "bookmark",
                                   detail: "Salve um termo e o servidor repete a busca no intervalo escolhido.")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(store.wishlist) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.text ?? "?").font(.subheadline)
                            Text("a cada \(item.intervalMinutes ?? 0) min · \(item.lastHitCount ?? 0) resultados · última \(item.lastRunAt ?? "nunca")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await store.removeWishlist(item) }
                            } label: {
                                Label("Remover", systemImage: "trash")
                            }
                            Button {
                                Task { await store.runWishlist(item) }
                            } label: {
                                Label("Rodar", systemImage: "play.fill")
                            }
                            .tint(.blue)
                        }
                    }
                } header: {
                    SectionLabel(text: "Buscas salvas")
                }

                Section {
                    TextField("termo da busca", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Stepper("A cada \(interval) min", value: $interval, in: 5...720, step: 5)
                    Button {
                        Task {
                            await store.addWishlist(draft, intervalMinutes: interval)
                            draft = ""
                        }
                    } label: {
                        Label("Salvar busca", systemImage: "plus.circle")
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    SectionLabel(text: "Nova busca")
                }

                if store.wishlistBusy {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("rodando a busca no servidor (cerca de 20s)…").font(.footnote)
                        }
                    }
                }

                if let action = store.actionMessage {
                    Section {
                        Text(action).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .task { await store.loadWishlist() }
            .refreshable { await store.loadWishlist() }
        }
    }
}
