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
4. if effective mode is `execute`, require bounded mutating scope (`<=2` files) and explicit approval context
5. preserve selected skill output contract as primary output
6. if skill unavailable, emit one `❓ question:` with retry/reroute action

Output footer (machine-friendly):

- `DUCKLING_CTX: skill=<name>;mode=<mode>;status=<ok|blocked>;evidence=<ids|none>`
