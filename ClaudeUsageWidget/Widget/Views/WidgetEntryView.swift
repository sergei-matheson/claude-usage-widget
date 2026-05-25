import SwiftUI
import WidgetKit

struct WidgetEntryView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        widgetContent
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch entry.state {
        case .unauthenticated:
            UnauthenticatedView()
        case .error(let message):
            ErrorView(message: message)
        case .loaded:
            if let usage = entry.usageData {
                contentView(for: usage)
            } else {
                ErrorView(message: "No data available")
            }
        }
    }

    @ViewBuilder
    private func contentView(for usage: UsageData) -> some View {
        switch widgetFamily {
        case .systemMedium:
            MediumWidgetView(usage: usage)
        default:
            SmallWidgetView(usage: usage)
        }
    }
}

#Preview("Small – Loaded", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.placeholder()
}

#Preview("Medium – Loaded", as: .systemMedium) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.placeholder()
}

#Preview("Small – Unauthenticated", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.unauthenticated()
}
