# Rubber Duck Scripts

CLI reference for install/update/uninstall tooling.

## Quick Start

```bash
# Install agents (example: project OpenCode target)
./scripts/rubber-duck.sh install --opencode --project

# Install using harness selector (single target)
./scripts/rubber-duck.sh install --harness "opencode" --project
```

`--project` scope is the default; pass `--global` for user-wide install.

Agent selection is straightforward:
- `rubber-duck.md` is installed as the agent file
- AGENTS.md is always installed (version marker)
- destination filename is `rubber-duck.md`

Sync targets from a manifest:

```bash
# Install/update enabled targets from project manifest
./scripts/rubber-duck.sh sync --project

# Also remove managed targets not enabled in the manifest
./scripts/rubber-duck.sh sync --project --prune
```

Generated sync helpers (created during `install`):

- project scope:
  - `.rubber-duck/sync-latest.sh`
  - `.rubber-duck/sync-latest.ps1`
- global scope:
  - `~/.config/rubber-duck/sync-latest.sh`
  - `~/.config/rubber-duck/sync-latest.ps1`

Behavior:
- check for newer version before syncing (compares manifest `lastAppliedVersion` against remote/local `VERSION`)
- if newer version available, prompt with version change and CHANGELOG link
- run matching installer source used during install:
  - local install source -> local installer path from current checkout
  - web install source -> downloaded installer from configured raw base
- run `sync` with matching scope (`--project/--global` or `-Project/-Global`)
- remove downloaded temp installer on exit (web mode)

Examples:

```bash
# project scope helper
.rubber-duck/sync-latest.sh

# project scope helper with prune
.rubber-duck/sync-latest.sh --prune
```

```powershell
# project scope helper
pwsh -NoProfile -File .rubber-duck/sync-latest.ps1

# project scope helper with prune
pwsh -NoProfile -File .rubber-duck/sync-latest.ps1 -Prune
```

## Commands

| Command | Purpose |
| --- | --- |
| `install` | Install/update agents, managed policy file, and skills package |
| `uninstall` | Remove installed agents, remove managed policy file, remove skills package |
| `status` | Show installed agent count, policy state, and skills state |
| `doctor` | Validate target paths and required tooling |
| `sync` | Install/update targets enabled in manifest; with `--prune`, remove managed targets not in manifest |

## Tailoring Flags

Opt out of default install steps or adjust source to fit your workflow. All optional.

| Flag (Bash) | Flag (PowerShell) | Effect |
| --- | --- | --- |
| `--skip-skills` | `-SkipSkills` | Skip `npx skills add/remove/list` |
| `--dry-run` | `-DryRun` | Print planned actions without writing |
| `--prune` | `-Prune` | With `sync`: remove managed targets not enabled in manifest |
| `--source <auto\|local\|web>` | `-Source auto\|local\|web` | Pick artifact + skills source (`auto` default) |
| `--branch <name>` | `-Branch <name>` | Install from non-`main` branch |
| `--extras` | `-Extras` | Also install extras skills (duck-adapt, duck-grill, duck-tape, duck-tidy) |
| `--session-hook` | `-SessionHook` | Also install the session-start hook (guarantees duck-policy loads at session start) |
| `--allow-untrusted-source` | `-AllowUntrustedSource` | Skip `rawBase` allowlist check (dangerous; forks/mirrors) |

## Bash CLI (`scripts/rubber-duck.sh`)

Use Bash CLI for Linux/macOS and shell-based CI.

| Flag | Type | Description |
| --- | --- | --- |
| `--harness <list>` | value | Comma-separated harness list (`opencode,copilot,claude`) |
| `--claude` | switch | Use Claude paths (required target; pick exactly one of `--claude/--copilot/--opencode`) |
| `--copilot` | switch | Use Copilot paths (required target; pick exactly one of `--claude/--copilot/--opencode`) |
| `--opencode` | switch | Use opencode paths (required target; pick exactly one of `--claude/--copilot/--opencode`) |
| `--global`  | switch | Apply global scope to selected target (opt into global; skills follow unless `--skip-skills`) |
| `--project` | switch | Apply project scope to selected target (default; skills follow unless `--skip-skills`) |
| `--branch <name>` | value | Branch to install from (default: `main`; pass explicitly for non-main installs) |
| `--skip-skills` | switch | Skip `npx skills add/remove/list` |
| `--source <auto\|local\|web>` | value | Artifact + skills source selection (`auto` default; `local` derives repo path, `web` derives GitHub URL) |
| `--raw-base <url>` | value | Raw GitHub base URL for web source |
| `--prune` | switch | With `sync`, uninstall managed targets not enabled in manifest |
| `--dry-run` | switch | Print planned actions without writing |
| `--extras` | switch | Also install extras skills (duck-adapt, duck-grill, duck-tape, duck-tidy) |
| `--session-hook` | switch | Also install the session-start hook for the selected target |
| `--allow-untrusted-source` | switch | Skip `rawBase` allowlist check (dangerous; forks/custom mirrors) |
| `-h`, `--help` | switch | Show help |

