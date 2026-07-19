---
name: quack
description: Explicit user-invoked routing for Rubber Duck. Resolves known intent aliases to route skills first; on alias miss, asks one targeted disambiguation question and waits. Use when user says "quack" or asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. Alias-first auto-route, else one targeted disambiguation question.

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

2. **Alias-miss disambiguation (fallback)**
   - Do not emit route pick-list options or recommendations.
   - Ask one targeted disambiguation question based on detected intent fragment.
   - Wait for user clarification before routing.

User override (optional):
- allow explicit override in prompt suffix: `use <subagent>` or `with <subagent>` or `via <subagent>` (for example `quack review with general`)
- validate override against platform-listed subagent names (static known set if runtime discovery unavailable)
- if valid, pass override as `preferred_subagent` instead of default `duckling`
- if invalid, ask one correction question and stay in current route flow

{{include: skill-snippets/philosophy-guardrails.md}}

## Activation / When to Use

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- explicit `quack` invocation
- available route set (`debug`/`review`/`design`/`explain`/`teach`/`triage`/`trace`/`risk`/`simplify`/`dry-review`/`patch`)
- readable alias registry at `references/route-aliases.json`
- platform-listed subagent set for override validation
- active host guardrails + mutating-action policy

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, depth/format)

Ambiguity/confirmation:
- if alias hit: auto-route without picker
- if alias miss: ask one targeted disambiguation question and wait for clarification before routing
- mutating paths still require approval gate.

## Method

1. Verify explicit `quack` invocation.
2. If bare `quack`, run heartbeat fast path and stop.
3. For non-bare input, load `references/route-aliases.json` and attempt case-insensitive alias match.
4. Normalize user intent and aliases using the alias normalization contract before matching.
5. Parse optional override token from same input: `use <subagent>` or `with <subagent>` or `via <subagent>`.
6. Validate override (if present) against platform-listed subagent names (static known set if runtime discovery unavailable).
7. Determine effective `preferred_subagent`: override if valid, else default to `duckling`.
8. If multiple aliases matched, apply tie-break rules (exact match > longest alias > ask one disambiguation question).
9. If alias matched, auto-route to mapped skill and continue there, passing effective `preferred_subagent`.
10. If alias not matched, ask one targeted disambiguation question derived from detected intent fragment.
11. Wait for user clarification; then retry alias resolution on clarified intent.
12. On invalid override, ask one correction question and remain in current route flow.
13. If mutating, enforce approval checkpoint before mutation.

## Boundaries & Handoffs

- Require explicit invocation; alias-hit path may auto-route, otherwise require clarification before routing.
- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.

## Failure / fallback behavior

If route confidence is low:
- state assumptions in one line
- ask one targeted disambiguation question
- if alias miss, do not proceed until user clarifies intent

## Edge Cases

- Mutating path selected: route handoff still requires explicit bounded approval before mutation.
- Load `references/Examples.md` when user asks for concrete route output examples or disambiguation wording calibration.
