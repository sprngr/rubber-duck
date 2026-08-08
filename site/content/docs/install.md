---
title: Install
---

# Install

Rubber Duck ships as an installer script (bash + PowerShell). It sets up the agent policy + skills for your harness of choice: **opencode**, **claude**, or **copilot**.

## Prerequisites

- `bash` or PowerShell 7+
- `node` + `npx` (for skills install)
- `jq` (bash only)

## Web install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode
```

Swap `--opencode` for `--claude` or `--copilot` for other harnesses. Add `--project` for project-scope install (default is global user scope).

## Local install (from repo checkout)

```bash
git clone https://github.com/sprngr/rubber-duck.git
cd rubber-duck
./scripts/rubber-duck.sh install --opencode --source local
```

Use this when developing rubber-duck itself or testing changes.

## Extras

Default install skips optional skills. Add them with `--extras`:

```bash
./scripts/rubber-duck.sh install --opencode --extras
```

Extras: `duck-adapt`, `duck-grill`, `duck-tape`. If you install `duck-tape`, initialize session memory once: `duck-tape init`.

## PowerShell equivalent

```powershell
./scripts/rubber-duck.ps1 install -OpenCode -Extras
```

Bash and PowerShell installers stay in feature parity — same flags, same behavior.
