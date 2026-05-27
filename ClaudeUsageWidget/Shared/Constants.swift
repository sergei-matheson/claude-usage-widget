import Foundation
import Security

// Bundle / entitlement identifiers shared between the app and the widget extension.
// These strings must match project.yml + entitlements in Resources/.
enum BundleIdentifiers {
    static let base = "io.github.sergei-matheson.claudeusagewidget"
    static let appGroup = "group.\(base)"
    // Derived from runtime signing entitlements to avoid hard-coding a Team ID.
    static let keychainAccessGroup: String? =
        Entitlements.keychainAccessGroups.first(where: { $0.hasSuffix(".\(base)") })
    static let keychainService = "\(base).session"
}

private enum Entitlements {
    static let keychainAccessGroups: [String] = {
        guard let task = SecTaskCreateFromSelf(nil) else { return [] }
        guard let value = SecTaskCopyValueForEntitlement(
            task,
            "keychain-access-groups" as CFString,
            nil
        ) else { return [] }
        if let groups = value as? [String] {
            return groups
        }
        if let group = value as? String {
            return [group]
        }
        assertionFailure(
            "Expected array or string for keychain-access-groups entitlement, got \(String(describing: type(of: value))). Check entitlements configuration."
        )
        return []
    }()
}

enum AppDeepLink: Equatable {
    case retry

    static func parse(_ url: URL) -> AppDeepLink? {
        guard url.scheme?.lowercased() == "claudeusagewidget" else { return nil }
        let target = "retry"
        let matchesHost = url.host?.lowercased() == target
        // Accept both host and path forms for compatibility with already-shipped deep links.
        let matchesPath = url.path.lowercased() == "/\(target)"
        let matchesPathOnly = (url.host == nil || url.host?.isEmpty == true) && matchesPath
        let matchesRetry = matchesHost || matchesPathOnly
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
