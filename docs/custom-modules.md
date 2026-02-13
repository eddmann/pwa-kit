# Creating Custom Bridge Modules

This guide explains how to extend PWAKit by creating your own native bridge modules that can be called from JavaScript.

## Overview

PWAKit uses a protocol-based module system where each native capability is encapsulated in a module. Modules:

- Have a unique name for routing messages from JavaScript
- Declare their supported actions
- Handle incoming requests asynchronously
- Return results or throw errors back to JavaScript

## The PWAModule Protocol

Every custom module must conform to the `PWAModule` protocol:

```swift
public protocol PWAModule: Sendable {
    /// Unique name for routing (e.g., "myModule")
    static var moduleName: String { get }

    /// List of supported actions (e.g., ["action1", "action2"])
    static var supportedActions: [String] { get }

    /// Handle incoming requests from JavaScript
    func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable?
}
```

### Key Requirements

1. **Sendable**: Modules must be thread-safe for concurrent access
2. **moduleName**: Unique identifier used in JavaScript to target this module
3. **supportedActions**: Array of action names this module responds to
4. **handle()**: Async method that processes requests and returns results

## Hello World Example

### Swift Module

Create a new file `kit/src/PWAKitCore/Modules/HelloWorld/HelloWorldModule.swift`:

```swift
import Foundation

/// A simple example module demonstrating the PWAModule protocol.
public struct HelloWorldModule: PWAModule {
    // MARK: - PWAModule

    public static let moduleName = "helloWorld"
    public static let supportedActions = ["greet", "echo", "add"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        // Validate the action is supported
        try validateAction(action)

        switch action {
        case "greet":
            return handleGreet(payload: payload)

        case "echo":
            return try handleEcho(payload: payload)

        case "add":
            return try handleAdd(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Action Handlers

    private func handleGreet(payload: AnyCodable?) -> AnyCodable {
        let name = payload?["name"]?.stringValue ?? "World"
        return AnyCodable([
            "message": AnyCodable("Hello, \(name)!"),
            "timestamp": AnyCodable(Date().timeIntervalSince1970)
        ])
    }

    private func handleEcho(payload: AnyCodable?) throws -> AnyCodable {
        guard let text = payload?["text"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'text' field")
        }
        return AnyCodable([
            "echoed": AnyCodable(text),
            "length": AnyCodable(text.count)
        ])
    }

    private func handleAdd(payload: AnyCodable?) throws -> AnyCodable {
        guard let a = payload?["a"]?.doubleValue,
              let b = payload?["b"]?.doubleValue else {
            throw BridgeError.invalidPayload("Missing required 'a' and 'b' fields")
        }
        return AnyCodable([
            "result": AnyCodable(a + b)
        ])
    }
}
```

### JavaScript Usage

```javascript
import { bridge } from "@pwa-kit/sdk";

// Simple greeting
const greeting = await bridge.call("helloWorld", "greet", {
  name: "Developer",
});
console.log(greeting.message); // "Hello, Developer!"
console.log(greeting.timestamp); // 1704067200.0

// Echo with validation
const echo = await bridge.call("helloWorld", "echo", { text: "Testing 123" });
console.log(echo.echoed); // "Testing 123"
console.log(echo.length); // 11

// Math operation
const sum = await bridge.call("helloWorld", "add", { a: 5, b: 3 });
console.log(sum.result); // 8

// Error handling
try {
  await bridge.call("helloWorld", "echo", {}); // Missing 'text'
} catch (error) {
  console.error(error.message); // "Invalid payload: Missing required 'text' field"
}
```

## Registering Your Module

### Option 1: Add to ModuleRegistration (Recommended)

Edit `kit/src/PWAKitCore/Modules/ModuleRegistration.swift`:

```swift
// In registerDefaultModules(in:features:)

// Add your module (always enabled)
await dispatcher.register(HelloWorldModule())
count += 1

// Or conditionally based on a feature flag
if features.myFeature {
    await dispatcher.register(HelloWorldModule())
    count += 1
}
```

### Option 2: Register Directly

In your app initialization code:

```swift
import PWAKitCore

let dispatcher = BridgeDispatcher()

// Register default modules
await ModuleRegistration.registerDefaultModules(
    in: dispatcher,
    features: configuration.features
)

// Register your custom module
await dispatcher.register(HelloWorldModule())
```

## Working with UIKit

For modules that need UI presentation (sheets, alerts, etc.), use the `ModuleContext`:

