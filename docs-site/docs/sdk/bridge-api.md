# Bridge API

`bridge` and `PWABridge` are the low-level transport for native module calls.

## Core methods

| Method | Description |
| --- | --- |
| `isAvailable()` | Checks `window.webkit.messageHandlers.pwakit` |
| `initialize()` | Installs `window.pwakit._handleResponse/_handleEvent` handlers |
| `call(module, action, payload?, options?)` | Sends request to native and resolves with response data |
| `on(type, listener)` | Subscribes to `pwa:<type>` CustomEvents |
| `once(type, listener)` | One-time event listener |

## Basic call

```ts
import { bridge } from "@pwa-kit/sdk";

const result = await bridge.call<{ message: string }>(
  "helloWorld",
  "greet",
  { name: "Taylor" }
);
```

## Timeout control

Default timeout is `30000` ms.

```ts
await bridge.call(
  "healthkit",
  "queryStepCount",
  {
    startDate: "2026-03-01T00:00:00Z",
    endDate: "2026-03-02T00:00:00Z"
  },
  { timeout: 45000 }
);
```

## Message and response shape

```ts
interface BridgeMessage {
  id: string;
  module: string;
  action: string;
  payload?: unknown;
}

interface BridgeResponse<T = unknown> {
  id: string;
  success: boolean;
  data?: T;
  error?: string;
}
```

## Events

Native events are dispatched as browser events with `pwa:` prefix.

```ts
import { bridge } from "@pwa-kit/sdk";

const unsubscribe = bridge.on<{ title?: string }>("push", (data) => {
  console.log(data.title);
});

// Later
unsubscribe();
```

Equivalent direct listener:

```ts
window.addEventListener("pwa:push", (event) => {
  console.log((event as CustomEvent).detail);
});
```

## Error types

- `BridgeUnavailableError`: bridge not present
- `BridgeTimeoutError`: call exceeded timeout
- `BridgeError`: native returned an error (or send failed)

See [Error Handling](/sdk/errors) for patterns.
