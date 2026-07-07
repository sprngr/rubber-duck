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
```

### Invoke a duckling directly

```text
/duck-reviewer Review the current diff for risky changes.
```

(Also available: `/duck-investigator`, `/duck-builder`, `/duck-adversary`, `/duck-dry`, `/duck-simple`.)

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
