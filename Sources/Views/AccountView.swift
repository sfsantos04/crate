import SwiftUI

/// Conta no servidor: ficar ausente, trocar senha e ver privilégios.
struct AccountView: View {
    @EnvironmentObject private var store: AppStore

    @State private var away = false
    @State private var showPassword = false
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                Toggle("Ficar ausente", isOn: $away)
                    .onChange(of: away) { _, value in
                        Task {
                            do {
                                try await store.client.setStatus(away: value)
                                store.flash(value ? "Status: ausente" : "Status: online")
                            } catch {
                                store.flash("Falhou ao mudar status")
                            }
                        }
                    }
            } header: {
                SectionLabel(text: "Status")
            } footer: {
                Text("Ausente aparece para quem te procura, mas você continua recebendo busca e transferência.")
            }

            Section {
                LabeledContent("Dias de privilégio", value: "\(store.ownPrivilegeDays)")
                Button("Trocar senha") { showPassword = true }
            } header: {
                SectionLabel(text: "Conta")
            } footer: {
                Text("A senha é a da conta Soulseek, não a do slskd. Trocar aqui desloga o slskd de outros lugares.")
            }
        }
        .navigationTitle("Conta")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadOwnPrivileges() }
        .alert("Nova senha da conta Soulseek", isPresented: $showPassword) {
            SecureField("nova senha", text: $password)
            Button("Trocar") {
                let value = password
                password = ""
                Task {
                    do {
                        try await store.client.changePassword(value)
                        store.flash("Senha alterada")
                    } catch {
                        store.flash("Falhou ao trocar a senha")
                    }
                }
            }
            Button("Cancelar", role: .cancel) { password = "" }
        } message: {
            Text("Mínimo de quatro caracteres. Guarde a nova senha: o Soulseek não tem recuperação.")
        }
    }
}
