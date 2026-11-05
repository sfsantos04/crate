import Foundation

struct ShareHostRow: Identifiable {
    let id: String
    let shares: Int
    let files: Int
}

@MainActor
extension AppStore {
    func startRealtime() {
        realtime.onSignal = { [weak self] in
            guard let self else { return }
            Task {
                await self.refresh()
                await self.reloadThread()
                await self.reloadRoom()
                await self.loadPositions()
            }
        }
        realtime.onState = { [weak self] up in
            self?.realtimeConnected = up
        }
        realtime.start { [weak self] in
            guard let self else { return nil }
            return try? await self.client.hubURL()
        }
    }

    func stopRealtime() {
        realtime.stop()
        realtimeConnected = false
    }

    // MARK: Shares

    func shareSummary() async -> [ShareHostRow] {
        guard let data = try? await client.sharesRaw(),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var rows: [ShareHostRow] = []
        for (host, value) in root {
            guard let items = value as? [[String: Any]] else { continue }
            var files = 0
            for item in items {
                if let count = item["files"] as? Int { files += count }
                else if let dirs = item["directories"] as? [[String: Any]] {
                    files += dirs.reduce(0) { $0 + (($1["files"] as? [Any])?.count ?? 0) }
                }
            }
            rows.append(ShareHostRow(id: host, shares: items.count, files: files))
        }
        return rows.sorted { $0.id < $1.id }
    }

    func rescanShares() async {
        do {
            try await client.rescanShares()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cancelShareScan() async {
        do {
            try await client.cancelShareScan()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Browse de subpasta

    func browseSubdirectory(_ path: String) async {
        guard let peer = browsePeer else { return }
        do {
            browseDirectories = try await client.browseDirectory(username: peer, directory: path)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
