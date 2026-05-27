import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var sessionToken = ""
    @State private var organizationId = ""
    @State private var statusMessage = ""
    @State private var hasSavedToken = false
    @State private var statusClearTask: Task<Void, Never>?

    private let keychain = KeychainStore()

    var body: some View {
        Form {
            Section {
                SecureField("Session token", text: $sessionToken)
                TextField("Organization ID (optional)", text: $organizationId)
                if hasSavedToken {
                    Label("Token saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
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
                    .disabled(!hasSavedToken)
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
        .onAppear(perform: loadExistingState)
    }

    private func loadExistingState() {
        if let existing = try? keychain.load() {
            organizationId = existing.organizationId
            hasSavedToken = !existing.sessionKey.isEmpty
        }
    }

    private func setStatus(_ message: String) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { statusMessage = "" }
        }
    }

    private func saveCredentials() {
        let validation = SessionCredentials.validateInput(token: sessionToken, organizationId: organizationId)
        if let message = validation.statusMessage {
            setStatus(message)
            return
        }
        guard case .valid(let trimmedToken, let trimmedOrg) = validation else { return }

        let credentials = SessionCredentials(sessionKey: trimmedToken, organizationId: trimmedOrg)
        do {
            try keychain.save(credentials)
            WidgetCenter.shared.reloadAllTimelines()
            hasSavedToken = true
            sessionToken = ""
            setStatus("Saved. Widget will refresh shortly.")
        } catch {
            setStatus("Failed to save credentials.")
        }
    }

    private func clearCredentials() {
        do {
            try keychain.delete()
            WidgetCenter.shared.reloadAllTimelines()
            organizationId = ""
            hasSavedToken = false
            setStatus("Credentials cleared.")
        } catch {
            setStatus("Failed to clear credentials.")
        }
    }
}

#Preview {
    SettingsView()
}
