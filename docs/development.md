# Development Guide

This document covers local development workflows, device testing, and debugging tips for PWAKit.

## Local Development

### Starting the Example Server

The example app provides a kitchen sink demo of all PWAKit features:

```bash
make example/serve
```

This starts an HTTPS server at `https://localhost:8443` with a self-signed certificate.

### Running in Simulator

1. Open Xcode: `make kit/open`
2. Select a simulator from the scheme dropdown
3. Press Cmd+R to build and run

### Running Tests

```bash
# Open Xcode
make kit/open

# Press Cmd+U to run all tests
# Or use Product > Test menu
```

## Testing on Physical Devices

The example server binds to `0.0.0.0` to allow access from devices on your network. For testing on physical iOS devices, you can use [Tailscale Funnel](https://tailscale.com/kb/1223/funnel) to expose your local server with a valid HTTPS URL.

### Using Tailscale Funnel

```bash
# 1. Start the example server
cd example
node server.js

# 2. In another terminal, expose via Tailscale Funnel
tailscale funnel 8443

# This creates a URL like: https://your-machine.tailnet-name.ts.net/
```

### Configure for Device Testing

Temporarily update `pwa-config.json` for device testing:

```json
{
  "app": {
    "startUrl": "https://your-machine.tailnet-name.ts.net/"
  },
  "origins": {
    "allowed": ["localhost", "your-machine.tailnet-name.ts.net"]
  }
}
```

And add the domain to `Info.plist` under `WKAppBoundDomains`:

```xml
<key>WKAppBoundDomains</key>
<array>
    <string>localhost</string>
    <string>your-machine.tailnet-name.ts.net</string>
</array>
```

> **Note:** Remember to revert these changes before committing. The Tailscale hostname is specific to your machine.

### Device Requirements

1. **Apple Developer Account** (free or paid)
   - Free accounts can deploy to 3 devices
   - Apps expire after 7 days with free accounts

2. **Device Registration**
   - Open Xcode > Window > Devices and Simulators
   - Connect your device and add it

3. **Developer Mode** (iOS 16+)
   - Settings > Privacy & Security > Developer Mode

4. **Code Signing**
   - Configure signing in Xcode under Signing & Capabilities
   - Find your Team ID at [developer.apple.com/account](https://developer.apple.com/account)

## SDK Development

### Building the SDK

```bash
make sdk/deps
make sdk/build
```

### Watching for Changes

```bash
cd sdk && npm run dev
```

### Running SDK Tests

```bash
make sdk/test
```

### Type Checking

```bash
make sdk/typecheck
```

## Code Quality

### Linting

```bash
make kit/lint       # Check for issues
make kit/lint/fix   # Auto-fix issues
```

### Formatting

```bash
make kit/fmt        # Format all Swift code
make kit/fmt/check  # Check formatting without changes
```

### Full Check

```bash
make kit/can-release  # Run format check + lint + build + test
```

## Debugging

### Viewing Simulator Logs

```bash
xcrun simctl spawn booted log stream --predicate 'process == "PWAKit"'
```

### Checking Code Signing

```bash
codesign -dvvv /path/to/PWAKit.app
```

### Verifying Entitlements

```bash
codesign -d --entitlements :- /path/to/PWAKit.app
```

### Validating Configuration

```bash
cat kit/src/PWAKit/Resources/pwa-config.json | python3 -m json.tool
```

## Project Structure

```
pwa-kit/
├── kit/                         # iOS Xcode project + Swift tooling
│   ├── PWAKitApp.xcodeproj/     # Xcode project
│   ├── src/
│   │   ├── PWAKit/              # iOS app target
│   │   │   ├── App/             # App entry point, delegates
│   │   │   ├── Views/           # SwiftUI views
│   │   │   └── Resources/       # Assets, pwa-config.json
│   │   └── PWAKitCore/          # Core library
│   │       ├── Bridge/          # JavaScript bridge
│   │       ├── Configuration/   # Config loading/validation
│   │       ├── Modules/         # Native modules
│   │       ├── Navigation/      # URL handling, deep links
│   │       ├── WebView/         # WKWebView setup
│   │       └── Files/           # Downloads, document preview
│   ├── tests/
│   │   └── PWAKitCoreTests/     # Unit tests
│   └── scripts/                 # lint.sh, format.sh
├── cli/                         # TypeScript CLI
├── sdk/                         # JavaScript SDK
│   ├── src/                     # TypeScript source
│   └── dist/                    # Compiled output
├── example/                     # Kitchen sink demo
└── docs/                        # Documentation
```

## Common Workflows

### Adding a New Feature

1. Create the Swift module in `kit/src/PWAKitCore/Modules/`
2. Register it in `ModuleRegistration.swift`
3. Add feature flag to `FeaturesConfiguration.swift` if needed
4. Create SDK wrapper in `sdk/src/`
5. Add tests for both Swift and TypeScript
6. Update documentation

### Updating Configuration Schema

1. Modify types in `kit/src/PWAKitCore/Configuration/`
2. Update `pwa-config.example.json`
3. Update `docs/config-schema.md`
4. Update `docs/configuration.md`

### Syncing Configuration

After changing `pwa-config.json`, sync the configuration:

```bash
make kit/sync
```

This updates `WKAppBoundDomains` in Info.plist, color assets, and app icon to match your configuration.
