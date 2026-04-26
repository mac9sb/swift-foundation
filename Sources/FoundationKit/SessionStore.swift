import Foundation
import Observation

/// Observable store for the current authentication state.
///
/// Inject one instance at the root of your SwiftUI hierarchy via `.environment`:
///
/// ```swift
/// @main struct MyApp: App {
///     let client = APIClient(baseURL: Config.baseURL)
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(SessionStore(client: client))
///                 .task { await sessionStore.refresh() }
///         }
///     }
/// }
/// ```
@Observable
@MainActor
public final class SessionStore {
    /// The authenticated user, or `nil` when signed out.
    public var user: SessionUser?
    /// `true` while a session refresh or sign-out is in flight.
    public var isLoading = false

    public var isAuthenticated: Bool { user != nil }

    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// Fetches the current session from `GET /api/session`.
    /// Sets `user` to `nil` on 401 or any error.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await client.get("/api/session")
        } catch {
            user = nil
        }
    }

    /// Signs out by calling `POST /auth/logout` and clears local state.
    public func signOut() async {
        isLoading = true
        defer { isLoading = false }
        try? await client.post("/auth/logout")
        user = nil
    }
}
