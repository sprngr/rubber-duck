# Rubber Duck Scripts

CLI reference for install/update/uninstall tooling.

## Quick Start

```bash
# Build generated harness artifacts (includes guardrails sync)
make build

# Verify guardrails + generated artifacts are up to date
make check-harness

# Install agents (example: project OpenCode target)
./scripts/rubber-duck.sh install --opencode-project
```

## Build Targets (Make)

| Target | Purpose |
|---|---|
| `make sync-guardrails` | Copy `skills/_shared/GUARDRAILS.md` into each `skills/duck-*/references/GUARDRAILS.md` |
| `make check-guardrails` | Verify no drift between canonical and vendored guardrails |
| `make build-harness` | Build harness artifacts into `dist/*` |
| `make check-harness` | Verify guardrails drift + harness artifacts are up to date |
| `make build` | Sync guardrails, then build harness artifacts |
| `make check` | Check guardrails drift, then check harness artifacts |

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
- Build mode syncs vendored guardrails before rendering.
- Check mode validates guardrails drift before artifact freshness checks.

## Scripts

- `scripts/rubber-duck.sh` — Bash installer/manager (local + web-compatible)
- `scripts/rubber-duck.ps1` — PowerShell installer/manager (Windows)
- `scripts/build-harness-artifacts.sh` — render harness artifacts into `dist/*` from `agents/*` config/body sources
- `scripts/sync-guardrails.sh` — sync canonical shared guardrails to each duck skill vendored reference
- `scripts/check-guardrails-drift.sh` — fail if vendored guardrails drift from canonical

## Commands

| Command | Purpose |
|---|---|
| `install` | Install/update agents, managed policy file, and skills package |
| `uninstall` | Remove installed agents, remove managed policy file, remove skills package |
| `status` | Show installed agent count, policy state, and skills state |
| `doctor` | Validate target paths and required tooling |

## Bash CLI (`scripts/rubber-duck.sh`)

Use Bash CLI for Linux/macOS and shell-based CI.

| Flag | Type | Description |
|---|---|---|
| `--claude` | switch | Use global Claude paths (`~/.claude/agents` + `~/.claude/CLAUDE.md` + sibling `~/.claude/AGENTS.md`) |
| `--claude-project` | switch | Use project Claude paths (`.claude/agents` + `CLAUDE.md` + sibling `AGENTS.md`) |
| `--copilot` | switch | Use global Copilot paths (`~/.copilot/agents` + `~/.copilot/AGENTS.md`) |
| `--copilot-project` | switch | Use project Copilot paths (`.github/agents` + project-root `AGENTS.md`) |
| `--opencode` | switch | Use preconfigured opencode paths |
| `--opencode-project` | switch | Use project opencode paths (`.opencode/agents` + project-root `AGENTS.md`) |
| `--claude-md <path>` | value | Claude target `CLAUDE.md` path override (global default for `--claude`, project default for `--claude-project`) |
| `--skip-skills` | switch | Skip `npx skills add/remove/list` |
| `--project-skills` | switch | Install skills in project scope (default uses global `npx -g`) |
| `--skills-source <url-or-path>` | value | Override skills package source |
| `--source <auto\|local\|web>` | value | Artifact source selection (`auto` default) |
| `--raw-base <url>` | value | Raw GitHub base URL for web source |
| `--dry-run` | switch | Print planned actions without writing |
| `-h`, `--help` | switch | Show help |

## PowerShell CLI (`scripts/rubber-duck.ps1`)

Use PowerShell CLI for Windows-native environments.

| Parameter | Type | Description |
|---|---|---|
| `-Action install\|uninstall\|status\|doctor` | value | Operation to execute |
| `-Claude` | switch | Use global Claude paths (`~/.claude/agents` + `~/.claude/CLAUDE.md` + sibling `~/.claude/AGENTS.md`) |
| `-ClaudeProject` | switch | Use project Claude paths (`.claude/agents` + `CLAUDE.md` + sibling `AGENTS.md`) |
| `-Copilot` | switch | Use global Copilot paths (`~/.copilot/agents` + `~/.copilot/AGENTS.md`) |
| `-CopilotProject` | switch | Use project Copilot paths (`.github/agents` + project-root `AGENTS.md`) |
| `-OpenCode` | switch | Use preconfigured opencode paths |
| `-OpenCodeProject` | switch | Use project opencode paths (`.opencode/agents` + project-root `AGENTS.md`) |
| `-ClaudeMd <path>` | value | Claude target `CLAUDE.md` path override (global default for `-Claude`, project default for `-ClaudeProject`) |
| `-SkipSkills` | switch | Skip `npx skills add/remove/list` |
| `-ProjectSkills` | switch | Install skills in project scope (default uses global `npx -g`) |
| `-SkillsSource <url-or-path>` | value | Override skills package source |
| `-Source auto\|local\|web` | value | Artifact source selection (`auto` default) |
| `-RawBase <url>` | value | Raw GitHub base URL for web source |

## Notes

### Mode and Flag Constraints

- `--claude-md` / `-ClaudeMd` requires Claude mode:
  - Bash: `--claude` or `--claude-project`
  - PowerShell: `-Claude` or `-ClaudeProject`
- Do not combine global and project Claude modes in one command:
  - Bash: `--claude` and `--claude-project` are mutually exclusive
  - PowerShell: `-Claude` and `-ClaudeProject` are mutually exclusive
- Do not combine global and project Copilot modes in one command:
  - Bash: `--copilot` and `--copilot-project` are mutually exclusive
  - PowerShell: `-Copilot` and `-CopilotProject` are mutually exclusive
- Do not combine global and project OpenCode modes in one command:
  - Bash: `--opencode` and `--opencode-project` are mutually exclusive
  - PowerShell: `-OpenCode` and `-OpenCodeProject` are mutually exclusive

### Target Path Behavior

- Claude target:
  - installs full duck set (router + ducklings)
  - global mode: writes/removes managed `~/.claude/CLAUDE.md` and sibling `~/.claude/AGENTS.md`
  - project mode (`--claude-project` / `-ClaudeProject`): writes/removes managed project `CLAUDE.md` and sibling `AGENTS.md`
  - backups before mutation:
    - `CLAUDE.md.bak.<YYYYmmdd-HHMMSS>`
    - `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`
- Copilot target:
  - global mode: uses `~/.copilot/agents` + `~/.copilot/AGENTS.md`
  - project mode (`--copilot-project` / `-CopilotProject`): uses `.github/agents` + project-root `AGENTS.md`
- OpenCode target:
  - installs full duck set (router + ducklings)
  - global mode: uses `~/.config/opencode/agents` + `~/.config/opencode/AGENTS.md`
  - project mode (`--opencode-project` / `-OpenCodeProject`): uses `.opencode/agents` + project-root `AGENTS.md`

- OpenCode targets:
  - use managed block markers in AGENTS.md
  - backup before mutation: `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`

### Installation Behavior

- Installer supports web invocation:
  - Bash: `curl .../scripts/rubber-duck.sh | bash -s -- <command>`
  - PowerShell: download script then execute.
- Skills install default: global (`npx skills add <source> -y -g`).
- Use project scope only when explicitly requested:
  - Bash: `--project-skills`
  - PowerShell: `-ProjectSkills`
