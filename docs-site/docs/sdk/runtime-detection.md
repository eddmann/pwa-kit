# Runtime Detection

Use these exports to decide when bridge calls should run, and how to deliver the SDK in browser contexts.

## Detection exports

| Export | Type | Notes |
| --- | --- | --- |
| `isNative` | boolean | Computed once at module load |
| `platformInfo` | object | Snapshot at module load |
| `hasMessageHandlers()` | function | Checks `window.webkit.messageHandlers.pwakit` |
| `hasPWAKitInUserAgent()` | function | Checks `PWAKit` in user agent |
| `detectPlatform()` | function | Returns `ios`, `browser`, or `unknown` |
| `getPlatformInfo()` | function | Re-evaluates full detection result |

## Recommendation

For dynamic checks, prefer `getPlatformInfo()` rather than relying only on `isNative`.

## Runtime behavior

| Environment | Detection | Bridge calls |
| --- | --- | --- |
| PWAKit iOS shell | `getPlatformInfo().isNative === true` | Available |
| Regular browser | usually `isNative === false` | Reject with `BridgeUnavailableError` |
| SSR/Node | `window` absent | Not available |

## Browser bundle (no bundler)

Use the IIFE bundle when you want script-tag usage:

```html
<script src="https://cdn.jsdelivr.net/npm/@pwa-kit/sdk@latest/dist/index.global.js"></script>
<script>
  const { isNative, push } = PWAKit;
  if (isNative) {
    push.subscribe();
  }
</script>
```

The global variable is `window.PWAKit`.

## Bridge events

`PWABridge` dispatches native events as browser `CustomEvent`s with `pwa:` prefix.

### Subscribe

```ts
import { bridge } from "@pwa-kit/sdk";

const unsubscribe = bridge.on("push", (data) => {
  console.log("Push payload", data);
});

// Later
unsubscribe();
```

### One-time listener

```ts
bridge.once("push", (data) => {
  console.log("First push only", data);
});
```

## Bridge call options

`bridge.call(module, action, payload, options)` supports:

- `options.timeout` (ms)

Default timeout is 30000 ms.

## Fallback pattern

```ts
import { BridgeUnavailableError, getPlatformInfo, ios } from "@pwa-kit/sdk";

export async function authenticateIfNative(): Promise<boolean> {
  if (!getPlatformInfo().isNative) return false;

  try {
    const result = await ios.biometrics.authenticate("Continue");
    return result.success;
  } catch (error) {
    if (error instanceof BridgeUnavailableError) return false;
    throw error;
  }
}
```
