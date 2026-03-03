# PWAKit

This directory contains the user-facing static documentation site for PWAKit, built with VitePress.

## Requirements

- Bun `1.3.3+`
- GNU Make

## Run locally

```bash
make docs/deps
make docs/dev
```

Open `http://localhost:4173`.

## Build static site

```bash
make docs/build
make docs/preview
```

The generated static files are written to `docs-site/docs/.vitepress/dist`.

## Commands

| Task | Command |
| --- | --- |
| Install deps | `make docs/deps` |
| Start dev server | `make docs/dev` |
| Build static output | `make docs/build` |
| Preview built output | `make docs/preview` |

## Content layout

- `docs-site/docs/` user-facing published docs.
- `docs/` in repo root internal/engineering docs (not published as site pages).
