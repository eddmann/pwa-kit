# PWAKit Kitchen Sink Demo

A comprehensive demonstration app showcasing **every PWAKit capability**. This "kitchen sink" example provides interactive testing for all SDK modules, from basic platform detection to advanced iOS features like HealthKit and StoreKit.

## Features Overview

| Category            | Capabilities                                                                    |
| ------------------- | ------------------------------------------------------------------------------- |
| Platform Detection  | Native bridge detection, device info, user agent parsing                        |
| Haptics             | Impact feedback (5 styles), notification feedback (3 types), selection feedback |
| Push Notifications  | Subscribe, get token, check permission, set/clear badge                         |
| Local Notifications | Schedule, cancel, list pending; time interval, date, and calendar triggers      |
| Share Sheet         | Share text/URLs, share files (images, documents)                                |
| Biometrics          | Face ID / Touch ID availability and authentication                              |
| Secure Storage      | Keychain save, load, delete, and exists operations                              |
| App Lifecycle       | Version info, open settings, request App Store review                           |
| Clipboard           | Copy and paste text                                                             |
| Print               | AirPrint dialog for current page                                                |
| In-App Purchases    | StoreKit 2: fetch products, purchase, restore, entitlements                     |
| HealthKit           | Query steps, heart rate, workouts, sleep; save workouts                         |
| Permissions         | Camera and location permission management                                       |

## Running the Example

1. Start the local HTTPS server:

   ```bash
   make example
   # Or directly: node example/server.js
   ```

2. Configure PWAKit to use the example:

   ```bash
   # Local development (against localhost server)
   ./scripts/configure.sh --force \
     --url "https://localhost:8443" \
     --name "PWAKit" \
     --features "notifications,haptics,biometrics,secureStorage,healthkit,iap,share,print,clipboard"

   # Or against the deployed Cloudflare Workers version
   ./scripts/configure.sh --force \
     --url "https://pwakit-example.eddmann.workers.dev" \
     --features "notifications,haptics,biometrics,secureStorage,healthkit,iap,share,print,clipboard"
   ```

3. Build and run in Xcode (`Cmd+R`)

## What You Can Test

### Platform & Detection

- Check if running as native app vs web browser
- View platform detection flags (`isNative`, `hasMessageHandlers`, `hasPWAKitUserAgent`)
- Get detailed platform info (OS version, app version, device model)

### Feedback (Haptics)

- **Impact haptics**: Light, Medium, Heavy, Soft, Rigid
- **Notification haptics**: Success, Warning, Error
- **Selection haptics**: For picker/slider interactions

### Push Notifications

- Subscribe to push notifications (requests permission, returns APNs token)
- Get existing subscription token
- Check permission state (granted/denied/prompt)
- Set and clear app icon badge count
- Listen for incoming push events in real-time

### Local Notifications

- Schedule one-off notifications (time interval or specific date)
- Schedule recurring notifications (calendar-based triggers)
- Cancel specific notifications by ID
- Cancel all scheduled notifications
- List all pending notifications with next trigger dates
- Configure badge, sound, and custom data payloads

### Sharing

- Check if sharing is available
- Share content with title, text, and URL
- Share files: sample image (PNG) and text document

### Security

**Biometrics (Face ID / Touch ID)**

- Check biometric availability and type
- Authenticate with custom reason text

**Secure Storage (Keychain)**

- Save key-value pairs to encrypted Keychain
- Load, check existence, and delete stored values

### System

**App Settings**

- Get app version and build number
- Open app settings in iOS Settings
- Request App Store review (SKStoreReviewController)

**Clipboard**

- Copy text to system clipboard
- Paste text from clipboard

**Print**

- Open AirPrint dialog for current page

### Purchases (StoreKit 2)

- Fetch product information by ID
- Purchase products
- Restore previous purchases
- Get current entitlements (owned products)
- Check if specific product is owned

### Health & Fitness (HealthKit)

- Check HealthKit availability
- Request authorization for health data
- Query: Steps (7 days), Heart Rate (24 hours), Workouts (30 days), Sleep (7 days)
- Save custom workouts with type, duration, and calories

### Permissions

- Check and request camera permission
- Check and request location permission

## Development Certificates

The `localhost+1.pem` and `localhost+1-key.pem` files are **development-only** self-signed certificates for running the example server over HTTPS locally.

### Important Notes

- These certificates are generated by [mkcert](https://github.com/FiloSottile/mkcert) for local development
- They are valid only for `localhost` and should **never** be used in production
- They are intentionally excluded from version control via `.gitignore`
- If missing, regenerate them with:

  ```bash
  # Install mkcert if needed
  brew install mkcert
  mkcert -install

  # Generate certificates
  cd example
  mkcert localhost 127.0.0.1
  ```

### Why HTTPS?

iOS requires HTTPS for many web features including:

- Service Workers
- Push Notifications
- Geolocation
- Camera/Microphone access

The development certificates allow testing these features locally without deploying to a real server.

## Files

| File                  | Description                                                                    |
| --------------------- | ------------------------------------------------------------------------------ |
| `index.html`          | Main app structure with organized sections for each feature category           |
| `app.js`              | 40+ test functions demonstrating all SDK modules with error handling           |
| `styles.css`          | Full iOS design system (light/dark mode, SF Pro typography, native components) |
| `manifest.json`       | PWA manifest configuration                                                     |
| `server.js`           | Node.js HTTPS server for local development                                     |
| `localhost+1.pem`     | Development SSL certificate (gitignored)                                       |
| `localhost+1-key.pem` | Development SSL private key (gitignored)                                       |

## Notes

- **Browser fallback**: The app works in a regular web browser with limited features. Native-only capabilities will show appropriate error messages.
- **Console panel**: A built-in console at the bottom of the screen shows all API calls and responses for debugging.
- **Event listeners**: The app automatically listens for `pwa:push` and `pwa:lifecycle` events from the native bridge.
