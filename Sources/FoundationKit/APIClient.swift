import Foundation

/// Sends typed JSON requests to a backend built on `deno-foundation`.
///
/// Uses `URLSession.shared` by default, which inherits the system cookie store —
/// the session cookie set by the server on sign-in is sent automatically on every
/// subsequent request without any extra handling.
public actor APIClient {
    public let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Sends a GET request and decodes the JSON response body.
    public func get<T: Decodable>(_ path: String) async throws -> T {
        let request = URLRequest(url: baseURL.appending(path: path))
        return try await perform(request)
    }

    /// Sends a POST request with a JSON-encoded body and decodes the response.
    public func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// Sends a POST request with no body, discarding the response body.
    public func post(_ path: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.tooManyRequests(retryAfter: retryAfter)
        default:
            throw APIError.httpError(http.statusCode)
        }
    }
}
