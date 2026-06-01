import Foundation

struct DiagnosticsStore {
    private let storeURL: URL?

    init() {
        self.storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: BundleIdentifiers.appGroup)?
            .appendingPathComponent("diagnostics.json")
    }

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func save(_ entry: DiagnosticsEntry) throws {
        guard let url = storeURL else { return }
        let encoded = try JSONEncoder.usageEncoder.encode(entry)
        try encoded.write(to: url, options: .atomic)
    }

    func load() -> DiagnosticsEntry? {
        guard let url = storeURL, let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.usageDecoder.decode(DiagnosticsEntry.self, from: raw)
    }

    func nextFetchCount() -> Int {
        (load()?.totalFetches ?? 0) + 1
    }
}
