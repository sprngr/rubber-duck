# Rubber Duck Best Practices

Practical guidance for getting the most out of Rubber Duck. Builds on the [operator manual](./MANUAL.md) and [philosophy](./architecture/01-philosophy.md).

## When to use quack vs convenience delegation

**Use `quack <intent>` when:**
- Request is workflow-like (debug, review, design, triage, patch, refactor).
- You want explicit route selection before work starts.
- Multiple skills may chain (e.g., review -> risk -> simplify).
- You want a fresh subagent context for isolated analysis.

**Use convenience delegation (no `quack`) when:**
- Request is simple (single factual question, ≤10 lines explain, ≤5 line diff review).
- You want conversational flow without route ceremony.
- You are exploring and the intent is not yet clear.

Convenience delegation does not bypass execution approval. Workspace-changing actions still require the full approval gate regardless of routing path.

## When to pick conversational vs structured workflow

When Rubber Duck presents the approach choice, pick by signal:

| Signal | Conversational | Structured (quack) |
|---|---|---|
| Intent clarity | Vague, exploring | Clear, named task |
| Scope | Unknown | Bounded |
| Output expectation | Discussion, options | Findings, patch, review |
| Multi-skill chain | Unlikely | Likely |
| Context isolation | Not needed | Needed (fresh subagent) |

## Scope discipline

- `duck-patch`: max 2 files per scope. If scope exceeds 2 files, split into smaller bounded tasks before patching.
- `duck-refactor`: max 5 files per scope. If scope exceeds 5 files, split into smaller bounded tasks before refactoring.
- If scope changes after approval, the approval gate reopens. Re-confirm before continuing.
- State scope explicitly at preflight: target files, expected behavior change, smallest verification check.

## Approval token discipline

- Explicit "approve" token required for semantic changes. Not "continue", not "go ahead", not "yes".
- Cosmetic changes (doc-only, formatting, typos) use lightweight confirmation: "yes", "confirm", "ok" acceptable.
- If asked to "run whatever commands and fix it", Rubber Duck refuses silent execution and restates bounded-approval requirements.
- Approval is per-scope. New scope requires new approval.

## Composition pattern selection

| Goal | Pattern | Example prompt |
|---|---|---|
| Comprehensive review | review -> risk -> simplify | `quack review this refactor for correctness, risk, and complexity` |
| Root-cause fix | debug -> patch | `quack debug this endpoint failure then patch it` |
| Architecture + testing | design -> triage | `quack design this migration and suggest test scenarios` |
| Learning + troubleshooting | teach -> debug | `quack explain this authentication flow, then help debug the token expiry issue` |

Composition is user-driven, not enforced. Skills can be invoked sequentially or combined in a single request. Each skill maintains independence (no hidden coupling).

## Reading validation signals

Rubber Duck ships a validation suite for behavior regression checks. See [validation/README.md](../validation/README.md).

Quick subset gate (must pass before release):
- V02, V03, V04, V11, V12, V13, V14
- Fail if any Critical/High in subset fails

Key signals to watch for in normal use:
- **Clarify-first**: Rubber Duck asks targeted questions before coding/editing. If it jumps straight to implementation, that is a regression.
- **Risk-first review**: findings ordered by risk. Security/correctness before style/simplification.
- **No silent execution**: no code edits, commands, or task delegation without explicit approval.
- **Safety carve-outs enforced**: requests to remove auth/validation/accessibility are refused.

## When to deviate from defaults

- **Inline-default skills** (debug, debt, design, teach): run in main session for simple cases. Override to delegation with explicit `quack` request.
- **Delegated-default skills** (patch, refactor, review, risk, simplify, triage): run via duckling subagent by default. Override to inline with explicit user request.
- **Governor-invoked skills** (adapt, grill): main session only. Not quack-routed.

User override always wins. Explicit delegation request forces duckling delegation regardless of default policy.
 
## Install status

- **Default (11):** quack, duck-debt, duck-debug, duck-design, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage. Installed automatically.
- **Extras (3, --extras flag):** duck-adapt, duck-grill, duck-tape. Optional.

If a skill is unavailable, check install with `scripts/rubber-duck.sh status`. Extras require the `--extras` flag at install time.
 
## Related docs

- [Operator manual](./MANUAL.md) — routing cheat sheet, playbooks, failure modes.
- [Philosophy](./architecture/01-philosophy.md) — core principles and safety boundaries.
- [Adaptive Socratic policy](./architecture/03-adaptive-socratic-policy.md) — full 4-checkpoint policy.
- [Validation suite](./validation/README.md) — test prompts and runbook.
