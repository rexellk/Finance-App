import Foundation
import SwiftUI

// MARK: - API Models

struct SimulationRequest: Codable {
    var tickers: [String]
    var weights: [String: Double]
    var nYears: Int
    var initialValue: Double
    var accountType: String
    var taxRate: Double
    var nSimulations: Int
    var forceRefresh: Bool

    enum CodingKeys: String, CodingKey {
        case tickers, weights
        case nYears = "n_years"
        case initialValue = "initial_value"
        case accountType = "account_type"
        case taxRate = "tax_rate"
        case nSimulations = "n_simulations"
        case forceRefresh = "force_refresh"
    }
}

struct SimulationResponse: Codable {
    let percentiles: [String: Double]
    let cagr: [String: Double]
    let multiples: [String: Double]
    let probProfit: Double
    let probDouble: Double
    let worstCase: Double
    let bestCase: Double
    let cone: [String: [Double]]
    let yearLabels: [Int]
    let nYears: Int
    let initialValue: Double

    enum CodingKeys: String, CodingKey {
        case percentiles, cagr, multiples, cone
        case probProfit = "prob_profit"
        case probDouble = "prob_double"
        case worstCase = "worst_case"
        case bestCase = "best_case"
        case yearLabels = "year_labels"
        case nYears = "n_years"
        case initialValue = "initial_value"
    }
}

// MARK: - Chart Data

struct ConePoint: Identifiable {
    let id: Int
    let year: Double
    let p10: Double
    let p25: Double
    let p50: Double
    let p75: Double
    let p90: Double

    static func fromResponse(_ r: SimulationResponse) -> [ConePoint] {
        guard let p10 = r.cone["10"], let p25 = r.cone["25"],
              let p50 = r.cone["50"], let p75 = r.cone["75"],
              let p90 = r.cone["90"], !p50.isEmpty else { return [] }
        let n = p50.count
        return (0..<n).map { i in
            ConePoint(
                id: i,
                year: Double(i) / Double(n - 1) * Double(r.nYears),
                p10: p10[i], p25: p25[i], p50: p50[i], p75: p75[i], p90: p90[i]
            )
        }
    }
}

// MARK: - Domain Types

enum AccountType: String, CaseIterable, Identifiable {
    case brokerage
    case roth
    case pretax = "401k"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brokerage: return "Brokerage"
        case .roth:      return "Roth IRA"
        case .pretax:    return "401k"
        }
    }

    var icon: String {
        switch self {
        case .brokerage: return "chart.line.uptrend.xyaxis"
        case .roth:      return "shield.lefthalf.filled"
        case .pretax:    return "building.columns"
        }
    }

    var taxDescription: String {
        switch self {
        case .brokerage:
            return "Only gains are taxed at withdrawal. Your principal is returned tax-free."
        case .roth:
            return "Contributions taxed when it's first deposited. No tax at withdrawal. (extra 10% penalty + income-tax if GAINS only withdrawn before age 59½)"
        case .pretax:
            return "Entire balance is taxed as ordinary income at withdrawal. Employer can match contributions. (extra 10% penalty if withdrawn before age 59½.)"
        }
    }
}

let availableTickers = ["QQQ", "GDX", "BTC-USD", "ETH-USD"]

struct TickerMeta {
    let name: String
    let icon: String
    let color: Color
}

let tickerMeta: [String: TickerMeta] = [
    "QQQ":     TickerMeta(name: "Nasdaq-100 ETF",  icon: "chart.bar.fill",         color: .blue),
    "GDX":     TickerMeta(name: "Gold Miners ETF", icon: "sparkle",                color: Color(red: 0.85, green: 0.65, blue: 0.1)),
    "BTC-USD": TickerMeta(name: "Bitcoin",          icon: "bitcoinsign.circle.fill", color: .orange),
    "ETH-USD": TickerMeta(name: "Ethereum",         icon: "hexagon.fill",           color: .purple),
]

// MARK: - Helpers

func formatCompact(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "$%.1fM", value / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "$%.0fK", value / 1_000)
    }
    return String(format: "$%.0f", value)
}
