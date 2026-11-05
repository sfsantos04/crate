import Foundation

@MainActor
extension AppStore {
    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: Conversas

    func loadConversations() async {
        do {
            conversations = try await client.conversations()
        } catch {
            errorMessage = describe(error)
        }
    }

    func openChat(_ peer: String) async {
        activePeer = peer
        thread = []
        do {
            thread = try await client.chatMessages(with: peer)
            try await client.acknowledgeChat(peer)
            await loadConversations()
        } catch {
            errorMessage = describe(error)
        }
    }

    func reloadThread() async {
        guard let peer = activePeer else { return }
        if let messages = try? await client.chatMessages(with: peer) {
            thread = messages
            try? await client.acknowledgeChat(peer)
        }
    }

    func sendChat(_ text: String) async {
        guard let peer = activePeer else { return }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        do {
            try await client.sendChat(body, to: peer)
            await reloadThread()
        } catch {
            errorMessage = describe(error)
        }
    }

    func closeChat(_ peer: String) async {
        do {
            try await client.closeConversation(peer)
            if activePeer == peer { activePeer = nil; thread = [] }
            await loadConversations()
        } catch {
            errorMessage = describe(error)
        }
    }

    var unreadTotal: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    // MARK: Salas

    func loadRooms() async {
        do {
            joinedRooms = try await client.joinedRooms()
            rooms = try await client.availableRooms()
        } catch {
            errorMessage = describe(error)
        }
    }

    func join(_ name: String) async {
        socialBusy = true
        do {
            try await client.joinRoom(name)
            await loadRooms()
        } catch {
            errorMessage = describe(error)
        }
        socialBusy = false
    }

    func leave(_ name: String) async {
        socialBusy = true
        do {
            try await client.leaveRoom(name)
            if activeRoom == name { activeRoom = nil; roomThread = [] }
            await loadRooms()
        } catch {
            errorMessage = describe(error)
        }
        socialBusy = false
    }

    func openRoom(_ name: String) async {
        activeRoom = name
        roomThread = []
        do {
            roomThread = try await client.roomMessages(name)
        } catch {
            errorMessage = describe(error)
        }
    }

    func reloadRoom() async {
        guard let room = activeRoom else { return }
        if let messages = try? await client.roomMessages(room) {
            roomThread = messages
        }
    }

    func sendRoom(_ text: String) async {
        guard let room = activeRoom else { return }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        do {
            try await client.sendRoom(body, to: room)
            await reloadRoom()
        } catch {
            errorMessage = describe(error)
        }
    }

    func roomMembers(_ name: String) async -> [String] {
        (try? await client.roomUsers(name)) ?? []
    }

    // MARK: Browse

    func browse(_ peer: String) async {
        browsePeer = peer
        browseDirectories = []
        browseProgress = 0
        do {
            let result = try await client.browse(peer)
            browseDirectories = result.directories ?? []
        } catch {
            errorMessage = describe(error)
        }
    }

    func refreshBrowseProgress() async {
        guard let peer = browsePeer else { return }
        if let status = try? await client.browseStatus(peer) {
            browseProgress = status.progress
        }
    }

    func closeBrowse() {
        browsePeer = nil
        browseDirectories = []
        browseProgress = 0
    }

    func downloadBrowse(_ file: BrowseFile, peer: String) async {
        guard let name = file.filename else { return }
        do {
            try await client.enqueue(username: peer, files: [(filename: name, size: file.size ?? 0)])
            await refresh()
        } catch {
            errorMessage = describe(error)
        }
    }

    func downloadBrowseDirectory(_ directory: BrowseDirectory, peer: String) async {
        let payload = (directory.files ?? []).compactMap { file -> (filename: String, size: Int64)? in
            guard let name = file.filename else { return nil }
            return (filename: name, size: file.size ?? 0)
        }
        guard !payload.isEmpty else { return }
        do {
            try await client.enqueue(username: peer, files: payload)
            await refresh()
        } catch {
            errorMessage = describe(error)
        }
    }

    // MARK: Ações de transferência

    func clearCompleted() async {
        do {
            try await client.clearCompletedDownloads()
            try await client.clearCompletedUploads()
            await refresh()
        } catch {
            errorMessage = describe(error)
        }
    }

    func retry(_ file: TransferFile) async {
        guard let name = file.filename, let peer = file.username else { return }
        do {
            try await client.enqueue(username: peer, files: [(filename: name, size: file.size ?? 0)])
            await refresh()
        } catch {
            errorMessage = describe(error)
        }
    }

    func cancelUpload(_ file: TransferFile) async {
        guard let id = file.transferID, let user = file.username else { return }
        do {
            try await client.cancelUpload(username: user, id: id)
            await refresh()
        } catch {
            errorMessage = describe(error)
        }
    }

    func loadPositions() async {
        var updated: [String: Int] = [:]
        for file in activeDownloads.prefix(20) {
            guard let id = file.transferID, let peer = file.username else { continue }
            if let position = try? await client.transferPosition(username: peer, id: id) {
                updated[file.id] = position
            }
        }
        positions = updated
    }
}
