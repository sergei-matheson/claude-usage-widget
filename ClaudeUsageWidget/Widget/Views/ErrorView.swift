import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Tap to retry")
                .font(.caption2)
                .foregroundStyle(.tint)
        }
        .padding()
        // Deep-links to the host app so the user can re-save credentials or force a refresh.
        // Register the "claudeusagewidget" URL scheme in the host app's Info.plist.
        .widgetURL(URL(string: "claudeusagewidget://retry"))
    }
}

#Preview {
    ErrorView(message: "Unable to fetch usage data.")
        .frame(width: 154, height: 154)
}
