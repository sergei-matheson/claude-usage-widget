import WidgetKit
import SwiftUI

@main
struct ClaudeUsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Shows your Claude message usage and plan status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
