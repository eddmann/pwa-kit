# Advanced Usage

Use this page after you are comfortable with the basics.

## 1) Manifest-driven setup and overrides

`init` pulls values from web manifest when available:

- name/short_name
- background_color
- theme_color
- orientation
- display
- icon

You can override any of these with CLI flags (`--name`, `--bg-color`, `--orientation`, etc.).

## 2) Keep start URL host in allowed origins

Validation fails if `app.startUrl` host does not match an allowed origin.

Safe pattern:

```json
{
  "app": { "startUrl": "https://app.example.com/" },
  "origins": { "allowed": ["app.example.com"], "auth": [], "external": [] }
}
```

## 3) Use `auth` and `external` intentionally

- `auth`: third-party login pages that should stay in webview with done toolbar
- `external`: docs/help/legal/blog pages you want in Safari

## 4) Feature strategy by app maturity

Suggested progression:

1. Start with core features only (`haptics`, `share`, `clipboard` as needed).
2. Add sensitive features (`cameraPermission`, `microphonePermission`, `locationPermission`) with proper usage descriptions.
3. Add review-sensitive features (`healthkit`, `iap`) only when app capabilities and review copy are ready.

## 5) Validate in CI

Use:

```bash
npx @pwa-kit/cli sync --validate
```

This catches drift between config and native project artifacts.

## 6) Runtime override behavior

From `ConfigurationLoader`, config load priority is:

1. Documents directory `pwa-config.json`
2. Bundled `pwa-config.json`
3. Built-in default fallback

This can be useful for advanced runtime testing, but most apps should treat bundled config as source of truth.
