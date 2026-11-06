import SwiftUI

/// Arquivos de log do slskd, com leitura do conteúdo.
struct LogsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var files: [String] = []
    @State private var selected: String?
    @State private var content = ""
    @State private var loading = false

    var body: some View {
        List {
            if loading {
                HStack { ProgressView(); Text("carregando…").font(.footnote) }
            }
            ForEach(files, id: \.self) { file in
                Button {
                    selected = file
                    content = ""
                    Task {
                        content = (try? await store.client.logContent(file)) ?? "sem conteúdo"
                    }
                } label: {
                    HStack {
                        Text(file).font(.caption)
                        Spacer()
                        if selected == file {
                            Image(systemName: "checkmark").font(.caption2).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }

            if !content.isEmpty {
                Section {
                    Text(content)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(400)
                } header: {
                    SectionLabel(text: selected ?? "log")
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loading = true
            files = (try? await store.client.logFiles()) ?? []
            loading = false
        }
        .refreshable {
            files = (try? await store.client.logFiles()) ?? []
        }
    }
}
