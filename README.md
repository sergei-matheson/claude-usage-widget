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

### 2. Enter your session token

The app opens to a settings screen. Paste your `sessionKey` cookie value there.

To find it:
1. Open [claude.ai](https://claude.ai) in Safari or Chrome
2. Open DevTools → Application → Cookies → `https://claude.ai`
3. Copy the value of the `sessionKey` cookie

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

- The session token is stored in the macOS Keychain.
- Usage data refreshes every 30 minutes via WidgetKit's timeline.
- Tap the widget to open the app and refresh immediately (or update the token if it expires).
