import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
