# Rubber Duck Scripts

CLI reference for install/update/uninstall tooling.

## Quick Start

```bash
# Build skill install artifacts from source-of-truth (src/skills -> skills)
bash scripts/assemble-skills.sh

# Build generated harness artifacts (src/agents -> dist)
make build

# Verify guardrails + skills + generated artifacts are up to date
make check

# Install agents (example: project OpenCode target)
./scripts/rubber-duck.sh install --opencode --project
```

## Build Targets (Make)

| Target | Purpose |
| --- | --- |
| `make check-guardrails` | Verify no drift between canonical and vendored guardrails |
| `make build-skills` | Assemble skills from `src/skills/*` into `skills/*` |
| `make check-skills` | Verify assembled skills are up to date |
| `make build-agents` | Build harness artifacts into `dist/*` from `src/agents/*` |
| `make check-agents` | Verify harness artifacts are up to date |
| `make build-harness` | Build harness artifacts into `dist/*` |
| `make check-harness` | Verify guardrails drift + harness artifacts are up to date |
| `make build` | Build skills + harness artifacts |
| `make check` | Check guardrails drift + skills + harness artifacts |

## Harness Artifact Build Script

`scripts/build-harness-artifacts.sh` supports:

- build mode (default): render/update harness outputs under `dist/`
- check mode (`--check`): fail if generated artifacts are missing or stale

Examples:

```bash
./scripts/build-harness-artifacts.sh
./scripts/build-harness-artifacts.sh --check
```

Notes:

- Requires `jq` at build/check time.
- Check mode validates guardrails drift before artifact freshness checks.
- Agent source-of-truth is `src/agents/*`.
- Model details (per-harness metadata, renderer boundary, adding a new harness): [docs/architecture/05-harness-agent-config.md](../docs/architecture/05-harness-agent-config.md).

## Scripts

- `scripts/rubber-duck.sh` — Bash installer/manager (local + web-compatible)
- `scripts/rubber-duck.ps1` — PowerShell installer/manager (Windows)
- `scripts/assemble-skills.sh` — assemble `src/skills/*` into install artifacts under `skills/*` (`--check` verifies drift + portability lint)
- `scripts/build-harness-artifacts.sh` — render harness artifacts into `dist/*` from `src/agents/*` config/body sources
- `scripts/check-guardrails-drift.sh` — fail if vendored guardrails drift from canonical

## Skill Assembly Script

`scripts/assemble-skills.sh` supports:

- build mode (default): copy-through from `src/skills/*` to `skills/*`
- check mode (`--check`): fail on stale/missing artifacts and portability deny-token violations

Examples:

```bash
bash scripts/assemble-skills.sh
bash scripts/assemble-skills.sh --check
```

Contract details (rules schema, drift controls, invariants): [docs/architecture/06-skill-assembly-contract.md](../docs/architecture/06-skill-assembly-contract.md).

## Commands

| Command | Purpose |
| --- | --- |
| `install` | Install/update agents, managed policy file, and skills package |
| `uninstall` | Remove installed agents, remove managed policy file, remove skills package |
| `status` | Show installed agent count, policy state, and skills state |
| `doctor` | Validate target paths and required tooling |

## Bash CLI (`scripts/rubber-duck.sh`)

Use Bash CLI for Linux/macOS and shell-based CI.

| Flag | Type | Description |
| --- | --- | --- |
| `--claude` | switch | Use Claude paths (default global; add `--project` for project scope) |
| `--copilot` | switch | Use Copilot paths (default global; add `--project` for project scope) |
| `--opencode` | switch | Use opencode paths (default global; add `--project` for project scope) |
| `--project` | switch | Apply project scope to selected target (and skills, unless `--skip-skills`) |
| `--claude-md <path>` | value | Claude target `CLAUDE.md` path override (default for `--claude`; project default when `--project` also set) |
| `--branch <name>` | value | Branch to install from (default: `main`, auto-detects from URL when piped) |
| `--skip-skills` | switch | Skip `npx skills add/remove/list` |
| `--skip-agents-md` | switch | Skip AGENTS.md policy block install/remove |
| `--source <auto\|local\|web>` | value | Artifact + skills source selection (`auto` default; `local` derives repo path, `web` derives GitHub URL) |
| `--raw-base <url>` | value | Raw GitHub base URL for web source |
| `--dry-run` | switch | Print planned actions without writing |
| `--extras` | switch | Also install extras skills (duck-adapt, duck-grill, duck-tape) |
| `-h`, `--help` | switch | Show help |

