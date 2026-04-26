# swift-foundation

Swift Package providing a typed API client, session management, and auth services for apps built against [`@mac9sb/deno-foundation`](https://jsr.io/@mac9sb/deno-foundation) backends.

**Minimum deployment targets**: iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1

## What's included

| Module | Description |
|---|---|
| `APIClient` | `actor`-based typed JSON client using `URLSession`. Cookie store is shared with the system, so the session cookie set on sign-in persists automatically. |
| `SessionStore` | `@Observable @MainActor` class that owns the "are we signed in?" truth. Inject at the SwiftUI root, call `refresh()` on launch. |
| `AuthService` | Stateless struct for all auth flows: magic link, Sign in with Apple, and passkey login/registration. |
| `PasskeyChallenge` / response types | Codable transport types that map directly to the server's WebAuthn JSON. |

## Installation

In Xcode: **File → Add Package Dependencies**, paste the repo URL, choose **Up to Next Major Version** from `0.1.0`.

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mac9sb/swift-foundation.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "FoundationKit", package: "swift-foundation"),
    ]),
]
```

## Quick start

```swift
import FoundationKit

// 1. Create the client once — reuse it everywhere
let client = APIClient(baseURL: URL(string: "https://myapp.deno.dev")!)
let session = SessionStore(client: client)
let auth = AuthService(client: client)

// 2. In your @main App, inject and refresh
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .task { await session.refresh() }
        }
    }
}

// 3. Gate content on auth state
struct ContentView: View {
    @Environment(SessionStore.self) var session
    var body: some View {
        if session.isAuthenticated {
            HomeView()
        } else {
            AuthView()
        }
    }
}
```

## Development setup

No external dependencies — just open the package in Xcode or run `swift test` in the terminal.

```bash
cd swift-foundation
swift build
swift test
```

## Production notes

- **Cookie persistence**: `URLSession.shared` uses the system cookie store, which persists across app launches. No extra keychain work needed for session continuity.
- **Sign in with Apple**: pass `credential.identityToken` (a `Data`) directly to `AuthService.signInWithApple(identityToken:)`. The server verifies the JWT and sets the session cookie.
- **Passkeys**: use `AuthService.beginPasskeyLogin()` / `finishPasskeyLogin(...)` alongside `ASAuthorizationController`. The challenge options and response types map 1-to-1 with `@simplewebauthn/server`'s JSON format.
- **Associated domains**: for passkeys to work across your web and native app, configure `webcredentials:<your-domain>` in the Associated Domains entitlement and serve a valid `apple-app-site-association` file from your Deno backend.
