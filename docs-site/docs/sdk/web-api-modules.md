# Web API Modules

These modules are aligned to browser APIs where possible.

## Push (`push`)

| Method | Returns |
| --- | --- |
| `subscribe()` | `Promise<{ token: string; endpoint: string }>` |
| `getSubscription()` | `Promise<PushSubscription \| null>` |
| `requestPermission()` | `Promise<'granted' \| 'denied' \| 'prompt'>` |
| `permissionState()` | `Promise<'granted' \| 'denied' \| 'prompt'>` |

`subscribe()` does not take browser-style options (for example `applicationServerKey`).

```ts
import { push } from "@pwa-kit/sdk";

const state = await push.permissionState();
if (state === "prompt") {
  await push.requestPermission();
}

const sub = await push.subscribe();
console.log(sub.token, sub.endpoint);
```

## Badging (`badging`)

| Method | Returns |
| --- | --- |
| `setAppBadge(count?)` | `Promise<void>` |
| `clearAppBadge()` | `Promise<void>` |

## Vibration (`vibration`)

| Method | Returns |
| --- | --- |
| `vibrate(pattern?)` | `boolean` |

`pattern` can be `number` or `number[]`.

```ts
import { vibration } from "@pwa-kit/sdk";

vibration.vibrate(100);
vibration.vibrate([100, 50, 100]);
```

## Clipboard (`clipboard`)

| Method | Returns |
| --- | --- |
| `writeText(text)` | `Promise<void>` |
| `readText()` | `Promise<string \| null>` |

## Share (`share`)

| Method | Returns |
| --- | --- |
| `share(options)` | `Promise<{ completed: boolean; activityType?: string }>` |
| `canShare()` | `Promise<boolean>` |

`options.files` uses `{ name, type, data }` where `data` is base64.

## Permissions (`permissions`)

Supported names: `camera`, `microphone`, `geolocation`.

| Method | Returns |
| --- | --- |
| `query({ name })` | `Promise<{ name; state }>` |
| `request({ name })` | `Promise<{ name; state }>` |

`state` maps to: `granted`, `denied`, `prompt`.

## Alignment and intentional deviations

### Alignment matrix

| SDK module | Web standard | Alignment |
| --- | --- | --- |
| `push` | PushManager | `subscribe()`, `getSubscription()`, `permissionState()` model |
| `badging` | Badging API | `setAppBadge()`, `clearAppBadge()` |
| `vibration` | Vibration API | `vibrate(pattern)` signature and boolean return |
| `clipboard` | Clipboard API | `writeText()`, `readText()` text-only subset |
| `share` | Web Share API | `share()`, `canShare()` style |
| `permissions` | Permissions API | `query()` model with native permission mapping |

### Intentional deviations

| Area | Behavior in PWAKit SDK | Why |
| --- | --- | --- |
| `push.subscribe(options)` | No options argument | APNs-native flow does not use VAPID/app server key input |
| `permissions.request()` | Exists as a first-class method | Native pre-prompt flow before web API use |
| `share.canShare(data)` | No data argument; async `Promise<boolean>` | Bridge checks native capability, not per-payload sync validation |
| `share.share()` | Returns `{ completed, activityType? }` | Exposes native share-sheet result detail |
| `clipboard.readText()` | Returns `string \| null` | Empty clipboard maps to `null` |
| Push endpoint | Returns `apns://<token>` | Keeps PushSubscription-like shape from APNs token |
| `badging.setAppBadge()` | Omitted count maps to `0` | iOS native bridge uses badge count semantics |
| Vibration implementation | Triggers haptics under the hood | iOS Safari does not support Web Vibration API |
| `vibration.vibrate()` return | Always returns `true` | Implemented as fire-and-forget haptic polyfill |
| `vibration.vibrate(0)` stop behavior | No active vibration state to stop | iOS implementation treats stop as successful no-op |

Push and permissions states are normalized to `granted`, `denied`, and `prompt`.