```swift
public struct MyUIModule: PWAModule {
    public static let moduleName = "myUI"
    public static let supportedActions = ["showAlert"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "showAlert":
            return try await showAlert(payload: payload, context: context)
        default:
            throw BridgeError.unknownAction(action)
        }
    }

    private func showAlert(
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable {
        // Get the view controller from context (requires @MainActor)
        guard let viewController = await context.viewController as? UIViewController else {
            throw BridgeError.invalidPayload("No view controller available")
        }

        let title = payload?["title"]?.stringValue ?? "Alert"
        let message = payload?["message"]?.stringValue

        // UI work must be on main actor
        return await MainActor.run {
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)

            return AnyCodable(["presented": AnyCodable(true)])
        }
    }
}
```

## Working with Haptics and UIKit APIs

Use `@MainActor` for any UIKit calls:

```swift
public struct MyHapticsModule: PWAModule {
    public static let moduleName = "myHaptics"
    public static let supportedActions = ["vibrate"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "vibrate":
            await triggerHaptic()
            return AnyCodable(["triggered": AnyCodable(true)])
        default:
            throw BridgeError.unknownAction(action)
        }
    }

    @MainActor
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
}
```

## Error Handling

Use `BridgeError` for standard errors:

```swift
// Module not found (handled by dispatcher)
throw BridgeError.unknownModule("widgets")

// Action not supported
throw BridgeError.unknownAction("invalidAction")

// Payload validation failed
throw BridgeError.invalidPayload("Missing required 'userId' field")

// Wrap other errors
do {
    try someOperation()
} catch {
    throw BridgeError.moduleError(underlying: error)
}
```

Errors are automatically returned to JavaScript as error responses:

```javascript
try {
  await bridge.call("myModule", "action", {});
} catch (error) {
  // error.message contains the localized error description
}
```

## Accessing Configuration

Check feature flags or app settings via `ModuleContext`:

```swift
public func handle(
    action: String,
    payload: AnyCodable?,
    context: ModuleContext
) async throws -> AnyCodable? {
    // Check if a feature is enabled
    guard context.configuration.features.myFeature else {
        throw BridgeError.invalidPayload("Feature not enabled")
    }

    // Access app configuration
    let appName = context.configuration.app.name
    let bundleId = context.configuration.app.bundleId

    // ... handle action
}
```

## AnyCodable Usage

`AnyCodable` is a type-erased wrapper for JSON-compatible values:

```swift
// Creating values
let string = AnyCodable("hello")
let number = AnyCodable(42)
let double = AnyCodable(3.14)
let bool = AnyCodable(true)
let null = AnyCodable.null

// Creating objects
let object = AnyCodable([
    "name": AnyCodable("John"),
    "age": AnyCodable(30),
    "active": AnyCodable(true)
])

// Creating arrays
let array = AnyCodable([
    AnyCodable(1),
    AnyCodable(2),
    AnyCodable(3)
])

// Reading values from payload
let name = payload?["name"]?.stringValue       // String?
let count = payload?["count"]?.intValue        // Int?
let price = payload?["price"]?.doubleValue     // Double?
let enabled = payload?["enabled"]?.boolValue   // Bool?
```

## Best Practices

### 1. Keep Modules Focused

Each module should handle a single capability or related set of features.

### 2. Validate Early

Always validate the action and payload at the start of `handle()`:

```swift
public func handle(...) async throws -> AnyCodable? {
    try validateAction(action)  // Use built-in helper

    guard let requiredField = payload?["field"]?.stringValue else {
        throw BridgeError.invalidPayload("Missing 'field'")
    }
    // ... continue
}
```

### 3. Use Async/Await

The module system is fully async. Avoid blocking calls:

```swift
// Good
let data = await fetchData()

// Bad - blocks the thread
let data = semaphore.wait()
```

### 4. Handle Threading Correctly

- Use `@MainActor` for UIKit calls
- Use `await MainActor.run { }` for isolated UI work
- Keep computation off the main thread

### 5. Return Meaningful Results

Include relevant data in responses for debugging and logging:

```swift
return AnyCodable([
    "success": AnyCodable(true),
    "itemCount": AnyCodable(items.count),
    "timestamp": AnyCodable(Date().timeIntervalSince1970)
])
```

### 6. Document Your Module

Add documentation comments explaining:

- What the module does
- What actions it supports
- What payload fields each action expects
- What response data each action returns

## Message Flow

```
JavaScript                     Swift
    │                            │
    │  bridge.call('mod', 'act') │
    │ ─────────────────────────► │
    │                            │  BridgeDispatcher
    │                            │  └─► ModuleRegistry.get("mod")
    │                            │  └─► module.handle("act", payload, context)
    │                            │
    │  { success: true, data }   │
    │ ◄───────────────────────── │
    │                            │
```

## Complete Example Module

See `kit/src/PWAKitCore/Modules/Clipboard/ClipboardModule.swift` for a real-world example showing:

- Action validation
- Payload parsing
- MainActor usage for UIKit (UIPasteboard)
- Proper error handling
- Clean return values
