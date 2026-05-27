import XCTest
import Foundation

final class UsageServiceHTTPTests: XCTestCase {

    private func makeService() -> UsageService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return UsageService(session: URLSession(configuration: config))
    }

    private let creds = SessionCredentials(sessionKey: "k", organizationId: "")

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testReturnsUsageOn200() async throws {
        StubURLProtocol.handler = { _ in
            let body = Data(#"{"five_hour":{"utilization":12.0,"resets_at":null}}"#.utf8)
            return (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let usage = try await makeService().fetchUsage(credentials: creds)
        XCTAssertEqual(usage.fiveHourUtilization, 12)
    }

    func testThrowsUnauthenticatedOn401() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.unauthenticated = error else {
                return XCTFail("expected .unauthenticated, got \(error)")
            }
        }
    }

    func testThrowsUnauthenticatedOn403() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.unauthenticated = error else {
                return XCTFail("expected .unauthenticated, got \(error)")
            }
        }
    }

    func testThrowsRateLimitedOn429() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.unexpectedResponse(429) = error else {
                return XCTFail("expected .unexpectedResponse(429), got \(error)")
            }
        }
    }

    func testThrowsUnexpectedOn500() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.unexpectedResponse(500) = error else {
                return XCTFail("expected .unexpectedResponse(500), got \(error)")
            }
        }
    }

    func testThrowsDecodingErrorOnMalformedBody() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("not json".utf8))
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.decodingError = error else {
                return XCTFail("expected .decodingError, got \(error)")
            }
        }
    }

    func testSendsCookieHeader() async throws {
        let observedHeaders = LockedBox<[String: String]>()
        StubURLProtocol.handler = { request in
            observedHeaders.value = request.allHTTPHeaderFields ?? [:]
            let body = Data(#"{"five_hour":{"utilization":0,"resets_at":null}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let service = makeService()
        _ = try await service.fetchUsage(credentials: SessionCredentials(sessionKey: "secret-token", organizationId: ""))
        XCTAssertEqual(observedHeaders.value?["Cookie"], "sessionKey=secret-token")
    }

    func testRejectsInvalidOrganizationId() async {
        let service = makeService()
        await XCTAssertThrowsErrorAsync(
            try await service.fetchUsage(credentials: SessionCredentials(sessionKey: "k", organizationId: "../me"))
        ) { error in
            guard case UsageServiceError.invalidOrganizationId = error else {
                return XCTFail("expected .invalidOrganizationId, got \(error)")
            }
        }
    }
}

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// Thread-safe box for capturing values inside the URLProtocol stub.
private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T?
    var value: T? {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}

// Async-throwing XCTAssertThrowsError equivalent.
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ verify: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("expected throw, got success", file: file, line: line)
    } catch {
        verify(error)
    }
}