## PowerShell CLI (`scripts/rubber-duck.ps1`)

Use PowerShell CLI for Windows-native environments.

| Parameter | Type | Description |
| --- | --- | --- |
| `-Action install\|uninstall\|status\|doctor` | value | Operation to execute |
| `-Claude` | switch | Use Claude paths (default global; add `-Project` for project scope) |
| `-Copilot` | switch | Use Copilot paths (default global; add `-Project` for project scope) |
| `-OpenCode` | switch | Use opencode paths (default global; add `-Project` for project scope) |
| `-Project` | switch | Apply project scope to selected target (and skills, unless `-SkipSkills`) |
| `-ClaudeMd <path>` | value | Claude target `CLAUDE.md` path override (default for `-Claude`; project default when `-Project` also set) |
| `-Branch <name>` | value | Branch to install from (default: `main`) |
| `-SkipSkills` | switch | Skip `npx skills add/remove/list` |
| `-SkipAgentsMd` | switch | Skip AGENTS.md policy block install/remove |
| `-Source auto\|local\|web` | value | Artifact + skills source selection (`auto` default; `local` derives repo path, `web` derives GitHub URL) |
| `-RawBase <url>` | value | Raw GitHub base URL for web source |
| `-Extras` | switch | Also install extras skills (duck-adapt, duck-grill, duck-tape) |

## Notes

### Optional local pre-commit hook

Enable repository-local pre-commit checks:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

Hook runs:

- `markdownlint-cli2` (via `npx`)
- broad scope with pragmatic rule profile (hygiene-first, style rules staged)
- `scripts/check-guardrails-drift.sh`
- `scripts/assemble-skills.sh --check`
- `scripts/build-harness-artifacts.sh --check`

### Mode and Flag Constraints

- `--claude-md` / `-ClaudeMd` requires `--claude` / `-Claude`.
- `--project` / `-Project` applies to whichever target flag is set (opencode, copilot, or claude). No target = opencode global.
- `--source` drives both artifact and skills source. `--skills-source` / `-SkillsSource` removed; installer derives skills source from `--source` + `--branch`.

### Target Path Behavior

- Claude target:
  - installs full duck set (router + ducklings)
  - global (default): writes/removes managed `~/.claude/CLAUDE.md` and sibling `~/.claude/AGENTS.md`
  - project (`--claude --project` / `-Claude -Project`): writes/removes managed project `CLAUDE.md` and sibling `AGENTS.md`
  - backups before mutation:
    - `CLAUDE.md.bak.<YYYYmmdd-HHMMSS>`
    - `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`
- Copilot target:
  - global (default): uses `~/.copilot/agents` + `~/.copilot/AGENTS.md`
  - project (`--copilot --project` / `-Copilot -Project`): uses `.github/agents` + project-root `AGENTS.md`
- OpenCode target:
  - installs full duck set (router + ducklings)
  - global (default): uses `~/.config/opencode/agents` + `~/.config/opencode/AGENTS.md`
  - project (`--opencode --project` / `-OpenCode -Project`): uses `.opencode/agents` + project-root `AGENTS.md`

- OpenCode targets:
  - use managed block markers in AGENTS.md
  - backup before mutation: `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`

### Installation Behavior

- Installer supports web invocation:
  - Bash: `curl .../scripts/rubber-duck.sh | bash -s -- <command>`
  - PowerShell: download script then execute.
- Skills install default: global (`npx skills add <source> -y -g`).
- Project scope for both target and skills via `--project` (bash) / `-Project` (PowerShell). Skills scope follows target scope unless `--skip-skills` / `-SkipSkills`.

### Skills Sets

Default skills (11) match `.claude-plugin/plugin.json`: quack, duck-debt, duck-debug, duck-design, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage.

Extras skills (3): duck-adapt, duck-grill, duck-tape. Installed only with `--extras` (bash) / `-Extras` (PowerShell). Optional by default.

`uninstall` removes all 14 skills (default + extras) regardless of flag so no orphan skills remain. `status` reports extras separately as optional (present/missing count).
