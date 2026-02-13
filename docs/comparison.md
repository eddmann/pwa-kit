# PWAKit vs Alternatives

This guide compares PWAKit with other approaches for building iOS apps, helping you choose the right tool for your project.

## The PWA-First Philosophy

PWAKit takes a fundamentally different approach from most mobile frameworks: **your app stays 100% web**.

Unlike frameworks that generate native code or require you to learn new languages, PWAKit wraps your existing Progressive Web App in a thin native shell. Your PWA runs unchanged inside a WKWebView, with a JavaScript bridge providing access to iOS capabilities that web APIs can't reach.

**Key Principles:**

- **Web-First**: Your entire application is web code (HTML, CSS, JavaScript/TypeScript)
- **Thin Native Shell**: The iOS app is just a container - no native business logic
- **Progressive Enhancement**: Native features are additive - your PWA works without them
- **One Codebase**: The same web app runs in browsers, as a PWA, and in the native shell
- **Preserve PWA Benefits**: Offline support, installability, and web standards remain intact

---

## Quick Comparison

| Aspect             | PWAKit     | Capacitor   | React Native       | Flutter           | Native Swift |
| ------------------ | ---------- | ----------- | ------------------ | ----------------- | ------------ |
| **Your Code**      | Web only   | Web only    | JS + Native        | Dart              | Swift        |
| **Runtime**        | WKWebView  | WKWebView   | JSC + Native Views | Skia Renderer     | Native       |
| **UI Rendering**   | Browser    | Browser     | Native components  | Custom painted    | Native       |
| **Learning Curve** | None       | Low         | Medium             | High              | High         |
| **App Size**       | ~2-5 MB    | ~2-5 MB     | ~20-50 MB          | ~15-25 MB         | ~5-15 MB     |
| **PWA Compatible** | Yes        | Yes         | No                 | No                | No           |
| **iOS Features**   | Via bridge | Via plugins | Native modules     | Platform channels | Direct       |

---

## PWAKit vs Capacitor

