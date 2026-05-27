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
      "seven_day_oauth_apps": null,
      "seven_day_opus": null,
      "seven_day_sonnet": null,
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
        XCTAssertEqual(parsed.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testFallsBackWhenFiveHourMissing() throws {
        let json = """
        { "seven_day": { "utilization": 5.0, "resets_at": null } }
        """
        let usage = try UsageService.parse(data: makeData(json))

        XCTAssertEqual(usage.fiveHourUtilization, 0)
        XCTAssertNil(usage.periodResetDate)
    }

    func testResetDatesAreNilWhenAPIReturnsNull() throws {
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

    func testIgnoresUnknownTopLevelKeys() throws {
        // Extra keys like tangelo, iguana_necktie should not cause a decode failure
        let json = """
        {
          "five_hour": { "utilization": 20.0, "resets_at": null },
          "tangelo": null,
          "iguana_necktie": null,
          "omelette_promotional": null
        }
        """
        XCTAssertNoThrow(try UsageService.parse(data: makeData(json)))
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
        XCTAssertEqual(
            url?.absoluteString,
            "https://claude.ai/api/organizations/1a2b3c4d-5e6f-7890-abcd-ef0123456789/usage"
        )
    }

    func testBuildURLRejectsPathTraversal() {
        let service = UsageService()
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "../me")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo/bar")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo bar")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo#frag")))
        XCTAssertNil(service.buildURL(credentials: SessionCredentials(sessionKey: "k", organizationId: "foo?q=1")))
    }

    func testSevenDayResetDateParsedFromFullResponse() throws {
        let response = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: makeData(fullResponseJSON))
        let usage = response.toUsageData()

        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 31
        components.hour = 1; components.minute = 0; components.second = 1
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(usage.sevenDayResetDate.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testBothBucketsMissingDefaultsToZero() throws {
        let json = "{}"
        let response = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: makeData(json))
        let usage = response.toUsageData()

        XCTAssertEqual(usage.messagesUsed, 0)
        XCTAssertEqual(usage.sevenDayUtilization, 0)
    }

    func testBothBucketsMissingFallbackDatesAreApproximate() throws {
        let json = "{}"
        let response = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: makeData(json))
        let usage = response.toUsageData()

        let expectedFiveHour = Date().addingTimeInterval(3600 * 5)
        let expectedSevenDay = Date().addingTimeInterval(86400 * 7)

        XCTAssertEqual(usage.periodResetDate.timeIntervalSince1970,
                       expectedFiveHour.timeIntervalSince1970,
                       accuracy: 5.0)
        XCTAssertEqual(usage.sevenDayResetDate.timeIntervalSince1970,
                       expectedSevenDay.timeIntervalSince1970,
                       accuracy: 5.0)
    }

    func testParsesDateWithoutFractionalSeconds() throws {
        let json = """
        {
          "five_hour": { "utilization": 5.0, "resets_at": "2026-05-25T10:00:01+00:00" },
          "seven_day": { "utilization": 1.0, "resets_at": null }
        }
        """
        let response = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: makeData(json))
        let usage = response.toUsageData()

        // Should not fall back to "now + 5h" — the date should be parsed correctly
        let fallback = Date().addingTimeInterval(3600 * 5)
        let difference = abs(usage.periodResetDate.timeIntervalSince1970 - fallback.timeIntervalSince1970)
        XCTAssertGreaterThan(difference, 60,
                             "Date without fractional seconds should be parsed, not fall back to 'now + 5h'")
    }

    func testUsageBucketDecodesWithAllNullFields() throws {
        let json = """
        { "five_hour": { "utilization": null, "resets_at": null } }
        """
        let response = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: makeData(json))
        let usage = response.toUsageData()

        // null utilization treated as 0
        XCTAssertEqual(usage.messagesUsed, 0)
        // null resets_at falls back to approx 5 hours from now
        let expectedFallback = Date().addingTimeInterval(3600 * 5)
        XCTAssertEqual(usage.periodResetDate.timeIntervalSince1970,
                       expectedFallback.timeIntervalSince1970,
                       accuracy: 5.0)
    }
}
