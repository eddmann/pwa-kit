# `init` Command

Goal: create or update a PWAKit project from your PWA URL.

## Usage

```bash
npx @pwa-kit/cli init [dir] [options]
```

- `dir` defaults to `.`.
- If `dir` does not exist, `init` creates it when extracting the template.
- If no project is found, the CLI downloads the template into `dir`.

## Interactive setup

```bash
npx @pwa-kit/cli init my-pwa-ios
```

Interactive mode is used when:

- `--url` is omitted
- stdin is a TTY

Wizard steps (from source):

1. Start URL
2. App name
3. Bundle ID
4. Additional allowed origins
5. Feature selection

## Non-interactive setup

```bash
npx @pwa-kit/cli init my-pwa-ios \
  --url "https://app.example.com" \
  --name "My App" \
  --bundle-id "com.example.myapp" \
  --features "notifications,haptics,biometrics,secureStorage" \
  --force
```

## Options

| Flag | Description |
| --- | --- |
| `-u, --url <url>` | Start URL (HTTPS required) |
| `-n, --name <name>` | App display name |
| `-b, --bundle-id <id>` | iOS bundle identifier |
| `-a, --allowed <origins>` | Additional allowed origins (comma-separated) |
| `--auth <origins>` | Auth origins (comma-separated) |
| `--bg-color <hex>` | Background color (`#RRGGBB`) |
| `--theme-color <hex>` | Theme color (`#RRGGBB`) |
| `--orientation <lock>` | `any`, `portrait`, `landscape` |
| `--display <mode>` | `standalone`, `fullscreen` |
| `--features <list>` | Enabled features (comma-separated) |
| `-f, --force` | Overwrite existing config in non-interactive mode |
| `--template-version <version>` | Download specific template release tag |

## Available feature keys

- `notifications`
- `haptics`
- `biometrics`
- `secureStorage`
- `healthkit`
- `iap`
- `share`
- `print`
- `clipboard`
- `cameraPermission`
- `microphonePermission`
- `locationPermission`

## What `init` writes and updates

1. Generates `src/PWAKit/Resources/pwa-config.json`
2. Optionally downloads `AppIcon-source.png` from manifest icon
3. Runs sync (`apply`) automatically

## Common errors

- Invalid `--url`: must be HTTPS and match CLI regex validation.
- Existing config in non-interactive mode: use `--force`.
- No app name in non-interactive mode: pass `--name` when manifest has no name.
