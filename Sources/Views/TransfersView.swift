import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = 0
    @State private var selected: TransferFile?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Modo", selection: $mode) {
                        Text("Baixando").tag(0)
                        Text("Enviando").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                if mode == 0 {
                    downloadsContent
                } else {
                    uploadsContent
                }

                if let message = store.errorMessage {
                    Section { ErrorBanner(message: message) }
                }
            }
            .navigationTitle("Transferências")
            .refreshable {
                await store.refresh()
                await store.loadPositions()
            }
            .task { await store.loadPositions() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") {
                        confirmClear = true
                    }
                    .font(.caption)
                }
            }
            .confirmationDialog("Apagar os concluídos da lista?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Apagar concluídos", role: .destructive) {
                    Task { await store.clearCompleted() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Só remove da lista. Os arquivos continuam no servidor.")
            }
            .sheet(item: $selected) { file in
                TransferDetailView(file: file)
                    .environmentObject(store)
            }
        }
    }

    // MARK: Downloads

    @ViewBuilder
    private var downloadsContent: some View {
        Section {
            HStack {
                StatTile(label: "ativos", value: "\(store.activeDownloads.count)")
                StatTile(label: "velocidade", value: Fmt.speed(store.totalSpeed), tint: Theme.ok)
                StatTile(label: "concluídos", value: "\(store.finishedDownloads.count)",
                         tint: .white.opacity(0.9))
            }
            .padding(12)
            .background(Theme.hero)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
        }

        if store.downloads.isEmpty {
            Section {
                EmptyState(title: "Nenhuma transferência",
                           systemImage: "arrow.down.circle",
                           detail: "Busque algo e mande baixar. A transferência roda no servidor, não no telefone.")
                    .listRowBackground(Color.clear)
            }
        } else {
            ForEach(store.downloads) { user in
                Section {
                    ForEach(user.directories ?? []) { directory in
                        ForEach(directory.files ?? []) { file in
                            row(file, uploading: false)
                        }
                    }
                } header: {
                    SectionLabel(text: user.username ?? "peer")
                }
            }
        }
    }

    // MARK: Uploads

    @ViewBuilder
    private var uploadsContent: some View {
        if store.uploads.isEmpty {
            Section {
                EmptyState(title: "Ninguém baixando de você",
                           systemImage: "arrow.up.circle",
                           detail: "Os uploads que os peers puxam do teu compartilhamento aparecem aqui.")
                    .listRowBackground(Color.clear)
            }
        } else {
            ForEach(store.uploads) { user in
                Section {
                    ForEach(user.directories ?? []) { directory in
                        ForEach(directory.files ?? []) { file in
                            row(file, uploading: true)
                        }
                    }
                } header: {
                    SectionLabel(text: user.username ?? "peer")
                }
            }
        }
    }

    // MARK: Linha

    @ViewBuilder
    private func row(_ file: TransferFile, uploading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(file.displayNameLabel).font(.subheadline).lineLimit(2)
            ProgressView(value: file.progress)
                .tint(file.isFailed ? Theme.danger : (file.isFinished ? Theme.ok : Theme.accent))
            HStack(spacing: 10) {
                Text(Fmt.stateLabel(file.state)).font(.caption2).foregroundStyle(.secondary)
                Text(Fmt.speed(file.averageSpeed)).font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(file.progress * 100))%").font(.caption2).foregroundStyle(.secondary)
                Text(Fmt.bytes(file.size)).font(.caption2).foregroundStyle(.tertiary)
                if !uploading, let position = store.positions[file.id], !file.isFinished {
                    Text("fila #\(position)").font(.caption2).foregroundStyle(Theme.warn)
                }
                Spacer()
                if !file.isFinished && !uploading {
                    Text(Fmt.eta(file)).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { selected = file }
        .swipeActions {
            if !file.isFinished {
                Button(role: .destructive) {
                    Task {
                        if uploading {
                            await store.cancelUpload(file)
                        } else {
                            await store.cancel(file: file)
                        }
                    }
                } label: {
                    Label("Cancelar", systemImage: "xmark")
                }
            }
            if file.isFinished {
                Button(role: .destructive) {
                    Task { await store.cancel(file: file) }
                } label: {
                    Label("Remover", systemImage: "trash")
                }
            }
            if file.isFailed && !uploading {
                Button {
                    Task { await store.retry(file) }
                } label: {
                    Label("Tentar de novo", systemImage: "arrow.clockwise")
                }
                .tint(.blue)
            }
        }
    }
}

extension TransferFile {
    var displayNameLabel: String {
        guard let raw = filename else { return "?" }
        return raw.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? raw
    }
}
