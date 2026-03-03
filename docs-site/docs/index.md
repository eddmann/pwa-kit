---
layout: home

hero:
  name: "PWAKit"
  text: "Ship your PWA as a native iOS app"
  tagline: "Keep your web code. Add native capabilities with a typed JavaScript bridge."
  image:
    src: /logo.png
    alt: PWAKit logo
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: CLI Docs
      link: /cli/overview
    - theme: alt
      text: SDK Docs
      link: /sdk/overview

features:
  - icon: "🚀"
    title: No Rewrite
    details: Wrap your existing Progressive Web App in a native iOS shell.
  - icon: "🧩"
    title: Native Bridge
    details: Access haptics, biometrics, push, keychain storage, HealthKit, and more from JavaScript.
  - icon: "🛠️"
    title: CLI-Driven Setup
    details: Generate config and sync project files with `npx @pwa-kit/cli`.
  - icon: "📦"
    title: Complete Toolkit
    details: Includes iOS runtime (Swift), CLI, and TypeScript SDK.
---

## Quick start

```bash
npx @pwa-kit/cli init my-pwa-ios
open my-pwa-ios/PWAKitApp.xcodeproj
```

`init` will download the latest PWAKit template if no project is found, create `pwa-config.json`, and sync the iOS project files.

## Start here

- Setup from zero: [Getting Started](/guide/getting-started)
- Full capability demo app: [Kitchen Sink Demo](/guide/kitchen-sink-demo)
- CLI behavior and flags: [CLI Overview](/cli/overview)
- Config fields and sync rules: [Configuration Overview](/configuration/overview)
- SDK module APIs: [SDK Overview](/sdk/overview)
- Debugging path: [Troubleshooting](/help/troubleshooting)
