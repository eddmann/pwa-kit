# Configuration Basics

Goal: understand only what you need to get a working app first.

## Step 1: Run init

```bash
npx @pwa-kit/cli init my-pwa-ios
```

This creates `src/PWAKit/Resources/pwa-config.json` and syncs native files.

## Step 2: Know the three required blocks

At minimum, focus on:

- `app`
- `origins.allowed`
- `version`

Example:

```json
{
  "version": 1,
  "app": {
    "name": "My App",
    "bundleId": "com.example.myapp",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com"],
    "auth": [],
    "external": []
  }
}
```

## Step 3: Edit and sync

Any manual edit requires sync:

```bash
npx @pwa-kit/cli sync
```

## Step 4: Rebuild

Open Xcode and run again (`Cmd+R`).

## What to learn next

- Every available field: [Full pwa-config.json](/configuration/full-pwa-config)
- Domain matching details: [Origins and URL Rules](/configuration/origins)
- Advanced patterns: [Advanced Usage](/configuration/advanced-usage)
