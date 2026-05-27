import Foundation
import Security

// Bundle / entitlement identifiers shared between the app and the widget extension.
// These strings must match project.yml + entitlements in Resources/.
enum BundleIdentifiers {
    static let base = "io.github.sergei-matheson.claudeusagewidget"
    static let appGroup = "group.\(base)"
    // Derived from runtime signing entitlements to avoid hard-coding a Team ID.
    static var keychainAccessGroup: String? {
        Entitlements.keychainAccessGroups.first(where: { $0.hasSuffix(".\(base)") })
    }
    static let keychainService = "\(base).session"
}

private enum Entitlements {
    static var keychainAccessGroups: [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "keychain-access-groups" as CFString,
                  nil
              ) else { return [] }
        return value as? [String] ?? []
    }
}

enum AppDeepLink: Equatable {
    case retry

    static func parse(_ url: URL) -> AppDeepLink? {
        guard url.scheme?.lowercased() == "claudeusagewidget" else { return nil }
        let target = "retry"
        let matchesRetry = url.host?.lowercased() == target || url.path.lowercased() == "/\(target)"
        return matchesRetry ? .retry : nil
    }
}

// Timing knobs for the timeline policy. Surface them in one place so the
// refresh interval, stale threshold, and back-off relate to each other.
enum RefreshPolicy {
    /// Normal timeline reload cadence.
    static let refreshInterval: TimeInterval = 1800           // 30 min
    /// After the 5-hour window has reset, check again sooner so the UI updates promptly.
    static let postResetInterval: TimeInterval = 300          // 5 min
    /// Fallback back-off when a 429 response carries no Retry-After header.
    static let rateLimitedFallback: TimeInterval = 3600       // 1 hour
    /// "Stale data" pill appears after this; 2 × refresh so a single missed refresh doesn't flicker.
    static let staleThreshold: TimeInterval = refreshInterval * 2
}
