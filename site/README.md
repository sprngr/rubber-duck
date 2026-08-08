# rubber-duck site

Static documentation site built with [docmd](https://github.com/docmd-io/docmd).
Deployed to https://sprngr.github.io/rubber-duck via GitHub Pages.

## Local development

```bash
cd site
npm install
npm run dev
```

Opens at http://localhost:3000.

## Build

```bash
npm run build
```

Output: `site/dist/`.

## Source of truth

- Site-only pages (landing, skill catalogue, demos): `site/content/`
- Architecture/philosophy content: `docs/` at repo root, synced into `site/content/reference/` at build time (see `site/scripts/sync-docs.mjs`, added in Phase 2).

Do not hand-edit synced content under `site/content/reference/`.
