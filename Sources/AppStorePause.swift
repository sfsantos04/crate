import Foundation

@MainActor
extension AppStore {
    func loadPauseState() async {
        guard forkMode else { return }
        if let state = try? await client.pausedState() {
            queuePaused = state.paused
            heldTransfers = state.held
        }
    }

    func enqueueFile(peer: String, path: String, size: Int64) async {
        do {
            try await client.enqueue(username: peer, files: [(filename: path, size: size)])
            flash("Na fila")
            await refresh()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            flash("Falhou: \(message)")
        }
    }

    func grantPrivileges(to username: String, days: Int) async {
        do {
            try await client.grantPrivileges(to: username, days: days)
            flash("Privilégios enviados: \(days) dia(s) para \(username)")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            flash("Falhou: \(message)")
        }
    }

    func loadOwnPrivileges() async {
        ownPrivilegeDays = (try? await client.ownPrivileges()) ?? 0
    }

    func openSearch(id: String) async {
        guard !id.isEmpty else { return }
        do {
            search = try await client.search(id: id)
            flash("Busca carregada")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            flash("Falhou: \(message)")
        }
    }

    func deleteSearch(id: String) async {
        do {
            try await client.deleteSearch(id: id)
        } catch {
            flash("Falhou ao apagar busca")
        }
    }

    func loadRoomTickers() async {
        guard forkMode, let room = activeRoom else { return }
        roomTickers = (try? await client.tickers(room: room)) ?? []
    }

    func togglePause() async {
        do {
            if queuePaused {
                try await client.resumeQueue()
                flash("Fila retomada")
            } else {
                try await client.pauseQueue()
                flash("Fila pausada")
            }
            await loadPauseState()
            await refresh()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            flash("Falhou: \(message)")
        }
    }
}
