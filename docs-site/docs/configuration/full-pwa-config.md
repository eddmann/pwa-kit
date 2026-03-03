# Full `pwa-config.json`

This page documents the full schema in one place.

## Complete example

```json
{
  "version": 1,
  "app": {
    "name": "My App",
    "bundleId": "com.example.myapp",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com", "*.example.com"],
    "auth": ["accounts.google.com"],
    "external": ["example.com/docs/*"]
  },
  "features": {
    "notifications": true,
    "haptics": true,
    "biometrics": true,
    "secureStorage": true,
    "healthkit": false,
    "iap": false,
    "share": true,
    "print": true,
    "clipboard": true,
    "cameraPermission": true,
    "microphonePermission": true,
    "locationPermission": true
  },
  "appearance": {
    "displayMode": "standalone",
    "pullToRefresh": false,
    "statusBarStyle": "adaptive",
    "orientationLock": "any",
    "backgroundColor": "#FFFFFF",
    "themeColor": "#007AFF"
  },
  "notifications": {
    "provider": "apns"
  }
}
```

## Top-level fields

| Field | Required | Notes |
| --- | --- | --- |
| `version` | Yes | Current schema version is `1` |
| `app` | Yes | Name, bundle ID, start URL |
| `origins` | Yes | URL routing behavior |
| `features` | No | If omitted, runtime defaults apply |
| `appearance` | No | If omitted, runtime defaults apply |
| `notifications` | No | If omitted, runtime default is APNs |

## `app`

| Field | Required | Validation |
| --- | --- | --- |
| `name` | Yes | Non-empty string |
| `bundleId` | Yes | Reverse-domain format |
| `startUrl` | Yes | Must be HTTPS |

## `origins`

| Field | Required | Default | Notes |
| --- | --- | --- | --- |
| `allowed` | Yes | - | Must not be empty |
| `auth` | No | `[]` | OAuth/login flow domains |
| `external` | No | `[]` | Force external browser |

Pattern examples:

- `example.com`
- `*.example.com`
- `example.com/path/*`

## `features`

| Key | Runtime default (if omitted) |
| --- | --- |
| `notifications` | `true` |
| `haptics` | `true` |
| `biometrics` | `true` |
| `secureStorage` | `true` |
| `healthkit` | `false` |
| `iap` | `false` |
| `share` | `true` |
| `print` | `true` |
| `clipboard` | `true` |
| `cameraPermission` | `true` |
| `microphonePermission` | `true` |
| `locationPermission` | `true` |

Important: CLI-generated config explicitly writes feature values based on your init choices.

## `appearance`

| Field | Allowed values | Runtime default |
| --- | --- | --- |
| `displayMode` | `standalone`, `fullscreen` | `standalone` |
| `pullToRefresh` | `true`, `false` | `false` |
| `statusBarStyle` | `adaptive`, `light`, `dark` | `adaptive` |
| `orientationLock` | `any`, `portrait`, `landscape` | `any` |
| `backgroundColor` | string (`#RRGGBB`) | `null` |
| `themeColor` | string (`#RRGGBB`) | `null` |

## `notifications`

| Field | Allowed values | Runtime default |
| --- | --- | --- |
| `provider` | `apns` | `apns` |

## Validate + sync

```bash
cat src/PWAKit/Resources/pwa-config.json | python3 -m json.tool
npx @pwa-kit/cli sync --validate
npx @pwa-kit/cli sync
```
