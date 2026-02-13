# @pwa-kit/sdk

TypeScript SDK for communicating with the PWAKit native iOS bridge. Provides Web API-aligned interfaces for native capabilities like push notifications, badges, haptics, biometrics, HealthKit, StoreKit, and more.

## Installation

```bash
npm install @pwa-kit/sdk
```

## Browser Bundle

For direct browser usage without a bundler:

```html
<script src="https://cdn.jsdelivr.net/gh/eddmann/pwa-kit@main/sdk/dist/index.global.js"></script>
<script>
  const { push, badging, haptics, ios, isNative } = PWAKit;

  if (isNative) {
    badging.setAppBadge(5);
  }
</script>
```

## Quick Start

```typescript
import { push, badging, haptics, ios, isNative } from "@pwa-kit/sdk";

if (isNative) {
  // Subscribe to push notifications (PushManager API)
  const subscription = await push.subscribe();
  console.log("Token:", subscription.token);

  // Set app badge (Badging API)
  await badging.setAppBadge(5);

  // Haptic feedback
  await haptics.impact("medium");

  // iOS-specific: Face ID / Touch ID
  const result = await ios.biometrics.authenticate("Confirm purchase");
}
```

## API Structure

The SDK organizes APIs into three categories:

### Web API-Aligned Modules

These modules follow Web Platform API conventions:

