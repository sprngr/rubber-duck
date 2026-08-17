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

- `--branch` / `-Branch` — install from a non-main branch (testing).
- `--extras` / `-Extras` — install optional skills (duck-adapt, duck-grill, duck-tape).

## AGENTS.md

v2 uses managed-block fencing. The installer adds fences when writing AGENTS.md to user directories. Policy content now lives in the agent body; AGENTS.md is a version marker only.

## Reinstall

Fresh install recommended:

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --<target>
```

---

# Migrating from v2.x to v3

v3 consolidates to a single self-contained agent, extracts enforcement rules to a portable skill, and simplifies the installer by removing policy mode flags.

## What changed

| Area | v2 | v3 |
| --- | --- | --- |
| Agent variants | Multiple agent variants | Single `rubber-duck` (self-contained) |
| Policy source | Split between agent body + AGENTS.md | Agent body only (AGENTS.md = version marker) |
| Enforcement rules | Inline in agent body | Extracted to `duck-policy` skill |
| Installer flags | `--policy host\|self`, `--skip-agents-md`, `--claude-md` | None of these |
| Validation tests | 48 tests with variant system | 44 tests, no variants |

## Removed flags

- `--policy host|self` / `-Policy host|self` — no longer needed (single agent)
- `--skip-agents-md` / `-SkipAgentsMd` — no longer needed (AGENTS.md is a version marker)
- `--claude-md` / `-ClaudeMd` — removed (use default CLAUDE.md path)

## New: duck-policy skill

Enforcement rules (approval gates, safety carve-outs, Duck Ladder, Style, Auto-Clarity, Boundaries, Deferred Debt Markers) are now available as a portable skill. Any agent can load `duck-policy` to gain Rubber Duck philosophy enforcement.

## Migration

**Automatic:** re-run the installer. It will:

1. Install the new self-contained `rubber-duck.md` (overwrites old)
2. Replace the old AGENTS.md managed block with new 3-line version marker
3. Remove any stale agent files no longer part of the installation
4. Update manifest pins

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --<target>
```

**Manual cleanup (optional):**

- Remove any stale agent files from `.opencode/agents/`, `.claude/agents/`, `.github/agents/`
- Remove any custom AGENTS.md content that referenced the old policy mode flags
