import Foundation

// Versioned envelope so adding a non-optional field to UsageData in the future
// can't silently fail to decode old cache files for existing users.
private struct CacheEnvelope: Codable {
    static let currentVersion = 1
    let version: Int
    let usage: UsageData
}

struct UsageCache {
    static let defaultFileName = "usage_cache.json"
    static let maxCacheAge: TimeInterval = 86400  // 24 hours

    private let cacheURL: URL?

    init() {
        self.cacheURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: BundleIdentifiers.appGroup)?
            .appendingPathComponent(Self.defaultFileName)
    }

    // Test seam: write to an arbitrary location instead of the App Group container.
    init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    func save(_ data: UsageData) throws {
        guard let url = cacheURL else { return }
        let envelope = CacheEnvelope(version: CacheEnvelope.currentVersion, usage: data)
        let encoded = try JSONEncoder.usageEncoder.encode(envelope)
        try encoded.write(to: url, options: .atomic)
    }

    func load() -> UsageData? {
        guard let url = cacheURL, let raw = try? Data(contentsOf: url) else { return nil }

        guard let envelope = try? JSONDecoder.usageDecoder.decode(CacheEnvelope.self, from: raw),
              envelope.version == CacheEnvelope.currentVersion else {
            // Unknown schema or unreadable — drop the file so we don't keep trying.
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        guard Date().timeIntervalSince(envelope.usage.lastUpdated) < Self.maxCacheAge else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return envelope.usage
    }
}
