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

## Output Format

On explicit `quack`, respond in this order:

0. **Heartbeat fast path (bare `quack`)**
   - If input is exactly `quack` (trim whitespace): output
     - one selected heartbeat line from `assets/heartbeat.md`
        - selection rule: stateless deterministic selector = hash(`session_or_conversation_id` + `turn_index`) mod heartbeat-line-count
     - full static quick-help from `assets/quick-help.md` (emit verbatim)
     - one-line route-intent prompt
   - For bare `quack`, emit the full quick-help asset verbatim instead of dynamic route lists or condensed summaries.
   - Do not generate ad-hoc/random quips in heartbeat path.

1. **Alias-first fast path (`quack <intent>`)**
   - Normalize invocation and intent, resolve route alias/direct skill, then auto-route.
   - Success response:
     - `Routing: <skill>.`
     - include `via <subagent>` only when user supplied explicit override.
   - Keep output minimal; do not emit success `ROUTE_EXEC` unless debug/compliance trace is explicitly requested.

2. **Alias-miss disambiguation (fallback)**
   - Do not emit a route menu.
   - Ask one targeted disambiguation question: `Need one detail: <question>`.
   - Wait for user clarification before routing.

User override (optional):
- allow explicit override: `use <subagent>` or `with <subagent>` or `via <subagent>`
- if valid, route with override instead of default `duckling`
- if invalid, ask one correction question and stay in current flow:
  - `Need one detail: unknown subagent "<x>". Use duckling or general?`

- Execution mechanics (normalization, tie-breaks, dispatch policy, and proof rules) are defined in **Method**.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

## Activation / When to Use

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Preflight Checks

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Required:
- explicit `quack` invocation
- readable alias registry at `references/route-aliases.json`
- platform-listed subagent set for override validation
- active host guardrails + mutating-action policy

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, depth/format)

Ambiguity/confirmation:
- if alias hit: auto-route without route menu
- if alias miss: ask one targeted disambiguation question and wait for clarification before routing
- mutating paths still require approval gate.

## Method

1. Verify explicit `quack` invocation.
1a. Normalize invocation prefix: strip one separator token immediately after `quack` (`:`, `-`, or `—`) before parsing intent.
1b. Normalize intent wrapper: if intent starts and ends with the same quote (`'` or `"`), strip that outer pair.
1c. Normalize terminal punctuation: strip trailing runs of `?`, `!`, `.`, `;`, or `:` from intent before alias resolution.
2. If bare `quack`, run heartbeat fast path and stop.
3. Parse optional override token from same input: `use <subagent>` or `with <subagent>` or `via <subagent>`.
4. Validate override (if present) against platform-listed subagent names (static known set if runtime discovery unavailable).
5. Determine effective `preferred_subagent`: override if valid, else default to `duckling`.
   - This value is authoritative for this turn. Do not replace or infer a different subagent later.
5a. Determine route execution policy:
   - inline-default routes: `duck-design`, `duck-teach`, `duck-debug`
   - delegated-default routes: `duck-patch`, `duck-risk`, `duck-review`, `duck-triage`, `duck-simplify`
   - if user provided explicit subagent override, delegation is allowed regardless of default policy.
6. Detect explicit full skill-name token in input (any explicit skill name).
7. If explicit full skill-name token is present, resolve route policy for that skill and continue there.
   - If policy is inline-default and no explicit subagent override was provided:
     - execute routed skill inline
     - capture execution proof internally
     - emit footer only when debug/compliance trace is explicitly requested:
       - `ROUTE_EXEC: skill=<resolved_skill>; subagent=inline; source=explicit; status=ok`
   - Otherwise (delegated-default or user override provided):
     - MUST launch `task` with `subagent_type=<effective_subagent>`
     - MUST include `skill_name=<resolved_skill>` in task prompt
     - Dispatch proof required: `task` response must include `task_id`
     - After successful dispatch, capture execution proof internally
     - emit footer only when debug/compliance trace is explicitly requested:
       - `ROUTE_EXEC: skill=<resolved_skill>; subagent=<effective_subagent>; source=explicit; task_id=<task_id>; status=ok`
     - If dispatch fails or `task_id` is missing, emit:
       - `ROUTE_EXEC: skill=<resolved_skill>; subagent=<effective_subagent>; source=explicit; status=blocked; reason=<dispatch_failure_or_missing_task_id>`
     - On blocked dispatch, ask one corrective question and stop.
   - Do not continue alias/disambiguation flow after successful route execution.
