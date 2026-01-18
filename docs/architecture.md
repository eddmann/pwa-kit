# PWAKit Architecture

This document explains the internal architecture of PWAKit, including the bridge system, module registry, and message flow.

## Overview

PWAKit uses a layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                        PWAKit App                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    SwiftUI App                         │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐  │  │
│  │  │ ContentView │ │ LoadingView │ │ ErrorView       │  │  │
│  │  └──────┬──────┘ └─────────────┘ └─────────────────┘  │  │
│  │         │                                              │  │
│  │  ┌──────▼──────────────────────────────────────────┐  │  │
│  │  │              WebViewContainer                    │  │  │
│  │  │  ┌────────────────────────────────────────────┐ │  │  │
│  │  │  │                WKWebView                    │ │  │  │
│  │  │  └────────────────────────────────────────────┘ │  │  │
│  │  └─────────────────────────┬──────────────────────┘  │  │
│  └────────────────────────────│─────────────────────────┘  │
│                               │                             │
│  ┌────────────────────────────▼────────────────────────┐   │
│  │                   PWAKitCore                         │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │              BridgeDispatcher                   │ │   │
│  │  └───────────────────────┬────────────────────────┘ │   │
│  │                          │                           │   │
│  │  ┌───────────────────────▼───────────────────────┐  │   │
│  │  │              ModuleRegistry                    │  │   │
│  │  │ ┌─────────┐ ┌─────────┐ ┌─────────┐          │  │   │
│  │  │ │Platform │ │Haptics  │ │  Push   │ ...      │  │   │
│  │  │ └─────────┘ └─────────┘ └─────────┘          │  │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### BridgeDispatcher (Actor)

The `BridgeDispatcher` is the central routing hub implemented as a Swift actor for thread-safe message handling. It:

- Receives JSON messages from JavaScript
- Parses and validates message format
- Routes to the appropriate module
- Returns responses back to JavaScript

**Location:** `src/PWAKitCore/Bridge/BridgeDispatcher.swift`

### ModuleRegistry

Thread-safe registry for looking up modules by name. Each module registers itself with a unique name (e.g., "haptics", "biometrics").

**Location:** `src/PWAKitCore/Bridge/ModuleRegistry.swift`

### PWAModule Protocol

All native modules implement this protocol:

```swift
public protocol PWAModule: Sendable {
    static var moduleName: String { get }
    static var supportedActions: [String] { get }

    func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable?
}
```

**Location:** `src/PWAKitCore/Modules/PWAModule.swift`

## Bridge Protocol

### JavaScript → Swift

Messages are sent via WebKit message handlers:

```javascript
window.webkit.messageHandlers.pwakit.postMessage({
  id: "uuid-string",
  module: "haptics",
  action: "impact",
  payload: { style: "medium" }
});
```

### Swift → JavaScript

Responses are sent back via JavaScript evaluation:

```javascript
// Success response
window.pwakit._handleResponse({
  id: "uuid-string",
  success: true,
  data: { triggered: true }
});

// Error response
window.pwakit._handleResponse({
  id: "uuid-string",
  success: false,
  error: "Unknown action"
});

// Event dispatch (unsolicited)
window.pwakit._handleEvent({
  type: "push",
  data: { title: "New Message", body: "..." }
});
```

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

1. JavaScript calls `bridge.call('moduleName', 'action', payload)`
2. SDK sends JSON message via `webkit.messageHandlers.pwakit`
3. `BridgeScriptMessageHandler` receives the message
4. `BridgeDispatcher` parses and routes to the module
5. Module processes the action and returns `AnyCodable`
6. Response is JSON-encoded and sent back via JavaScript evaluation
7. SDK resolves the promise with the response data

## Configuration Flow

```
pwa-config.json (source of truth)
           │
           ▼
ConfigurationLoader (parses JSON)
           │
           ▼
ConfigurationValidator (validates schema)
           │
           ▼
ConfigurationStore (actor, immutable)
           │
           ├─► Info.plist (synced via sync-config.sh)
           └─► ModuleRegistration (feature flags)
```

## Module Registration

At app startup, `ModuleRegistration.registerDefaultModules()`:

1. Checks feature flags from configuration
2. Conditionally registers each module
3. Only enabled modules are available to JavaScript

Disabled modules return "module not available" errors.

## Thread Safety

PWAKit uses Swift 6's strict concurrency model:

- **Actors** for shared mutable state (`BridgeDispatcher`, `ConfigurationStore`)
- **Sendable** constraint on all modules
- **@MainActor** for UIKit operations
- No race conditions by design

## Key Files

| Component | Location |
|-----------|----------|
| App Entry | `src/PWAKit/App/PWAKitApp.swift` |
| WebView Container | `src/PWAKit/Views/WebViewContainer.swift` |
| Bridge Dispatcher | `src/PWAKitCore/Bridge/BridgeDispatcher.swift` |
| Module Registry | `src/PWAKitCore/Bridge/ModuleRegistry.swift` |
| Module Protocol | `src/PWAKitCore/Modules/PWAModule.swift` |
| Module Registration | `src/PWAKitCore/Modules/ModuleRegistration.swift` |
| Configuration Loader | `src/PWAKitCore/Configuration/ConfigurationLoader.swift` |
