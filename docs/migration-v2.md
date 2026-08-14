# Migrating from v1.x to v2

v2 consolidates agents, renames skills, trims aliases, and changes the debt-marker format. This guide covers what breaks and how to update.

## Agents

v1 shipped 6 specialized duckling subagents. v2 collapses them into a single `duckling` delegator that routes to skills.

| v1.x subagent | v2 successor |
| --- | --- |
| duck-adversary | duck-risk |
| duck-builder | duck-patch |
| duck-dry | duck-teach |
| duck-investigator | duck-debug |
| duck-reviewer | duck-review |
| duck-simple | duck-simplify |

**Action:** remove old duckling configs from your harness. The single `duckling` agent replaces all six.

## Skills

- `duck-explain` merged into `duck-teach`. Remove `duck-explain` if installed.
- New skills: `duck-adapt`, `duck-grill`, `duck-tape`, `duck-refactor`.
- `duck-debt` now marker-agnostic: reads `TODO`, `FIXME`, `HACK`, `XXX` (v1 read only `TODO`).

Skill count: 7 -> 13.

## Aliases

Alias set trimmed 76 -> 33 (-57%). Run `quack` to see active aliases. Custom aliases referencing removed skills or subagents no longer resolve.

## Debt markers

v1 format:

```
TODO(decision-debt): <date> <what deferred>
```

v2 format (generalized debt type):

```
TODO(<debt type>): <date> <what deferred>
```

Existing `TODO(decision-debt):` markers still parse under `duck-debt` broad mode but use the new format for new markers.

## Installer

New flags:

- `--policy host|self` / `-Policy host|self` (`-p`) — policy mode selection (`host` default; `self` skips AGENTS policy block install and uses full self-contained duck agent policy).
- `--skip-agents-md` / `-SkipAgentsMd` — legacy alias for `--policy self` / `-Policy self`.
- `--branch` / `-Branch` — install from a non-main branch (testing).
- `--extras` / `-Extras` — install optional skills (duck-adapt, duck-grill, duck-tape).

## AGENTS.md

v2 uses managed-block fencing. The installer adds fences when writing AGENTS.md to user directories. Source file has no fences. If you hand-edited the managed block in v1, re-run the installer to reconcile.

## Reinstall

Fresh install recommended:

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --<target>
```

Use `--policy self` (or legacy `--skip-agents-md`) when you want to preserve existing AGENTS.md customizations outside the managed block.
