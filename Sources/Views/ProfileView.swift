import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var likeDraft = ""
    @State private var hateDraft = ""

    var body: some View {
        List {
            Section {
                LabeledContent("Privilégios", value: store.privilegesDays.map { "\($0) dias" } ?? "—")
                Toggle(isOn: Binding(
                    get: { store.isAway },
                    set: { value in Task { await store.setAway(value) } }
                )) {
                    Label(store.isAway ? "Ausente" : "Disponível", systemImage: store.isAway ? "moon.zzz.fill" : "moon.zzz")
                }
            } header: {
                SectionLabel(text: "Conta")
            }

            interestSection(title: "Gosta", items: store.myLikes, hated: false, draft: $likeDraft)
            interestSection(title: "Não gosta", items: store.myHates, hated: true, draft: $hateDraft)

            if !store.similar.isEmpty {
                Section {
                    ForEach(store.similar.prefix(30)) { user in
                        HStack {
                            Text(user.username ?? "?").font(.subheadline)
                            Spacer()
                            CountPill(text: "\(user.rating ?? 0)")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await store.watch(user.username ?? "") } }
                    }
                } header: {
                    SectionLabel(text: "Usuários similares")
                } footer: {
                    Text("Toque para adicionar à buddy list (mostra país e estatísticas).")
                }
            }

            if !store.globalRecommendations.isEmpty {
                Section {
                    ForEach(store.globalRecommendations.prefix(20)) { item in
                        HStack(spacing: 8) {
                            Text(item.interest ?? "?").font(.subheadline)
                            Spacer()
                            CountPill(text: "\(item.count ?? 0)", tint: Theme.ok)
                            Menu {
                                Button("Gostar: \(item.interest ?? "")") {
                                    Task { await store.addInterest(item.interest ?? "", hated: false) }
                                }
                                Button("Não gostar: \(item.interest ?? "")") {
                                    Task { await store.addInterest(item.interest ?? "", hated: true) }
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    SectionLabel(text: "Recomendados pela rede")
                }
            }

            if !store.personalRecommendations.isEmpty {
                Section {
                    ForEach(store.personalRecommendations.prefix(20)) { item in
                        HStack {
                            Text(item.interest ?? "?").font(.subheadline)
                            Spacer()
                            CountPill(text: "\(item.count ?? 0)", tint: Theme.warn)
                            Menu {
                                Button("Gostar: \(item.interest ?? "")") {
                                    Task { await store.addInterest(item.interest ?? "", hated: false) }
                                }
                                Button("Não gostar: \(item.interest ?? "")") {
                                    Task { await store.addInterest(item.interest ?? "", hated: true) }
                                }
                                Button("Ver usuários similares") {
                                    Task { await store.loadProfile() }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    SectionLabel(text: "Recomendados para você")
                }
            }

            if let note = store.profileNote {
                Section {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.loadProfile() }
        .task { await store.loadProfile() }
        .overlay {
            if store.profileLoading && store.myLikes.isEmpty {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func interestSection(title: String, items: [String], hated: Bool,
                                 draft: Binding<String>) -> some View {
        Section {
            if items.isEmpty {
                Text("Nenhum termo cadastrado.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item).font(.subheadline)
                    Spacer()
                    Button {
                        Task { await store.removeInterest(item, hated: hated) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField(hated ? "adicionar termo que evita" : "adicionar termo que gosta",
                          text: draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { submit(draft: draft, hated: hated) }
                Button {
                    submit(draft: draft, hated: hated)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            SectionLabel(text: title)
        }
    }

    private func submit(draft: Binding<String>, hated: Bool) {
        let text = draft.wrappedValue
        draft.wrappedValue = ""
        Task { await store.addInterest(text, hated: hated) }
    }
}
