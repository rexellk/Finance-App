import SwiftUI

struct ResultsView: View {
    var vm: SimulationViewModel

    var body: some View {
        Group {
            if let result = vm.result {
                ScrollView {
                    VStack(spacing: 20) {
                        statsGrid(result)
                        ConeChartView(response: result)
                        PercentileTableView(result: result)
                        probabilityRow(result)
                    }
                    .padding(24)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if vm.isLoading {
                loadingView
            } else if let err = vm.errorMessage {
                errorView(err)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .animation(.spring(duration: 0.4), value: vm.result != nil)
        .animation(.easeInOut, value: vm.isLoading)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ r: SimulationResponse) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            StatCard(
                title: "Median Outcome",
                value: (r.percentiles["50"] ?? 0).formatted(.currency(code: "USD").precision(.fractionLength(0))),
                subtitle: "50th percentile",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue,
                highlighted: true
            )
            StatCard(
                title: "Conservative",
                value: (r.percentiles["10"] ?? 0).formatted(.currency(code: "USD").precision(.fractionLength(0))),
                subtitle: "10th percentile",
                icon: "arrow.down.forward",
                color: .orange
            )
            StatCard(
                title: "Optimistic",
                value: (r.percentiles["90"] ?? 0).formatted(.currency(code: "USD").precision(.fractionLength(0))),
                subtitle: "90th percentile",
                icon: "arrow.up.forward",
                color: .green
            )
            StatCard(
                title: "Median CAGR",
                value: (r.cagr["50"] ?? 0).formatted(.percent.precision(.fractionLength(1))),
                subtitle: "Annualized return",
                icon: "percent",
                color: .purple
            )
        }
    }

    // MARK: - Probability Row

    private func probabilityRow(_ r: SimulationResponse) -> some View {
        HStack(spacing: 12) {
            ProbabilityCard(
                title: "Probability of Profit",
                value: r.probProfit,
                icon: "arrow.up.circle.fill",
                color: .green
            )
            ProbabilityCard(
                title: "Probability of 2×",
                value: r.probDouble,
                icon: "multiply.circle.fill",
                color: .blue
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            VStack(spacing: 6) {
                Text("Running Simulation")
                    .font(.title3.weight(.semibold))
                Text("Bootstrapping \(vm.nSimulations.formatted()) scenarios over \(vm.nYears) years…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            VStack(spacing: 6) {
                Text("Ready to Simulate")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Configure your portfolio and tap Run Simulation.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            VStack(spacing: 6) {
                Text("Simulation Failed")
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            Button("Try Again") {
                Task { await vm.simulate() }
            }
            .buttonStyle(.bordered)
        }
    }
}
