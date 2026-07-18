---
name: quack
description: Explicit user-invoked routing for Rubber Duck. Resolves known intent aliases to route skills first, else offers 1-3 route options with recommendation and user choice. Use when user says "quack" or asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. Alias-first auto-route, else user chooses route.

## Purpose

Provide explicit user-controlled routing for workflow-like requests while preserving safety and approval constraints.

## Output Format

On explicit `quack`, respond in this order:

0. **Heartbeat fast path (bare `quack`)**
   - If input is exactly `quack` (trim whitespace): output
     - `🦆` + brief status
     - one-line route-intent prompt
   - Do not emit full route options without task intent.

1. **Alias-first fast path (`quack <intent>`)**
   - Load `references/route-aliases.json`.
   - Resolve both route and default `preferred_subagent` from the matched route entry.
   - Normalize for matching using this contract:
     - lowercase
     - trim leading/trailing whitespace
     - collapse internal whitespace runs to single spaces
     - strip leading `/`
     - remove surrounding punctuation wrappers (for example quotes/brackets)
     - treat punctuation separators inside phrase as spaces (for example `code-review` -> `code review`)
   - Accept common variants (for example `/review`, `code review`, `cr`).
   - If alias matches, auto-route immediately:
      - one-line acknowledgement of resolved route
      - invoke mapped route skill with `preferred_subagent`
      - continue in mapped route flow (do not emit picker)
   - If multiple aliases match after normalization:
     - prefer exact normalized alias match
     - else prefer longest normalized alias
     - else ask one disambiguation question

2. **Route options (1-3 max, fallback)**
   - Each option includes: `id` (A/B/C), `route`, `best_for`, `tradeoff`, `chain`.

3. **Recommendation (exactly one)**
   - Recommend one option id with one-line reason grounded in prompt/artifacts.

4. **Choice prompt**
   - Ask user to pick option id before continuing.

If choice is ambiguous/invalid: ask one narrowed follow-up and stay in route-selection mode.

On follow-up selection turn (fallback picker path only):
- accept concise choice forms: `A`/`B`/`C`, `pick A`, `choose B`, `quack A`
- if choice is valid:
  - acknowledge selected option in one line
  - hand off by invoking selected route skill with mapped `preferred_subagent` (for example, `A -> duck-debug + duck-investigator`, `B -> duck-review + duck-reviewer`)
  - continue in selected route flow (do not re-list route options)
- if choice is ambiguous/invalid:
  - ask one narrowed follow-up
  - remain in route-selection mode

User override (optional):
- allow explicit override in prompt suffix: `use <subagent>` (for example `quack review use general`)
- validate override against available subagents
- if valid, pass override as `preferred_subagent` instead of mapped default
- if invalid, ask one correction question and stay in current route flow

{{include: skill-snippets/philosophy-guardrails.md}}

## Activation / When to Use

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- explicit `quack` invocation
- available route set (`debug`/`review`/`design`/`explain`/`teach`/`triage`)
- readable alias registry at `references/route-aliases.json`
- available subagent set for override validation
- active host guardrails + mutating-action policy

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, depth/format)

Ambiguity/confirmation:
- if alias hit: auto-route without picker
- if alias miss: allow route-level ambiguity only and require user route choice before routing continues
- mutating paths still require approval gate.

## Route option format (canonical)

Use this schema per option:

`<ID> | route=<skill> | best_for=<when to pick> | tradeoff=<what it deprioritizes> | chain=<expected subagent/skill sequence>`

## Method

1. Verify explicit `quack` invocation.
2. If bare `quack`, run heartbeat fast path and stop.
3. For non-bare input, load `references/route-aliases.json` and attempt case-insensitive alias match.
4. Normalize user intent and aliases using the alias normalization contract before matching.
5. Parse optional override token `use <subagent>` from the same input.
6. Validate override (if present) against available subagents.
7. Determine effective `preferred_subagent`: override if valid, else mapped default from route entry.
8. If multiple aliases matched, apply tie-break rules (exact match > longest alias > ask one disambiguation question).
9. If alias matched, auto-route to mapped skill and continue there, passing effective `preferred_subagent`.
10. If alias not matched, provide 1-3 route options with chain hints, recommend one, and require user choice.
11. On valid picker selection, hand off to selected route with effective `preferred_subagent`.
12. Persist route context in response footer for next-turn continuity (single-line, machine-friendly) when using picker path:
   - `ROUTE_CTX: A=<route>;B=<route>[;C=<route>]`
13. On invalid override, ask one correction question and remain in current route flow.
14. If mutating, enforce approval checkpoint before mutation.

## Boundaries & Handoffs

- Require explicit invocation; alias-hit path may auto-route, otherwise require user route choice.
- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.

## Failure / fallback behavior

If route confidence is low:
- state assumptions in one line
- ask one targeted disambiguation question
- if alias miss and picker path is active, do not proceed until user selects a route

## Edge Cases

- Mutating path selected: route handoff still requires explicit bounded approval before mutation.
- Load `references/Examples.md` when user asks for concrete route output examples or route-choice wording calibration.
