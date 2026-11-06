import SwiftUI

struct ResultRow: Identifiable {
    let id: String
    let file: SearchFile
    let peer: SearchResponse
}

/// Resultados no formato de tabela: cabeçalho ordenável e linhas densas.
struct ResultsTable: View {
    let rows: [ResultRow]
    @Binding var column: Int
    @Binding var ascending: Bool
    let onDownload: (SearchFile, String) -> Void

    private let widths: (size: CGFloat, bit: CGFloat, user: CGFloat) = (62, 46, 92)

    var body: some View {
        Section {
            header
            ForEach(sorted) { row in
                line(row)
            }
        }
    }

    private var sorted: [ResultRow] {
        rows.sorted { lhs, rhs in
            let result: Bool
            switch column {
            case 1:
                result = (lhs.file.size ?? 0) < (rhs.file.size ?? 0)
            case 2:
                result = (lhs.file.bitRate ?? 0) < (rhs.file.bitRate ?? 0)
            case 3:
                result = (lhs.peer.username ?? "") < (rhs.peer.username ?? "")
            default:
                result = lhs.file.displayName.localizedCaseInsensitiveCompare(rhs.file.displayName) == .orderedAscending
            }
            return ascending ? result : !result
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            button("Nome", 0, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            button("Tam", 1, alignment: .trailing)
                .frame(width: widths.size, alignment: .trailing)
            button("Bit", 2, alignment: .trailing)
                .frame(width: widths.bit, alignment: .trailing)
            button("Usuário", 3, alignment: .leading)
                .frame(width: widths.user, alignment: .leading)
        }
        .font(.system(.caption2, design: .monospaced).weight(.semibold))
        .listRowBackground(Theme.accent.opacity(0.10))
    }

    private func button(_ title: String, _ index: Int, alignment: Alignment) -> some View {
        Button {
            if column == index { ascending.toggle() } else { column = index; ascending = true }
        } label: {
            HStack(spacing: 2) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                if column == index {
                    Image(systemName: ascending ? "arrow.up" : "arrow.down").font(.system(size: 8))
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .foregroundStyle(column == index ? Theme.accent : .secondary)
        }
        .buttonStyle(.borderless)
    }

    private func line(_ row: ResultRow) -> some View {
        HStack(spacing: 6) {
            Text(row.file.displayName)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Fmt.bytes(row.file.size))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: widths.size, alignment: .trailing)

            Text((row.file.bitRate ?? 0) > 0 ? "\(row.file.bitRate ?? 0)k" : "—")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: widths.bit, alignment: .trailing)

            Text(row.peer.username ?? "?")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .frame(width: widths.user, alignment: .leading)

            Button {
                onDownload(row.file, row.peer.username ?? "")
            } label: {
                Image(systemName: "arrow.down").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}
