# Origins and URL Rules

Origins determine which URLs open inside your app versus outside it.

## The three origin lists

- `origins.allowed`: trusted in-app webview domains
- `origins.auth`: login/auth domains that still run in webview
- `origins.external`: always open externally

## Example

```json
{
  "origins": {
    "allowed": ["app.example.com", "*.example.com"],
    "auth": ["accounts.google.com"],
    "external": ["example.com/docs/*"]
  }
}
```

## Pattern behavior

| Pattern | Meaning |
| --- | --- |
| `example.com` | exact host |
| `*.example.com` | any subdomain |
| `example.com/path/*` | matching path prefix |

## Evaluation order

1. `external`
2. `auth`
3. `allowed`
4. fallback to external

## iOS requirement: App-Bound Domains

`origins.allowed` and `origins.auth` must be reflected in `WKAppBoundDomains`.

Always run after changes:

```bash
npx @pwa-kit/cli sync
```

If domains are out of sync, your app may show a blank screen or fail navigation policy checks.
