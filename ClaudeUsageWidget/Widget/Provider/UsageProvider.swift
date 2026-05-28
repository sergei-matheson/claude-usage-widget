import WidgetKit
import Foundation

struct UsageProvider: TimelineProvider {
    private let service: UsageService
    private let keychain: KeychainStore
    private let cache: UsageCache

    init(
        service: UsageService = UsageService(),
        keychain: KeychainStore = KeychainStore(),
        cache: UsageCache = UsageCache()
    ) {
        self.service = service
        self.keychain = keychain
        self.cache = cache
    }

    struct Result {
        let entries: [UsageEntry]
        let refreshDate: Date?  // nil → .never policy
    }

    func placeholder(in context: Context) -> UsageEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if let cached = cache.load() {
            completion(UsageEntry(date: Date(), usageData: cached, state: .loaded))
        } else {
            completion(.placeholder())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        Task {
            let result = await buildResult()
            let policy: TimelineReloadPolicy = result.refreshDate.map { .after($0) } ?? .never
            completion(Timeline(entries: result.entries, policy: policy))
        }
    }

    func buildResult() async -> Result {
        let credentials: SessionCredentials
        do {
            credentials = try keychain.load()
        } catch KeychainError.notFound {
            return Result(entries: [.unauthenticated()], refreshDate: nil)
        } catch {
            return Result(entries: [.error("Credential error")], refreshDate: nil)
        }

        let nextRefresh = Date().addingTimeInterval(RefreshPolicy.refreshInterval)

        do {
            let usage = try await service.fetchUsage(credentials: credentials)
            try? cache.save(usage)

            let refreshDate: Date
            if let reset = usage.periodResetDate, reset < Date() {
                refreshDate = Date().addingTimeInterval(RefreshPolicy.postResetInterval)
            } else {
                refreshDate = nextRefresh
            }

            return Result(entries: [UsageEntry(date: Date(), usageData: usage, state: .loaded)], refreshDate: refreshDate)
        } catch UsageServiceError.unauthenticated {
            return Result(entries: [.unauthenticated()], refreshDate: nil)
        } catch UsageServiceError.rateLimited(let retryAfter) {
            let delay = retryAfter ?? RefreshPolicy.rateLimitedFallback
            let laterRefresh = Date().addingTimeInterval(delay)
            if let stale = cache.load() {
                return Result(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], refreshDate: laterRefresh)
            } else {
                return Result(entries: [.error("Rate limited. Retrying soon.")], refreshDate: laterRefresh)
            }
        } catch {
            if let stale = cache.load() {
                return Result(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], refreshDate: nextRefresh)
            } else {
                return Result(entries: [.error("Couldn't reach claude.ai")], refreshDate: nextRefresh)
            }
        }
    }
}
