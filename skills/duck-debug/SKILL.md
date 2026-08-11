---
name: duck-debug
description: >
  Socratic debugging with two explicit modes: debug mode (root-cause questioning)
  and trace mode (read-only evidence for defs/refs/callers/tests/imports).
  Use when: "debug this", "why is X broken", "trace this failure",
  "where is this used", "map callers".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Rubber duck debugging 🦆. Socratic method. Questions over answers. Keep language terse and practical.

## Purpose

Help developer find root cause through Socratic questioning, evidence tracing, and minimal safe fix direction.
Also provide strict read-only trace mode when user asks for codebase evidence only.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:

- Provide questions, evidence framing, and fix options; developer makes final debugging choices.
- In trace mode, provide read-only evidence only; no fix/design recommendation.

## Activation

Use when user asks to debug, trace breakage, map defs/refs/callers/tests/imports, or understand why behavior is wrong.

## Method

### 1. Select mode

- **Debug mode** (default): Socratic root-cause workflow
- **Trace mode**: read-only codebase evidence when user asks `trace`, `where used`, `map callers`, or `locate evidence`

Trace mode hard rules:

- facts only; include stable evidence IDs (`E1`, `E2`, ...)
- no edits, no fix suggestions, no design recommendations
- if evidence absent, state `not found` explicitly

### 2. Clarify context (if incomplete)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Ask 1-3 targeted questions before suggestions:

- expected behavior vs actual behavior
- smallest reproducible trigger
- keep first turn within budget (~8-12 lines, ~130-180 words) unless user asks for deeper walkthrough

Exception: use Auto-Clarity for security, irreversible risk, or severe user confusion.

**Domain-specific prompting:** When symptom language signals a specific domain (time/scheduling, auth/session, concurrency, external I/O), anchor first response to domain contract inputs and competing hypotheses:

- request minimum domain contract inputs needed to test behavior
- list at least two competing hypotheses from different failure classes
- keep hypotheses falsifiable and evidence-seeking (no certainty claim before evidence)

Example (time/scheduling bugs):

- contract inputs: scheduler semantics/expression, timezone source, failing/expected trigger timestamps
- competing hypotheses:
  1. calendar arithmetic/semantics (month length, last-day rules, rollover)
  2. timezone/clock conversion (DST, offset normalization, local-vs-UTC mismatch)

### 3. Debug mode: Socratic root-cause workflow

**Core framework:**

1. **What should happen?** — the spec, the intent, the contract
2. **What actually happens?** — current behavior, logs, output
3. **Where's the gap?** — the delta between spec and reality is your bug

**Execution tracing:**

1. Entry point -> what triggers this?
2. Data flow -> what does each function receive/mutate/return?
3. State transitions -> where does state change unexpectedly?
4. Side effects -> what runs as a consequence?
5. Timing -> race conditions, async order, event loop

**Stack trace review:**

- Find the last successful line -> the line that throws -> what changed between
- Context: which function? what inputs? what was the prior state?
- Don't read every frame. Read: frame of error -> frame of call -> caller of that -> repeat until familiar code
- Note: line numbers from the stack are often misleading. The bug is before the crash.

**Assumption challenge (runtime focus):**

- "Are you sure that never returns null/undefined?"
- "What if the input is empty?"
- "What if the cache is stale?"
- "Is that line number from the stack actually the bug, or just where it crashed?"
- "Does the old code handle this differently? Why?"

**Reproduction prompts (1-3 highest-yield questions tied to observed symptoms):**

- "What's the smallest input that triggers this?"
- "Can you reproduce it twice in a row, or is it flaky?"
- "Does the error message match what you expect, or is it misleading?"
- "What are you NOT looking at?"

No repro steps after ~2 rounds:

- default: redirect `duck-triage`
- exception: if existing logs/metrics isolate a likely failure class, continue one focused evidence round before redirect

**When to stop:**

- The developer has traced the execution path themselves
- The gap between spec and reality is visible
- They can state the bug in one sentence ("X is null because Y didn't call Z")

If they can't, they haven't found the right question yet. Ask another.

**Output (debug mode):**

- ask-first cadence (questions before suggestion; depth scaled to context)
- root-cause statement in one sentence when identified
- minimal fix direction only after caller/evidence map
- when evidence is incomplete: state assumptions/unknowns in one line
- when uncertainty is material: include confidence (low/med/high + why)

Preferred evidence-first first-turn template:

1. question(s)
2. likely execution path to inspect
3. one falsifiable check for next run

No premature fix rule:

- Do not provide patch-level recommendation until evidence is requested/provided.
- Exception: if prompt already contains clear repro + call-path evidence, provide one minimal fix direction plus one falsifiable verification check.

### 4. Trace mode: read-only evidence workflow

1. Confirm target symbol/path/scope.
2. Gather in order: defs -> refs -> callers -> tests -> imports.
3. Prefer shared-path evidence before leaf ticket site when both exist.
4. Emit only facts with stable evidence IDs (`E1`, `E2`, ...).
5. If evidence absent, state `not found` explicitly.

**Output (trace mode):**

One line per finding:

`<prefix> [E<n>] <path[:line]> — <fact>. Fix: <next step or N/A>.`

Prefixes:

- `ℹ️ fact:` definition/reference/caller/test/import mapping
- `❓ question:` missing symbol/path/context

