import AppIntents
import WidgetKit

struct RefreshUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Claude Usage"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: BundleIdentifiers.widgetKind)
        return .result()
    }
}
