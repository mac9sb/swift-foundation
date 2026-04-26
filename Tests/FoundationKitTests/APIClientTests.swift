import XCTest
@testable import FoundationKit

final class APIClientTests: XCTestCase {

    // MARK: - Helpers

    func makeClient(handler: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = handler
        let session = URLSession(configuration: config)
        return APIClient(baseURL: URL(string: "https://api.example.com")!, session: session)
    }

    func jsonResponse(_ body: String, status: Int = 200) -> (Data, URLResponse) {
        let data = body.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    // MARK: - GET

    func testGetDecodesJSON() async throws {
        let client = makeClient { _ in self.jsonResponse(#"{"userId":"u1","email":"a@b.com"}"#) }
        let user: SessionUser = try await client.get("/api/session")
        XCTAssertEqual(user.userId, "u1")
        XCTAssertEqual(user.email, "a@b.com")
    }

    func testGetThrowsUnauthorizedOn401() async throws {
        let client = makeClient { _ in self.jsonResponse(#"{"error":"Unauthorized"}"#, status: 401) }
        do {
            let _: SessionUser = try await client.get("/api/session")
            XCTFail("Expected throw")
        } catch APIError.unauthorized {
            // expected
        }
    }

    func testGetThrowsTooManyRequestsOn429() async throws {
        let client = makeClient { _ in
            let data = #"{"error":"rate limited"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "30"]
            )!
            return (data, response)
        }
        do {
            let _: SessionUser = try await client.get("/api/session")
            XCTFail("Expected throw")
        } catch APIError.tooManyRequests(let retryAfter) {
            XCTAssertEqual(retryAfter, 30)
        }
    }

    // MARK: - POST

    func testPostEncodesBodyAsJSON() async throws {
        var captured: URLRequest?
        let client = makeClient { req in
            captured = req
            return self.jsonResponse(#"{"ok":true}"#)
        }
        struct Body: Encodable { let email: String }
        let _: OkResponse = try await client.post("/auth/magic-link", body: Body(email: "a@b.com"))
        let body = try XCTUnwrap(captured?.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)
        XCTAssertEqual(decoded["email"], "a@b.com")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: (@Sendable (URLRequest) throws -> (Data, URLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
