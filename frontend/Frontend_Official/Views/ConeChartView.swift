import SwiftUI
import Charts

struct ConeChartView: View {
    let response: SimulationResponse

    private var points: [ConePoint] { ConePoint.fromResponse(response) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Growth Projection")
                        .font(.headline)
                    Text("\(response.nYears)-year outlook · \(response.nYears * 12) monthly samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                legendView
            }

            // Chart
            Chart {
                // Outer band: P10–P90
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Year", pt.year),
                        yStart: .value("P10", pt.p10),
                        yEnd: .value("P90", pt.p90)
                    )
                    .foregroundStyle(.blue.opacity(0.07))
                    .interpolationMethod(.catmullRom)
                }

                // Inner band: P25–P75
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Year", pt.year),
                        yStart: .value("P25", pt.p25),
                        yEnd: .value("P75", pt.p75)
                    )
                    .foregroundStyle(.blue.opacity(0.14))
                    .interpolationMethod(.catmullRom)
                }

                // P10 dashed line
                ForEach(points) { pt in
                    LineMark(x: .value("Year", pt.year), y: .value("P10", pt.p10))
                        .foregroundStyle(.orange.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .interpolationMethod(.catmullRom)
                }

                // P90 dashed line
                ForEach(points) { pt in
                    LineMark(x: .value("Year", pt.year), y: .value("P90", pt.p90))
                        .foregroundStyle(.green.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .interpolationMethod(.catmullRom)
                }

                // Median — most prominent
                ForEach(points) { pt in
                    LineMark(x: .value("Year", pt.year), y: .value("Median", pt.p50))
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }

                // Initial value reference
                RuleMark(y: .value("Start", response.initialValue))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 5]))
                    .annotation(position: .leading, alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: Double(max(1, response.nYears / 5)))) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self), v > 0 {
                            Text("Yr \(Int(v))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatCompact(v)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 280)
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var legendView: some View {
        HStack(spacing: 14) {
            LegendItem(symbol: .line(solid: true, color: .blue),  label: "Median")
            LegendItem(symbol: .band(color: .blue.opacity(0.25)), label: "25–75%")
            LegendItem(symbol: .band(color: .blue.opacity(0.12)), label: "10–90%")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Legend

private enum LegendSymbol {
    case line(solid: Bool, color: Color)
    case band(color: Color)
}

private struct LegendItem: View {
    let symbol: LegendSymbol
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            switch symbol {
            case .line(_, let color):
                Capsule().fill(color).frame(width: 14, height: 3)
            case .band(let color):
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 8)
            }
            Text(label)
        }
    }
}
