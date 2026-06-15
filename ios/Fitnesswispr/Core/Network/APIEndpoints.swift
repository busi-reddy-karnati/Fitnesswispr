import Foundation

enum APIEndpoints {
    static var baseURL: String {
        #if DEBUG
        return "http://localhost:8000"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:8000"
        #endif
    }

    static var health: URL { URL(string: "\(baseURL)/api/v1/health")! }
    static var parse: URL { URL(string: "\(baseURL)/api/v1/parse")! }
    static var sessions: URL { URL(string: "\(baseURL)/api/v1/sessions")! }

    static func session(_ id: String) -> URL {
        URL(string: "\(baseURL)/api/v1/sessions/\(id)")!
    }

    static func calendar(deviceUUID: String, year: Int, month: Int) -> URL {
        URL(string: "\(baseURL)/api/v1/calendar?device_uuid=\(deviceUUID)&year=\(year)&month=\(month)")!
    }

    static func sessions(deviceUUID: String, startDate: String? = nil, endDate: String? = nil, limit: Int = 50, offset: Int = 0) -> URL {
        var components = URLComponents(string: "\(baseURL)/api/v1/sessions")!
        var items = [
            URLQueryItem(name: "device_uuid", value: deviceUUID),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let s = startDate { items.append(URLQueryItem(name: "start_date", value: s)) }
        if let e = endDate { items.append(URLQueryItem(name: "end_date", value: e)) }
        components.queryItems = items
        return components.url!
    }

    static func export(deviceUUID: String, format: String) -> URL {
        URL(string: "\(baseURL)/api/v1/export?device_uuid=\(deviceUUID)&format=\(format)")!
    }

    static func deviceContext(_ deviceUUID: String) -> URL {
        URL(string: "\(baseURL)/api/v1/devices/\(deviceUUID)/context")!
    }
}
