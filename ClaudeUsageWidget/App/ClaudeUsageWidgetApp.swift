import SwiftUI
import WidgetKit

@main
struct ClaudeUsageWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
                .onOpenURL { url in
                    guard AppDeepLink.parse(url) == .retry else { return }
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .windowResizability(.contentSize)
    }
}
