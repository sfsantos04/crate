import SwiftUI

/// O que o slskd não guarda: buscas recebidas, conversas e uploads recusados.
struct ActivityView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = 0

    var body: some View {
        List {
            Section {
                Picker("Modo", selection: $mode) {
                    Text("Buscas").tag(0)
                    Text("Conversas").tag(1)
                    Text("Recusas").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            let items = mode == 0 ? store.receivedSearches : (mode == 1 ? store.chatLog : store.deniedLog)
            if items.isEmpty {
                EmptyState(title: "Nada registrado",
                           systemImage: "clock.arrow.circlepath",
                           detail: "O slskd não guarda isso por conta própria; o fork mantém os últimos 500 eventos em memória.")
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        Text(item.detail).font(.caption).lineLimit(2)
                        Text(item.at).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            } header: {
                SectionLabel(text: "\(items.count) eventos")
            }
        }
        .navigationTitle("Atividade")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadActivity() }
        .refreshable { await store.loadActivity() }
    }
}