## PowerShell CLI (`scripts/rubber-duck.ps1`)

Use PowerShell CLI for Windows-native environments.

| Parameter | Type | Description |
| --- | --- | --- |
| `-Action install\|uninstall\|status\|doctor\|sync` | value | Operation to execute |
| `-Harness <list>` | value | Comma-separated harness list (`opencode,copilot,claude`) |
| `-Claude` | switch | Use Claude paths (required target; pick exactly one of `-Claude/-Copilot/-OpenCode`) |
| `-Copilot` | switch | Use Copilot paths (required target; pick exactly one of `-Claude/-Copilot/-OpenCode`) |
| `-OpenCode` | switch | Use opencode paths (required target; pick exactly one of `-Claude/-Copilot/-OpenCode`) |
| `-Global` | switch | Apply global scope to selected target (opt into global; skills follow unless `-SkipSkills`) |
| `-Project` | switch | Apply project scope to selected target (default; skills follow unless `-SkipSkills`) |
| `-Branch <name>` | value | Branch to install from (default: `main`) |
| `-SkipSkills` | switch | Skip `npx skills add/remove/list` |
| `-Source auto\|local\|web` | value | Artifact + skills source selection (`auto` default; `local` derives repo path, `web` derives GitHub URL) |
| `-RawBase <url>` | value | Raw GitHub base URL for web source |
| `-Prune` | switch | With `sync`, uninstall managed targets not enabled in manifest |
| `-DryRun` | switch | Print planned actions without writing |
| `-Extras` | switch | Also install extras skills (duck-adapt, duck-grill, duck-tape, duck-tidy) |
| `-SessionHook` | switch | Also install the session-start hook for the selected target |
| `-AllowUntrustedSource` | switch | Skip `rawBase` allowlist check (dangerous; forks/custom mirrors) |

## Installation Behavior

- Install writes lightweight sync helpers into `.rubber-duck/` (project) or `~/.config/rubber-duck/` (global). Helpers are convenience wrappers only; they do not create local repo checkouts.
- Agent file: `rubber-duck.md` is installed as the agent file in the target agents directory.
- AGENTS.md: always installed as a version marker.

- Installer supports web invocation:
  - Bash: `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh <command>`
  - PowerShell: download script then execute.
- For non-`main` sources, pass `--branch <name>` / `-Branch <name>` explicitly.
  - Fresh install seeds the manifest from `dist/templates/manifest.template.json` when running against a local checkout; web installs use built-in defaults.
- Backup retention: before mutating a managed policy file (`AGENTS.md`, `CLAUDE.md`), the installer writes a `<file>.bak.<YYYYmmdd-HHMMSS>` copy alongside it. Only the most recent `<file>.bak.*` is kept per policy file; prior backups are pruned on install/uninstall to avoid accumulation. Applies to both bash and PowerShell installers.
- Skills install default: project (`npx skills add <source> -y`).
- `status` reports canonical version parsed from managed AGENTS artifact marker.

### Session-start hook (--session-hook / -SessionHook)

Opt-in feature that deterministically causes the `rubber-duck` agent to load the
`duck-policy` skill at session start. Installs harness-specific session-start
hooks:

- OpenCode: copies the plugin to `.opencode/plugins/session-start.js` and the
  directive to `.opencode/session-start.directive.md`. The plugin registers
  rubber-duck sessions and injects the directive into the system prompt on every
  model call (`experimental.chat.system.transform`).
- Claude Code: copies scripts to `.claude/hooks/` and merges a `SessionStart`
  hook into `.claude/settings.local.json` (idempotent). Runs only when launched
  with the rubber-duck agent (`claude --agent <rubber-duck>`), which the script
  detects via the hook input `agent_type`.

