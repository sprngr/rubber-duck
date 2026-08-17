# Worked Examples

<!--
asset-type: reference
loading: conditional (Method step 6 — when a rule's application is unclear)
format: illustrative examples for policy rules
last-updated: 2026-08-17
-->

Illustrative examples. Consult when a rule's application is unclear.

## Duck Ladder decision

```
User: "Add caching to getUserById"

Rung 1: Caching is a real need (repeated DB calls). Not YAGNI.
Rung 2: grep "cache" — found lib/cache.ts with a generic Cache class. Reuse it.
Decision: Wrap getUserById with Cache.get/set using existing Cache class.
Diff: 3 lines. No new dependencies.
```

## Auto-Clarity expansion (security trigger)

```
Finding: SQL injection in src/auth/users.ts:44

The query `SELECT * FROM users WHERE id = ${userId}` concatenates
user input directly into SQL. An attacker can inject:
  userId = "1; DROP TABLE users;--"

Fix: use parameterized query:
  db.query("SELECT * FROM users WHERE id = $1", [userId])

This preserves the trust boundary between user input and database.
```

## Style before/after

| Before | After |
|---|---|
| "I think we should probably consider refactoring this function" | "Refactor this function" |
| "It seems like there might be an issue with the auth check" | "Auth check fails when token is expired" |
| "Could you please approve this change?" | "Approve this scope?" |
| "The implementation would be to use a cache here" | "Use cache here. Reuse lib/cache.ts." |

## Phase examples (file/line thresholds)

| Phase | Files | Lines | Action |
|---|---|---|---|
| Phase 1 (stubs) | 5 files | 170 lines | Within cap — one approval |
| Phase 2 (wiring) | 4 files | 130 lines | Exceeds threshold — split into 2 approvals |
| Phase 3 (impl) | 2 files, one at 45 lines | — | Exceeds single-file threshold — split edits |

## Debt marker types

| Type | When to use |
|---|---|
| `perf` | Performance optimization deferred |
| `arch` | Architecture decision pending |
| `ux` | UX improvement deferred |
| `test` | Test coverage gap acknowledged |
| `ops` | Operational concern deferred |

## Approval ask without diff (anti-pattern)

Wrong:

```
Scope: add 2 decision entries + 1 Notes entry to CONTEXT.md covering
enforcement bootstrap and 3.x install migration.
Approve this scope? (examples: approve/ok/confirm)
```

Right: same preflight, then a unified-diff block per file with an annotation above each hunk, then the approval ask. Prose scope descriptions do not substitute for a diff block, even for small textual edits to docs. If the ask has been emitted without a diff and the user approves, treat scope as unapproved and re-present with the diff.
