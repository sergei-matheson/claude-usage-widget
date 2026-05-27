import XCTest
import Foundation

// MARK: - Mock URLProtocol

private final class MockURLProtocol: URLProtocol {
    /// Set before each test to control what the mock returns (or throws).
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

extension UsageServiceNetworkTests {
    func makeHTTPResponse(status: Int, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    // Minimal valid JSON that the service can decode successfully.
    var successJSON: Data {
        Data("""
        {
          "five_hour": { "utilization": 30.0, "resets_at": null },
          "seven_day": { "utilization": 5.0, "resets_at": null }
        }
        """.utf8)
    }

    var personalCredentials: SessionCredentials {
        SessionCredentials(sessionKey: "sk-test", organizationId: "")
    }

    var orgCredentials: SessionCredentials {
        SessionCredentials(sessionKey: "sk-test", organizationId: "org-123")
    }
}

// MARK: - Tests

final class UsageServiceNetworkTests: XCTestCase {

    private var service: UsageService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        service = UsageService(session: URLSession(configuration: config))
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        service = nil
        super.tearDown()
    }

    // MARK: - URL construction

    func testFetchUsageBuildsPersonalURL() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { [self] request in
            capturedURL = request.url
            return (makeHTTPResponse(status: 200, url: request.url!), successJSON)
        }

        _ = try await service.fetchUsage(credentials: personalCredentials)

        XCTAssertEqual(capturedURL?.absoluteString, "https://claude.ai/api/usage")
    }

    func testFetchUsageBuildsOrgScopedURL() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { [self] request in
            capturedURL = request.url
            return (makeHTTPResponse(status: 200, url: request.url!), successJSON)
        }

        _ = try await service.fetchUsage(credentials: orgCredentials)

        XCTAssertEqual(capturedURL?.absoluteString,
                       "https://claude.ai/api/organizations/org-123/usage")
    }

    // MARK: - Request headers

    func testFetchUsageSendsCookieHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { [self] request in
            capturedRequest = request
            return (makeHTTPResponse(status: 200, url: request.url!), successJSON)
        }

        _ = try await service.fetchUsage(credentials: personalCredentials)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Cookie"), "sessionKey=sk-test")
    }

    func testFetchUsageSendsAcceptHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { [self] request in
            capturedRequest = request
            return (makeHTTPResponse(status: 200, url: request.url!), successJSON)
        }

        _ = try await service.fetchUsage(credentials: personalCredentials)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    // MARK: - HTTP 401 / 403 → unauthenticated

    func testFetchUsageThrowsUnauthenticatedOn401() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 401, url: request.url!), Data())
        }
        await assertThrowsUsageServiceError(.unauthenticated) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    func testFetchUsageThrowsUnauthenticatedOn403() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 403, url: request.url!), Data())
        }
        await assertThrowsUsageServiceError(.unauthenticated) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    // MARK: - HTTP 429 → unexpectedResponse(429)

    func testFetchUsageThrowsUnexpectedResponseOn429() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 429, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchUsage(credentials: personalCredentials)
            XCTFail("Expected unexpectedResponse(429)")
        } catch UsageServiceError.unexpectedResponse(let code) {
            XCTAssertEqual(code, 429)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Other HTTP errors → unexpectedResponse(statusCode)

    func testFetchUsageThrowsUnexpectedResponseOn500() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 500, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchUsage(credentials: personalCredentials)
            XCTFail("Expected unexpectedResponse(500)")
        } catch UsageServiceError.unexpectedResponse(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchUsageThrowsUnexpectedResponseOn404() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 404, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchUsage(credentials: personalCredentials)
            XCTFail("Expected unexpectedResponse(404)")
        } catch UsageServiceError.unexpectedResponse(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Network failure → networkError

    func testFetchUsageWrapsNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        await assertThrowsUsageServiceError(.networkError) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    func testFetchUsageWrapsTimeoutAsNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        await assertThrowsUsageServiceError(.networkError) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    // MARK: - Bad JSON → decodingError

    func testFetchUsageThrowsDecodingErrorForInvalidJSON() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 200, url: request.url!), Data("not-json".utf8))
        }
        await assertThrowsUsageServiceError(.decodingError) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    func testFetchUsageThrowsDecodingErrorForEmptyBody() async {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 200, url: request.url!), Data())
        }
        await assertThrowsUsageServiceError(.decodingError) {
            try await service.fetchUsage(credentials: personalCredentials)
        }
    }

    // MARK: - Successful 200 response

    func testFetchUsageReturnsDecodedUsageDataOnSuccess() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            (makeHTTPResponse(status: 200, url: request.url!), successJSON)
        }

        let usage = try await service.fetchUsage(credentials: personalCredentials)

        XCTAssertEqual(usage.messagesUsed, 30)
        XCTAssertEqual(usage.sevenDayUtilization, 5)
        XCTAssertEqual(usage.messagesLimit, 100)
        XCTAssertEqual(usage.planName, "Pro")
    }
}

// MARK: - Assertion helpers

extension UsageServiceNetworkTests {
    private enum ErrorKind { case unauthenticated, networkError, decodingError, unexpectedResponse }

    private func assertThrowsUsageServiceError(
        _ kind: ErrorKind,
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected an error but none was thrown", file: file, line: line)
        } catch {
            switch (kind, error) {
            case (.unauthenticated, UsageServiceError.unauthenticated): break
            case (.networkError, UsageServiceError.networkError): break
            case (.decodingError, UsageServiceError.decodingError): break
            case (.unexpectedResponse, UsageServiceError.unexpectedResponse): break
            default:
                XCTFail("Expected \(kind) but got: \(error)", file: file, line: line)
            }
        }
    }
}
