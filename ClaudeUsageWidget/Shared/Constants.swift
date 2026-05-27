import Foundation

// Bundle / entitlement identifiers shared between the app and the widget extension.
// These strings must match the entitlements files in Resources/.
enum BundleIdentifiers {
    static let teamPrefix = "HR4LVL7TKY"
    static let base = "io.github.sergei-matheson.claudeusagewidget"
    static let appGroup = "group.\(base)"
    static let keychainAccessGroup = "\(teamPrefix).\(base)"
    static let keychainService = "\(base).session"
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
