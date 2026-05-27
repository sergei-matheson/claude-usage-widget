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
            let credentials: SessionCredentials
            do {
                credentials = try keychain.load()
            } catch KeychainError.notFound {
                completion(Timeline(entries: [.unauthenticated()], policy: .never))
                return
            } catch {
                completion(Timeline(entries: [.error("Credential error")], policy: .never))
                return
            }

            let nextRefresh = Date().addingTimeInterval(RefreshPolicy.refreshInterval)

            do {
                let usage = try await service.fetchUsage(credentials: credentials)
                try? cache.save(usage)

                let policy: TimelineReloadPolicy
                if let reset = usage.periodResetDate, reset < Date() {
                    policy = .after(Date().addingTimeInterval(RefreshPolicy.postResetInterval))
                } else {
                    policy = .after(nextRefresh)
                }

                let entry = UsageEntry(date: Date(), usageData: usage, state: .loaded)
                completion(Timeline(entries: [entry], policy: policy))
            } catch UsageServiceError.unauthenticated {
                completion(Timeline(entries: [.unauthenticated()], policy: .never))
            } catch UsageServiceError.rateLimited(let retryAfter) {
                let delay = retryAfter ?? RefreshPolicy.rateLimitedFallback
                let laterRefresh = Date().addingTimeInterval(delay)
                if let stale = cache.load() {
                    completion(Timeline(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], policy: .after(laterRefresh)))
                } else {
                    completion(Timeline(entries: [.error("Rate limited. Retrying soon.")], policy: .after(laterRefresh)))
                }
            } catch {
                if let stale = cache.load() {
                    completion(Timeline(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], policy: .after(nextRefresh)))
                } else {
                    // Fixed user-facing string so URLError details (proxy, host hints) can't leak.
                    completion(Timeline(entries: [.error("Couldn't reach claude.ai")], policy: .after(nextRefresh)))
                }
            }
        }
    }
}
