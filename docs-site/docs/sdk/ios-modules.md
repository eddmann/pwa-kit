# iOS Modules

These APIs are namespaced under `ios.*`.

## Biometrics (`ios.biometrics`)

| Method | Returns |
| --- | --- |
| `isAvailable()` | `Promise<{ available: boolean; biometryType; error? }>` |
| `authenticate(reason)` | `Promise<{ success: boolean; error? }>` |

## Secure Storage (`ios.secureStorage`)

| Method | Returns |
| --- | --- |
| `set(key, value)` | `Promise<void>` |
| `get(key)` | `Promise<string \| null>` |
| `delete(key)` | `Promise<void>` |
| `has(key)` | `Promise<boolean>` |

## HealthKit (`ios.healthKit`)

| Method | Returns |
| --- | --- |
| `isAvailable()` | `Promise<{ available: boolean }>` |
| `requestAuthorization(request)` | `Promise<{ success: boolean; error? }>` |
| `querySteps(options)` | `Promise<HealthSample[]>` |
| `queryStepCount(options)` | `Promise<{ totalSteps: number }>` |
| `queryHeartRate(options)` | `Promise<HealthSample[]>` |
| `queryWorkouts(options)` | `Promise<WorkoutData[]>` |
| `querySleep(options)` | `Promise<SleepSample[]>` |
| `saveWorkout(request)` | `Promise<{ success: boolean; error?: string }>` |

`options` requires `startDate` and `endDate` (ISO 8601).

Example:

```ts
import { ios } from "@pwa-kit/sdk";

const steps = await ios.healthKit.queryStepCount({
  startDate: "2026-03-01T00:00:00Z",
  endDate: "2026-03-02T00:00:00Z"
});
```

## StoreKit (`ios.storeKit`)

| Method | Returns |
| --- | --- |
| `getProducts(productIds)` | `Promise<ProductInfo[]>` |
| `purchase(productId)` | `Promise<PurchaseResult>` |
| `restore()` | `Promise<void>` |
| `getEntitlements()` | `Promise<{ ownedProductIds: string[] }>` |
| `isOwned(productId)` | `Promise<boolean>` |

## App (`ios.app`)

| Method | Returns |
| --- | --- |
| `getVersion()` | `Promise<{ version; build; pwaKitVersion }>` |
| `requestReview()` | `Promise<{ presented: boolean }>` |
| `openSettings()` | `Promise<void>` |

## Local Notifications (`ios.notifications`)

| Method | Returns |
| --- | --- |
| `schedule(options)` | `Promise<string>` (notification id) |
| `cancel(id)` | `Promise<void>` |
| `cancelAll()` | `Promise<void>` |
| `getPending()` | `Promise<PendingNotification[]>` |

`schedule` requires `id`, `title`, and `trigger`.

```ts
await ios.notifications.schedule({
  id: "daily-checkin",
  title: "Daily check-in",
  trigger: {
    type: "calendar",
    hour: 9,
    minute: 0,
    repeats: true
  }
});
```
