# Error Handling

Bridge calls fail in predictable ways. Handle these explicitly.

## Error types

| Type | Meaning |
| --- | --- |
| `BridgeUnavailableError` | Not running in PWAKit native wrapper |
| `BridgeTimeoutError` | Call exceeded timeout (default 30000 ms) |
| `BridgeError` | Native returned an error or send failed |

## Common failure patterns

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `BridgeUnavailableError` | Running in normal browser | Guard with runtime detection |
| `BridgeTimeoutError` | Native action stalled | Increase timeout and inspect native logs |
| `module not available` | Feature flag disabled | Enable feature and sync config |
| Permission-related error | Missing iOS usage key or denied permission | Update Info.plist, retry permission flow |

## Pattern: explicit runtime guard

```ts
import { getPlatformInfo, ios } from "@pwa-kit/sdk";

export async function authenticateOrThrow() {
  const env = getPlatformInfo();
  if (!env.isNative) {
    throw new Error("PWAKit native runtime required");
  }

  return ios.biometrics.authenticate("Continue");
}
```

## Pattern: custom timeout

```ts
import { bridge } from "@pwa-kit/sdk";

await bridge.call("healthkit", "queryStepCount", {
  startDate: "2026-03-01T00:00:00Z",
  endDate: "2026-03-02T00:00:00Z"
}, {
  timeout: 45000
});
```

## Debug checklist

1. Confirm native runtime (`getPlatformInfo().isNative`).
2. Confirm config feature flag is enabled.
3. Run `npx @pwa-kit/cli sync --validate`.
4. Rebuild and reproduce.
5. Inspect simulator or device logs.
