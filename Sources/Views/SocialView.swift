import SwiftUI

struct SocialView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = 0

    var body: some View {
        NavigationStack {
            Group {
                if mode == 0 {
                    conversationsList
                } else {
                    roomsList
                }
            }
            .navigationTitle(mode == 0 ? "Chat" : "Salas")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Modo", selection: $mode) {
                        Text("Chat").tag(0)
                        Text("Salas").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if mode == 0 { await store.loadConversations() } else { await store.loadRooms() }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if mode == 0 { await store.loadConversations() } else { await store.loadRooms() }
            }
            .onChange(of: mode) { _, value in
                Task {
                    if value == 0 { await store.loadConversations() } else { await store.loadRooms() }
                }
            }
        }
    }

    private var conversationsList: some View {
        List {
            if store.conversations.isEmpty {
                ContentUnavailableView(
                    "Sem conversas",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Mensagens privadas trocadas pelo slskd aparecem aqui.")
                )
            }
            ForEach(store.conversations) { conversation in
                NavigationLink {
                    ChatThreadView(peer: conversation.username ?? "")
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.username ?? "?").font(.subheadline).bold()
                            Text((conversation.isActive ?? false) ? "ativa" : "inativa")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if conversation.unread > 0 {
                            Text("\(conversation.unread)")
                                .font(.caption2).bold()
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(Capsule())
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

    private var roomsList: some View {
        List {
            Section("Entradas") {
                if store.joinedRooms.isEmpty {
                    Text("Nenhuma sala.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.joinedRooms) { room in
                    NavigationLink {
                        RoomThreadView(room: room.name ?? "")
                    } label: {
                        HStack {
                            Text(room.name ?? "?").font(.subheadline)
                            Spacer()
                            Button("sair") {
                                Task { await store.leave(room.name ?? "") }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                }
            }
            Section("Disponíveis (\(store.rooms.count))") {
                ForEach(store.rooms.prefix(200)) { room in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(room.name ?? "?").font(.subheadline).lineLimit(1)
                            Text("\(room.userCount ?? 0) usuários\((room.isModerated ?? false) ? " · moderada" : "")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("entrar") {
                            Task { await store.join(room.name ?? "") }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }
        .refreshable { await store.loadRooms() }
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
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.thread.count) { _, _ in
                    if let last = store.thread.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
                    Image(systemName: "paperplane.fill")
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
                Text(message.message ?? "")
                    .font(.subheadline)
                Text(message.timestamp ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .background(message.incoming ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if !message.incoming { Spacer(minLength: 40) }
        }
    }
}

struct RoomThreadView: View {
    @EnvironmentObject private var store: AppStore
    let room: String
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.roomThread) { message in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(message.username ?? "?").font(.caption).bold()
                            Text(message.message ?? "").font(.subheadline)
                        }
                    }
                }
                .padding()
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
                    Image(systemName: "paperplane.fill")
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
        }
        .navigationTitle(room)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.openRoom(room)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await store.reloadRoom()
            }
        }
    }
}
