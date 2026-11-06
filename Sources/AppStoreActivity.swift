import Foundation

@MainActor
extension AppStore {
    private func describeActivity(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func loadGroups() async {
        guard forkMode else { return }
        groups = (try? await client.groups()) ?? [:]
    }

    func createGroup(_ name: String) async {
        let value = name.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        do { try await client.createGroup(value); await loadGroups(); flash("Grupo \(value) criado") }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func deleteGroup(_ name: String) async {
        do { try await client.deleteGroup(name); await loadGroups(); flash("Grupo \(name) apagado") }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func addGroupMember(_ group: String, _ username: String) async {
        let value = username.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        do { try await client.addGroupMember(group, value); await loadGroups(); flash("\(value) em \(group)") }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func removeGroupMember(_ group: String, _ username: String) async {
        do { try await client.removeGroupMember(group, username); await loadGroups() }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func loadBanned() async {
        guard forkMode else { return }
        bannedUsers = (try? await client.banned()) ?? []
    }

    func ban(_ username: String) async {
        let value = username.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        do { try await client.ban(value); await loadBanned(); flash("\(value) banido") }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func unban(_ username: String) async {
        do { try await client.unban(username); await loadBanned() }
        catch { flash("Falhou: \(describeActivity(error))") }
    }

    func loadActivity() async {
        guard forkMode else { return }
        receivedSearches = (try? await client.receivedSearches()) ?? []
        chatLog = (try? await client.chatLog()) ?? []
        deniedLog = (try? await client.deniedLog()) ?? []
    }
}
