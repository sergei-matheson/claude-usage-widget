import XCTest
import Foundation

final class UsageCacheTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage_cache_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    private func sample(lastUpdated: Date = Date()) -> UsageData {
        UsageData(
            fiveHourUtilization: 33,
            periodResetDate: Date().addingTimeInterval(3600),
            sevenDayUtilization: 7,
            sevenDayResetDate: Date().addingTimeInterval(86400),
            lastUpdated: lastUpdated
        )
    }

    func testRoundTrip() throws {
        let cache = UsageCache(cacheURL: tempURL)
        let original = sample()
        try cache.save(original)

        let loaded = cache.load()
        XCTAssertEqual(loaded?.fiveHourUtilization, 33)
        XCTAssertEqual(loaded?.sevenDayUtilization, 7)
    }

    func testReturnsNilWhenNoFile() {
        let cache = UsageCache(cacheURL: tempURL)
        XCTAssertNil(cache.load())
    }

    func testReturnsNilWhenExpired() throws {
        let cache = UsageCache(cacheURL: tempURL)
        // Older than the 24h maxCacheAge
        let stale = sample(lastUpdated: Date().addingTimeInterval(-(UsageCache.maxCacheAge + 60)))
        try cache.save(stale)
        XCTAssertNil(cache.load())
    }

    func testReturnsNilOnCorruptFile() throws {
        try Data("not json".utf8).write(to: tempURL)
        let cache = UsageCache(cacheURL: tempURL)
        XCTAssertNil(cache.load())
    }
}