| Module        | Web Standard                                                                        | Description                     |
| ------------- | ----------------------------------------------------------------------------------- | ------------------------------- |
| `push`        | [PushManager](https://developer.mozilla.org/en-US/docs/Web/API/PushManager)         | Push notification registration  |
| `badging`     | [Badging API](https://developer.mozilla.org/en-US/docs/Web/API/Badging_API)         | App icon badges                 |
| `vibration`   | [Vibration API](https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API)     | Vibration (uses haptics on iOS) |
| `clipboard`   | [Clipboard API](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API)     | Read/write clipboard            |
| `share`       | [Web Share API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API)     | Native share sheet              |
| `permissions` | [Permissions API](https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API) | Permission management           |

### Enhanced APIs

Extended functionality beyond web standards:

| Module     | Description                                           |
| ---------- | ----------------------------------------------------- |
| `haptics`  | iOS haptic feedback (impact, notification, selection) |
| `print`    | AirPrint functionality                                |
| `platform` | Platform detection and device info                    |

### iOS-Specific Modules (Namespaced)

Native iOS features without web equivalents, namespaced under `ios.*`:

| Module              | Description                       |
| ------------------- | --------------------------------- |
| `ios.biometrics`    | Face ID / Touch ID authentication |
| `ios.secureStorage` | Keychain storage                  |
| `ios.healthKit`     | HealthKit data access             |
| `ios.storeKit`      | In-app purchases (StoreKit 2)     |
| `ios.app`           | App lifecycle and reviews         |
| `ios.notifications` | Local notification scheduling     |

## Web API Alignment

PWAKit SDK methods are designed to match Web Platform API signatures as closely as possible:

| SDK Module    | Web Standard                                                                        | Alignment                                                             |
| ------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `push`        | [PushManager](https://developer.mozilla.org/en-US/docs/Web/API/PushManager)         | Exact match - `subscribe()`, `getSubscription()`, `permissionState()` |
| `badging`     | [Badging API](https://developer.mozilla.org/en-US/docs/Web/API/Badging_API)         | Exact match - `setAppBadge()`, `clearAppBadge()`                      |
| `vibration`   | [Vibration API](https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API)     | Exact match - `vibrate(pattern)` (polyfills with haptics on iOS)      |
| `clipboard`   | [Clipboard API](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API)     | Text methods - `writeText()`, `readText()`                            |
| `share`       | [Web Share API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API)     | Match - `share()`, async `canShare()`                                 |
| `permissions` | [Permissions API](https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API) | Match with extension - `query()` + `request()`                        |

### Intentional Deviations

These deviations improve the developer experience on mobile:

- **`clipboard.readText()`** returns `string | null` instead of throwing when clipboard is empty
- **`share.canShare()`** is async to check native availability (Web API is sync)
- **`share.share()`** returns `ShareResult` with `completed` and `activityType` (Web returns void)
- **`permissions.request()`** is an extension for pre-prompting (not in Web standard)

## Web API-Aligned Modules

### Push (PushManager)

```typescript
import { push } from "@pwa-kit/sdk";

// Subscribe to push notifications
const subscription = await push.subscribe();
console.log("Token:", subscription.token);
console.log("Endpoint:", subscription.endpoint); // apns://token

// Get existing subscription
const existing = await push.getSubscription();
if (existing) {
  console.log("Already subscribed");
}

// Check permission state
const state = await push.permissionState();
// 'granted' | 'denied' | 'prompt'
```

### Badging (Badging API)

```typescript
import { badging } from "@pwa-kit/sdk";

// Set badge count
await badging.setAppBadge(5);

// Clear badge
await badging.clearAppBadge();
```

### Vibration (Vibration API)

```typescript
import { vibration } from "@pwa-kit/sdk";

// Vibrate (triggers haptic on iOS)
await vibration.vibrate(100);
await vibration.vibrate([100, 50, 100]); // Pattern
```

### Clipboard (Clipboard API)

```typescript
import { clipboard } from "@pwa-kit/sdk";

// Write text
await clipboard.writeText("Hello, World!");

// Read text
const text = await clipboard.readText();
```

### Share (Web Share API)

```typescript
import { share } from "@pwa-kit/sdk";

// Share URL
await share.share({
  title: "Check this out",
  url: "https://example.com",
});

// Share with files
await share.share({
  title: "Document",
  files: [
    {
      name: "report.pdf",
      type: "application/pdf",
      data: "base64encodeddata...",
    },
  ],
});

// Check availability
const canShare = await share.canShare();
```

### Permissions (Permissions API)

```typescript
import { permissions } from "@pwa-kit/sdk";

// Query permission state
const status = await permissions.query({ name: "camera" });
console.log("Camera:", status.state); // 'granted' | 'denied' | 'prompt'

// Request permission
const result = await permissions.request({ name: "geolocation" });

// Supported permissions: 'camera', 'geolocation', 'microphone'
```

## Enhanced APIs

### Haptics

Native iOS haptic feedback with impact, notification, and selection patterns.

```typescript
import { haptics } from "@pwa-kit/sdk";

// Impact feedback
await haptics.impact("light"); // light, medium, heavy, soft, rigid
await haptics.impact("medium");
await haptics.impact("heavy");

// Notification feedback
await haptics.notification("success"); // success, warning, error
await haptics.notification("error");

// Selection feedback
await haptics.selection();
```

### Print

AirPrint support for the current page.

```typescript
import { print } from "@pwa-kit/sdk";

const result = await print.print();
if (result.success) {
  console.log("Print job submitted");
}
```

### Platform

Platform detection and device information.

```typescript
import { platform } from "@pwa-kit/sdk";

const info = await platform.getInfo();
// {
//   platform: 'ios',
//   version: '17.0',
//   isNative: true,
//   appVersion: '1.0.0',
//   buildNumber: '42',
//   deviceModel: 'iPhone15,2'
// }
```

## iOS-Specific Modules

These modules are namespaced under `ios.*` as they don't have web equivalents.

### ios.biometrics

Face ID and Touch ID authentication.

```typescript
import { ios } from "@pwa-kit/sdk";

// Check availability
const availability = await ios.biometrics.isAvailable();
// { available: true, biometryType: 'faceId' }

// Authenticate
const result = await ios.biometrics.authenticate("Confirm your identity");
if (result.success) {
  // Authentication successful
}
```

### ios.secureStorage

Keychain-backed secure storage that persists across app reinstalls.

```typescript
import { ios } from "@pwa-kit/sdk";

// Store value
await ios.secureStorage.set("auth_token", "secret123");

// Retrieve value
const token = await ios.secureStorage.get("auth_token");

// Check if key exists
const exists = await ios.secureStorage.has("auth_token");

// Delete value
await ios.secureStorage.delete("auth_token");
```

### ios.healthKit

Access health and fitness data via Apple HealthKit.

```typescript
import { ios } from "@pwa-kit/sdk";

// Check availability
const { available } = await ios.healthKit.isAvailable();

// Request authorization
const auth = await ios.healthKit.requestAuthorization({
  read: ["stepCount", "heartRate"],
  readWorkouts: true,
  readSleep: true,
});

// Query steps
const steps = await ios.healthKit.querySteps({
  startDate: "2024-01-01T00:00:00Z",
  endDate: "2024-01-31T23:59:59Z",
});

// Query heart rate
const heartRate = await ios.healthKit.queryHeartRate({
  startDate: "2024-01-01T00:00:00Z",
  endDate: "2024-01-31T23:59:59Z",
});

// Query workouts
const workouts = await ios.healthKit.queryWorkouts({
  startDate: "2024-01-01T00:00:00Z",
  endDate: "2024-01-31T23:59:59Z",
  limit: 10,
});

// Query sleep
const sleep = await ios.healthKit.querySleep({
  startDate: "2024-01-01T00:00:00Z",
  endDate: "2024-01-31T23:59:59Z",
});

// Save workout
await ios.healthKit.saveWorkout({
  activityType: "running",
  startDate: "2024-01-15T08:00:00Z",
  endDate: "2024-01-15T08:30:00Z",
  duration: 1800,
  totalEnergyBurned: 350,
  totalDistance: 5000,
});
```

### ios.storeKit

In-app purchases via StoreKit 2.

```typescript
import { ios } from "@pwa-kit/sdk";

// Get products
const products = await ios.storeKit.getProducts(["premium", "coins_100"]);
for (const product of products) {
  console.log(`${product.displayName}: ${product.displayPrice}`);
}

// Purchase
const result = await ios.storeKit.purchase("premium");
if (result.success) {
  console.log("Transaction ID:", result.transactionId);
}

// Restore purchases
await ios.storeKit.restore();

// Get entitlements
const entitlements = await ios.storeKit.getEntitlements();
console.log("Owned:", entitlements.ownedProductIds);

// Check ownership
const hasPremium = await ios.storeKit.isOwned("premium");
```

### ios.app

App lifecycle and utilities.

```typescript
import { ios } from "@pwa-kit/sdk";

// Get app version
const version = await ios.app.getVersion();
// { version: '1.0.0', build: '42' }

// Request App Store review
await ios.app.requestReview();

// Open app settings
await ios.app.openSettings();
```

### ios.notifications

Local notification scheduling. Schedule one-off or recurring notifications that fire even when the app is in the background.

```typescript
import { ios } from "@pwa-kit/sdk";

// Schedule a notification in 60 seconds
await ios.notifications.schedule({
  id: "reminder-123",
  title: "Time for a break",
  body: "You have been working for an hour",
  trigger: { type: "timeInterval", seconds: 60 },
});

// Schedule a repeating notification (minimum 60 seconds)
await ios.notifications.schedule({
  id: "hourly",
  title: "Hourly check-in",
  trigger: { type: "timeInterval", seconds: 3600, repeats: true },
});

// Schedule at a specific date
await ios.notifications.schedule({
  id: "meeting",
  title: "Meeting starts",
  body: "Project sync in conference room A",
  trigger: { type: "date", date: new Date("2024-12-25T10:00:00") },
});

// Schedule a daily recurring notification (9 AM)
await ios.notifications.schedule({
  id: "daily-reminder",
  title: "Good morning!",
  body: "Start your day with a review",
  trigger: { type: "calendar", hour: 9, minute: 0, repeats: true },
});

// Include badge, sound, and custom data
await ios.notifications.schedule({
  id: "full-example",
  title: "New message",
  body: "You have a new message",
  subtitle: "From John",
  badge: 1,
  sound: "default",
  data: { messageId: "123", senderId: "john" },
  trigger: { type: "timeInterval", seconds: 5 },
});

// Cancel a specific notification
await ios.notifications.cancel("reminder-123");

// Cancel all scheduled notifications
await ios.notifications.cancelAll();

// Get all pending notifications
const pending = await ios.notifications.getPending();
for (const notification of pending) {
  console.log(`${notification.id}: ${notification.title}`);
  if (notification.nextTriggerDate) {
    console.log(`  Next: ${notification.nextTriggerDate}`);
  }
}
```

**Trigger Types:**

| Type           | Description                | Example                                                   |
| -------------- | -------------------------- | --------------------------------------------------------- |
| `timeInterval` | Fire after N seconds       | `{ type: 'timeInterval', seconds: 60, repeats: false }`   |
| `date`         | Fire at specific date/time | `{ type: 'date', date: new Date('2024-12-25T10:00:00') }` |
| `calendar`     | Fire on calendar match     | `{ type: 'calendar', hour: 9, minute: 0, repeats: true }` |

**Calendar Trigger Components:**

- `hour` (0-23), `minute` (0-59), `second` (0-59)
- `weekday` (1=Sunday, 7=Saturday)
- `day` (1-31), `month` (1-12), `year`

**Note:** iOS limits apps to 64 scheduled local notifications. Use `getPending()` to monitor your notification count.

## Detection Utilities

```typescript
import {
  isNative,
  getPlatformInfo,
  hasMessageHandlers,
} from "@pwa-kit/sdk";

// Quick check if running in native app
if (isNative) {
  // Use native features
}

// Full platform info
const info = getPlatformInfo();
// {
//   isNative: true,
//   hasMessageHandlers: true,
//   hasPWAKitUserAgent: true,
//   platform: 'ios',
//   userAgent: '...'
// }

// Check for webkit message handlers
if (hasMessageHandlers()) {
  // Bridge is available
}
```

## Bridge API

For advanced usage, access the bridge directly.

```typescript
import { bridge } from "@pwa-kit/sdk";

// Call any native module
const response = await bridge.call("myModule", "myAction", { key: "value" });

// Listen to native events
window.addEventListener("pwa:push", (event) => {
  console.log("Push notification:", event.detail);
});

window.addEventListener("pwa:lifecycle", (event) => {
  console.log("Lifecycle event:", event.detail);
});
```

## Custom Modules

You can extend PWAKit by creating your own native Swift modules that can be called from JavaScript.

### Quick Example

**Swift Module:**

```swift
public struct MyModule: PWAModule {
    public static let moduleName = "myModule"
    public static let supportedActions = ["doSomething"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "doSomething":
            let value = payload?["value"]?.stringValue ?? "default"
            return AnyCodable([
                "result": AnyCodable("Processed: \(value)")
            ])
        default:
            throw BridgeError.unknownAction(action)
        }
    }
}
```

**JavaScript Usage:**

```typescript
import { bridge } from "@pwa-kit/sdk";

const result = await bridge.call("myModule", "doSomething", { value: "test" });
console.log(result.result); // "Processed: test"
```

See the [Custom Modules Guide](../docs/custom-modules.md) for complete documentation including:

- The `PWAModule` protocol
- Registration and feature flags
- Working with UIKit and @MainActor
- Error handling patterns
- Complete Hello World example

## TypeScript

Full TypeScript support with type definitions for all modules.

```typescript
import type {
  // Push types
  PushSubscription,
  PushPermissionState,
  // Permission types
  PermissionName,
  PermissionState,
  PermissionStatus,
  // iOS types
  BiometryType,
  BiometricAvailability,
  AuthenticationResult,
  ProductInfo,
  PurchaseResult,
  HealthSample,
  WorkoutData,
  // Local notification types
  NotificationOptions,
  NotificationTrigger,
  TimeIntervalTrigger,
  DateTrigger,
  CalendarTrigger,
  PendingNotification,
  // Platform types
  PlatformInfo,
  PlatformDetectionInfo,
} from "@pwa-kit/sdk";
```

## Browser Compatibility

The SDK safely handles non-native environments:

```typescript
import { isNative, push, haptics } from "@pwa-kit/sdk";

if (isNative) {
  // Running in PWAKit native app
  await push.subscribe();
  await haptics.impact("medium");
} else {
  // Running in browser - provide fallbacks
  console.log("Native features unavailable");
  // Use web APIs or graceful degradation
}
```

## License

MIT
