# Rubber Duck Pi Extension

Pi-native Rubber Duck extension package.

This extension adds:
- Duck status line (`🦆`) in Pi
- Ambient routing mode (on by default) for normal non-slash prompts
- Base command: `/duck status|reset|on|off|policy|mode|route`
- Manual duckling commands:
  - `/duck-reviewer`
  - `/duck-investigator`
  - `/duck-builder`
  - `/duck-adversary`
  - `/duck-dry`
  - `/duck-simple`
- Subprocess agent execution using packaged extension agents (`pi/agents/*.md`)
- Chained ambient execution passes prior duckling output into the next step
- Child agent runs are isolated with `--no-extensions` to avoid extension-level permission gates

## Build agent artifacts

From repo root:

```bash
make build-pi
```

This renders packaged extension artifacts to:

```text
pi/agents/*.md
pi/AGENTS.md
```

## Install extension in Pi

### Local path install

From the repo root:

```bash
pi install ./pi
```

Or from elsewhere:

```bash
pi install /absolute/path/to/rubber-duck/pi
```

### Run once without install

```bash
pi -e ./pi/src/index.ts
```

## Usage

### Base command

```text
/duck status
/duck on
/duck off
/duck reset
/duck policy on
/duck policy off
/duck mode on
/duck mode off
/duck route Review this diff for risky changes
/duck chain duck-investigator "scan auth flow" -> duck-reviewer "review risks"
```

### Invoke a duckling directly

```text
/duck-reviewer Review the current diff for risky changes.
```

(Also available: `/duck-investigator`, `/duck-builder`, `/duck-adversary`, `/duck-dry`, `/duck-simple`.)

Direct duckling commands also accept chain tails:

```text
/duck-reviewer "review current diff" -> duck-adversary "stress test failure modes"
```

## Chain grammar, placeholders, and options

Chain syntax:

```text
/duck chain <step> -> <step> -> ... [-- <shared-input>]
```

Step forms:

- single step: `duck-reviewer "task"`
- single step with shared input fallback: `duck-reviewer`
- parallel group: `(duck-reviewer "A" | duck-simple "B")`
- group with options: `(duck-reviewer "A" | duck-simple "B")[concurrency=2,failFast]`

### Placeholder contract (public)

Step task templates support two placeholders:

- `{input}` → the shared task text passed after `--` (or empty when omitted)
- `{previous}` → prior step output (for parallel groups, a merged summary of successful child outputs)

Examples:

```text
/duck chain duck-investigator "{input}" -> duck-reviewer "Use this evidence:\n{previous}" -- audit auth
/duck chain duck-investigator "scan" -> (duck-reviewer "risk: {previous}" | duck-simple "shrink: {previous}")[concurrency=2]
```

### Failure behavior

- Chains continue after failures and summarize at the end.
- Parallel groups honor `failFast` within the group only.
- Final summary includes succeeded/failed counts and failed step diagnostics.

Example failure summary:

```text
Chain complete: 2 succeeded, 1 failed.
✅ step 1 duck-investigator
❌ step 2 duck-reviewer — Unknown duck agent: duck-reviewer-x
✅ step 3 duck-simple
```

### Known limitations

- Chain parser is lightweight: nested parallel groups are not supported.
- Inline options currently support `concurrency=<N>` and `failFast` only.
- Option values cannot contain commas or spaces.
- `-- <shared-input>` is parsed at top-level only; placing `--` inside quotes may still be interpreted as literal text.
- Single-step tasks are parsed as either quoted text (`"..."` or `'...'`) or raw remainder after agent name.
- Escaped quote edge-cases may require simplifying/rewriting the step text.

### Ambient mode (default)

When ambient mode is on, normal non-slash prompts are routed automatically to the best duckling.

Examples:

```text
Review this diff for risky changes.
Why is this endpoint returning 500?
What are the tradeoffs in this architecture?
```

## Agent artifact resolution

Duck agents are loaded from the packaged extension path only (`pi/agents/*.md`).
No runtime discovery is performed from environment variables or project directories.
The extension AGENTS policy is loaded from packaged `pi/AGENTS.md` (toggle with `/duck policy on|off`).

## Notes

- Keep packaged artifacts in sync after policy/agent changes (`make build-pi`).
- Current command output is surfaced via Pi notifications.
