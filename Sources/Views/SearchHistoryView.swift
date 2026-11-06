import SwiftUI

struct SearchSummary: Decodable, Identifiable {
    var id: String?
    var searchText: String?
    var fileCount: Int?
    var responseCount: Int?
    var state: String?
    var startedAt: String?
    var endedAt: String?

    var ident: String { id ?? UUID().uuidString }
}

extension SlskdClient {
    func allSearches() async throws -> [SearchSummary] {
        let data = try await send("/api/v0/searches")
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return decoded.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            var summary = SearchSummary()
            summary.id = id
            summary.searchText = item["searchText"] as? String
            summary.fileCount = item["fileCount"] as? Int
            summary.responseCount = item["responseCount"] as? Int
            summary.state = item["state"] as? String
            summary.startedAt = item["startedAt"] as? String
            summary.endedAt = item["endedAt"] as? String
            return summary
        }
    }
}

/// Histórico de buscas do servidor, com a possibilidade de reabrir qualquer uma.
struct SearchHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var searches: [SearchSummary] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { ProgressView(); Text("carregando…").font(.footnote) }
                } else if searches.isEmpty {
                    EmptyState(title: "Sem buscas",
                               systemImage: "clock",
                               detail: "O slskd guarda as buscas recentes; elas aparecem aqui para reabrir sem digitar de novo.")
                        .listRowBackground(Color.clear)
                }
                ForEach(searches) { item in
                    Button {
                        Task {
                            await store.openSearch(id: item.id ?? "")
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.searchText ?? "?").font(.subheadline).foregroundStyle(.primary)
                            Text("\(item.responseCount ?? 0) peers · \(item.fileCount ?? 0) arquivos · \(item.state ?? "?")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let item = searches[index]
                        Task { await store.deleteSearch(id: item.id ?? "") }
                    }
                    searches.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Buscas recentes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .task {
                searches = (try? await store.client.allSearches()) ?? []
                loading = false
            }
            .refreshable {
                searches = (try? await store.client.allSearches()) ?? []
            }
        }
    }
}
