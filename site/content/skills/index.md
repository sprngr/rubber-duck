---
title: Skills
---

# Skills Catalogue

Every duck skill: purpose, triggers, boundaries.

Tier: **default** = installed by installer; **extra** = opt-in via `--extras`.

## Analysis

Think, review, question.

- [duck-design](./duck-design.md) — _default_ — Socratic design discussion to evaluate approaches, identify tradeoffs, suggest alternatives, and challenge assumptions. Design matrix for option comparison. Use when: "choose between approaches", "architecture tradeoffs", "help me choose".
- [duck-debug](./duck-debug.md) — _default_ — Socratic debugging with two explicit modes: debug mode (root-cause questioning) and trace mode (read-only evidence for defs/refs/callers/tests/imports). Use when: "debug this", "why is X broken", "trace this failure", "where is this used", "map callers".
- [duck-review](./duck-review.md) — _default_ — Risk-first code review with terse, actionable findings in paste-ready format. One-line comments: location + problem + fix. Use when: "review this", "code review", "review the diff".
- [duck-risk](./duck-risk.md) — _default_ — Adversarial risk review for failure modes, rollback safety, compatibility, and trust-boundary misuse. Identifies highest-impact risks and smallest safe mitigations. Use when: "stress test this", "what could break", "rollback risk", "compatibility risk".
- [duck-triage](./duck-triage.md) — _default_ — Test coverage analysis and bug triage. Identifies missing tests, assesses test quality, classifies bug severity, suggests test scenarios, discovers edge cases. Use when: "test coverage gaps", "what should we test", "triage this bug", "bug severity".
- [duck-teach](./duck-teach.md) — _default_ — Structured teaching for code, logs, queries, and config with explicit depth modes. "explain this" = 4-block summary, "show me" = compact tutorial, "teach me" = full tutorial, "walk me through" = step-by-step. Searches codebase first, prefers real project usage. Use when: "explain this", "teach me", "show me", "walk me through".
- [duck-grill](./duck-grill.md) — _extra_ — Batched grilling interview (up to 3 questions at a time) to pressure-test plans against repo docs, domain language, and decision guardrails. Deep assumption/risk interrogation mode. Use when: "grill this", "grill this plan", "challenge assumptions".

## Action

Mutating changes.

- [duck-patch](./duck-patch.md) — _default_ — Surgical implementation for small, bounded code edits after direction is clear. Minimal safe diffs, reuses existing local patterns, verifies smallest runnable check. Use when: "apply this fix", "make a targeted edit", "patch this", "implement the agreed change".
- [duck-refactor](./duck-refactor.md) — _default_ — Multi-file code restructuring with reference tracking. Extract functions/classes, rename across codebase, move code between files, inline, convert patterns. Use when: "refactor this", "extract this function", "rename this across codebase", "move this to another file", "inline this".
- [duck-simplify](./duck-simplify.md) — _default_ — Complexity reduction and semantic duplication/divergence review. Identifies unnecessary abstractions, oversized config/state surfaces, directness opportunities, safe extraction boundaries. Modes: standard (complexity reduction), dry (DRY/divergence). Use when: "simplify this", "is this overengineered", "DRY this", "divergence review".

## Meta

Routing, adaptation, memory.

- [quack](./quack.md) — _default_ — Explicit user-invoked routing for Rubber Duck workflows. Resolves known intent aliases to route skills first; on alias miss, asks one targeted disambiguation question and waits. Use when: "quack", "quack <intent>".
- [duck-adapt](./duck-adapt.md) — _extra_ — Meta-skill that adapts external skills to rubber-duck philosophy: Socratic method, evidence-first discipline, Duck Ladder, execution approval gates, and prompt order standard. Also audits existing skills for philosophy compliance and detects overlaps. Use when: "adapt this skill", "make this duck-compatible", "audit skill", "should we add this skill".
- [duck-tape](./duck-tape.md) — _extra_ — Two-tier session memory: compact into CONTEXT.md (persistent) and .duck-tape/<id>.state.md (working). Merge/dedupe fixed-schema sections, append-only Notes, bootstrap from session content. Subcommands: merge, resume, init, prune, migrate. Use when: "duck-tape", "compact session", "update CONTEXT.md", "resume session".
- [duck-debt](./duck-debt.md) — _default_ — Read-only deferred-work ledger from TODO/FIXME/HACK/XXX comments. Broad mode (default) shows all entries; strict mode returns only issue-linked entries. Use when: "duck debt", "what did we defer", "audit deferred work".
