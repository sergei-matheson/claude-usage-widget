import Foundation
import OSLog

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
    private let logger = Logger(subsystem: BundleIdentifiers.base, category: "UsageCache")

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
        logger.debug("Cache written")
    }

    func load() -> UsageData? {
        guard let url = cacheURL, let raw = try? Data(contentsOf: url) else {
            logger.debug("Cache miss — no file")
            return nil
        }

        guard let envelope = try? JSONDecoder.usageDecoder.decode(CacheEnvelope.self, from: raw),
              envelope.version == CacheEnvelope.currentVersion else {
            logger.warning("Cache invalid — dropping file")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        let age = Date().timeIntervalSince(envelope.usage.lastUpdated)
        guard age < Self.maxCacheAge else {
            logger.info("Cache expired — dropping file")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        logger.debug("Cache hit, age=\(age, privacy: .public)s")
        return envelope.usage
    }
}
