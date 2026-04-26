/// The authenticated user returned by `GET /api/session`.
public struct SessionUser: Codable, Sendable, Equatable {
    public let userId: String
    public let email: String
}

/// Response body for endpoints that return `{ "ok": true }`.
struct OkResponse: Decodable {
    let ok: Bool
}
