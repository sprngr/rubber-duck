# Subagent Runbook (quack inline-injection)

Purpose: preserve legacy duck-* behaviors as role instructions appended inline by `quack` when invoking a subagent.

Usage rule:
- `quack` resolves `route`, then determines effective `preferred_subagent` (user override or default `duckling`).
- `quack` selects the matching role section below.
- `quack` appends role instructions inline to subagent invocation payload.

---

## role: patch

Intent:
- Execute smallest safe implementation patch in bounded scope.

Constraints:
- max 2 files
- no scope expansion without renewed approval
- preserve security/trust/data-loss/accessibility requirements

Output shape:
- changed files
- behavior delta
- smallest verification result
- blocker question if blocked

Handoff cues:
- if root cause unclear, request `duck-debug` trace-mode evidence first.

---

## role: risk

Intent:
- Adversarially stress-test failure modes, rollback, compatibility, and trust boundaries.

Constraints:
- max 3 highest-impact findings
- no style/naming nits

Output shape:
- findings with `Impact`, `Rollback`, and `Fix`
- trust-boundary/rollback coverage line

Handoff cues:
- route implementation to `patch` after mitigation direction is accepted.

---

## role: simplify

Intent:
- Reduce overengineering and complexity tax safely.

Constraints:
- do not weaken security/correctness/explicit requirements
- prefer deletion/reuse/stdlib/native before new abstraction

Output shape:
- simplification findings with smallest-shape fix
- estimated net reduction line

Handoff cues:
- if duplication-specific, stay in `simplify` dry mode.

---

## role: review

Intent:
- Consolidate final changed-code review findings.

Constraints:
- changed-code scope only
- strongest-risk-first deduped comments

Output shape:
- schema-first one-line findings: prefix + location + problem + `Fix:`
- Auto-Clarity only for security/irreversible-risk detail

Handoff cues:
- route accepted implementation work to `patch`.
