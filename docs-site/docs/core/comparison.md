# PWAKit vs Other Approaches

PWAKit is optimized for teams with an existing PWA that want iOS App Store distribution plus native APIs.

## High-level comparison

| Aspect | PWAKit | Capacitor | React Native | Flutter | Native Swift |
| --- | --- | --- | --- | --- | --- |
| Existing web app reuse | Excellent | Excellent | Limited (UI rewrite) | Limited (rewrite) | None |
| Runtime | WKWebView | WKWebView | JS + native views | Custom renderer | Native |
| Team fit for web devs | Strong | Strong | Medium | Medium/low | Low |
| Native performance ceiling | Medium | Medium | High | High | Highest |
| PWA parity | High | High | Low | Low | Low |

## Choose PWAKit when

- You already have a production PWA.
- You want one main web codebase.
- You need native capabilities through a JS bridge.
- Your team is stronger in web than native iOS.

## Choose native-first frameworks when

- You need maximum animation/render performance.
- You are building a deeply iOS-native UI from scratch.
- Your roadmap depends on lower-level native APIs everywhere.

## Practical framing

PWAKit is the fastest path from existing web product to iOS app with native enhancements.
It is not meant to replace full native stacks for highly custom, graphics-heavy, or platform-specialized apps.
