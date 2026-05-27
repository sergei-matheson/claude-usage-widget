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

            let nextRefresh = Date().addingTimeInterval(1800)  // 30 minutes

            do {
                let usage = try await service.fetchUsage(credentials: credentials)
                try? cache.save(usage)

                // If the period has already reset, check again soon
                let policy: TimelineReloadPolicy
                if let reset = usage.periodResetDate, reset < Date() {
                    policy = .after(Date().addingTimeInterval(300))
                } else {
                    policy = .after(nextRefresh)
                }

                let entry = UsageEntry(date: Date(), usageData: usage, state: .loaded)
                completion(Timeline(entries: [entry], policy: policy))
            } catch UsageServiceError.unauthenticated {
                completion(Timeline(entries: [.unauthenticated()], policy: .never))
            } catch UsageServiceError.unexpectedResponse(429) {
                // Rate limited: back off to 60 minutes
                let laterRefresh = Date().addingTimeInterval(3600)
                if let stale = cache.load() {
                    completion(Timeline(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], policy: .after(laterRefresh)))
                } else {
                    completion(Timeline(entries: [.error("Rate limited. Retrying in 1 hour.")], policy: .after(laterRefresh)))
                }
            } catch {
                if let stale = cache.load() {
                    completion(Timeline(entries: [UsageEntry(date: Date(), usageData: stale, state: .loaded)], policy: .after(nextRefresh)))
                } else {
                    completion(Timeline(entries: [.error(error.localizedDescription)], policy: .after(nextRefresh)))
                }
            }
        }
    }
}
