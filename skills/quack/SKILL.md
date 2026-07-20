---
name: quack
description: >
   Explicit user-invoked routing for Rubber Duck. Resolves known intent aliases to route skills first;
   on alias miss, asks one targeted disambiguation question and waits. Use when user says "quack" or
   asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. Alias-first auto-route, else one targeted disambiguation question.

## Purpose

Provide explicit user-controlled routing for workflow-like requests while preserving safety and approval constraints.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

## Activation

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Method

1. Verify explicit `quack` invocation.
2. Normalize intent: strip separator after `quack` (`:`, `-`, `—`), strip outer matching quotes, strip trailing punctuation (`?!.;:`).
3. **Bare `quack` (heartbeat path):**
   - Emit one heartbeat line from `assets/heartbeat.md`
   - Emit full `assets/quick-help.md` verbatim
   - Emit one-line route-intent prompt
   - Stop (do not generate ad-hoc quips)
4. Parse optional override: `use <subagent>` or `with <subagent>` or `via <subagent>`.
5. Validate override (if present) against platform subagent list; if invalid, ask one correction question: `Need one detail: unknown subagent "<x>". Use duckling or general?` and stop.
6. Determine effective subagent: override if valid, else default `duckling`.
7. Determine route execution policy:
   - inline-default: `duck-design`, `duck-teach`, `duck-debug`
   - delegated-default: `duck-patch`, `duck-risk`, `duck-review`, `duck-triage`, `duck-simplify`
   - user override forces delegation regardless of default policy
8. If explicit full skill name in input, resolve that skill and execute route (see step 11).
9. Otherwise, load `assets/route-aliases.json` and attempt case-insensitive match.
10. If multiple aliases match, apply tie-break: exact match > longest alias > ask one disambiguation question.
11. **Route execution** (explicit skill name or alias match):
    - Load role instructions from `assets/subagent-runbook.md` for resolved skill
    - If inline-default policy AND no user override:
      - execute skill inline
      - emit `Routing: <skill>.` only
    - Otherwise (delegated-default OR user override):
      - launch `task` with `subagent_type=<effective_subagent>` and `skill_name=<resolved_skill>`
      - emit `Routing: <skill> via <subagent>.` if override supplied, else `Routing: <skill>.`
      - if dispatch fails, ask one corrective question and stop
12. **Alias miss (disambiguation):**
    - Detect intent fragment and ask one targeted question:
      - debug-ish (error/fail/trace/stack/broken): `Need one detail: is this debug, trace, or review?`
      - rollout/risk (rollout/migration/compat/rollback): `Need one detail: is this risk review or design tradeoff?`
      - code-change (fix/change/refactor/clean up): `Need one detail: do you want review, patch, or simplify?`
      - unknown: `Need one detail: which route fits—review, debug, design, teach, triage, risk, or simplify?`
    - Wait for user clarification, then retry alias resolution.

## Boundaries

- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.
