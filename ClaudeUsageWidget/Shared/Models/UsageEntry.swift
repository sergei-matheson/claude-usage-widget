import WidgetKit
import Foundation

struct UsageEntry: TimelineEntry {
    let date: Date
    let usageData: UsageData?
    let state: EntryState

    static func placeholder() -> UsageEntry {
        UsageEntry(date: Date(), usageData: UsageData.placeholder(), state: .loaded)
    }

    static func unauthenticated() -> UsageEntry {
        UsageEntry(date: Date(), usageData: nil, state: .unauthenticated)
    }

    static func error(_ message: String) -> UsageEntry {
        UsageEntry(date: Date(), usageData: nil, state: .error(message))
    }
}
