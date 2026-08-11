---
name: quack
description: >
  Explicit user-invoked routing for Rubber Duck workflows. Resolves known intent aliases
  to route skills first; on alias miss, asks one targeted disambiguation question and waits.
  Use when: "quack", "quack <intent>".
license: MIT
metadata:
  author: sprngr
  version: v2.1.0
  RUBBER_DUCK_VERSION: __RUBBER_DUCK_VERSION__
---

# Skill: quack

Explicit route control 🦆. Alias-first auto-route, else one targeted disambiguation question.

## Purpose

Provide explicit user-controlled routing for workflow-like requests while preserving safety and approval constraints.

{{include: skill-snippets/philosophy-guardrails.md}}

{{include: skill-snippets/clarify-first-preflight.md}}

## Activation

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Method

1. Verify explicit `quack` invocation.
2. Normalize intent: strip separator after `quack` (`:`, `-`, `—`), strip outer matching quotes, strip trailing punctuation (`?!.;:`).
3. **Bare `quack` (heartbeat path):**
   - If normalized intent is empty or whitespace-only:
     - Read `assets/heartbeat.md` and select one random heartbeat line from the list
     - Read and emit full `assets/quick-help.md` content verbatim (no summarization)
     - Emit closing prompt: `What would you like to route?`
     - Stop (do not generate ad-hoc quips, do not enter disambiguation)
4. Parse optional override: `use <subagent>` or `with <subagent>` or `via <subagent>`.
5. Validate override (if present) against platform subagent list; if invalid, ask one correction question: `Need one detail: unknown subagent "<x>". Use duckling or general?` and stop.
6. Determine effective subagent: if override parsed in step 4, use that; otherwise default to `duckling`.
7. Determine route execution policy:
   - inline-default: `duck-design`, `duck-teach`, `duck-debug`, `duck-debt`
   - delegated-default: `duck-patch`, `duck-refactor`, `duck-risk`, `duck-review`, `duck-triage`, `duck-simplify`
   - user override forces delegation regardless of default policy
8. If explicit full skill name in input, resolve that skill and execute route (see step 11).
9. Otherwise, load `assets/route-aliases.json` and attempt case-insensitive match.
10. **Apply keyword-based precedence** (when multiple skills match):
    - Scan intent for precedence keywords:
      - **Risk signals** (`rollback`, `breaking`, `compatibility`, `compat`, `failure`, `impact`) -> prioritize `duck-risk`
      - **Complexity signals** (`overengineered`, `complexity`, `simpler`, `too many`, `bloated`) -> prioritize `duck-simplify`
      - **Learning signals** (`why`, `how`, `what does`, `explain`, `teach me`) -> prioritize `duck-teach` over `duck-debug`
      - **Test signals** (`test`, `coverage`, `should I test`, `before PR`) -> prioritize `duck-triage`
      - **Design signals** (`choose`, `tradeoff`, `approach`, `option`) -> prioritize `duck-design`
    - Reorder matched skills with precedence-matched skill first
    - Still present alternatives (precedence aids ranking, doesn't eliminate choice)
11. If multiple aliases match after precedence, apply tie-break: exact match > longest alias > ask one disambiguation question.
12. **Route execution** (explicit skill name or alias match):
     - Load role instructions from `assets/subagent-runbook.md` for resolved skill
     - If inline-default policy AND no user override:
       - execute skill inline first
       - if execution fails, ask one corrective question and stop
       - emit `Routing: <skill>.` only after inline execution step completes
     - Otherwise (delegated-default OR user override):
       - launch `task` with `subagent_type=<effective_subagent>` (determined in step 6, defaults to `duckling`) first
       - pass `skill_name=<resolved_skill>` parameter
       - if dispatch fails, ask one corrective question and stop
       - emit `Routing: <skill> via <subagent>.` if user override supplied, else `Routing: <skill>.` only after dispatch succeeds
     - Do not stop at routing text alone when execution path is available.
13. **Alias miss (disambiguation):**
    - Detect intent fragment and ask one targeted question:
      - debug-ish (error/fail/trace/stack/broken): `Need one detail: is this debug, trace, or review?`
      - rollout/risk (rollout/migration/compat/rollback): `Need one detail: is this risk review or design tradeoff?`
      - code-change (fix/change/refactor/clean up): `Need one detail: do you want review, patch, refactor, or simplify?`
      - tech-debt (todo/defer/fixme/debt): `Need one detail: is this debt audit or simplify?`
      - unknown: `Need one detail: which route fits—review, debug, design, teach, triage, risk, simplify, patch, refactor, or debt?`
    - Wait for user clarification, then retry alias resolution.

## Boundaries

- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.
