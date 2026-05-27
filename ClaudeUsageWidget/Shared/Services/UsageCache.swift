import Foundation

struct UsageCache {
    static let appGroupID = "group.io.github.sergei-matheson.claudeusagewidget"
    static let defaultFileName = "usage_cache.json"
    static let maxCacheAge: TimeInterval = 86400  // 24 hours

    private let cacheURL: URL?

    init() {
        self.cacheURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent(Self.defaultFileName)
    }

    // Test seam: write to an arbitrary location instead of the App Group container.
    init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    func save(_ data: UsageData) throws {
        guard let url = cacheURL else { return }
        let encoded = try JSONEncoder.usageEncoder.encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    func load() -> UsageData? {
        guard let url = cacheURL,
              let raw = try? Data(contentsOf: url),
              let usage = try? JSONDecoder.usageDecoder.decode(UsageData.self, from: raw)
        else { return nil }

        guard Date().timeIntervalSince(usage.lastUpdated) < Self.maxCacheAge else { return nil }
        return usage
    }
}
