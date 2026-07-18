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
     - invoke mapped route skill
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
  - hand off by invoking selected route skill (for example, `A -> duck-debug`, `B -> duck-review`)
  - continue in selected route flow (do not re-list route options)
- if choice is ambiguous/invalid:
  - ask one narrowed follow-up
  - remain in route-selection mode

{{include: skill-snippets/philosophy-guardrails.md}}

## Activation / When to Use

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- explicit `quack` invocation
- available route set (`debug`/`review`/`design`/`explain`/`teach`/`triage`)
- readable alias registry at `references/route-aliases.json`
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
5. If alias matched, auto-route to mapped skill and continue there.
6. If multiple aliases matched, apply tie-break rules (exact match > longest alias > ask one disambiguation question).
7. If alias not matched, provide 1-3 route options with chain hints, recommend one, and require user choice.
8. Persist route context in response footer for next-turn continuity (single-line, machine-friendly) when using picker path:
   - `ROUTE_CTX: A=<route>;B=<route>[;C=<route>]`
9. On valid next-turn route selection, hand off to chosen route flow; if mutating, enforce approval checkpoint before mutation.

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
