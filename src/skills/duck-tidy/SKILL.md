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
  RUBBER_DUCK_VERSION: __RUBBER_DUCK_VERSION__
---

Stale comment and doc cleanup 🦆🧹. Audit-first, evidence-backed staleness detection.

## Purpose

Identify stale/outdated comments and non-CONTEXT docs so they stop polluting
future sessions and confusing agents and developers. Audit-first; edits hand
off to duck-patch.

{{include: skill-snippets/philosophy-guardrails.md}}
{{include: skill-snippets/clarify-first-preflight.md}}

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

{{include: policy-snippets/mutating-action-gate.md}}

Verify with smallest runnable check (build/test, or re-audit of changed hunks).

## Boundaries

- No auto-edits without approval.
- If a target is a TODO/FIXME/HACK/XXX marker, leave it — duck-debt owns those.
- If a target is an ADR/design note, flag only; do not edit.
- If a target is CONTEXT.md or .duck-tape state, leave it — duck-tape owns those.
- Every deletion carries cited evidence.