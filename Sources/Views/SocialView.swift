import SwiftUI

struct SocialView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = 0
    @State private var sortByUsers = true
    @State private var roomQuery = ""

    var body: some View {
        NavigationStack {
            Group {
                if mode == 0 {
                    conversationsList
                } else if mode == 1 {
                    roomsList
                } else {
                    ListsView()
                }
            }
            .navigationTitle(mode == 0 ? "Chat" : (mode == 1 ? "Salas" : "Listas"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Modo", selection: $mode) {
                        Text("Chat").tag(0)
                        Text("Salas").tag(1)
                        Text("Listas").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await reload() }
            .onChange(of: mode) { _, _ in Task { await reload() } }
        }
    }

    private func reload() async {
        if mode == 0 { await store.loadConversations() } else { await store.loadRooms() }
    }

    // MARK: Chat

    private var conversationsList: some View {
        List {
            if let action = store.actionMessage {
                Section {
                    Label(action, systemImage: action.hasPrefix("Falhou") ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(action.hasPrefix("Falhou") ? Theme.danger : Theme.ok)
                }
            }
            if store.conversations.isEmpty {
                EmptyState(title: "Sem conversas",
                           systemImage: "bubble.left.and.bubble.right",
                           detail: "Mensagens privadas trocadas pelo slskd aparecem aqui, com contador de não lidas.")
                    .listRowBackground(Color.clear)
            }
            ForEach(store.conversations) { conversation in
                NavigationLink {
                    ChatThreadView(peer: conversation.username ?? "")
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill((conversation.isActive ?? false) ? Theme.ok : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.username ?? "?").font(.subheadline.weight(.medium))
                            Text((conversation.isActive ?? false) ? "ativa" : "inativa")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if conversation.unread > 0 {
                            CountPill(text: "\(conversation.unread)", tint: Theme.warn)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await store.closeChat(conversation.username ?? "") }
                    } label: {
                        Label("Fechar", systemImage: "trash")
                    }
                }
            }
        }
        .refreshable { await store.loadConversations() }
    }

    // MARK: Salas

    private var visibleRooms: [RoomInfo] {
        let query = roomQuery.trimmingCharacters(in: .whitespaces)
        var list = store.rooms
        if !query.isEmpty {
            list = list.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
        }
        if sortByUsers {
            list.sort { ($0.userCount ?? 0) > ($1.userCount ?? 0) }
        } else {
            list.sort { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        }
        return list
    }

    private var roomsList: some View {
        List {
            if let action = store.actionMessage {
                Section {
                    Label(action, systemImage: action.hasPrefix("Falhou") ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(action.hasPrefix("Falhou") ? Theme.danger : Theme.ok)
                }
            }
            Section {
                Toggle(isOn: $sortByUsers) {
                    Label("Ordenar por usuários", systemImage: "person.3.fill")
                        .font(.subheadline)
                }
                .tint(Theme.accent)
            }

            if !store.joinedRooms.isEmpty {
                Section {
                    ForEach(store.joinedRooms) { room in
                        NavigationLink {
                            RoomThreadView(room: room.name ?? "")
                        } label: {
                            roomRow(room, joined: true)
                        }
                    }
                } header: {
                    SectionLabel(text: "Entradas")
                }
            }

            Section {
                ForEach(visibleRooms.prefix(300)) { room in
                    NavigationLink {
                        RoomThreadView(room: room.name ?? "")
                    } label: {
                        roomRow(room, joined: false)
                    }
                }
            } header: {
                SectionLabel(text: "Disponíveis · \(visibleRooms.count)")
            }
        }
        .searchable(text: $roomQuery, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "filtrar salas")
        .refreshable { await store.loadRooms() }
    }

    @ViewBuilder
    private func roomRow(_ room: RoomInfo, joined: Bool) -> some View {
        let match = CountryFlag.detect(room.name ?? "")
        HStack(spacing: 10) {
            Text(match?.emoji ?? "🌐")
                .font(.title3)
                .accessibilityLabel(match?.name ?? "país não identificado")
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name ?? "?").font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if let name = match?.name {
                        Text(name).font(.caption2).foregroundStyle(.secondary)
                    }
                    if room.isModerated == true {
                        Text("moderada").font(.caption2).foregroundStyle(Theme.warn)
                    }
                    if room.isPrivate == true {
                        Text("privada").font(.caption2).foregroundStyle(Theme.danger)
                    }
                }
            }
            Spacer()
            CountPill(text: "\(room.userCount ?? 0)", tint: joined ? Theme.ok : Theme.accent)
            if !joined {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(Theme.accent.opacity(0.7))
                    .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ChatThreadView: View {
    @EnvironmentObject private var store: AppStore
    let peer: String
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.thread) { message in
                            bubble(message).id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.thread.count) { _, _ in
                    if let last = store.thread.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("mensagem", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = draft
                    draft = ""
                    Task { await store.sendChat(text) }
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
        }
        .navigationTitle(peer)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.openChat(peer)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await store.reloadThread()
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.incoming { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(message.message ?? "").font(.subheadline)
                Text(message.timestamp ?? "").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(message.incoming ? Color.secondary.opacity(0.14) : Theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !message.incoming { Spacer(minLength: 40) }
        }
    }
}

struct RoomThreadView: View {
    @EnvironmentObject private var store: AppStore
    let room: String
    @State private var draft = ""
    @State private var members: [String] = []
    @State private var showMembers = false
    @State private var showScopedSearch = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.roomThread) { message in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(message.username ?? "?")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text(message.message ?? "").font(.subheadline)
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.roomThread.count) { _, _ in
                    if let last = store.roomThread.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("mensagem para a sala", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = draft
                    draft = ""
                    Task { await store.sendRoom(text) }
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
        }
        .navigationTitle(room)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showScopedSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        members = await store.roomMembers(room)
                        showMembers = true
                    }
                } label: {
                    Image(systemName: "person.2")
                }
            }
        }
        .sheet(isPresented: $showScopedSearch) {
            ScopedSearchView(room: room, username: nil).environmentObject(store)
        }
        .sheet(isPresented: $showMembers) {
            NavigationStack {
                List(members, id: \.self) { member in
                    NavigationLink {
                        UserProfileView(username: member)
                    } label: {
                        Text(member).font(.subheadline)
                    }
                }
                .navigationTitle("\(members.count) na sala")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fechar") { showMembers = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            if !store.joinedRooms.contains(where: { $0.name == room }) {
                await store.join(room)
            }
            await store.openRoom(room)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await store.reloadRoom()
            }
        }
    }
}
