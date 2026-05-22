import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var sessionToken = ""
    @State private var organizationId = ""
    @State private var statusMessage = ""

    private let keychain = KeychainStore()

    var body: some View {
        Form {
            Section {
                SecureField("Session token", text: $sessionToken)
                TextField("Organization ID (optional)", text: $organizationId)
            } header: {
                Text("Claude.ai Credentials")
            } footer: {
                Text("""
                To find your session token: open claude.ai in your browser → open DevTools (⌥⌘I) \
                → Application tab → Cookies → claude.ai → copy the value of the 'sessionKey' cookie.
                """)
                .font(.caption)
            }

            Section {
                Button("Save") { saveCredentials() }
                    .disabled(sessionToken.isEmpty)

                Button("Clear", role: .destructive) { clearCredentials() }
            }

            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 320)
        .onAppear(perform: loadExistingOrgID)
    }

    private func loadExistingOrgID() {
        if let existing = try? keychain.load() {
            organizationId = existing.organizationId
        }
    }

    private func saveCredentials() {
        guard !sessionToken.isEmpty else { return }
        let credentials = SessionCredentials(sessionKey: sessionToken, organizationId: organizationId)
        do {
            try keychain.save(credentials)
            WidgetCenter.shared.reloadAllTimelines()
            statusMessage = "Saved. Widget will refresh shortly."
            sessionToken = ""
        } catch {
            statusMessage = "Failed to save credentials."
        }
    }

    private func clearCredentials() {
        do {
            try keychain.delete()
            WidgetCenter.shared.reloadAllTimelines()
            organizationId = ""
            statusMessage = "Credentials cleared."
        } catch {
            statusMessage = "Failed to clear credentials."
        }
    }
}

#Preview {
    SettingsView()
}
