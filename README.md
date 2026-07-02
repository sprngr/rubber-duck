# Rubber Duck 🦆

Socratic assistant operating system for developers who want **better quality decisions**, not blind automation.

Rubber Duck helps you debug, review, design, and triage with structured questioning, evidence-first routing, and explicit safety guardrails.

## Quick start

### Quick skills-only install

```bash
npx skills add https://github.com/sprngr/rubber-duck
```

Use this when you only want skills built with the [Rubber Duck philosophy](#philosophy-guardrails).

For raw `npx skills` usage, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

### Full Rubber Duck agent system (Installer / Updater / Uninstaller)

Use the installer scripts for managed agent + policy setup. Adds all `duck-*` skills required by the router and duckling subagents.

Full CLI/options are documented in: [scripts/README.md](./scripts/README.md) (canonical).

#### Minimal install examples

| Target | Bash (macOS/Linux) | PowerShell (Windows) |
|---|---|---|
| Claude (global) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --claude` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p -Action install -Claude` |
| Copilot (global) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --copilot` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p -Action install -Copilot` |
| OpenCode (global) | `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh \| bash -s -- install --opencode` | `$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p -Action install -OpenCode` |

Project-scoped skills (instead of global):

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode --project-skills
```

```powershell
$p = Join-Path $env:TEMP "rubber-duck.ps1"; irm https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.ps1 -OutFile $p; & $p -Action install -OpenCode -ProjectSkills
```

For generic/custom paths, uninstall, status, doctor, mode constraints, and all flags, see [scripts/README.md](./scripts/README.md).

## Verify after install

Use this to quickly validate behavior and fit in your own workflow.

### Step 0: Enable Rubber Duck Agent

Rubber Duck can run two ways:

- **As the main agent (whole session):** the duck *is* the session and routes from the first turn.
  - **Claude Code**: `claude --agent rubber-duck`, or set `"agent": "rubber-duck"` in `.claude/settings.json` (project) or `~/.claude/settings.json` (global). The startup header shows `@rubber-duck` to confirm, and the router greeting (`initialPrompt`) auto-runs on the first turn. The `--agent` flag overrides the setting when both are present.
  - **Copilot CLI**: `copilot --agent rubber-duck`, or select `rubber-duck` through the `/agent` menu - it will appear in the status bar as `🦆`. This is to avoid confusion with the built in [rubber-duck agent](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/rubber-duck).
  - **Copilot VS Code**: select `🦆` from the agent menu, the argument hint should display 'Quack.' to show it's ready.
  - **OpenCode**: `opencode --agent 🦆` (recommended to assign to alias) or select `🦆` as the primary agent (its `mode: all` allows primary use) through the `/agents` menu or keyboard shortcut (default: tab).

> [!NOTE]
> All duckling subagents (ex: `duck-reviewer`, `duck-adversary`) can be invoked in the same manner outlined below.

- **As a subagent (on demand):** invoke it from inside an existing session —
  - **Claude Code**: `@agent-rubber-duck <prompt>`.
  - **Copilot CLI & VS Code**: `#runSubagent @rubber-duck <prompt>`.
  - **OpenCode**: `@🦆 <prompt>` (use the autocomplete menu that appears to pick the name).

Either way the agent must already be installed for your target (see install section above).

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

## Positioning and intent

### Why

I built Rubber Duck after noticing something in my own agent-assisted workflow: I could ship code faster, but I didn’t always feel like I fully understood the decisions behind it.

The same pattern kept showing up — the model would make implicit assumptions or design calls, and I’d only catch them later during review, cleanup, or when explaining the work to someone else.

Rubber Duck is my way of flipping that tradeoff. It prioritizes:

- decision quality,
- developer understanding,
- safe, bounded change,
- reduced rework.

Core idea: keep humans in control and make reasoning explicit before execution.

### Who this is for

- This is for you if you want an assistant that helps you think more clearly, challenge assumptions, and keeps decision ownership with you — not the model.

### Who this is not for

- This is probably not a fit if you want fully autonomous, end-to-end execution with minimal checkpoints or human involvement.

### Does it actually work better?

For me, yes — because “better” is not raw speed; it’s leaving a session knowing exactly what was decided, why it was decided, and which risks I’m consciously accepting. Maybe that's what you're searching for too.

## Philosophy Guardrails

Every skill is bound by the corresponding philosophy:

- Decision ownership: developer selects tradeoff; this skill frames options and consequences.
- Ask-before-act: ask clarifying scoping questions before recommendations.
- Evidence-first: ground recommendations in explicit system constraints and known behavior.
- Bounded approval: implementation actions require explicit user approval and scoped handoff.
- Safety carve-outs: never trade away trust-boundary validation, security, data-loss prevention, accessibility, or explicit requirements.

## Deep dive docs

### Start here

- [Architecture index](./docs/architecture/README.md)
- [Philosophy](./docs/architecture/01-philosophy.md)
- [Agent + skill model](./docs/architecture/02-agent-skill-model.md)
- [Adaptive Socratic policy](./docs/architecture/03-adaptive-socratic-policy.md)
- [Validation prompt suite](./docs/validation/README.md)
- [Operator start here](./docs/MANUAL.md)

### Prompt contracts

- Router + duckling subagents: [`agents/`](./agents)
- Skills: [`skills/`](./skills)

## Attribution

Rubber Duck is inspired by its [namesake](https://rubberduckdebugging.com/) and the practice of talking through a problem to find your own solution—except this one can talk back and ask sharp questions.

Rubber Duck adopted terse language and the review structure inspired by [Caveman](https://github.com/JuliusBrussee/caveman), though token reduction slowly stopped being the primary goal as it took on a life of its own.

Part of Rubber Duck's operating model adapts ideas from [Ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert.
