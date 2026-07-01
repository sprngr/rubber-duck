# Rubber Duck 🦆

Socratic assistant operating system for developers who want **better quality decisions**, not blind automation.

Rubber Duck helps you debug, review, design, and triage with structured questioning, evidence-first routing, and explicit safety guardrails.

## Why

Initially Rubber Duck started as my attempt to build a better debugger. I used the first versions to do pre-reviews before submitting code.
As time went on I found myself letting the model do more and more work. I would attend meetings where my team and myself realized decisions were being made
that we weren't actually aware were included in our own work being put up for review. We sacrificed understanding in favor of speed of output.

This is my attempt to flip the current practice and lean even harder into "human in the loop".

Most assistant setups optimize for speed-to-output. Rubber Duck optimizes for:

- decision quality,
- developer understanding,
- safe, bounded change,
- reduced rework from shallow fixes.

Core idea: keep human in control, keep reasoning explicit. We're reducing rework by increasing understanding and decisions before they are executed.

### Who this is for

- If you are a developer who want an assistant that sharpens thinking without taking over by keeping you in the driver seat.

### Who this is not for

- If you want fully autonomous, no-checkpoint, end-to-end automated runs with minimal human involvement, this project is likely not a fit.

### Does it actually work better?

- Depends on your definition of better, but I feel like I actually know what is going on.

## Philosophy Guardrails

Every skill is bound by the corresponding philosophy:

- Decision ownership: developer selects tradeoff; this skill frames options and consequences.
- Ask-before-act: ask clarifying scoping questions before recommendations.
- Evidence-first: ground recommendations in explicit system constraints and known behavior.
- Bounded approval: implementation actions require explicit user approval and scoped handoff.
- Safety carve-outs: never trade away trust-boundary validation, security, data-loss prevention, accessibility, or explicit requirements.

## Quick skill-only install

