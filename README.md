# Rubber Duck 🦆

Socratic assistant operating system for developers who want **better quality decisions**, not blind automation.

Rubber Duck helps you debug, review, design, and triage with structured questioning, evidence-first routing, and explicit safety guardrails.

## Why

Initially Rubber Duck started as my attempt to build a better debugger. I used the first versions to do pre-reviews before submitting code.
As time went on I found myself letting the model do more and more work until I found myself in meetings where we realized decisions were being made
that we weren't actually aware were included in our own work. We sacrificed understanding in favor of speed of output.

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

## Full Rubber Duck agent system (Installer/Updater & Uninstaller)

Checkout repo locally, then use installer script.

### Generic harness target (default)

Install to custom agent dir + AGENTS file, using `npx skills add` for skills:

```bash
./scripts/rubber-duck.sh install \
  --agents-dir /path/to/harness/agents \
  --agents-md /path/to/harness/AGENTS.md
```

Uninstall from generic target:

```bash
./scripts/rubber-duck.sh uninstall \
  --agents-dir /path/to/harness/agents \
  --agents-md /path/to/harness/AGENTS.md
```

Show status:

```bash
./scripts/rubber-duck.sh status \
  --agents-dir /path/to/harness/agents \
  --agents-md /path/to/harness/AGENTS.md
```

Run environment checks:

```bash
./scripts/rubber-duck.sh doctor \
  --agents-dir /path/to/harness/agents \
  --agents-md /path/to/harness/AGENTS.md
```

### Opencode target (preconfigured shortcut)

Install agents + managed AGENTS policy block + skills package:

```bash
./scripts/rubber-duck.sh install --opencode
```

Uninstall managed artifacts:

```bash
./scripts/rubber-duck.sh uninstall --opencode
```

Notes:
- script copies agent files to directory
- AGENTS policy is appended/removed via managed block markers
- use `--skip-skills` if you only need agents + AGENTS policy changes
- use `--dry-run` to print planned actions + AGENTS.md diff preview without writing
- install/uninstall always creates AGENTS backup in same dir: `AGENTS.md.bak.<YYYYmmdd-HHMMSS>`

## Verify after install

Use this to quickly validate behavior and fit in your own workflow.

### Step 0: Enable Rubber Duck Agent

Depending on your harness, can be a dropdown menu or @🦆

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
- [Strict Socratic mode](./docs/architecture/03-strict-socratic-mode.md)
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
