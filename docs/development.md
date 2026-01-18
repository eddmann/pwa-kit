# Development Guide

This document covers local development workflows, device testing, and debugging tips for PWAKit.

## Local Development

### Starting the Example Server

The example app provides a kitchen sink demo of all PWAKit features:

```bash
make example
```

This starts an HTTPS server at `https://localhost:8443` with a self-signed certificate.

### Running in Simulator

1. Open Xcode: `make open`
2. Select a simulator from the scheme dropdown
3. Press Cmd+R to build and run

### Running Tests

```bash
# Open Xcode
make open

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
cd sdk
npm install
npm run build
```

### Watching for Changes

```bash
cd sdk
npm run dev
```

### Running SDK Tests

```bash
cd sdk
npm test
npm run test:watch  # Watch mode
```

### Type Checking

```bash
cd sdk
npm run typecheck
```

## Code Quality

### Linting

```bash
make lint           # Check for issues
make lint-fix       # Auto-fix issues
```

### Formatting

```bash
make format         # Format all Swift code
make format-check   # Check formatting without changes
```

### Full Check

```bash
make check          # Run format-check + lint
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
cat src/PWAKit/Resources/pwa-config.json | python3 -m json.tool
```

## Project Structure

```
pwa-kit/
├── src/
│   ├── PWAKit/                  # iOS app target
│   │   ├── App/                 # App entry point, delegates
│   │   ├── Views/               # SwiftUI views
│   │   └── Resources/           # Assets, pwa-config.json
│   └── PWAKitCore/              # Core library
│       ├── Bridge/              # JavaScript bridge
│       ├── Configuration/       # Config loading/validation
│       ├── Modules/             # Native modules
│       ├── Navigation/          # URL handling, deep links
│       ├── WebView/             # WKWebView setup
│       └── Files/               # Downloads, document preview
├── tests/
│   └── PWAKitCoreTests/         # Unit tests
├── sdk/                         # JavaScript SDK
│   ├── src/                     # TypeScript source
│   └── dist/                    # Compiled output
├── example/                     # Kitchen sink demo
├── scripts/                     # Setup and utility scripts
└── docs/                        # Documentation
```

## Common Workflows

### Adding a New Feature

1. Create the Swift module in `src/PWAKitCore/Modules/`
2. Register it in `ModuleRegistration.swift`
3. Add feature flag to `FeaturesConfiguration.swift` if needed
4. Create SDK wrapper in `sdk/src/`
5. Add tests for both Swift and TypeScript
6. Update documentation

### Updating Configuration Schema

1. Modify types in `src/PWAKitCore/Configuration/`
2. Update `pwa-config.example.json`
3. Update `docs/config-schema.md`
4. Update `docs/configuration.md`

### Syncing Configuration to Info.plist

After changing `pwa-config.json`, sync the domains:

```bash
./scripts/sync-config.sh
```

This updates `WKAppBoundDomains` in Info.plist to match your origins configuration.