8. Otherwise, load `references/route-aliases.json` and attempt case-insensitive alias match.
9. Normalize user intent and aliases using the alias normalization contract before matching.
10. If multiple aliases matched, apply tie-break rules (exact match > longest alias > ask one disambiguation question).
11. If alias matched, auto-route to mapped skill and continue there, passing effective `preferred_subagent`.
11a. Load `references/subagent-runbook.md`, select role section matching resolved route (`patch`/`risk`/`simplify`/`review`), and append those role instructions inline to the subagent invocation payload.
11b. Resolve route policy for mapped skill.
11c. If policy is inline-default and no explicit subagent override was provided:
   - execute routed skill inline
   - capture execution proof internally
   - emit footer only when debug/compliance trace is explicitly requested:
     - `ROUTE_EXEC: skill=<resolved_skill>; subagent=inline; source=alias; status=ok`
11d. Otherwise (delegated-default or user override provided):
   - MUST launch `task` with `subagent_type=<effective_subagent>`
   - MUST include `skill_name=<resolved_skill>` in task prompt
   - Dispatch proof required: `task` response must include `task_id`
   - After successful dispatch, capture execution proof internally
   - emit footer only when debug/compliance trace is explicitly requested:
     - `ROUTE_EXEC: skill=<resolved_skill>; subagent=<effective_subagent>; source=alias; task_id=<task_id>; status=ok`
   - If dispatch fails or `task_id` is missing, emit:
     - `ROUTE_EXEC: skill=<resolved_skill>; subagent=<effective_subagent>; source=alias; status=blocked; reason=<dispatch_failure_or_missing_task_id>`
   - On blocked dispatch, ask one corrective question and stop.
12. If alias not matched, ask one targeted disambiguation question derived from detected intent fragment.
    - Use deterministic templates:
      - debug-ish fragment (error/fail/trace/stack/broken): `Need one detail: is this debug, trace, or review?`
      - rollout/risk fragment (rollout/migration/compat/rollback): `Need one detail: is this risk review or design tradeoff?`
      - code-change fragment (fix/change/refactor/clean up): `Need one detail: do you want review, patch, or simplify?`
      - unknown fragment: `Need one detail: which route fits—review, debug, design, teach, triage, risk, or simplify?`
13. Wait for user clarification; then retry alias resolution on clarified intent.
14. On invalid override, ask one correction question and remain in current route flow.
    - Use template: `Need one detail: unknown subagent "<x>". Use duckling or general?`
15. If mutating, enforce approval checkpoint before mutation.

## Boundaries & Handoffs

- Require explicit invocation; alias-hit path may auto-route, otherwise require clarification before routing.
- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.
- Invocation integrity rule: apply route policy deterministically (inline-default vs delegated-default), with user override allowed to force delegation.
- Delegated proof rule: when route execution is delegated, no success claim without `task_id` evidence.

## Failure / fallback behavior

- Low confidence: follow Method step 12 (one targeted disambiguation question) and do not proceed until user clarifies intent.
- Dispatch unavailable or proof missing: follow Method steps 7/11 blocked-path handling (`ROUTE_EXEC ... status=blocked ... reason=<...>` + one corrective question), then stop.

## Compliance check (before send)

- Apply Method execution-proof rules only (steps 7 and 11):
  - success proof captured internally; success footer optional by default
  - blocked dispatch requires blocked `ROUTE_EXEC` + one corrective question
  - success `ROUTE_EXEC` footer only on explicit debug/compliance request

## Edge Cases

- Mutating path selected: route handoff still requires explicit bounded approval before mutation.
- Load `references/Examples.md` when user asks for concrete route output examples or disambiguation wording calibration.
