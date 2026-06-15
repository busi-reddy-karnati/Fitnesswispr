import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case httpError(Int, Data)
    case decodingError(Error)
    case noData
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, _): return "Server error \(code)"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .noData: return "No data received"
        case .parseFailed(let reason): return "Parse failed: \(reason)"
        }
    }
}
