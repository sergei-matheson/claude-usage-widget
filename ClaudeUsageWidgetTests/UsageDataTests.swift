import XCTest
import Foundation

final class UsageDataTests: XCTestCase {

    // Fixed timestamps make assertions deterministic.
    private let t1 = Date(timeIntervalSince1970: 1_000_000)
    private let t2 = Date(timeIntervalSince1970: 2_000_000)
    private let t3 = Date(timeIntervalSince1970: 3_000_000)

    private func makeUsageData(
        messagesUsed: Int = 42,
        messagesLimit: Int = 100,
        planName: String = "Pro",
        periodResetDate: Date? = nil,
        sevenDayUtilization: Int = 18,
        sevenDayResetDate: Date? = nil,
        lastUpdated: Date? = nil
    ) -> UsageData {
        UsageData(
            messagesUsed: messagesUsed,
            messagesLimit: messagesLimit,
            planName: planName,
            periodResetDate: periodResetDate ?? t1,
            sevenDayUtilization: sevenDayUtilization,
            sevenDayResetDate: sevenDayResetDate ?? t2,
            lastUpdated: lastUpdated ?? t3
        )
    }

    // MARK: - Equatable

    func testEqualInstancesAreEqual() {
        XCTAssertEqual(makeUsageData(), makeUsageData())
    }

    func testDifferentMessagesUsedIsNotEqual() {
        XCTAssertNotEqual(makeUsageData(messagesUsed: 10), makeUsageData(messagesUsed: 20))
    }

    func testDifferentMessagesLimitIsNotEqual() {
        XCTAssertNotEqual(makeUsageData(messagesLimit: 100), makeUsageData(messagesLimit: 50))
    }

    func testDifferentPlanNameIsNotEqual() {
        XCTAssertNotEqual(makeUsageData(planName: "Pro"), makeUsageData(planName: "Max"))
    }

    func testDifferentSevenDayUtilizationIsNotEqual() {
        XCTAssertNotEqual(makeUsageData(sevenDayUtilization: 5), makeUsageData(sevenDayUtilization: 50))
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let original = makeUsageData()
        let encoded = try JSONEncoder.usageEncoder.encode(original)
        let decoded = try JSONDecoder.usageDecoder.decode(UsageData.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testEncoderRepresentsDatesAsISO8601Strings() throws {
        let data = makeUsageData()
        let encoded = try JSONEncoder.usageEncoder.encode(data)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertTrue(json?["periodResetDate"] is String,
                      "periodResetDate should be encoded as an ISO 8601 string, not a number")
        XCTAssertTrue(json?["sevenDayResetDate"] is String,
                      "sevenDayResetDate should be encoded as an ISO 8601 string, not a number")
        XCTAssertTrue(json?["lastUpdated"] is String,
                      "lastUpdated should be encoded as an ISO 8601 string, not a number")
    }

    func testDecoderAcceptsISO8601DateStrings() throws {
        let json = """
        {
          "messagesUsed": 10,
          "messagesLimit": 100,
          "planName": "Pro",
          "periodResetDate": "2026-05-25T10:00:01Z",
          "sevenDayUtilization": 3,
          "sevenDayResetDate": "2026-06-01T00:00:00Z",
          "lastUpdated": "2026-05-25T08:00:00Z"
        }
        """
        let decoded = try JSONDecoder.usageDecoder.decode(UsageData.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.messagesUsed, 10)
        XCTAssertEqual(decoded.planName, "Pro")

        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 25
        components.hour = 10; components.minute = 0; components.second = 1
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(decoded.periodResetDate.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    // MARK: - placeholder

    func testPlaceholderHasExpectedShape() {
        let placeholder = UsageData.placeholder()
        XCTAssertEqual(placeholder.messagesUsed, 42)
        XCTAssertEqual(placeholder.messagesLimit, 100)
        XCTAssertEqual(placeholder.planName, "Pro")
        XCTAssertEqual(placeholder.sevenDayUtilization, 18)
    }

    func testPlaceholderDatesAreInTheFuture() {
        let now = Date()
        let placeholder = UsageData.placeholder()
        XCTAssertGreaterThan(placeholder.periodResetDate, now,
                             "periodResetDate should be set in the future")
        XCTAssertGreaterThan(placeholder.sevenDayResetDate, now,
                             "sevenDayResetDate should be set in the future")
    }
}
