# Harness Agent Configuration Model

## Overview

Rubber Duck ships the same agent prompts to multiple harnesses (Claude Code, OpenCode, and extensible to others). Each harness needs different frontmatter. The model is: **one shared agent body + per-harness metadata**, rendered into harness-specific artifacts at build time.

## Configuration model

Each agent is authored as:

- shared prompt body (harness-agnostic)
- shared identity fields (`name`, `description`)
- explicit per-harness frontmatter sections

Per-harness metadata is authoritative for that harness. There is no cross-harness capability translation layer.

### Why metadata is per harness

Harness permission surfaces are not equivalent.

- OpenCode uses a `permission:` object (e.g. `read`, `edit`, `task`, `skill`)
- Claude uses a `tools:` allowlist

Keeping sections explicit avoids lossy mapping and keeps each harness configuration auditable.

## Target layout

```
agents/<name>/
  body.md      # harness-agnostic prompt (single source of truth)
  meta.json    # shared identity + per-harness frontmatter
```

`meta.json` schema:

```json
{
  "name": "duck-simple",
  "description": "Use for simplicity review to reduce overengineering, indirection, and unnecessary abstractions.",
  "harnesses": {
    "claude":   { "tools": "Read, Glob, Grep, Skill" },
    "opencode": {
      "mode": "all",
      "color": "#FFD801",
      "permission": { "read": "allow", "edit": "allow", "skill": "allow" }
    }
  }
}
```

- `name` / `description` are shared identity, rendered into every harness.
- `harnesses.<harness>` holds only that harness's frontmatter fields, rendered verbatim into its format.
- Fields that happen to coincide across harnesses (e.g. `color`) stay per-harness — coincidental overlap is not shared semantics.

The router follows the same model as every other agent (`body.md` + `meta.json`).

## Build model

- The builder (`scripts/build-harness-artifacts.sh`) reads each agent's `meta.json` and `body.md`.
- For each harness, a renderer emits harness-specific frontmatter (`render_claude_fm`, `render_opencode_fm`, ...), then appends the shared body.
- Output artifacts are written to `dist/<harness>/` and committed.
- `--check` mode verifies committed artifacts match a fresh render; mismatch is CI drift.
- Install mode selection (global vs project) is handled by installer scripts and layered on top of built artifacts.

### Dependency boundary

The builder is a **build-time/CI tool**, not an installer runtime dependency.

- End users consume pre-built `dist/` artifacts via installer scripts.
- The builder may depend on `jq` for JSON parsing.
- `jq` is validated in builder preflight checks.

## Adding a new harness

1. Add a `harnesses.<new>` section to each agent's `meta.json`.
2. Add a `render_<new>_fm` renderer and a `dist/<new>/` output path in the builder.
3. Add the harness's install mode(s) (for example: global/project variants) to `scripts/rubber-duck.sh` / `rubber-duck.ps1`.

No change to agent bodies or to other harnesses' sections.
