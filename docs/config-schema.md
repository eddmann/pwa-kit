# PWA Configuration Schema

This document describes the JSON schema for `pwa-config.json`, the configuration file that controls PWAKit behavior.

## Overview

PWAKit uses a JSON configuration file to define app metadata, URL handling rules, feature flags, and UI customization. This approach enables web-based tooling to generate and modify the configuration without needing Swift knowledge.

## Schema Version

Current schema version: **1**

The `version` field allows for future schema migrations while maintaining backwards compatibility.

## Top-Level Structure

```json
{
  "version": 1,
  "app": { ... },
  "origins": { ... },
  "features": { ... },
  "appearance": { ... },
  "notifications": { ... }
}
```

| Field           | Type      | Required | Description                |
| --------------- | --------- | -------- | -------------------------- |
| `version`       | `integer` | Yes      | Schema version number      |
| `app`           | `object`  | Yes      | App metadata configuration |
| `origins`       | `object`  | Yes      | URL handling rules         |
| `features`      | `object`  | No       | Feature flags for modules  |
| `appearance`    | `object`  | No       | UI customization settings  |
| `notifications` | `object`  | No       | Push notification settings |

---

## App Configuration

The `app` object contains core application metadata.

```json
{
  "app": {
    "name": "My PWA",
    "bundleId": "com.example.mypwa",
    "startUrl": "https://app.example.com/"
  }
}
```

### Fields

| Field      | Type     | Required | Description                                     |
| ---------- | -------- | -------- | ----------------------------------------------- |
| `name`     | `string` | Yes      | Display name of the application                 |
| `bundleId` | `string` | Yes      | iOS bundle identifier (e.g., `com.example.app`) |
| `startUrl` | `string` | Yes      | The initial URL to load (must be HTTPS)         |

### Validation Rules

- `name`: Non-empty string
- `bundleId`: Valid bundle identifier format (alphanumeric with periods)
- `startUrl`: Valid HTTPS URL

---

## Origins Configuration

The `origins` object controls how URLs are handled within the app.

```json
{
  "origins": {
    "allowed": ["app.example.com", "*.example.com"],
    "auth": ["accounts.google.com", "auth0.com"],
    "external": ["example.com/external/*"]
  }
}
```

### Fields

| Field      | Type       | Required | Default | Description                               |
| ---------- | ---------- | -------- | ------- | ----------------------------------------- |
| `allowed`  | `[string]` | Yes      | -       | Origins that load within the WebView      |
| `auth`     | `[string]` | No       | `[]`    | Origins that show the "Done" toolbar      |
| `external` | `[string]` | No       | `[]`    | URLs that open in Safari/external browser |

### Origin Patterns

Origins support wildcard patterns:

| Pattern               | Matches                       |
| --------------------- | ----------------------------- |
| `example.com`         | Exact domain match            |
| `*.example.com`       | Any subdomain of example.com  |
| `example.com/path/*`  | Any path starting with /path/ |
| `*.example.com/api/*` | Subdomain with path pattern   |

### Behavior

1. **Allowed Origins**: URLs matching these patterns load inside the WKWebView with full bridge access.

2. **Auth Origins**: URLs matching these patterns load inside the WebView but display a "Done" toolbar. Useful for OAuth flows that navigate to third-party domains (Google, Apple, etc.).

3. **External Origins**: URLs matching these patterns open in SFSafariViewController or the system browser instead of the WebView.

4. **Unmatched URLs**: URLs not matching any pattern are opened externally.

### Priority Order

1. External patterns are checked first
2. Auth patterns are checked second
3. Allowed patterns are checked last
4. Unmatched URLs default to external

---

## Features Configuration

The `features` object enables or disables individual bridge modules.

```json
{
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
  }
}
```

### Available Features

