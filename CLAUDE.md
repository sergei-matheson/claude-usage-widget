# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A macOS menubar/Notification Center widget that polls the undocumented `claude.ai/api/usage` endpoint and displays the 5-hour rate-limit window and 7-day rolling usage. The app's only UI is a settings screen for entering the session token; everything else lives in the WidgetKit extension.

Target macOS version: **26.0**. Swift 5.9.

## Build & run

The Xcode project is generated from `project.yml` via XcodeGen. Regenerate after editing `project.yml`:

```sh
xcodegen generate
```

Build and run tests from the command line:

```sh
# Run all tests
xcodebuild test -project ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidgetTests \
  -destination 'platform=macOS'

# Run a single test method
xcodebuild test -project ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidgetTests \
  -destination 'platform=macOS' \
  -only-testing:ClaudeUsageWidgetTests/UsageServiceTests/testParsesUtilizationValues
```

Build the app:

```sh
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetApp
```

## Architecture

Three targets share source via the `Shared/` directory:

| Target | Sources |
|--------|---------|
| `ClaudeUsageWidgetApp` | `App/` + `Shared/` |
| `ClaudeUsageWidgetExtension` | `Widget/` + `Shared/` |
| `ClaudeUsageWidgetTests` | `ClaudeUsageWidgetTests/` + `Shared/` |

### Shared layer (`ClaudeUsageWidget/Shared/`)

- **`Models/SessionCredentials`** — the session key + optional org ID stored in Keychain.
- **`Models/UsageData`** — the decoded API payload; also holds `JSONDecoder.usageDecoder` / `JSONEncoder.usageEncoder` helpers (snake_case ↔ camelCase, ISO 8601 dates).
- **`Models/UsageEntry`** — conforms to `TimelineEntry`; wraps `UsageData?` + `EntryState` (`.loaded`, `.unauthenticated`, `.error`).
- **`Services/KeychainStore`** — reads/writes `SessionCredentials` as JSON in the Keychain. Uses a shared access group (`HR4LVL7TKY.io.github.sergei-matheson.claudeusagewidget`) so both app and extension can access it. Tests pass a unique service name and no access group to avoid sandbox conflicts.
- **`Services/UsageService`** — fetches `https://claude.ai/api/usage` (or the org-scoped variant). Maps the undocumented `five_hour` / `seven_day` JSON buckets to `UsageData`. The endpoint path should be verified by inspecting network traffic on `claude.ai/settings/usage` if it stops working.
- **`Services/UsageCache`** — persists the last `UsageData` as JSON in the App Group container (`group.io.github.sergei-matheson.claudeusagewidget`). Cache expires after 24 hours.

### Widget extension (`ClaudeUsageWidget/Widget/`)

- **`UsageProvider`** — `TimelineProvider`. Reads credentials from Keychain; on success, saves to cache and schedules a 30-minute refresh. Falls back to stale cache on network errors; backs off to 60 minutes on 429.
- **`WidgetEntryView`** — dispatches to `SmallWidgetView`, `MediumWidgetView`, `UnauthenticatedView`, or `ErrorView` based on family and `EntryState`.

### App (`ClaudeUsageWidget/App/`)

`SettingsView` is the entire app UI: a form to save/clear the session token (and optional org ID) to Keychain. Saving calls `WidgetCenter.shared.reloadAllTimelines()`.

## Key constraints

- Both the app and extension must have matching `keychain-access-groups` and `application-groups` entitlements; these are defined in `project.yml` and the `.entitlements` files in `Resources/`.
- `kSecAttrAccessibleAfterFirstUnlock` is used so the widget extension can read credentials before the user unlocks the device.
- The `claudeusagewidget://` URL scheme lets the widget's `ErrorView` deep-link back into the app for re-authentication.