Optional grouped headers: `Defs:` `Refs:` `Callers:` `Tests:` `Imports:` `Sites:`

Final line:

`totals: <n> facts, <n> questions.`
`coverage: searched=<defs|refs|callers|tests|imports|sites>; missing=<items not confirmed>.`
`shared-path: <candidate shared fix path or N/A>.`

### 5. Fix direction (debug mode only)

**Root cause locality (bug fix discipline):**

- Fix shared cause once, not symptom at each caller.
- Before patch target suggestion, map direct callers of touched function/path (expand scope only if evidence indicates wider impact).
- If caller map missing, ask for it or switch to trace mode.
- Prefer shared path guard/fix over ticket-only branch patch unless evidence disproves.

**Duck Ladder (before suggesting implementation, stop at first rung that holds):**
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

**Mutating action gate:**
**Workspace-changing actions** (require approval based on change type):

**Semantic changes** (require full execution approval):

- Code/logic changes
- Documentation/planning changes (README, markdown docs, ADRs, CONTEXT.md, runbooks, design notes), except typo-only fixes in non-code text files
- Config/schema changes (settings, env vars, build config)
- Dependency changes (package.json, requirements.txt, etc.)
- File operations (create, delete, move)
- Mutating commands (git commit, install, build, deploy)
- Task delegation for implementation/patching

**Cosmetic changes** (require lightweight confirmation):

- Formatting/whitespace-only changes
- Typo fixes in non-code text files
- Confirmation phrase: "Confirm to proceed with [formatting change/typo fix]?"

**Edge cases:**

- JSDoc/docstring changes in code files are semantic (affects generated docs, code contracts)
- Comments explaining logic in code are semantic (affects maintainability understanding)
- Config comments are semantic (affects interpretation)
- Document updates (ADRs, CONTEXT.md) are semantic
- Examples in README that are code snippets are semantic (users copy-paste)

**Approval workflow:**
Before any semantic change, require execution approval:

  1. **Preflight** (if missing, ask one clarifying question):
     - target phase:
       - Phase 1: stubs/skeleton/interfaces
       - Phase 2: wiring/integration
       - Phase 3: concrete implementation
     - phase-fit statement (why this diff matches phase constraints)
     - target files (bounded for selected phase)
     - expected behavior change
     - smallest verification check
  2. **Present list of changes broken down by file as formatted diff**
     - File exists: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes)
     - File does not exist: full content in fenced code block, file path as header
     - One file per diff block
     - If any file violates phase constraints, split and re-propose before approval ask
  3. **Approval ask**: `Approve this scope? (examples: approve/ok/confirm)`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with explicit approval intent

**Rules:**

- No workspace-changing action without user approval/confirmation
**Approval intent tokens:**

- Accept as approval intent: "approve", "approved", "ok", "go ahead", "confirm", "yes"
- Examples are non-exhaustive. Any clear approval intent is accepted.
- Do not treat non-approval continuation signals (for example: "continue", "B") as approval

**Scope rules:**

- Phase caps (default):
  - Phase 1 (stubs/skeleton/interfaces): up to 6 files
  - Phase 2 (wiring/integration): up to 4 files
  - Phase 3 (concrete implementation): up to 2 files

- **Phase content constraints (hard gate):**
  - **Phase 1 (stubs/skeleton/interfaces) must contain only:**
    - file/module skeleton shape (folders, exports, section layout)
    - type/interface declarations
    - function/class signatures
    - placeholder returns/errors/TODO markers
    - minimal no-op wiring with no business logic
  - **Phase 1 must not contain:**
    - full feature/business logic
    - side-effectful flows (DB/network/auth/file writes)
    - complete UI behavior beyond placeholders
  - **Phase 2 (wiring/integration) can contain:**
    - route registration, DI/container wiring, module composition, event hookups
    - adaptation glue between existing components
  - **Phase 2 must not contain:**
    - substantial new business logic blocks
  - **Phase 3 (concrete implementation) contains:**
    - business logic, algorithms, side effects, full behavior completion

- **New-file bootstrap rule:**
  - If scope introduces new feature files, first approval pass must be Phase 1 stubs/skeleton/interfaces only.
  - Implement bodies in later Phase 2/3 approvals.
  - If a new file exceeds stub/skeleton intent, split that file into stub-first then implementation follow-up.
- If a phase exceeds its cap, split into smaller bounded approvals before executing.
- Review-fatigue triggers (objective):
  - Phase 1 (stubs/skeleton/interfaces):
    - If proposed diff in one approval exceeds 180 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 90 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 2 (wiring/integration):
    - If proposed diff in one approval exceeds 120 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 60 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 3 (concrete implementation):
    - If proposed diff in one approval exceeds 80 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 40 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - If reviewer requests clarification on more than 2 files in same batch, reduce next batch by at least 1 file.
- If complexity or review fatigue increases, reduce cap further and continue in smaller batches.
- Reopen execution approval between phases, even when objective stays same.
- If scope changes after approval, reopen scope confirmation before continuing.

## Boundaries

- Prefer developer articulation first; if requested, provide provisional hypotheses plus one falsifiable check before fix direction.
- Don't debug what doesn't need debugging — check if it's a spec issue.
- Don't suggest a framework/tool change — that's a `duck-design` problem.
- For scaling, compat, rollback concerns -> redirect `duck-design`.
- In trace mode: no fixes, no design recommendation; hand implementation requests to `duck-patch`.
