# Architecture

PWAKit has three components in the upstream project:

- iOS runtime (Swift + SwiftUI)
- TypeScript SDK (`@pwa-kit/sdk`)
- Setup/sync CLI (`@pwa-kit/cli`)

In generated app projects, iOS source lives under `src/`.

## Runtime data flow

1. Your PWA runs in `WKWebView`.
2. JavaScript sends bridge requests (`module`, `action`, `payload`).
3. `BridgeDispatcher` routes request to a native module.
4. Module returns data/error.
5. SDK resolves/rejects promise in JavaScript.

## Core native pieces

| Component | Responsibility |
| --- | --- |
| `BridgeDispatcher` | Parses + routes bridge messages |
| `ModuleRegistry` | Stores module registrations by name |
| `PWAModule` protocol | Native module contract |
| Configuration store/loader | Validated runtime config |

## Concurrency model

PWAKit uses Swift 6 strict concurrency:

- Actors for shared mutable state
- `Sendable` constraints for module safety
- `@MainActor` for UIKit-bound operations

## Key source paths (generated template)

- `src/PWAKitCore/Bridge/`
- `src/PWAKitCore/Modules/`
- `src/PWAKitCore/Configuration/`
- `src/PWAKit/Views/`
