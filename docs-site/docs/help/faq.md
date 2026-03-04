# FAQ

## Do I need to rewrite my web app?

No. PWAKit is a thin native shell around your existing PWA.

## Can I use PWAKit without Swift knowledge?

Yes for standard usage. You only need Swift when building custom native modules.

## Is Android supported?

Not in this repository. PWAKit is intentionally iOS-focused.

## Do I need to clone the `pwa-kit` repository to use it?

No for normal usage. Run:

```bash
npx @pwa-kit/cli init my-pwa-ios
```

`init` downloads the template when no local project exists.

## Why is HTTPS required for `startUrl`?

WKWebView + modern web APIs and security expectations require HTTPS for production-safe behavior.

## Can I keep using the app in a normal browser?

Yes. Native features are additive; your web app can still run in a standard browser.

## Where should I store runtime secrets?

Use `SecureStorageModule` (Keychain-backed) rather than embedding keys in source.

## How should I run setup commands?

Use the CLI directly:

```bash
npx @pwa-kit/cli init my-pwa-ios
```

`init` already runs sync automatically.

Run `sync` later only after manual edits to `pwa-config.json`:

```bash
cd my-pwa-ios && npx @pwa-kit/cli sync
```
