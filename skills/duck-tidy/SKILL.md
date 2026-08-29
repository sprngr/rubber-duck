---
name: duck-tidy
description: >
  Stale/outdated comment and doc cleanup audit. Flags comments contradicting
  current code, describing removed behavior, or documenting worktree-only
  add/remove that never reached the default branch. TODO markers ignored (duck-debt owns).
  ADR/design notes flagged only, never edited. Audit-first, patch handoff.
  Use when: "tidy comments", "clean up stale comments", "outdated docs audit",
  "duck-tidy".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v3.1.0
---

Stale comment and doc cleanup 🦆🧹. Audit-first, evidence-backed staleness detection.

## Purpose

Identify stale/outdated comments and non-CONTEXT docs so they stop polluting
future sessions and confusing agents and developers. Audit-first; edits hand
off to duck-patch.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Skill-specific delta:

- Staleness evidence-backed: comment contradicts current code, describes
  behavior no longer existing, or documents worktree-only add/remove never
  merged to main.
- TODO/FIXME/HACK/XXX markers out of scope (duck-debt owns the ledger).
- ADR/design notes historic by design: flag superseded info, never edit.

## Activation

**Audit-only** (default): scan, report, no edits. Signals: "duck-tidy",
"stale comments audit", "outdated docs audit".

**Audit-and-edit**: audit, then hand agreed findings to duck-patch. Signals:
"tidy and fix comments", "clean up stale comments".

## Method

### 1. Scan scope

Scope: explicit paths/globs from user, else worktree files (tracked +
untracked, git-ignored excluded) minus CONTEXT.md, .duck-tape/, and common
generated dirs (build/, dist/, node_modules/, coverage/, target/).

If the repo's generated dirs differ, ask one question before scanning.

If scope unclear, ask one question: single file / directory / worktree diff
vs default branch.

Collect code comments, doc comments, non-CONTEXT markdown in scope.

### 2. Gather staleness evidence

Stale iff any rule holds:

- **Contradiction**: text contradicts current code (outdated invariants, wrong
  parameter semantics, old return type or signature).
- **Removed behavior**: describes functionality no longer present (referenced
  symbol/function/feature deleted).
- **Worktree-only add/remove**: documents behavior added then removed in the
  current worktree, never merged to the default branch. Verify via
  `git diff <default-branch>`: behavior exists only in unmerged worktree
  changes. Resolve default branch with `git symbolic-ref refs/remotes/origin/HEAD`,
  fall back to `main`. For untracked files, confirm worktree-only status via
  `git status --porcelain`.

Cross-reference each suspect: symbol resolves? tests exercise it? Cite the
contradiction (file:line, symbol, diff hunk). No vibes-based staleness.

### 3. Classify findings

- `stale-comment`: actionable (contradiction / removed behavior /
  worktree-only). Editable.
- `superseded-doc`: ADR/design note now outdated. Flag only, never edit.
- `skip`: TODO markers (duck-debt), accurate or historic comments,
  CONTEXT.md/.duck-tape content (duck-tape).

### 4. Produce audit report

Ledger per finding: location (file:line), class, evidence (one cited line),
proposed action (delete / reword / flag).

ADR findings grouped separately as flags: "outdated — do not cite as current",
with supersession evidence.

Audit-only mode stops here. Report only; no edits.

### 5. Patch handoff

Audit-and-edit only:

1. Present audit ledger.
2. User selects findings to fix.
3. Hand selected edits to duck-patch as bounded scope.
4. Walk execution approval before edits.

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

  1. **Preflight** (required for every approval ask; if a field is missing, ask one clarifying question):
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
     - Inline an annotation above the diff hunks explaining each change
     - If any file violates phase constraints, split and re-propose before approval ask
  3. **Approval ask**: `Approve this scope? (examples: approve/ok/confirm)`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with explicit approval intent

**Rules:**

- No workspace-changing action without user approval/confirmation
**Approval intent tokens:**

- Accept as approval intent: "approve", "approved", "ok", "go ahead", "confirm", "yes"
- Also accept option-referencing approval sentences: "Proceed with option B in files X and Y.", "Approved. Run verification plan as proposed."
- Examples are non-exhaustive. Any clear approval intent is accepted.
- Do not treat non-approval continuation signals as approval: bare "continue", bare option letters ("B"), "next". No approval verb, no scope reference — not approval.

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

- Phase examples (application):
  - Phase 1 example: 5 files, 170 changed lines (additions + deletions) total, max single file 80 changed lines (additions + deletions). This is within cap and thresholds, so one approval can proceed.
  - Phase 2 example: 4 files, 130 changed lines (additions + deletions) total. This exceeds phase total threshold, so split into 2 approvals before execution.
  - Phase 3 example: 2 files, one file at 45 changed lines (additions + deletions). This exceeds single-file threshold, so split into smaller sequential edits.

Verify with smallest runnable check (build/test, or re-audit of changed hunks).

## Boundaries

- No auto-edits without approval.
- If a target is a TODO/FIXME/HACK/XXX marker, leave it — duck-debt owns those.
- If a target is an ADR/design note, flag only; do not edit.
- If a target is CONTEXT.md or .duck-tape state, leave it — duck-tape owns those.
- Every deletion carries cited evidence.
