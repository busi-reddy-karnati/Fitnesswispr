import Foundation

final class APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared

    private init() {}

    private func baseRequest(url: URL, method: String = "GET", timeout: TimeInterval = 30) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(Identity.current, forHTTPHeaderField: "X-Device-UUID")
        if let token = AccountStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpMethod = method
        req.timeoutInterval = timeout
        return req
    }

    func get<T: Decodable>(_ url: URL) async throws -> T {
        let req = baseRequest(url: url)
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(_ url: URL, body: Body, timeout: TimeInterval = 30) async throws -> Response {
        var req = baseRequest(url: url, method: "POST", timeout: timeout)
        req.httpBody = try snakeCaseEncoder.encode(body)
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        return try decode(Response.self, from: data)
    }

    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        var req = baseRequest(url: url, method: "PUT")
        req.httpBody = try snakeCaseEncoder.encode(body)
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        return try decode(Response.self, from: data)
    }

    /// POST a JSON body to an endpoint that returns no content (e.g. 204).
    func postNoContent<Body: Encodable>(_ url: URL, body: Body) async throws {
        var req = baseRequest(url: url, method: "POST")
        req.httpBody = try snakeCaseEncoder.encode(body)
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
    }

    /// Upload raw bytes (e.g. an image) with a PUT.
    func putData(_ url: URL, data: Data, contentType: String) async throws {
        var req = baseRequest(url: url, method: "PUT")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (respData, response) = try await session.upload(for: req, from: data)
        try validate(response: response, data: respData)
    }

    private var snakeCaseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    func delete(_ url: URL) async throws {
        let req = baseRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
    }

    func download(_ url: URL) async throws -> Data {
        let req = baseRequest(url: url)
        let (data, response) = try await session.data(for: req)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpError(http.statusCode, data)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
