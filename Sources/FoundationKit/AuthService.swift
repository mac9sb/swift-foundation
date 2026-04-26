import Foundation
import AuthenticationServices

/// Stateless service for all authentication flows against `deno-foundation` endpoints.
///
/// Create one instance alongside your ``APIClient`` and pass it down to views
/// that need to trigger sign-in flows.
public struct AuthService: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    // MARK: - Magic link

    /// Sends a magic-link email to `email` via `POST /auth/magic-link`.
    public func sendMagicLink(email: String) async throws {
        struct Body: Encodable { let email: String }
        let _: OkResponse = try await client.post("/auth/magic-link", body: Body(email: email))
    }

    // MARK: - Sign in with Apple

    /// Exchanges an Apple identity token for a server session via `POST /auth/apple`.
    ///
    /// Pass `credential.identityToken` from your `ASAuthorizationAppleIDCredential` directly.
    /// On success the server sets a session cookie; call ``SessionStore/refresh()`` afterwards
    /// to populate the store.
    public func signInWithApple(identityToken: Data) async throws {
        guard let token = String(data: identityToken, encoding: .utf8) else {
            throw APIError.invalidResponse
        }
        struct Body: Encodable { let identityToken: String }
        let _: OkResponse = try await client.post("/auth/apple", body: Body(identityToken: token))
    }

    // MARK: - Passkeys

    /// Fetches the WebAuthn authentication challenge from `POST /auth/passkey/login/begin`.
    /// Use the returned options to drive `ASAuthorizationController` on iOS 16+.
    public func beginPasskeyLogin() async throws -> PasskeyChallenge {
        try await client.post("/auth/passkey/login/begin", body: EmptyBody())
    }

    /// Submits the signed WebAuthn assertion to `POST /auth/passkey/login/finish`.
    public func finishPasskeyLogin(challengeId: String, response: PasskeyAssertionResponse) async throws {
        struct Body: Encodable {
            let challengeId: String
            let response: PasskeyAssertionResponse
        }
        let _: OkResponse = try await client.post(
            "/auth/passkey/login/finish",
            body: Body(challengeId: challengeId, response: response)
        )
    }

    /// Fetches the WebAuthn registration challenge from `POST /auth/passkey/register/begin`.
    public func beginPasskeyRegistration() async throws -> PasskeyChallenge {
        try await client.post("/auth/passkey/register/begin", body: EmptyBody())
    }

    /// Submits the new credential to `POST /auth/passkey/register/finish`.
    public func finishPasskeyRegistration(challengeId: String, response: PasskeyAttestationResponse) async throws {
        struct Body: Encodable {
            let challengeId: String
            let response: PasskeyAttestationResponse
        }
        let _: OkResponse = try await client.post(
            "/auth/passkey/register/finish",
            body: Body(challengeId: challengeId, response: response)
        )
    }
}

// MARK: - Passkey transport types

/// WebAuthn challenge options returned by the server's `/begin` endpoints.
public struct PasskeyChallenge: Decodable, Sendable {
    public let challengeId: String
    public let options: PasskeyChallengeOptions
}

public struct PasskeyChallengeOptions: Decodable, Sendable {
    public let challenge: String
    public let rpId: String?
    public let timeout: Int?
}

/// Encoded assertion response sent to `/auth/passkey/login/finish`.
public struct PasskeyAssertionResponse: Encodable, Sendable {
    public let id: String
    public let rawId: String
    public let type: String
    public let response: AssertionResponseData

    public init(id: String, rawId: String, type: String, response: AssertionResponseData) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
    }
}

public struct AssertionResponseData: Encodable, Sendable {
    public let clientDataJSON: String
    public let authenticatorData: String
    public let signature: String
    public let userHandle: String?

    public init(
        clientDataJSON: String,
        authenticatorData: String,
        signature: String,
        userHandle: String? = nil
    ) {
        self.clientDataJSON = clientDataJSON
        self.authenticatorData = authenticatorData
        self.signature = signature
        self.userHandle = userHandle
    }
}

/// Encoded attestation response sent to `/auth/passkey/register/finish`.
public struct PasskeyAttestationResponse: Encodable, Sendable {
    public let id: String
    public let rawId: String
    public let type: String
    public let response: AttestationResponseData

    public init(id: String, rawId: String, type: String, response: AttestationResponseData) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
    }
}

public struct AttestationResponseData: Encodable, Sendable {
    public let clientDataJSON: String
    public let attestationObject: String

    public init(clientDataJSON: String, attestationObject: String) {
        self.clientDataJSON = clientDataJSON
        self.attestationObject = attestationObject
    }
}

private struct EmptyBody: Encodable {}
