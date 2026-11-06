import SwiftUI

/// Slots de upload e limites de velocidade, aplicados no servidor em tempo real.
struct TransferSettingsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var uploadSlots = 10
    @State private var uploadUnlimited = true
    @State private var uploadKB = 512.0
    @State private var downloadUnlimited = true
    @State private var downloadKB = 2048.0
    @State private var busy = false
    @State private var loaded = false
    @State private var listenPort = 0
    @State private var uploadsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Aceitar uploads", isOn: $uploadsEnabled)
                    .onChange(of: uploadsEnabled) { _, value in
                        Task {
                            try? await store.client.setUploads(enabled: value)
                            store.flash(value ? "Uploads aceitos" : "Uploads recusados")
                        }
                    }
                Stepper("Slots de upload: \(uploadSlots)", value: $uploadSlots, in: 1...50)
            } header: {
                SectionLabel(text: "Upload")
            } footer: {
                Text("Quantas pessoas podem baixar de você ao mesmo tempo. O SoulseekQt chama isso de upload slots.")
            }

            Section {
                Toggle("Sem limite de upload", isOn: $uploadUnlimited)
                if !uploadUnlimited {
                    HStack {
                        Text("\(Int(uploadKB)) KB/s").font(.subheadline).monospacedDigit()
                        Slider(value: $uploadKB, in: 64...8192, step: 64)
                    }
                }
            } header: {
                SectionLabel(text: "Velocidade de upload")
            }

            Section {
                Toggle("Sem limite de download", isOn: $downloadUnlimited)
                if !downloadUnlimited {
                    HStack {
                        Text("\(Int(downloadKB)) KB/s").font(.subheadline).monospacedDigit()
                        Slider(value: $downloadKB, in: 256...20480, step: 256)
                    }
                }
            } header: {
                SectionLabel(text: "Velocidade de download")
            }

            Section {
                TextField("porta de escuta", value: $listenPort, format: .number)
                    .keyboardType(.numberPad)
                Button {
                    applyPort()
                } label: {
                    Label("Aplicar porta", systemImage: "network")
                }
            } header: {
                SectionLabel(text: "Porta")
            } footer: {
                Text("Porta em que outros clientes conectam para baixar de você. Mudar exige que ela esteja liberada no roteador.")
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Label("Aplicar no servidor", systemImage: "checkmark.circle")
                        if busy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(busy || !loaded)
            } footer: {
                Text("Aplica na hora, sem reiniciar o slskd. Vale para todas as transferências em andamento.")
            }
        }
        .navigationTitle("Transferências")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        if let settings = try? await store.client.transferSettings() {
            uploadSlots = settings.uploadSlots
            uploadUnlimited = settings.uploadUnlimited
            downloadUnlimited = settings.downloadUnlimited
            if !settings.uploadUnlimited {
                uploadKB = Double(settings.uploadSpeedLimit) / 1024
            }
            if !settings.downloadUnlimited {
                downloadKB = Double(settings.downloadSpeedLimit) / 1024
            }
        }
        listenPort = (try? await store.client.listenPort()) ?? 0
        uploadsEnabled = (try? await store.client.uploadsEnabled()) ?? true
        loaded = true
    }

    private func applyPort() {
        guard listenPort > 1023 && listenPort < 65536 else {
            store.flash("Porta inválida")
            return
        }
        Task {
            do {
                try await store.client.setListenPort(listenPort)
                store.flash("Porta aplicada: \(listenPort)")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                store.flash("Falhou: \(message)")
            }
        }
    }

    private func save() {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await store.client.patchTransfers(
                    uploadSlots: uploadSlots,
                    uploadSpeed: uploadUnlimited ? TransferSettings.unlimited : Int(uploadKB * 1024),
                    downloadSpeed: downloadUnlimited ? TransferSettings.unlimited : Int(downloadKB * 1024)
                )
                store.flash("Ajustes aplicados")
                await load()
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                store.flash("Falhou: \(message)")
            }
        }
    }
}
