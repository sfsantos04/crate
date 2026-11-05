import Foundation

@MainActor
extension AppStore {
    private func describeFork(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    /// Detecta se o servidor é o fork; roda no login e no refresh manual.
    func detectFork() async {
        let available = await client.forkAvailable()
        if forkMode != available {
            forkMode = available
        }
        if available {
            await loadProfile()
        }
    }

    func loadProfile() async {
        guard forkMode else { return }
        profileLoading = true
        defer { profileLoading = false }
        do {
            if let interests = try? await client.myInterests() {
                myLikes = interests.likes
                myHates = interests.hates
            }
            if let privileges = try? await client.privileges() {
                privilegesDays = privileges.daysRemaining
            }
            if let users = try? await client.similarUsers() {
                similar = users.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            }
            if let global = try? await client.recommendations(scope: "global") {
                globalRecommendations = global.yes
            }
            if let personal = try? await client.recommendations(scope: "personal") {
                personalRecommendations = personal.yes
            }
            profileNote = nil
        }
    }

    func addInterest(_ text: String, hated: Bool) async {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try await client.addInterest(hated ? "hated" : "liked", value)
            await loadProfile()
        } catch {
            profileNote = describeFork(error)
        }
    }

    func removeInterest(_ text: String, hated: Bool) async {
        do {
            try await client.removeInterest(hated ? "hated" : "liked", text)
            await loadProfile()
        } catch {
            profileNote = describeFork(error)
        }
    }

    func toggleAway() async {
        do {
            try await client.setStatus(away: true)
            profileNote = "Status alterado para ausente."
        } catch {
            profileNote = describeFork(error)
        }
    }

    func watch(_ username: String) async {
        do {
            let user = try await client.watchedUser(username)
            let country = [user.flag, user.countryName].compactMap { $0 }.joined(separator: " ")
            profileNote = "\(user.username ?? username): \(country.isEmpty ? "sem país" : country), \(user.fileCount ?? 0) arquivos, \(Int(user.averageSpeed ?? 0) / 1024) KB/s"
        } catch {
            profileNote = describeFork(error)
        }
    }
}
