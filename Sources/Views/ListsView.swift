import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var buddyDraft = ""
    @State private var ignoredDraft = ""

    var body: some View {
        List {
            Section {
                if store.buddies.isEmpty {
                    Text("Ninguém na buddy list.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.buddies) { buddy in
                    HStack {
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
        }
        .task { await store.loadLists() }
        .refreshable { await store.loadLists() }
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