[Capacitor](https://capacitorjs.com) (by Ionic) is the closest alternative to PWAKit. Both wrap web apps in WKWebView with native bridges.

### Similarities

- Both use WKWebView to render your web app
- Both provide JavaScript bridges to native features
- Both allow you to keep your existing web codebase
- Both produce native iOS apps for App Store distribution

### Key Differences

| Aspect                | PWAKit                    | Capacitor                     |
| --------------------- | ------------------------- | ----------------------------- |
| **Focus**             | PWA wrapping specifically | General hybrid app platform   |
| **Platforms**         | iOS only (focused)        | iOS, Android, Web             |
| **Native Code**       | Zero required             | Sometimes needed for plugins  |
| **Configuration**     | JSON only                 | JSON + native project files   |
| **Plugin System**     | 15 built-in modules       | Large community ecosystem     |
| **Project Structure** | Xcode project             | Xcode project + CocoaPods/SPM |
| **Swift Version**     | Swift 6 with actors       | Varies by plugin              |

### When to Choose PWAKit

- You only need iOS (no Android requirement)
- You want zero native code or native project management
- The 15 built-in modules cover your needs
- You prefer a focused, single-purpose tool

### When to Choose Capacitor

- You need cross-platform (iOS + Android) from one codebase
- You need plugins beyond PWAKit's built-in modules
- You're already in the Ionic ecosystem
- You're comfortable managing native project configuration

---

## PWAKit vs React Native

[React Native](https://reactnative.dev) is fundamentally different from PWAKit - it's not a web wrapper.

### How React Native Works

React Native compiles your JavaScript/TypeScript into native UI components. When you write `<View>` and `<Text>`, React Native creates actual `UIView` and `UILabel` instances. Your JavaScript runs in a JavaScript engine (Hermes or JSC), but the UI is native.

### Key Differences

| Aspect            | PWAKit                    | React Native                        |
| ----------------- | ------------------------- | ----------------------------------- |
| **UI**            | Web (HTML/CSS in WebView) | Native iOS components               |
| **Existing Code** | Use your PWA directly     | Must rewrite UI in React Native     |
| **Styling**       | CSS                       | StyleSheet (CSS-like but different) |
| **DOM APIs**      | Full browser APIs         | None (no DOM)                       |
| **Performance**   | Web performance           | Near-native performance             |
| **Bundle Size**   | ~2-5 MB                   | ~20-50 MB                           |
| **Hot Reload**    | Browser dev tools         | Metro bundler                       |

### When to Choose PWAKit

- You have an existing PWA or web app
- Your team knows web technologies, not React Native
- Web performance is acceptable for your use case
- You want to maintain one codebase for web and iOS

### When to Choose React Native

- You're building from scratch and want native UI feel
- Performance is critical (complex animations, games)
- You need deep native integrations
- Your team already knows React Native

---

## PWAKit vs Flutter

[Flutter](https://flutter.dev) is Google's UI toolkit using the Dart language and a custom rendering engine.

### How Flutter Works

Flutter doesn't use native UI components OR web views. It paints every pixel using its own Skia-based rendering engine. You write Dart code, and Flutter draws your UI directly on a canvas.

### Key Differences

| Aspect             | PWAKit                         | Flutter                         |
| ------------------ | ------------------------------ | ------------------------------- |
| **Language**       | JavaScript/TypeScript          | Dart                            |
| **Rendering**      | WebView (browser engine)       | Custom Skia engine              |
| **Learning Curve** | None (use existing web skills) | High (new language + framework) |
| **UI Paradigm**    | HTML/CSS                       | Widget tree                     |
| **Existing Code**  | Use your PWA directly          | Must rewrite everything         |
| **Bundle Size**    | ~2-5 MB                        | ~15-25 MB                       |
| **Web Support**    | Native (it's a web app)        | Flutter Web (different runtime) |

### When to Choose PWAKit

- You have web development expertise
- You have an existing PWA to wrap
- You want the smallest possible app size
- Web rendering quality is acceptable

### When to Choose Flutter

- You're starting fresh and want maximum UI control
- You need identical pixel-perfect UI across platforms
- Your team is willing to learn Dart
- You want Flutter's rich widget ecosystem

---

## PWAKit vs Native Swift

Writing a fully native iOS app in Swift/SwiftUI is the "traditional" approach Apple recommends.

### How Native Swift Works

You write Swift code using Apple's frameworks (UIKit, SwiftUI). Your app compiles to native machine code. You have direct access to all iOS APIs without bridges or wrappers.

### Key Differences

| Aspect             | PWAKit                   | Native Swift                     |
| ------------------ | ------------------------ | -------------------------------- |
| **Language**       | JavaScript/TypeScript    | Swift                            |
| **UI Framework**   | HTML/CSS                 | SwiftUI/UIKit                    |
| **IDE**            | Any web IDE              | Xcode required                   |
| **Learning Curve** | None (web skills)        | High (new language + frameworks) |
| **API Access**     | Via bridge (async)       | Direct (sync)                    |
| **Performance**    | Web performance          | Maximum native performance       |
| **Code Sharing**   | Web + iOS from same code | iOS only                         |
| **Team Skills**    | Web developers           | iOS developers                   |

### When to Choose PWAKit

- Your team are web developers, not iOS developers
- You have an existing web app or PWA
- You want to share code between web and iOS
- You don't need maximum native performance
- Faster time-to-market is a priority

### When to Choose Native Swift

- Performance is critical (games, video editing, AR)
- You need cutting-edge iOS features immediately
- Your team are experienced iOS developers
- You're only building for iOS (no web version)
- You want the "Apple way" with full platform integration

### Hybrid Approach

Some teams use PWAKit for most of their app while building performance-critical features natively. PWAKit's modular architecture supports this - you can add custom native modules when needed.

---

## The PWABuilder Connection

[PWABuilder.com](https://pwabuilder.com) is Microsoft's free tool for packaging PWAs for app stores. PWAKit shares the same philosophy: **PWAs deserve first-class app store presence** without abandoning web technology.

### How PWABuilder Works

1. Enter your PWA's URL
2. PWABuilder analyzes your web app manifest and service worker
3. Generate native app packages for iOS, Android, Windows
4. Submit to app stores

### PWABuilder's iOS Output

PWABuilder generates an Xcode project that wraps your PWA in WKWebView - conceptually similar to PWAKit.

### PWAKit vs PWABuilder iOS

| Aspect             | PWAKit                                  | PWABuilder iOS             |
| ------------------ | --------------------------------------- | -------------------------- |
| **Native Modules** | 15 built-in (haptics, biometrics, etc.) | Basic (fewer capabilities) |
| **TypeScript SDK** | Yes, fully typed                        | Limited                    |
| **Configuration**  | JSON-based, flexible                    | Generated from manifest    |
| **Maintenance**    | Actively developed                      | Generated output           |
| **Customization**  | High (module system)                    | Limited                    |
| **Architecture**   | Swift 6, actor-based                    | Older Swift patterns       |

### When to Use PWABuilder

- Quick prototype to test App Store viability
- Minimal native feature requirements
- You want Android + iOS from one tool
- You don't need PWAKit's extended native modules

### When to Use PWAKit

- You need rich native iOS features
- You want a TypeScript SDK for type-safe bridge calls
- You need ongoing development and customization
- You want modern Swift architecture

### Using Both

A common workflow:

1. Use PWABuilder to quickly validate your PWA works as an iOS app
2. Migrate to PWAKit when you need more native features
3. The same PWA works with both - no code changes needed

---

## What PWAs Retain in PWAKit

When wrapped with PWAKit, your PWA keeps all its advantages:

| PWA Feature        | Status    | Notes                                |
| ------------------ | --------- | ------------------------------------ |
| Service Workers    | Supported | Offline caching works normally       |
| HTTPS              | Required  | Start URL must be HTTPS              |
| Responsive Design  | Supported | Your CSS handles all screen sizes    |
| IndexedDB          | Supported | Client-side database works           |
| LocalStorage       | Supported | All web storage APIs work            |
| Cache API          | Supported | Service worker caching works         |
| Background Sync    | Supported | Where iOS allows                     |
| Web Push           | Enhanced  | APNs provides better iOS integration |
| Add to Home Screen | Native    | App Store install replaces this      |
| Web App Manifest   | N/A       | Native app config replaces manifest  |

---

## Decision Flowchart

```
Do you have an existing PWA or web app?
├── Yes → Do you need Android support?
│         ├── Yes → Consider Capacitor
│         └── No → Do PWAKit's 15 modules cover your needs?
│                  ├── Yes → Use PWAKit
│                  └── No → Consider Capacitor (more plugins)
│
└── No → Is your team experienced with native development?
         ├── Yes → Consider Native Swift or Flutter
         └── No → Do you want to learn a new language?
                  ├── Yes → Consider Flutter (Dart) or React Native
                  └── No → Build a PWA first, then use PWAKit
```

---

## Summary

| Tool             | Best For                                                                 |
| ---------------- | ------------------------------------------------------------------------ |
| **PWAKit**       | Existing PWAs needing iOS App Store with native features, web-only teams |
| **Capacitor**    | Cross-platform hybrid apps, large plugin ecosystem needs                 |
| **React Native** | Teams wanting native UI with JavaScript, React expertise                 |
| **Flutter**      | New projects wanting pixel-perfect cross-platform UI                     |
| **Native Swift** | Maximum performance, iOS-only, experienced native teams                  |
| **PWABuilder**   | Quick PWA-to-App-Store with minimal native features                      |
