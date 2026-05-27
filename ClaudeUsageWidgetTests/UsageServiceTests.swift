import XCTest
import Foundation

final class UsageServiceTests: XCTestCase {

    private func makeData(_ json: String) -> Data { Data(json.utf8) }

    private let fullResponseJSON = """
    {
      "five_hour": {
        "utilization": 15.0,
        "resets_at": "2026-05-25T10:00:01.174634+00:00"
      },
      "seven_day": {
        "utilization": 2.0,
        "resets_at": "2026-05-31T01:00:01.174660+00:00"
      },
      "extra_usage": { "is_enabled": false }
    }
    """

    func testParsesUtilizationValues() throws {
        let usage = try UsageService.parse(data: makeData(fullResponseJSON))
        XCTAssertEqual(usage.fiveHourUtilization, 15)
        XCTAssertEqual(usage.sevenDayUtilization, 2)
    }

    func testRoundsUtilizationToNearestInt() throws {
        let json = """
        {
          "five_hour": { "utilization": 15.6, "resets_at": null },
          "seven_day": { "utilization": 2.4, "resets_at": null }
        }

        func testClampsUtilizationToValidRange() throws {
            let json = """
            {
              "five_hour": { "utilization": 135.2, "resets_at": null },
              "seven_day": { "utilization": -8.4, "resets_at": null }
            }
            """
            let usage = try UsageService.parse(data: makeData(json))
            XCTAssertEqual(usage.fiveHourUtilization, 100)
            XCTAssertEqual(usage.sevenDayUtilization, 0)
        }
        """
        let usage = try UsageService.parse(data: makeData(json))
        XCTAssertEqual(usage.fiveHourUtilization, 16)
        XCTAssertEqual(usage.sevenDayUtilization, 2)
    }

    func testParsesFractionalSecondsResetDate() throws {
        let usage = try UsageService.parse(data: makeData(fullResponseJSON))

        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 25
        components.hour = 10; components.minute = 0; components.second = 1
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = Calendar(identifier: .gregorian).date(from: components)!

        let parsed = try XCTUnwrap(usage.periodResetDate)
        XCTAssertEqual(parsed.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
    }

    func testParsesDateWithoutFractionalSeconds() throws {
        let json = """
        {
          "five_hour": { "utilization": 5.0, "resets_at": "2026-05-25T10:00:01+00:00" },
          "seven_day": { "utilization": 1.0, "resets_at": null }
        }
        """
        let usage = try UsageService.parse(data: makeData(json))
        XCTAssertNotNil(usage.periodResetDate)
    }

    func testReturnsNilDatesWhenBucketsMissing() throws {
        let usage = try UsageService.parse(data: makeData("{}"))
        XCTAssertEqual(usage.fiveHourUtilization, 0)
        XCTAssertEqual(usage.sevenDayUtilization, 0)
        XCTAssertNil(usage.periodResetDate)
        XCTAssertNil(usage.sevenDayResetDate)
    }

    func testReturnsNilDatesWhenAPIReturnsNullDateFields() throws {
        let json = """
        {
          "five_hour": { "utilization": 10.0, "resets_at": null },
          "seven_day": { "utilization": 1.0, "resets_at": null }
        }
        """
        let usage = try UsageService.parse(data: makeData(json))
        XCTAssertNil(usage.periodResetDate)
        XCTAssertNil(usage.sevenDayResetDate)
    }

    func testIgnoresUnknownTopLevelKeys() {
        let json = """
        {
          "five_hour": { "utilization": 20.0, "resets_at": null },
          "tangelo": null,
          "iguana_necktie": null
        }
        """
        XCTAssertNoThrow(try UsageService.parse(data: makeData(json)))
    }

    func testParseWrapsMalformedPayloadAsDecodingError() {
        XCTAssertThrowsError(try UsageService.parse(data: makeData("not-json"))) { error in
            guard case UsageServiceError.decodingError = error else {
                return XCTFail("expected .decodingError, got \(error)")
            }
        }
    }

    // MARK: - buildURL

    func testBuildURLWithEmptyOrgId() {
        let service = UsageService()
        let url = service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: ""))
        XCTAssertEqual(url?.absoluteString, "https://claude.ai/api/usage")
    }

    func testBuildURLWithValidOrgId() {
        let service = UsageService()
        let url = service.buildURL(credentials: SessionCredentials(
            sessionKey: "k",
            organizationId: "1a2b3c4d-5e6f-7890-abcd-ef0123456789"
        ))
        XCTAssertEqual(url?.absoluteString, "https://claude.ai/api/organizations/1a2b3c4d-5e6f-7890-abcd-ef0123456789/usage")
    }

    func testBuildURLRejectsInvalidOrgIdCharacters() {
        let service = UsageService()
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "../me")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo/bar")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo bar")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo#frag")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo?q=1")))
    }

    func testBuildURLRejectsTooLongOrgId() {
        let service = UsageService()
        let tooLong = String(repeating: "a", count: 65)
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: tooLong)))
    }

    // MARK: - parseRetryAfter

    func testParseRetryAfterTrimsWhitespace() {
        let response = HTTPURLResponse(
            url: URL(string: "https://claude.ai")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": " 120 "]
        )!
        XCTAssertEqual(UsageService.parseRetryAfter(response), 120)
    }

    func testParseRetryAfterRejectsZeroAndNegative() {
        let zero = HTTPURLResponse(
            url: URL(string: "https://claude.ai")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "0"]
        )!
        XCTAssertNil(UsageService.parseRetryAfter(zero))

        let negative = HTTPURLResponse(
            url: URL(string: "https://claude.ai")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "-1"]
        )!
        XCTAssertNil(UsageService.parseRetryAfter(negative))
    }
}

final class EntryStateAndUsageEntryTests: XCTestCase {
    func testEntryStateEquality() {
        XCTAssertEqual(EntryState.loaded, .loaded)
        XCTAssertEqual(EntryState.unauthenticated, .unauthenticated)
        XCTAssertEqual(EntryState.error("oops"), .error("oops"))
        XCTAssertNotEqual(EntryState.error("a"), .error("b"))
        XCTAssertNotEqual(EntryState.loaded, .unauthenticated)
    }

    func testUsageEntryPlaceholderHasLoadedStateAndData() {
        let entry = UsageEntry.placeholder()
        XCTAssertEqual(entry.state, .loaded)
        XCTAssertNotNil(entry.usageData)
    }

    func testUsageEntryFactoriesSetExpectedState() {
        XCTAssertEqual(UsageEntry.unauthenticated().state, .unauthenticated)
        XCTAssertNil(UsageEntry.unauthenticated().usageData)

        let errorEntry = UsageEntry.error("Network failed")
        XCTAssertEqual(errorEntry.state, .error("Network failed"))
        XCTAssertNil(errorEntry.usageData)
    }
}
