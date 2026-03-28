import Foundation
import Observation

@Observable
final class SimulationViewModel {

    // MARK: - Configuration
    var weights: [String: Double] = [
        "QQQ":     60.0,
        "GDX":     20.0,
        "BTC-USD": 15.0,
        "ETH-USD":  5.0,
    ]
    var nYears: Int = 10
    var initialValue: Double = 25_000
    var accountType: AccountType = .brokerage
    var taxRate: Double = 0.20
    var nSimulations: Int = 1_000
    var growthOnlyMode: Bool = false  // bypasses all tax — shows raw accumulation

    // MARK: - State
    var isLoading = false
    var result: SimulationResponse?
    var errorMessage: String?

    // MARK: - Computed
    var totalWeight: Double { weights.values.reduce(0, +) }
    var weightsValid: Bool { abs(totalWeight - 100.0) < 0.5 }
    var canSimulate: Bool { weightsValid && !isLoading && initialValue > 0 }

    // MARK: - Actions
    @MainActor
    func simulate() async {
        isLoading = true
        errorMessage = nil

        let effectiveAccountType = growthOnlyMode ? "roth" : accountType.rawValue
        let effectiveTaxRate = growthOnlyMode ? 0.0 : (accountType == .roth ? 0.0 : taxRate)

        let request = SimulationRequest(
            tickers: availableTickers,
            weights: weights.mapValues { $0 / 100.0 },
            nYears: nYears,
            initialValue: initialValue,
            accountType: effectiveAccountType,
            taxRate: effectiveTaxRate,
            nSimulations: nSimulations,
            forceRefresh: false
        )

        do {
            result = try await APIService.shared.simulate(request)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
