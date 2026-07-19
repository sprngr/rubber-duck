### Duckling General Contract

Use this shared contract for thin wrapper agents that delegate to a target skill.

Wrapper mode rule:
- wrappers must pass explicit `mode` (`analyze` or `execute`) when delegating.

Input shape:
- `skill_name`: target skill to load (required)
- `mode`: `analyze` or `execute` (required)
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
3. if `mode=execute`, require bounded mutating scope (`<=2` files) and explicit approval context
4. preserve selected skill output contract as primary output
5. if skill unavailable, emit one `❓ question:` with retry/reroute action

Output footer (machine-friendly):
- `DUCKLING_CTX: skill=<name>;mode=<mode>;status=<ok|blocked>;evidence=<ids|none>`
