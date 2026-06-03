<p align="center">
  <img src="ClaudeUsageWidget/App/Assets.xcassets/AppIcon.appiconset/icon_128.png" width="128" alt="Claude Usage Widget icon"/>
</p>

# Claude Usage Widget

A macOS widget that shows your [Claude.ai](https://claude.ai) usage at a glance.

**Small widget** — 5-hour rate-limit window: usage percentage and time until reset.  
**Medium widget** — adds a 7-day rolling usage bar and last-updated timestamp.

## Setup

### 1. Build and install

Run the install script (requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```sh
./install.sh
```

This builds the app, copies it to `/Applications`, clears the quarantine flag, and registers the widget extension. Then open the app from `/Applications`.

### 2. Enter your credentials

The app opens to a settings screen. You need two values:

**Session token** — the `sessionKey` cookie from claude.ai:
1. Open [claude.ai](https://claude.ai) in Safari or Chrome
2. Open DevTools → Application → Cookies → `https://claude.ai`
3. Copy the value of the `sessionKey` cookie

**Organization ID** — required; the personal usage endpoint was removed in June 2026:
1. Open [claude.ai/settings/usage](https://claude.ai/settings/usage) in your browser
2. Open DevTools → Network, reload the page, and find the `usage` API request
3. Copy the organization ID from the request URL: `/api/organizations/{org_id}/usage`

### 3. Add the widget

Open Notification Center, scroll to the bottom, click **Edit Widgets**, and search for **Claude Usage**.

## Development

Run the test suite:

```sh
./test.sh
```

To run a specific test class or method, pass its identifier:

```sh
./test.sh ClaudeUsageWidgetTests/UsageServiceTests
./test.sh ClaudeUsageWidgetTests/UsageServiceTests/testParsesUtilizationValues
```

## Notes

- Credentials (session token and org ID) are stored in the macOS Keychain.
- Usage data refreshes every 30 minutes via WidgetKit's timeline.
- The medium widget has a refresh button (↻) to trigger an immediate update.
- If the widget shows an error, tap it to open the app and re-enter credentials.
- The app's settings screen includes a **Diagnostics** section showing the last fetch time, data source (live or cached), and any errors.
