/// Errors thrown by ``APIClient`` when the server returns a non-2xx response.
public enum APIError: Error, Sendable {
    case unauthorized
    case notFound
    /// Server responded with 429. `retryAfter` is the value of the `Retry-After` header in seconds.
    case tooManyRequests(retryAfter: Int?)
    case httpError(Int)
    case invalidResponse
}
