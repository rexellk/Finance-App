import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid server URL."
        case .networkError(let e):      return "Could not reach the server. Is it running?\n\(e.localizedDescription)"
        case .serverError(let c, let m): return "Server error \(c): \(m)"
        case .decodingError(let e):     return "Unexpected response format: \(e.localizedDescription)"
        }
    }
}

private struct ErrorResponse: Decodable { let detail: String }

final class APIService {
    static let shared = APIService()
    private let baseURL = "http://127.0.0.1:8000"
    private init() {}

    func simulate(_ request: SimulationRequest) async throws -> SimulationResponse {
        guard let url = URL(string: "\(baseURL)/simulate") else { throw APIError.invalidURL }

        var req = URLRequest(url: url, timeoutInterval: 300)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.detail ?? "Unknown error"
            throw APIError.serverError(http.statusCode, msg)
        }

        do {
            return try JSONDecoder().decode(SimulationResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
