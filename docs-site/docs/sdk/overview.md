# SDK Overview

`@pwa-kit/sdk` is the JavaScript bridge client for PWAKit native modules.

## Install

```bash
npm install @pwa-kit/sdk
```

## Runtime model

- In PWAKit native wrapper: bridge calls are available.
- In regular browser: bridge calls reject with `BridgeUnavailableError`.

Always guard native calls:

```ts
import { isNative, platform } from "@pwa-kit/sdk";

if (isNative) {
  const info = await platform.getInfo();
  console.log(info);
}
```

## Surface areas

- Web API-aligned modules:
  - `push`, `badging`, `vibration`, `clipboard`, `share`, `permissions`
- Enhanced modules:
  - `haptics`, `print`, `platform`
- iOS namespace:
  - `ios.biometrics`, `ios.secureStorage`, `ios.healthKit`, `ios.storeKit`, `ios.app`, `ios.notifications`

## Core bridge exports

- `bridge` (singleton `PWABridge`)
- `PWABridge` class
- `BridgeError`, `BridgeTimeoutError`, `BridgeUnavailableError`

## TypeScript exports at a glance

`@pwa-kit/sdk` exports typed interfaces and unions for:

- Bridge protocol: `BridgeMessage`, `BridgeResponse`, `BridgeEvent`
- Detection: `Platform`, `PlatformDetectionInfo`
- Web-aligned modules: push/share/permissions/haptics/print/platform types
- iOS modules: biometrics, secure storage, HealthKit, StoreKit, app, notifications

Example:

```ts
import type { PlatformDetectionInfo, ProductInfo, NotificationOptions } from "@pwa-kit/sdk";
```

## Suggested reading order

1. Runtime checks and events: [Runtime Detection](/sdk/runtime-detection)
2. Browser-aligned APIs and deviations: [Web API Modules](/sdk/web-api-modules)
3. iOS-specific APIs: [iOS Modules](/sdk/ios-modules)
4. Custom native bridge wrappers: [Custom Module SDK Integration](/sdk/custom-modules)
5. Low-level bridge details: [Bridge API](/sdk/bridge-api)
6. Error behavior: [Error Handling](/sdk/errors)
