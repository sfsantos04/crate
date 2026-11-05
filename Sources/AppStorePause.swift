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
