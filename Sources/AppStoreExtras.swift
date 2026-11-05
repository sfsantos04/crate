import Foundation

@MainActor
extension AppStore {
    private func describeExtras(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: Listas

    func loadLists() async {
        guard forkMode else { return }
        if let list = try? await client.buddies() {
            buddies = list
        }
        if let list = try? await client.ignoredUsers() {
            ignoredUsers = list
        }
    }

    func addBuddy(_ username: String) async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try await client.addBuddy(name)
            await loadLists()
            flash("\(name) na buddy list")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    func removeBuddy(_ username: String) async {
        do {
            try await client.removeBuddy(username)
            await loadLists()
            flash("\(username) removido dos buddies")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    func addIgnored(_ username: String) async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try await client.addIgnored(name)
            await loadLists()
            flash("\(name) ignorado")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    func removeIgnored(_ username: String) async {
        do {
            try await client.removeIgnored(username)
            await loadLists()
            flash("\(username) liberado")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    // MARK: Notas

    func loadNote(for username: String) async -> String {
        (try? await client.note(for: username)) ?? ""
    }

    func saveNote(_ text: String, for username: String) async {
        do {
            try await client.setNote(text, for: username)
            flash("Nota salva")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    // MARK: Wishlist

    func loadWishlist() async {
        guard forkMode else { return }
        if let list = try? await client.wishlist() {
            wishlist = list
        }
    }

    func addWishlist(_ text: String, intervalMinutes: Int) async {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            _ = try await client.addWishlist(text: value, intervalMinutes: intervalMinutes)
            await loadWishlist()
            flash("Busca salva")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    func removeWishlist(_ item: WishlistItem) async {
        guard let id = item.id else { return }
        do {
            try await client.removeWishlist(id: id)
            await loadWishlist()
            flash("Busca removida")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }

    func runWishlist(_ item: WishlistItem) async {
        guard let id = item.id else { return }
        wishlistBusy = true
        defer { wishlistBusy = false }
        do {
            let updated = try await client.runWishlist(id: id)
            await loadWishlist()
            flash("\(updated.text ?? ""): \(updated.lastHitCount ?? 0) resultados")
        } catch {
            flash("Falhou: \(describeExtras(error))")
        }
    }
}
