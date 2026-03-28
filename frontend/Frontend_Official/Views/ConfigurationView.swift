import SwiftUI
import Observation

struct ConfigurationView: View {
    var vm: SimulationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                portfolioSection
                investmentSection
                taxSection
                simulateButton
            }
            .padding(16)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Portfolio Simulator")
    }

    // MARK: - Portfolio Weights

    private var portfolioSection: some View {
        CardSection(title: "Portfolio", icon: "chart.pie.fill") {
            VStack(spacing: 12) {
                ForEach(availableTickers, id: \.self) { ticker in
                    TickerWeightRow(
                        ticker: ticker,
                        weight: Binding(
                            get: { vm.weights[ticker, default: 0] },
                            set: { vm.weights[ticker] = $0 }
                        )
                    )
                    if ticker != availableTickers.last {
                        Divider().padding(.leading, 36)
                    }
                }

                Divider()

                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(vm.totalWeight, format: .number.precision(.fractionLength(1)))%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(vm.weightsValid ? .primary : Color.red)
                        Image(systemName: vm.weightsValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(vm.weightsValid ? Color.green : Color.red)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: vm.weightsValid)
            }
        }
    }

    // MARK: - Investment Settings

    private var investmentSection: some View {
        CardSection(title: "Investment", icon: "dollarsign.circle.fill") {
            VStack(spacing: 0) {
                RowItem(label: "Initial Investment") {
                    TextField("$0", value: Binding(
                        get: { vm.initialValue },
                        set: { vm.initialValue = max($0, 0) }
                    ), format: .currency(code: "USD").precision(.fractionLength(0)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
                    .font(.body.weight(.medium).monospacedDigit())
                    .inputBox()
                }
                Divider().padding(.leading, 0)
                RowItem(label: "Length of time in Years") {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { vm.nYears },
                            set: { vm.nYears = min(max($0, 1), 100) }
                        ), format: .number)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .font(.body.weight(.medium).monospacedDigit())
                        .inputBox()
                    }
                }
                Divider()
                RowItem(label: "Simulations") {
                    Picker("", selection: Binding(
                        get: { vm.nSimulations },
                        set: { vm.nSimulations = $0 }
                    )) {
                        Text("500").tag(500)
                        Text("1,000").tag(1_000)
                        Text("5,000").tag(5_000)
                        Text("10,000").tag(10_000)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Tax Settings

    private var taxSection: some View {
        CardSection(title: "Tax Treatment", icon: "building.columns.fill") {
            VStack(spacing: 12) {

                // Growth-only toggle
                Toggle(isOn: Binding(
                    get: { vm.growthOnlyMode },
                    set: { vm.growthOnlyMode = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Growth Only Mode")
                            .font(.subheadline.weight(.medium))
                        Text("Preview raw accumulation, no withdrawal tax applied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !vm.growthOnlyMode {
                    Divider()

                    Picker("Account", selection: Binding(
                        get: { vm.accountType },
                        set: { vm.accountType = $0 }
                    )) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(vm.accountType.taxDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.2), value: vm.accountType)

                    if vm.accountType != .roth {
                        Divider()
                        RowItem(label: "Tax Rate") {
                            HStack(spacing: 8) {
                                Slider(value: Binding(
                                    get: { vm.taxRate },
                                    set: { vm.taxRate = $0 }
                                ), in: 0...0.5, step: 0.01)
                                .frame(width: 90)
                                Text(vm.taxRate, format: .percent.precision(.fractionLength(0)))
                                    .font(.body.monospacedDigit())
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tax rules applied at the end of your selected year horizon, assuming a full withdrawal from your \(vm.accountType.displayName) account at that point.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.growthOnlyMode)
        .animation(.easeInOut(duration: 0.2), value: vm.accountType)
    }

    // MARK: - Simulate Button

    private var simulateButton: some View {
        Button {
            Task { await vm.simulate() }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "play.fill")
                        .font(.callout)
                }
                Text(vm.isLoading ? "Simulating…" : "Run Simulation")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!vm.canSimulate)
        .animation(.easeInOut(duration: 0.15), value: vm.isLoading)
    }
}

// MARK: - Input Box Modifier

private extension View {
    func inputBox() -> some View {
        self
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(.separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - Reusable Components

struct CardSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RowItem<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
        .padding(.vertical, 8)
    }
}

struct TickerWeightRow: View {
    let ticker: String
    @Binding var weight: Double

    private var meta: TickerMeta {
        tickerMeta[ticker] ?? TickerMeta(name: ticker, icon: "questionmark.circle", color: .gray)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meta.icon)
                .font(.body)
                .foregroundStyle(meta.color)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(ticker)
                    .font(.subheadline.weight(.medium))
                Text(meta.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                TextField("0", value: $weight, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                    .font(.body.weight(.medium).monospacedDigit())
                    .inputBox()
                Text("%")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