The rubber-duck agent body keeps its own Enforcement Bootstrap mandate as a
fallback when the hook is not installed.

Example:
```bash
scripts/rubber-duck.sh install --opencode --project --session-hook
scripts/rubber-duck.sh install --claude --project --session-hook
```

`sync` replays the hook per target (tracked in the manifest `sessionHook` field).
- `sync` behavior:
  - reads manifest:
    - project: `.rubber-duck/manifest.json`
    - global: `~/.config/rubber-duck/manifest.json`
  - installs/updates enabled targets
  - with `--prune` / `-Prune`, uninstalls managed targets not enabled in manifest

### Manifest & Local State

- Manifest paths:
  - project: `.rubber-duck/manifest.json`
  - global: `~/.config/rubber-duck/manifest.json`
- `sync` reads manifest from the scope you invoke it with. Run `sync --project` / `-Project` from the project root that owns the manifest.
- `rawBase` guardrail:
  - defaults to the canonical prefix `https://raw.githubusercontent.com/sprngr/rubber-duck`; helps avoid accidentally pointing at a fork or mistyped URL
  - override with `--allow-untrusted-source` / `-AllowUntrustedSource` (emits warning) when installing from a fork or mirror
- Artifact pinning (SHA-256), used as a change log and skip-unchanged optimization:
  - `install` writes a `pins` block with hashes of installed agent files and policy artifact
  - on subsequent `install`, agent files with matching destination hash are skipped (no rewrite, mtime preserved)
  - the `pins` block is refreshed after each install so it always reflects what is on disk
  - inspect `.rubber-duck/manifest.json` to see what content is currently installed
- Version downgrade:
  - warns when the manifest's `lastAppliedVersion` is newer than the incoming release
  - warning only; does not block the install
- Multi-target install (`--harness "opencode,claude"` / multi-target `-Harness`) shares one `source` block in the manifest. Mixing `--source local` and `--source web` across a single invocation results in last-wins for the `source` block; artifact `pins` are per-artifact and remain accurate.

### Skills Sets

Default skills (12) match `build/skill-assembly.rules.json`: quack, duck-policy, duck-debt, duck-debug, duck-design, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage.

Extras skills (4): duck-adapt, duck-grill, duck-tape, duck-tidy. Installed only with `--extras` (bash) / `-Extras` (PowerShell). Optional by default.

`uninstall` removes all 16 skills (default + extras) regardless of flag so no orphan skills remain. `status` reports extras separately as optional (present/missing count).

Skills install scope: each install/uninstall run passes `-a <agent>` for every selected harness (`opencode`, `github-copilot`, `claude-code`), so skills only land in the harnesses you asked for. Multi-target invocations collapse to a single `npx skills` call.

## Developer Tooling

### Build Targets (Make)

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

### Harness Artifact Build Script

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
- Requires root `VERSION` file (`vX.Y.Z`) as canonical release value for generated artifacts.
- Check mode validates guardrails drift before artifact freshness checks.
- Agent source-of-truth is `src/agents/*`.
- Model details (per-harness metadata, renderer boundary, adding a new harness): [docs/architecture/05-harness-agent-config.md](../docs/architecture/05-harness-agent-config.md).

### Skill Assembly Script

`scripts/assemble-skills.sh` supports:

- build mode (default): copy-through from `src/skills/*` to `skills/*`
- check mode (`--check`): fail on stale/missing artifacts and portability deny-token violations

Examples:

```bash
bash scripts/assemble-skills.sh
bash scripts/assemble-skills.sh --check
```

Contract details (rules schema, drift controls, invariants): [docs/architecture/06-skill-assembly-contract.md](../docs/architecture/06-skill-assembly-contract.md).

### Scripts

- `scripts/rubber-duck.sh` — Bash installer/manager (local + web-compatible)
- `scripts/rubber-duck.ps1` — PowerShell installer/manager (Windows)
- `scripts/assemble-skills.sh` — assemble `src/skills/*` into install artifacts under `skills/*` (`--check` verifies drift + portability lint)
- `scripts/build-harness-artifacts.sh` — render harness artifacts into `dist/*` from `src/agents/*` config/body sources
- `scripts/check-guardrails-drift.sh` — fail if vendored guardrails drift from canonical

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
