import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case httpError(Int, Data)
    case decodingError(Error)
    case noData
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code, let data):
            // Prefer the server's human-readable reason (rate-limit reached,
            // input too long, file too large, …) so the UI shows the real cause.
            if let detail = Self.serverDetail(from: data) { return detail }
            return Self.fallbackMessage(for: code)
        case .decodingError(let e):
            return "Decode error: \(e.localizedDescription)"
        case .noData:
            return "No data received"
        case .parseFailed(let reason):
            return "Parse failed: \(reason)"
        }
    }

    /// True when the server rejected the request because a usage limit was hit.
    var isRateLimited: Bool {
        if case .httpError(429, _) = self { return true }
        return false
    }

    /// Extract FastAPI's `detail`. It's a plain string for our HTTPException
    /// responses; for raw validation errors it can be an array of objects.
    private static func serverDetail(from data: Data) -> String? {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = obj["detail"] else { return nil }
        if let s = detail as? String, !s.isEmpty { return s }
        if let arr = detail as? [[String: Any]],
           let msg = arr.first?["msg"] as? String, !msg.isEmpty { return msg }
        return nil
    }

    private static func fallbackMessage(for code: Int) -> String {
        switch code {
        case 429: return "You've hit a usage limit. Please try again later."
        case 413: return "That file is too large."
        case 422: return "That request couldn't be processed."
        case 500...599: return "Something went wrong on our end. Please try again."
        default: return "Server error \(code)"
        }
    }
}
