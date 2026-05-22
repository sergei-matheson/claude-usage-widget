import Foundation

struct UsageCache {
    private let appGroupID = "group.com.yourorg.claudeusagewidget"
    private let fileName = "usage_cache.json"
    private let maxCacheAge: TimeInterval = 86400  // 24 hours

    private var cacheURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
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

        guard Date().timeIntervalSince(usage.lastUpdated) < maxCacheAge else { return nil }
        return usage
    }
}
