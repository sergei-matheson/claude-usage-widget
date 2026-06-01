# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A macOS Notification Center widget that polls the undocumented `claude.ai/api/organizations/{org_id}/usage` endpoint and displays the 5-hour rate-limit window and 7-day rolling usage. The app's only UI is a settings screen for entering the session token and org ID; everything else lives in the WidgetKit extension.

Target macOS version: **26.0**. Swift 5.9.

## Build & run

The Xcode project is generated from `project.yml` via XcodeGen. Regenerate after editing `project.yml`:

```sh
xcodegen generate
```

Run tests:

```sh
# Run all tests
./test.sh

# Run a single test class or method
./test.sh ClaudeUsageWidgetTests/UsageServiceTests
./test.sh ClaudeUsageWidgetTests/UsageServiceTests/testParsesUtilizationValues
```

Build and install the app to `/Applications`:

```sh
./install.sh
```

## Architecture

Three targets share source via the `Shared/` directory:

| Target | Sources |
|--------|---------|
| `ClaudeUsageWidgetApp` | `App/` + `Shared/` |
| `ClaudeUsageWidgetExtension` | `Widget/` + `Shared/` |
| `ClaudeUsageWidgetTests` | `ClaudeUsageWidgetTests/` + `Shared/` + `Widget/Provider/` |

### Shared layer (`ClaudeUsageWidget/Shared/`)

- **`Constants`** — `BundleIdentifiers` (app group, keychain service, widget kind, access group read from runtime entitlements), `AppDeepLink` (parses `claudeusagewidget://retry` URLs), `RefreshPolicy` (timing constants: 30 min refresh, 5 min post-reset, 1 hour rate-limit fallback, stale threshold).
- **`Models/SessionCredentials`** — the session key + optional org ID stored in Keychain.
- **`Models/UsageData`** — the decoded API payload; also holds `JSONDecoder.usageDecoder` / `JSONEncoder.usageEncoder` helpers (snake_case ↔ camelCase, ISO 8601 dates).
- **`Models/UsageEntry`** — conforms to `TimelineEntry`; wraps `UsageData?` + `EntryState`.
- **`Models/EntryState`** — enum with cases `.loaded`, `.unauthenticated`, `.error(String)`.
- **`Models/DiagnosticsEntry`** — records fetch metadata: date, source (`.live` / `.cached`), optional error message, and cumulative fetch count.
- **`Intents/RefreshUsageIntent`** — `AppIntent` that calls `WidgetCenter.shared.reloadTimelines(ofKind:)`. Wired to the refresh button in `MediumWidgetView`.
- **`Services/KeychainStore`** — reads/writes `SessionCredentials` as JSON in the Keychain. Uses a shared access group derived at runtime from entitlements so both app and extension can access it. Tests pass a unique service name and no access group to avoid sandbox conflicts.
- **`Services/UsageService`** — fetches `https://claude.ai/api/organizations/{org_id}/usage`. An org ID is required; the personal `/api/usage` endpoint was removed in June 2026. Maps the undocumented `five_hour` / `seven_day` JSON buckets to `UsageData`. Verify the path by inspecting network traffic on `claude.ai/settings/usage` if it stops working.
- **`Services/UsageCache`** — persists the last `UsageData` as JSON in the App Group container (`group.io.github.sergei-matheson.claudeusagewidget`). Cache expires after 24 hours.
- **`Services/DiagnosticsStore`** — persists the last `DiagnosticsEntry` as JSON in the App Group container (`diagnostics.json`). Exposes `nextFetchCount()` to generate a monotonically increasing fetch counter.

### Widget extension (`ClaudeUsageWidget/Widget/`)

- **`Provider/UsageProvider`** — `TimelineProvider`. Core logic lives in `buildResult() async -> Result` (a plain struct with `entries: [UsageEntry]` and `refreshDate: Date?`); `getTimeline` calls `buildResult()` and converts the result to a `Timeline`. This separation exists because `TimelineProviderContext` has no public initializer and `TimelineReloadPolicy` is a struct with no inspectable properties — neither can be used cleanly in tests. Falls back to stale cache on network errors; backs off on 429.
- **`WidgetEntryView`** — dispatches to `SmallWidgetView`, `MediumWidgetView`, `UnauthenticatedView`, or `ErrorView` based on family and `EntryState`.

### App (`ClaudeUsageWidget/App/`)

`SettingsView` is the entire app UI: a form to save/clear the session token (and optional org ID) to Keychain. Saving calls `WidgetCenter.shared.reloadAllTimelines()`. `onOpenURL` is attached to `SettingsView` (not the `WindowGroup` scene) to handle `claudeusagewidget://retry` deep links from the widget.

## CI

GitHub Actions workflow at `.github/workflows/ci.yml` runs `./test.sh` on every push to `main` and on every pull request, using a `macos-26` runner. The test target has code signing disabled (`CODE_SIGN_IDENTITY=""`) so no certificate is needed on the runner.

## Key constraints

- Both the app and extension must have matching `keychain-access-groups` and `application-groups` entitlements; these are defined in `project.yml` and the `.entitlements` files in `Resources/`.
- `kSecAttrAccessibleAfterFirstUnlock` is used so the widget extension can read credentials before the user unlocks the device.
- The `claudeusagewidget://` URL scheme lets the widget's `ErrorView` deep-link back into the app for re-authentication. `onOpenURL` must be a `View` modifier (on `SettingsView`), not a `Scene` modifier — `Scene` does not have this member on macOS.
- The test target compiles `Widget/Provider/` directly (in addition to `Shared/`) so `UsageProviderTests` (in `UsageServiceHTTPTests.swift`) can call `buildResult()` without going through `getTimeline(in:completion:)`.
