# Custom Module SDK Integration

Use this page after you add a custom Swift module.

Related native setup: [Custom Native Modules](/core/custom-modules)

## 1) Start with a direct bridge call

`bridge.call<T>(module, action, payload)` is the lowest-level SDK API.

```ts
import { bridge } from "@pwa-kit/sdk";

const response = await bridge.call<{ message: string; appName: string }>(
  "helloWorld",
  "greet",
  { name: "Taylor" }
);
```

Module and action names must match your Swift module:

- `module`: `HelloWorldModule.moduleName`
- `action`: one item in `HelloWorldModule.supportedActions`

## 2) Build a typed wrapper (recommended)

Create a local wrapper in your web app, for example `src/native/helloWorld.ts`:

```ts
import { bridge } from "@pwa-kit/sdk";

export interface HelloWorldResult {
  message: string;
  appName: string;
}

export const helloWorld = {
  async greet(name: string): Promise<HelloWorldResult> {
    return bridge.call<HelloWorldResult>("helloWorld", "greet", { name });
  },
};
```

This keeps raw module/action strings in one place.

## 3) Add runtime-safe usage

```ts
import { getPlatformInfo } from "@pwa-kit/sdk";
import { helloWorld } from "./native/helloWorld";

export async function greetUser(name: string): Promise<string> {
  if (!getPlatformInfo().isNative) {
    return `Hello, ${name}!`;
  }

  const result = await helloWorld.greet(name);
  return result.message;
}
```

## 4) Handle bridge errors explicitly

```ts
import {
  BridgeError,
  BridgeTimeoutError,
  BridgeUnavailableError,
} from "@pwa-kit/sdk";

try {
  await helloWorld.greet("Taylor");
} catch (error) {
  if (error instanceof BridgeUnavailableError) {
    // Browser environment, not native shell
  } else if (error instanceof BridgeTimeoutError) {
    // Native action did not return in time
  } else if (error instanceof BridgeError) {
    // Native module threw an error (for example invalid payload)
    console.error(error.message);
  } else {
    throw error;
  }
}
```

## 5) Optional event integration

If your Swift module dispatches an event with `JavaScriptBridge.formatEvent(type:data)`,
listen in JavaScript with `bridge.on(type, listener)`.

```ts
import { bridge } from "@pwa-kit/sdk";

const unsubscribe = bridge.on<{ status: string }>("helloWorldStatus", (data) => {
  console.log(data.status);
});

// Later:
unsubscribe();
```
