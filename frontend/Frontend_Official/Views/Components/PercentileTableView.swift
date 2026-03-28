import SwiftUI

struct PercentileTableView: View {
    let result: SimulationResponse

    private let rows: [(pct: Int, label: String, color: Color)] = [
        (10, "10th — Conservative", .orange),
        (25, "25th",                .yellow),
        (50, "50th — Median",       .blue),
        (75, "75th",                .teal),
        (90, "90th — Optimistic",   .green),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Percentile Breakdown")
                    .font(.headline)
            }

            VStack(spacing: 0) {
                headerRow
                Divider()
                ForEach(rows, id: \.pct) { row in
                    tableRow(row)
                    if row.pct != 90 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Percentile").frame(maxWidth: .infinity, alignment: .leading)
            Text("Final Value").frame(width: 120, alignment: .trailing)
            Text("Multiple").frame(width: 72, alignment: .trailing)
            Text("CAGR").frame(width: 60, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tableRow(_ row: (pct: Int, label: String, color: Color)) -> some View {
        let key = String(row.pct)
        let finalVal = result.percentiles[key] ?? 0
        let multiple = result.multiples[key] ?? 0
        let cagr = result.cagr[key] ?? 0
        let isMedian = row.pct == 50

        return HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(row.color)
                    .frame(width: 7, height: 7)
                Text(row.label)
                    .font(isMedian ? .subheadline.weight(.semibold) : .subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(finalVal, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.subheadline.monospacedDigit())
                .frame(width: 120, alignment: .trailing)

            Text(String(format: "%.1f×", multiple))
                .font(.subheadline.monospacedDigit())
                .frame(width: 72, alignment: .trailing)

            Text(cagr, format: .percent.precision(.fractionLength(1)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(cagr >= 0 ? .green : .red)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(isMedian ? Color.blue.opacity(0.05) : .clear)
    }
}