| Feature              | Default | Description                                 |
| -------------------- | ------- | ------------------------------------------- |
| `notifications`      | `true`  | Push notification support (APNs)            |
| `haptics`            | `true`  | Haptic feedback (UIImpactFeedbackGenerator) |
| `biometrics`         | `true`  | Face ID / Touch ID authentication           |
| `secureStorage`      | `true`  | Keychain-based secure storage               |
| `healthkit`          | `false` | HealthKit data access                       |
| `iap`                | `false` | In-app purchases (StoreKit 2)               |
| `share`              | `true`  | Native share sheet                          |
| `print`              | `true`  | AirPrint support                            |
| `clipboard`          | `true`  | System clipboard access                     |
| `cameraPermission`   | `true`  | Camera permission requests                  |
| `microphonePermission` | `true` | Microphone permission requests             |
| `locationPermission` | `true`  | Location permission requests                |

### Notes

- Disabled features return "module not available" errors from the bridge
- Some features require additional configuration (entitlements, Info.plist keys)
- `healthkit` and `iap` are disabled by default as they require App Store review

---

## Appearance Configuration

The `appearance` object controls UI behavior and styling.

```json
{
  "appearance": {
    "displayMode": "standalone",
    "pullToRefresh": false,
    "statusBarStyle": "adaptive",
    "orientationLock": "any",
    "backgroundColor": "#FFFFFF",
    "themeColor": "#007AFF"
  }
}
```

### Fields

| Field             | Type      | Default        | Description                                   |
| ----------------- | --------- | -------------- | --------------------------------------------- |
| `displayMode`     | `string`  | `"standalone"` | How the app displays content                  |
| `pullToRefresh`   | `boolean` | `false`        | Enable pull-to-refresh gesture                |
| `statusBarStyle`  | `string`  | `"adaptive"`   | Status bar appearance                         |
| `orientationLock` | `string`  | `"any"`        | Device orientation lock                       |
| `backgroundColor` | `string`  | `null`         | App background color (hex, e.g., `"#FFFFFF"`) |
| `themeColor`      | `string`  | `null`         | Theme/accent color (hex, e.g., `"#007AFF"`)   |

### Display Modes

| Mode         | Description                            |
| ------------ | -------------------------------------- |
| `standalone` | Hides browser UI, app appears native   |
| `fullscreen` | Hides status bar, maximum screen space |

### Status Bar Styles

| Style      | Description                                                      |
| ---------- | ---------------------------------------------------------------- |
| `adaptive` | Observes WebView background color, switches light/dark automatically |
| `light`    | Forces light appearance (dark status bar text)                   |
| `dark`     | Forces dark appearance (light status bar text)                   |

### Orientation Lock Values

| Value       | Description                   |
| ----------- | ----------------------------- |
| `any`       | Allow all orientations        |
| `portrait`  | Lock to portrait orientation  |
| `landscape` | Lock to landscape orientation |

---

## Notifications Configuration

The `notifications` object configures push notification behavior.

```json
{
  "notifications": {
    "provider": "apns"
  }
}
```

### Fields

| Field      | Type     | Default  | Description                |
| ---------- | -------- | -------- | -------------------------- |
| `provider` | `string` | `"apns"` | Push notification provider |

### Providers

| Provider | Description                              |
| -------- | ---------------------------------------- |
| `apns`   | Apple Push Notification service (native) |

PWAKit uses native APNs exclusively. The device token is provided to your web app via the bridge for server-side registration.

---

## Complete Example

```json
{
  "version": 1,
  "app": {
    "name": "My PWA",
    "bundleId": "com.example.mypwa",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com", "*.example.com"],
    "auth": ["accounts.google.com", "auth0.com"],
    "external": ["example.com/external/*"]
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

---

## Minimal Example

Only required fields:

```json
{
  "version": 1,
  "app": {
    "name": "My App",
    "bundleId": "com.example.app",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com"]
  }
}
```

All other fields use their default values.

---

## File Location

The configuration file should be placed at:

```
kit/src/PWAKit/Resources/pwa-config.json
```

For development, you can copy the example file:

```bash
cp kit/src/PWAKit/Resources/pwa-config.example.json \
   kit/src/PWAKit/Resources/pwa-config.json
