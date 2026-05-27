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
        StubURLProtocol.error = nil
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
            guard case UsageServiceError.rateLimited(let retryAfter) = error else {
                return XCTFail("expected .rateLimited, got \(error)")
            }
            XCTAssertNil(retryAfter)
        }
    }

    func testHonorsRetryAfterHeaderOn429() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(
                url: URL(string: "https://x")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "120"]
            )!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.rateLimited(let retryAfter) = error else {
                return XCTFail("expected .rateLimited, got \(error)")
            }
            XCTAssertEqual(retryAfter, 120)
        }
    }

    func testIgnoresInvalidRetryAfterHeader() async {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(
                url: URL(string: "https://x")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "Mon, 01 Jan 2030 00:00:00 GMT"]  // HTTP-date form: not parsed
            )!, Data())
        }
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.rateLimited(let retryAfter) = error else {
                return XCTFail("expected .rateLimited, got \(error)")
            }
            XCTAssertNil(retryAfter)
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

    func testWrapsNetworkErrors() async {
        StubURLProtocol.error = URLError(.timedOut)
        await XCTAssertThrowsErrorAsync(try await self.makeService().fetchUsage(credentials: self.creds)) { error in
            guard case UsageServiceError.networkError = error else {
                return XCTFail("expected .networkError, got \(error)")
            }
        }
    }

    func testSendsUserAgentHeader() async throws {
        let observedHeaders = LockedBox<[String: String]>()
        StubURLProtocol.handler = { request in
            observedHeaders.value = request.allHTTPHeaderFields ?? [:]
            let body = Data(#"{"five_hour":{"utilization":0,"resets_at":null}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        _ = try await makeService().fetchUsage(credentials: creds)
        XCTAssertEqual(observedHeaders.value?["User-Agent"], "ClaudeUsageWidget/1.0 macOS")
    }
}

final class UsageProviderTests: XCTestCase {
    private var keychain: KeychainStore!
    private var cacheURL: URL!

    override func setUp() {
        super.setUp()
        keychain = KeychainStore(service: "io.github.sergei-matheson.claudeusagewidget.provider-tests.\(UUID().uuidString)")
        cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage_provider_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? keychain.delete()
        try? FileManager.default.removeItem(at: cacheURL)
        StubURLProtocol.handler = nil
        StubURLProtocol.error = nil
        super.tearDown()
    }

    private func makeProvider() -> UsageProvider {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let service = UsageService(session: URLSession(configuration: config))
        let cache = UsageCache(cacheURL: cacheURL)
        return UsageProvider(service: service, keychain: keychain, cache: cache)
    }

    private func awaitTimeline(_ provider: UsageProvider) async -> Timeline<UsageEntry> {
        await withCheckedContinuation { continuation in
            provider.getTimeline(in: .init()) { timeline in
                continuation.resume(returning: timeline)
            }
        }
    }

    func testUnauthenticatedWhenCredentialsMissing() async {
        let timeline = await awaitTimeline(makeProvider())
        XCTAssertEqual(timeline.entries.first?.state, .unauthenticated)
    }

    func testSuccessReturnsLoadedEntry() async throws {
        try keychain.save(SessionCredentials(sessionKey: "sk", organizationId: ""))
        StubURLProtocol.handler = { request in
            let body = Data(#"{"five_hour":{"utilization":12.0,"resets_at":null}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let timeline = await awaitTimeline(makeProvider())
        XCTAssertEqual(timeline.entries.first?.state, .loaded)
        XCTAssertEqual(timeline.entries.first?.usageData?.fiveHourUtilization, 12)
    }

    func testRateLimitedWithRetryAfterSchedulesRetry() async throws {
        try keychain.save(SessionCredentials(sessionKey: "sk", organizationId: ""))
        StubURLProtocol.handler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "120"]
                )!,
                Data()
            )
        }

        let timeline = await awaitTimeline(makeProvider())
        XCTAssertEqual(timeline.entries.first?.state, .error("Rate limited. Retrying soon."))
        if case .after(let date) = timeline.policy {
            XCTAssertGreaterThanOrEqual(date.timeIntervalSinceNow, 100)
            XCTAssertLessThanOrEqual(date.timeIntervalSinceNow, 140)
        } else {
            XCTFail("expected .after policy")
        }
    }

    func testRateLimitedWithoutRetryAfterUsesFallbackAndCache() async throws {
        try keychain.save(SessionCredentials(sessionKey: "sk", organizationId: ""))
        try UsageCache(cacheURL: cacheURL).save(
            UsageData(
                fiveHourUtilization: 77,
                periodResetDate: nil,
                sevenDayUtilization: 22,
                sevenDayResetDate: nil,
                lastUpdated: Date()
            )
        )
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }

        let timeline = await awaitTimeline(makeProvider())
        XCTAssertEqual(timeline.entries.first?.state, .loaded)
        XCTAssertEqual(timeline.entries.first?.usageData?.fiveHourUtilization, 77)
        if case .after(let date) = timeline.policy {
            XCTAssertGreaterThanOrEqual(date.timeIntervalSinceNow, RefreshPolicy.rateLimitedFallback - 5)
        } else {
            XCTFail("expected .after policy")
        }
    }

    func testNetworkErrorFallsBackToCache() async throws {
        try keychain.save(SessionCredentials(sessionKey: "sk", organizationId: ""))
        try UsageCache(cacheURL: cacheURL).save(
            UsageData(
                fiveHourUtilization: 45,
                periodResetDate: nil,
                sevenDayUtilization: 10,
                sevenDayResetDate: nil,
                lastUpdated: Date()
            )
        )
        StubURLProtocol.error = URLError(.timedOut)

        let timeline = await awaitTimeline(makeProvider())
        XCTAssertEqual(timeline.entries.first?.state, .loaded)
        XCTAssertEqual(timeline.entries.first?.usageData?.fiveHourUtilization, 45)
    }
}

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = StubURLProtocol.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
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
