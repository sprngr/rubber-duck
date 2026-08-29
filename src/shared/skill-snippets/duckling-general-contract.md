### Duckling General Contract

Use this shared contract for thin wrapper agents that delegate to a target skill.

Wrapper mode rule:

- wrappers may pass explicit `mode` (`analyze` or `execute`) when delegating.
- if `mode` is omitted, infer from task intent; fallback to `analyze`.

Input shape:

- `skill_name`: target skill to load (required)
- `mode`: `analyze` or `execute` (optional)
- `intent`: short user intent (required)
- `artifacts`: paths/log snippets/diff refs (optional)
- `constraints`:
  - `max_files` (default 2 for execute)
  - `mutating_allowed` (default false)
  - `verification` (smallest runnable check)
- `upstream_evidence`: evidence IDs/refs (optional)

Behavior rules:

1. load `skill_name`
2. enforce global guardrails before skill logic
3. determine effective mode:
   - use provided `mode` when present
   - else infer from intent (mutating/apply/edit/fix => `execute`; otherwise `analyze`)
   - if still unclear, default to `analyze`
4. if effective mode is `execute`, do not mutate the workspace. Produce an approval package (preflight + per-file diffs + `Approve this scope?`) as terminal output for the parent to relay. Bounded mutating scope (`<=2` files) still applies to the proposed diff.
5. preserve selected skill output contract as primary output, EXCEPT for interactive-dialog contracts (Socratic loops, batched interviews, multi-turn design dialogs): flatten questions to a final `## Unresolved questions` block. If questions remain unanswered, do not emit them as terminal output posing as content.
6. if skill unavailable, emit terminal error naming the skill and set `status=blocked_skill_unavailable`. Do not attempt to prompt the user or reroute; parent re-invokes with a corrected `skill_name`.

Output footer (machine-friendly):

- `DUCKLING_CTX: skill=<name>;mode=<mode>;status=<status>;evidence=<ids|none>`

Status tokens:

- `ok` — work completed, terminal output is the result
- `blocked_awaiting_approval` — approval package emitted; parent must relay
- `blocked_skill_unavailable` — `skill_name` did not resolve
- `blocked_recursive_routing` — `skill_name` is on the non-delegation list
- `blocked_missing_inputs` — required inputs absent
- `phase_complete_await_parent` — one phase done; parent must re-invoke for next phase
- `degraded_tool_unavailable` — required tool unavailable in this harness; output degraded
