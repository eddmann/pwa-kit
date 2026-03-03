# Custom Native Modules

Use this when built-in modules do not cover a native capability you need.

## 1) Create a module in `src/PWAKitCore/Modules/`

Add a new Swift file under `src/PWAKitCore/Modules/Custom/` and implement `PWAModule`.

```swift
import Foundation

public struct HelloWorldModule: PWAModule {
    public static let moduleName = "helloWorld"
    public static let supportedActions = ["greet"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "greet":
            guard let name = payload?["name"]?.stringValue, !name.isEmpty else {
                throw BridgeError.invalidPayload("Expected non-empty 'name'")
            }

            return AnyCodable([
                "message": AnyCodable("Hello, \(name)!"),
                "appName": AnyCodable(context.configuration.app.name),
            ])
        default:
            throw BridgeError.unknownAction(action)
        }
    }
}
```

### Why this shape

- `moduleName` routes calls (`bridge.call(module, action, payload)`).
- `supportedActions` is enforced by dispatcher validation.
- `validateAction(action)` gives consistent unknown-action behavior.
- `AnyCodable` is the bridge payload/response type.

## 2) Register the module during app bootstrap

Register custom modules in `src/PWAKit/App/PWAKitApp.swift` after default module registration in `initializeApp()`.

```swift
let count = await ModuleRegistration.registerDefaultModules(
    in: dispatcher,
    features: config.features
)

_ = await dispatcher.register(HelloWorldModule(), allowOverwrite: false)
```

If you also use the fallback branch (`registerDefaultModules(in: dispatcher)`), register your custom module there too.

## 3) Call it from JavaScript

```ts
import { bridge } from "@pwa-kit/sdk";

const result = await bridge.call<{ message: string; appName: string }>(
  "helloWorld",
  "greet",
  { name: "Team" }
);

console.log(result.message, result.appName);
```

## 4) Optional conditional registration

`BridgeDispatcher` supports condition-based registration:

```swift
_ = await dispatcher.register(
    HelloWorldModule(),
    if: ProcessInfo.processInfo.environment["ENABLE_HELLO_WORLD"] == "1",
    allowOverwrite: false
)
```

## 5) Optional event push back to JavaScript

For unsolicited events, use `JavaScriptBridge.formatEvent` and `pwa:<type>` listeners.

See [Custom Module SDK Integration](/sdk/custom-modules).

## Design checklist

- Keep actions small and explicit.
- Validate payload fields and throw `BridgeError.invalidPayload`.
- Throw `BridgeError.unknownAction` for unsupported actions.
- Keep modules `Sendable` and concurrency-safe.
- Use `ModuleContext` for configuration and UI/webview access.
