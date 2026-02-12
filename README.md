# PWAKit

<p align="center">
  <img src="docs/logo.png" alt="PWAKit">
</p>

> **Disclaimer:** This project is in active development. APIs and features may change.

Turn your Progressive Web App into a native iOS app with full access to native capabilities.

PWAKit wraps your web app in a native iOS shell, providing a JavaScript bridge to access device features like haptics, biometrics, push notifications, HealthKit, and more.

## Why PWAKit?

PWAKit wraps your existing Progressive Web App in a thin native iOS shell. Unlike frameworks that require learning new languages or rewriting your app, **your code stays 100% web**. For detailed comparisons with Capacitor, React Native, Flutter, and native Swift, see [docs/comparison.md](docs/comparison.md).

## Features

- **Native iOS App**: Full App Store distribution with native performance
- **JavaScript Bridge**: Access iOS capabilities from your web code
- **14 Native Modules**: Haptics, notifications, biometrics, secure storage, and more
- **TypeScript SDK**: Fully typed APIs for all native features
- **JSON Configuration**: Easy setup without Swift knowledge
- **iOS 15+ Support**: Broad device compatibility

## Quick Start

### Prerequisites

| Tool        | Version      | Installation               |
| ----------- | ------------ | -------------------------- |
| macOS       | 14+ (Sonoma) | -                          |
| Xcode       | 15.0+        | App Store                  |
| Swift       | 6.0+         | Included with Xcode        |
| SwiftFormat | 0.54+        | `brew install swiftformat` |
| SwiftLint   | 0.54+        | `brew install swiftlint`   |

### Setup in 3 Steps

```bash
# 1. Clone the repository
git clone https://github.com/eddmann/pwa-kit.git
cd pwa-kit

# 2. Configure your PWA
make setup

# 3. Open in Xcode and run
make open
# Then press Cmd+R in Xcode to build and run
```

The setup wizard will prompt for:

- **App Name**: Display name of your app
- **Start URL**: Your PWA's URL (must be HTTPS)
- **Bundle ID**: iOS bundle identifier (e.g., `com.example.app`)

## Configuration

PWAKit uses a JSON configuration file at `src/PWAKit/Resources/pwa-config.json`.

### Minimal Configuration

```json
{
  "version": 1,
  "app": {
    "name": "My App",
    "bundleId": "com.example.app",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com"]
  }
}
```

See [docs/configuration.md](docs/configuration.md) for feature flags, Info.plist setup, and entitlements. See [docs/config-schema.md](docs/config-schema.md) for the complete schema reference.

## JavaScript SDK

Install the SDK in your web app:

```bash
npm install @eddmann/pwa-kit-sdk
```

### Basic Usage

```typescript
import { push, badging, haptics, ios, isNative } from "@eddmann/pwa-kit-sdk";

if (isNative) {
  // Subscribe to push notifications
  const subscription = await push.subscribe();
  console.log("Token:", subscription.token);

  // Set app badge
  await badging.setAppBadge(5);

  // Haptic feedback
  await haptics.impact("medium");

  // iOS-specific: Face ID / Touch ID
  const result = await ios.biometrics.authenticate("Confirm purchase");
}
```

See [sdk/README.md](sdk/README.md) for the complete SDK documentation and API reference.

## Native Modules

PWAKit includes 13 native modules:

| Module              | Description             | SDK API                                        |
| ------------------- | ----------------------- | ---------------------------------------------- |
| Platform            | Device info             | `platform.getInfo()`                           |
| App                 | Lifecycle, reviews      | `ios.app.requestReview()`                      |
| Haptics             | Haptic feedback         | `haptics.impact('medium')`                     |
| Push Notifications  | Remote push (APNs)      | `push.subscribe()`                             |
| Local Notifications | Scheduled notifications | `ios.notifications.schedule()`                 |
| Biometrics          | Face ID / Touch ID      | `ios.biometrics.authenticate()`                |
| Secure Storage      | Keychain                | `ios.secureStorage.set()`                      |
| Clipboard           | Copy/paste              | `clipboard.writeText()`                        |
| Share               | Share sheet             | `share.share()`                                |
| Print               | AirPrint                | `print.print()`                                |
| Camera Permission   | Camera access           | `permissions.request({ name: 'camera' })`      |
| Location Permission | Location access         | `permissions.request({ name: 'geolocation' })` |
| HealthKit           | Health data             | `ios.healthKit.querySteps()`                   |
| StoreKit            | In-app purchases        | `ios.storeKit.purchase()`                      |

For full API documentation, see [sdk/README.md](sdk/README.md). To create your own modules, see [docs/custom-modules.md](docs/custom-modules.md).

## Development

Run `make help` to see all available commands. Key commands:

```bash
make setup          # Run interactive setup wizard
make open           # Open Xcode project (Cmd+R to run, Cmd+U to test)
make example        # Run kitchen sink demo server
make lint           # Run SwiftLint
make format         # Format code with SwiftFormat
```

For device testing, debugging, and deployment, see [docs/development.md](docs/development.md).

## Documentation

| Document                                     | Description                                                  |
| -------------------------------------------- | ------------------------------------------------------------ |
| [Configuration Guide](docs/configuration.md) | Info.plist keys, entitlements, and feature flag setup        |
| [Config Schema](docs/config-schema.md)       | Complete JSON schema reference for pwa-config.json           |
| [Framework Comparison](docs/comparison.md)   | PWAKit vs Capacitor, React Native, Flutter, and native Swift |
| [Custom Modules](docs/custom-modules.md)     | Guide to creating your own native bridge modules             |
| [Architecture](docs/architecture.md)         | Internal architecture, bridge protocol, and message flow     |
| [Development](docs/development.md)           | Local development, device testing, and debugging             |
| [Troubleshooting](docs/troubleshooting.md)   | Common issues and their solutions                            |
| [SDK Reference](sdk/README.md)               | TypeScript SDK documentation and API reference               |

## License

MIT License - see [LICENSE](LICENSE) for details.
