import Foundation

enum APIEndpoints {
    static var baseURL: String {
        #if DEBUG
        // Debug/simulator builds talk to a local backend for fast iteration.
        // Override with the API_BASE_URL launch env var when testing against a server.
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        return "http://localhost:8000"
        #else
        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !configured.isEmpty {
            return configured
        }
        return "http://localhost:8000"
        #endif
    }

    static var health: URL { URL(string: "\(baseURL)/api/v1/health")! }
    static var parse: URL { URL(string: "\(baseURL)/api/v1/parse")! }
    static var sessions: URL { URL(string: "\(baseURL)/api/v1/sessions")! }
    static var assistantChat: URL { URL(string: "\(baseURL)/api/v1/assistant/chat")! }
    static var importPreview: URL { URL(string: "\(baseURL)/api/v1/import/preview")! }
    static var importCommit: URL { URL(string: "\(baseURL)/api/v1/import/commit")! }
    static var authApple: URL { URL(string: "\(baseURL)/api/v1/auth/apple")! }
    static var authAccount: URL { URL(string: "\(baseURL)/api/v1/auth/account")! }
    static var healthSync: URL { URL(string: "\(baseURL)/api/v1/health/sync")! }
    static var exercisesRename: URL { URL(string: "\(baseURL)/api/v1/exercises/rename")! }
    static var exercisesSuggestName: URL { URL(string: "\(baseURL)/api/v1/exercises/suggest-name")! }
    static var exercisesParseCommand: URL { URL(string: "\(baseURL)/api/v1/exercises/parse-command")! }

    static func profile(_ deviceUUID: String) -> URL {
        URL(string: "\(baseURL)/api/v1/profile/\(deviceUUID)")!
    }

    static func profileAvatar(_ deviceUUID: String) -> URL {
        URL(string: "\(baseURL)/api/v1/profile/\(deviceUUID)/avatar")!
    }

    static func grants(owner: String) -> URL {
        URL(string: "\(baseURL)/api/v1/profile/\(owner)/grants")!
    }

    static func grant(owner: String, grantee: String) -> URL {
        URL(string: "\(baseURL)/api/v1/profile/\(owner)/grants/\(grantee)")!
    }

    static func spotting(_ deviceUUID: String) -> URL {
        URL(string: "\(baseURL)/api/v1/profile/\(deviceUUID)/spotting")!
    }

    static func health(deviceUUID: String, startDate: String? = nil, endDate: String? = nil) -> URL {
        var components = URLComponents(string: "\(baseURL)/api/v1/health/days")!
        var items = [URLQueryItem(name: "device_uuid", value: deviceUUID)]
        if let s = startDate { items.append(URLQueryItem(name: "start_date", value: s)) }
        if let e = endDate { items.append(URLQueryItem(name: "end_date", value: e)) }
        components.queryItems = items
        return components.url!
    }

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
