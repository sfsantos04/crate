import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: AppStore
    @State private var host = ""
    @State private var user = ""
    @State private var password = ""
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("host:porta do slskd", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("usuário do slskd", text: $user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("senha do slskd", text: $password)
                } header: {
                    Text("slskd")
                } footer: {
                    Text("Endereço do container na sua rede. A senha fica no Keychain do aparelho, não no código do app.")
                }

                if let message = localError ?? store.errorMessage {
                    Section { ErrorBanner(message: message) }
                }

                Section {
                    Button {
                        Task {
                            guard !host.isEmpty, !user.isEmpty, !password.isEmpty else {
                                localError = "Preencha host, usuário e senha."
                                return
                            }
                            localError = nil
                            await store.signIn(host: host, username: user, password: password)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if store.busy {
                                ProgressView()
                            } else {
                                Text("Entrar").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(store.busy)
                }
            }
            .navigationTitle("Sonda")
            .onAppear {
                if host.isEmpty { host = store.host }
                if user.isEmpty { user = store.username }
            }
        }
    }
}
