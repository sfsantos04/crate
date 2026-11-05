import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var hostDraft = ""
    @State private var password = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Conexão") {
                    TextField("host:porta", text: $hostDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("senha do slskd (só para reconectar)", text: $password)
                    Button("Reconectar") {
                        Task {
                            await store.signIn(host: hostDraft, username: store.username, password: password)
                            message = store.errorMessage ?? "Conectado."
                            password = ""
                        }
                    }
                    .disabled(hostDraft.isEmpty || password.isEmpty)
                }

                if store.forkMode {
                    Section("Fork") {
                        NavigationLink {
                            TransferSettingsView()
                        } label: {
                            Label("Slots e velocidades", systemImage: "speedometer")
                        }
                        NavigationLink {
                            WishlistView()
                        } label: {
                            Label("Wishlist", systemImage: "bookmark")
                        }
                    }
                }

                Section("Sessão") {
                    LabeledContent("Usuário", value: store.username.isEmpty ? "—" : store.username)
                    LabeledContent("Host", value: store.host)
                    Button("Sair e esquecer a senha", role: .destructive) {
                        store.signOut()
                    }
                }

                Section("Sobre") {
                    LabeledContent("Versão do app", value: store.appVersion)
                    LabeledContent("Slskd", value: store.snapshot?.version ?? "—")
                    Text("Sonda é um cliente de monitoramento do seu próprio slskd. Busca, fila e transferência rodam no servidor; o app só comanda e mostra o estado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .onAppear { hostDraft = store.host }
        }
    }
}