```bash
npx skills add https://github.com/sprngr/rubber-duck
```
For more options with `npx skills` see the [vercel-labs/skills](https://github.com/vercel-labs/skills) repository.

## Full Rubber Duck agent system (Installer/Updater & Uninstaller)

Installer has default behavior making assumptions about system, targeting global skills install and universal agent skills directory.

If you require a different path for your setup, use the `--skip-skills` argument and run `npx skills add` separately.

CLI reference: [scripts/README.md](./scripts/README.md)

### One-line installer (matrix)

| Target | Bash (macOS/Linux) | PowerShell (Windows) |
|---|---|---|
| Generic (custom harness paths) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --agents-dir /path/to/harness/agents --agents-md /path/to/harness/AGENTS.md` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p install -AgentsDir C:\path\to\harness\agents -AgentsMd C:\path\to\harness\AGENTS.md` |
| OpenCode (preconfigured) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --opencode` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p install -OpenCode` |
| Claude Code (global defaults) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --claude` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p install -Claude` |
| Claude Code (project paths) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --claude-project` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p install -ClaudeProject` |

Project-scoped skills instead of global:

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode --project-skills
```

```powershell
$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p install -OpenCode -ProjectSkills
```

## Local installer

Checkout repo locally, then use installer script.

### Local usage patterns

```bash
# install
./scripts/rubber-duck.sh install <target-flags>

# uninstall
./scripts/rubber-duck.sh uninstall <target-flags>

# status
./scripts/rubber-duck.sh status <target-flags>

# doctor
./scripts/rubber-duck.sh doctor <target-flags>
```

Target flags:

- Generic: `--agents-dir /path/to/harness/agents --agents-md /path/to/harness/AGENTS.md`
- OpenCode: `--opencode`
- Claude (global): `--claude` (optional: `--claude-md ~/.claude/CLAUDE.md`)
- Claude (project): `--claude-project` (optional: `--claude-md ./docs/CLAUDE.md`)

Mode constraints:

- `--claude-md` requires `--claude` or `--claude-project`.
- `--claude` and `--claude-project` are mutually exclusive.

Notes:
- script copies agent files to target directory
- AGENTS policy is appended/removed via managed block markers
- Claude target upserts/removes a managed block in both `CLAUDE.md` and its sibling `AGENTS.md` (existing user content in those files is preserved)
- use `--skip-skills` if you only need agents + AGENTS policy changes
- use `--dry-run` to print planned actions + AGENTS.md diff preview without writing
- install/uninstall always creates policy backup in same dir: `<policy>.bak.<YYYYmmdd-HHMMSS>`

### Target behavior matrix (simplified)

| Target | Agents installed to | Policy behavior on install | Policy behavior on uninstall | Backups |
|---|---|---|---|---|
| `--opencode` | `~/.config/opencode/agents` | Upsert managed block in `~/.config/opencode/AGENTS.md` | Remove managed block from `~/.config/opencode/AGENTS.md` | `AGENTS.md.bak.<ts>` |
| generic (`--agents-dir` + `--agents-md`) | your `--agents-dir` | Upsert managed block in your `--agents-md` | Remove managed block from your `--agents-md` | `<agents-md>.bak.<ts>` |
| `--claude` | `~/.claude/agents` (or custom via `--claude-md`) | Upsert managed block in `~/.claude/CLAUDE.md` and sibling `~/.claude/AGENTS.md` | Remove managed block from each; user content preserved | `CLAUDE.md.bak.<ts>` and `AGENTS.md.bak.<ts>` |
| `--claude-project` | `./.claude/agents` (or custom via `--claude-md`) | Upsert managed block in project `CLAUDE.md` and sibling `AGENTS.md` | Remove managed block from each; user content preserved | `CLAUDE.md.bak.<ts>` and `AGENTS.md.bak.<ts>` |

Claude target installs the full duck set (router + ducklings), not router-only.

## Verify after install

Use this to quickly validate behavior and fit in your own workflow.

### Step 0: Enable Rubber Duck Agent

Rubber Duck can run two ways. The distinction matters most on Claude Code:

- **As a subagent (on demand):** invoke it from inside an existing session — `@🦆` (OpenCode) or `@agent-rubber-duck` (Claude), or via your harness dropdown. Spawned per request; the router greeting does not auto-run.
- **As the main agent (whole session):** the duck *is* the session and routes from the first turn.
  - Claude Code: `claude --agent rubber-duck`, or set `"agent": "rubber-duck"` in `.claude/settings.json` (project) or `~/.claude/settings.json` (global). The startup header shows `@rubber-duck` to confirm, and the router greeting (`initialPrompt`) auto-runs on the first turn. The `--agent` flag overrides the setting when both are present.
  - OpenCode: select `🦆` as the primary agent (its `mode: all` allows primary use).

Either way the agent must already be installed for your target (see install matrix above).

### Step 1: heartbeat check

Prompt:

```text
quack
```

Expected:
- duck status response (router active).

### Step 2: review behavior check

Prompt:

```text
Review this snippet for correctness and simplification:

function parseAge(input) {
  return Number(input) || 0;
}
```

Expected:
- risk-aware findings first,
- concrete fix direction,
- no silent code edits.

### Step 3: debug behavior check

Prompt:

```text
My endpoint returns 500 when userId is missing. Help me debug this.
```

Expected:
- clarifying questions first,
- evidence-first reasoning,
- explicit handoff/approval before implementation.

## Deep dive docs

### Start here

- [Architecture index](./docs/architecture/README.md)
- [Philosophy](./docs/architecture/01-philosophy.md)
- [Agent + skill model](./docs/architecture/02-agent-skill-model.md)
- [Adaptive Socratic policy](./docs/architecture/03-adaptive-socratic-policy.md)
- [Validation prompt suite](./docs/validation/README.md)

### Prompt contracts

- Router + subagents: [`agents/`](./agents)
- Skills: [`skills/`](./skills)

## Attribution

Rubber Duck is inspired by its [namesake](https://rubberduckdebugging.com/) and the philosophy of talking to the duck to determine your problem and arrive at your own solution; except this one can actually talk back and ask really good questions.

Rubber Duck adopted terse language and the review structure inspired by [Caveman](https://github.com/JuliusBrussee/caveman), though token reduction slowly stopped being the primary goal as it took on a life of its own.

Part of Rubber Duck operating model adapt ideas from [Ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert.

### Concept mapping (Ponytail → Rubber Duck adaptation)

- **Lazy ladder / first-rung decision policy**  
  Ponytail: YAGNI → reuse → stdlib → native → installed dep → minimal code.  
  Rubber Duck: shared “Duck Ladder” added across `duck-debug`, `duck-review`, `duck-triage`, `duck-design`, `duck-teach`, `duck-explain`.

- **Root cause over symptom patching**  
  Ponytail: fix shared path once, not caller-by-caller.  
  Rubber Duck: `duck-debug` root-cause locality + caller-map-before-patch guidance.

- **Overengineering review taxonomy**  
  Ponytail: `delete/stdlib/native/yagni/shrink` review lens.  
  Rubber Duck: simplification prefixes (`🪶 yagni`, `📚 stdlib`, `🧱 native`, `✂️ shrink`, `🗑️ delete`) in `duck-review` and `duck-simple`.

- **Risk-first precedence during review**  
  Ponytail: simplification never at expense of safety/correctness.  
  Rubber Duck: reviewer merge order and prefix precedence enforce security/correctness first.

- **Minimum-check discipline**  
  Ponytail: non-trivial logic leaves one runnable check.  
  Rubber Duck: `duck-triage` minimum runnable check rule.

- **Deferred simplification ledger**  
  Ponytail: `ponytail:` debt markers and debt harvesting.  
  Rubber Duck: `duck-debt:` marker convention + `duck-debt` skill for read-only debt ledger.

- **Safety carve-outs**  
  Ponytail: never simplify away trust-boundary validation, security, data-loss prevention, accessibility.  
  Rubber Duck: mirrored in repo [AGENTS policy](AGENTS.md) minimal-change discipline and skill policy text.
