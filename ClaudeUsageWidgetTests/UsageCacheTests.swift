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

    func testReturnsNilOnUnknownSchemaVersion() throws {
        // An envelope with version 999 is a future format we don't understand.
        let future = #"{"version":999,"usage":{"fiveHourUtilization":1,"sevenDayUtilization":1,"lastUpdated":"2026-01-01T00:00:00Z"}}"#
        try Data(future.utf8).write(to: tempURL)
        let cache = UsageCache(cacheURL: tempURL)
        XCTAssertNil(cache.load())
    }

    func testDeletesFileOnExpiry() throws {
        let cache = UsageCache(cacheURL: tempURL)
        let stale = sample(lastUpdated: Date().addingTimeInterval(-(UsageCache.maxCacheAge + 60)))
        try cache.save(stale)
        _ = cache.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }

    func testDeletesFileOnCorruption() throws {
        try Data("garbage".utf8).write(to: tempURL)
        let cache = UsageCache(cacheURL: tempURL)
        _ = cache.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }
}

final class UsageDataModelTests: XCTestCase {
    func testPlaceholderHasExpectedShape() {
        let placeholder = UsageData.placeholder()
        XCTAssertEqual(placeholder.fiveHourUtilization, 42)
        XCTAssertEqual(placeholder.sevenDayUtilization, 18)
    }

    func testPlaceholderDatesAreInTheFuture() {
        let now = Date()
        let placeholder = UsageData.placeholder()
        guard let periodResetDate = placeholder.periodResetDate,
              let sevenDayResetDate = placeholder.sevenDayResetDate else {
            return XCTFail("placeholder reset dates should not be nil")
        }
        XCTAssertGreaterThan(periodResetDate, now)
        XCTAssertGreaterThan(sevenDayResetDate, now)
    }

    func testUsageDataCodableRoundTripPreservesOptionalDates() throws {
        let original = UsageData(
            fiveHourUtilization: 10,
            periodResetDate: nil,
            sevenDayUtilization: 4,
            sevenDayResetDate: nil,
            lastUpdated: Date(timeIntervalSince1970: 2_000_000)
        )
        let data = try JSONEncoder.usageEncoder.encode(original)
        let decoded = try JSONDecoder.usageDecoder.decode(UsageData.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

final class SharedConstantsTests: XCTestCase {
    func testBundleIdentifierComposition() {
        XCTAssertEqual(BundleIdentifiers.base, "io.github.sergei-matheson.claudeusagewidget")
        XCTAssertEqual(BundleIdentifiers.appGroup, "group.io.github.sergei-matheson.claudeusagewidget")
        if let accessGroup = BundleIdentifiers.keychainAccessGroup {
            XCTAssertTrue(accessGroup.hasSuffix(".io.github.sergei-matheson.claudeusagewidget"))
        }
        XCTAssertEqual(BundleIdentifiers.keychainService, "io.github.sergei-matheson.claudeusagewidget.session")
    }

    func testRefreshPolicyIntervals() {
        XCTAssertEqual(RefreshPolicy.refreshInterval, 1800)
        XCTAssertEqual(RefreshPolicy.postResetInterval, 300)
        XCTAssertEqual(RefreshPolicy.rateLimitedFallback, 3600)
        XCTAssertEqual(RefreshPolicy.staleThreshold, RefreshPolicy.refreshInterval * 2)
    }
}

final class AppDeepLinkTests: XCTestCase {
    func testParseRetryByHost() {
        let url = URL(string: "claudeusagewidget://retry")!
        XCTAssertEqual(AppDeepLink.parse(url), .retry)
    }

    func testParseRetryByPath() {
        let url = URL(string: "claudeusagewidget:///retry")!
        XCTAssertEqual(AppDeepLink.parse(url), .retry)
    }

    func testRejectsUnknownURLs() {
        XCTAssertNil(AppDeepLink.parse(URL(string: "https://claude.ai/retry")!))
        XCTAssertNil(AppDeepLink.parse(URL(string: "claudeusagewidget://settings")!))
    }
}