```

---

## Validation

The configuration is validated at app launch. Validation includes:

1. **Schema version**: Must be a supported version number
2. **Required fields**: All required fields must be present
3. **URL format**: `startUrl` must be a valid HTTPS URL
4. **Bundle ID format**: Must match iOS bundle identifier rules
5. **Origin patterns**: Must be valid domain/path patterns
6. **At least one allowed origin**: The `allowed` array cannot be empty

Validation errors are logged and may prevent the app from loading the WebView.

---

## JSON Schema (Draft-07)

For tooling integration, here is the formal JSON Schema:

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "$id": "https://pwakit.dev/schemas/pwa-config.json",
  "title": "PWAKit Configuration",
  "type": "object",
  "required": ["version", "app", "origins"],
  "properties": {
    "version": {
      "type": "integer",
      "minimum": 1,
      "description": "Schema version number"
    },
    "app": {
      "type": "object",
      "required": ["name", "bundleId", "startUrl"],
      "properties": {
        "name": {
          "type": "string",
          "minLength": 1,
          "description": "Application display name"
        },
        "bundleId": {
          "type": "string",
          "pattern": "^[a-zA-Z][a-zA-Z0-9]*(\\.[a-zA-Z][a-zA-Z0-9]*)+$",
          "description": "iOS bundle identifier"
        },
        "startUrl": {
          "type": "string",
          "format": "uri",
          "pattern": "^https://",
          "description": "Initial URL to load"
        }
      }
    },
    "origins": {
      "type": "object",
      "required": ["allowed"],
      "properties": {
        "allowed": {
          "type": "array",
          "items": { "type": "string" },
          "minItems": 1,
          "description": "Origins that load in the WebView"
        },
        "auth": {
          "type": "array",
          "items": { "type": "string" },
          "default": [],
          "description": "Origins that show Done toolbar"
        },
        "external": {
          "type": "array",
          "items": { "type": "string" },
          "default": [],
          "description": "Origins that open externally"
        }
      }
    },
    "features": {
      "type": "object",
      "properties": {
        "notifications": { "type": "boolean", "default": true },
        "haptics": { "type": "boolean", "default": true },
        "biometrics": { "type": "boolean", "default": true },
        "secureStorage": { "type": "boolean", "default": true },
        "healthkit": { "type": "boolean", "default": false },
        "iap": { "type": "boolean", "default": false },
        "share": { "type": "boolean", "default": true },
        "print": { "type": "boolean", "default": true },
        "clipboard": { "type": "boolean", "default": true },
        "cameraPermission": { "type": "boolean", "default": true },
        "microphonePermission": { "type": "boolean", "default": true },
        "locationPermission": { "type": "boolean", "default": true }
      }
    },
    "appearance": {
      "type": "object",
      "properties": {
        "displayMode": {
          "type": "string",
          "enum": ["standalone", "fullscreen"],
          "default": "standalone"
        },
        "pullToRefresh": { "type": "boolean", "default": false },
        "statusBarStyle": {
          "type": "string",
          "enum": ["adaptive", "light", "dark"],
          "default": "adaptive"
        },
        "orientationLock": {
          "type": "string",
          "enum": ["any", "portrait", "landscape"],
          "default": "any"
        },
        "backgroundColor": {
          "type": "string",
          "pattern": "^#[0-9A-Fa-f]{6}$",
          "description": "App background color (hex)"
        },
        "themeColor": {
          "type": "string",
          "pattern": "^#[0-9A-Fa-f]{6}$",
          "description": "Theme/accent color (hex)"
        }
      }
    },
    "notifications": {
      "type": "object",
      "properties": {
        "provider": {
          "type": "string",
          "enum": ["apns"],
          "default": "apns"
        }
      }
    }
  }
}
```
