# Rubber Duck Scripts

CLI reference for install/update/uninstall tooling.

## Scripts

- `scripts/rubber-duck.sh` — Bash installer/manager (local + web-compatible)
- `scripts/rubber-duck.ps1` — PowerShell installer/manager (Windows)

## Commands

| Command | Purpose |
|---|---|
| `install` | Install/update agents, managed policy file, and skills package |
| `uninstall` | Remove installed agents, remove managed policy file, remove skills package |
| `status` | Show installed agent count, policy state, and skills state |
| `doctor` | Validate target paths and required tooling |

## Bash CLI (`scripts/rubber-duck.sh`)

| Flag | Type | Description |
|---|---|---|
| `--opencode` | switch | Use preconfigured opencode paths |
| `--claude` | switch | Use project-default Claude paths (`.claude/agents` + `CLAUDE.md` + sibling `AGENTS.md`) |
| `--agents-dir <path>` | value | Generic target agent directory |
| `--agents-md <path>` | value | Generic target AGENTS.md file path |
| `--claude-md <path>` | value | Claude target `CLAUDE.md` path override (default: `./CLAUDE.md`) |
| `--skip-skills` | switch | Skip `npx skills add/remove/list` |
| `--project-skills` | switch | Install skills in project scope (default uses global `npx -g`) |
| `--skills-source <url-or-path>` | value | Override skills package source |
| `--source <auto\|local\|web>` | value | Artifact source selection (`auto` default) |
| `--raw-base <url>` | value | Raw GitHub base URL for web source |
| `--dry-run` | switch | Print planned actions without writing |
| `-h`, `--help` | switch | Show help |

## PowerShell CLI (`scripts/rubber-duck.ps1`)

| Parameter | Type | Description |
|---|---|---|
| `-Action install\|uninstall\|status\|doctor` | value | Operation to execute |
| `-OpenCode` | switch | Use preconfigured opencode paths |
| `-Claude` | switch | Use project-default Claude paths (`.claude/agents` + `CLAUDE.md` + sibling `AGENTS.md`) |
| `-AgentsDir <path>` | value | Generic target agent directory |
| `-AgentsMd <path>` | value | Generic target AGENTS.md file path |
| `-ClaudeMd <path>` | value | Claude target `CLAUDE.md` path override (default: `./CLAUDE.md`) |
| `-SkipSkills` | switch | Skip `npx skills add/remove/list` |
| `-ProjectSkills` | switch | Install skills in project scope (default uses global `npx -g`) |
| `-SkillsSource <url-or-path>` | value | Override skills package source |
| `-Source auto\|local\|web` | value | Artifact source selection (`auto` default) |
| `-RawBase <url>` | value | Raw GitHub base URL for web source |

## Notes

- Generic target requires agents dir + AGENTS.md path.
- OpenCode/generic targets:
  - install full duck set (router + ducklings)
  - use managed block markers in AGENTS.md
  - backup before mutation: `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`
- Claude target:
  - installs full duck set (router + ducklings)
  - writes/removes managed `CLAUDE.md` and sibling `AGENTS.md` files
  - backups before mutation:
    - `CLAUDE.md.bak.<YYYYmmdd-HHMMSS>`
    - `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`
- Installer supports web invocation:
  - Bash: `curl .../scripts/rubber-duck.sh | bash -s -- <command>`
  - PowerShell: download script then execute.
- Skills install default: global (`npx skills add <source> -y -g`).
- Use project scope only when explicitly requested:
  - Bash: `--project-skills`
  - PowerShell: `-ProjectSkills`
