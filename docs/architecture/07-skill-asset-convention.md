# Skill Asset Convention

Standard organization for skill assets and references.

## Directory Structure

```
src/skills/<skill-name>/
  ├── SKILL.md
  ├── assets/              # Runtime data (always loaded)
  │   ├── *.md
  │   └── *.json
  └── references/          # Conditional references (loaded on demand)
      └── *.md
```

## Asset Types

### assets/ (runtime data)

**Purpose:** Data files loaded automatically during skill execution.

**Examples:**
- `quack/assets/heartbeat.md` — status quips (always loaded on bare `quack`)
- `quack/assets/quick-help.md` — usage guide (always loaded on bare `quack`)
- `quack/assets/route-aliases.json` — alias registry (always loaded on intent match)
- `quack/assets/subagent-runbook.md` — role instructions (always loaded on route execution)

**Loading behavior:** Automatic, specified in Method steps.

### references/ (conditional references)

**Purpose:** Documentation, examples, patterns loaded conditionally.

**Examples:**
- `duck-design/references/TradeoffMatrix.md` — matrix framework (loaded for multi-option decisions)
- `duck-design/references/DesignPatterns.md` — pattern catalog (loaded when symptom matches)
- `duck-design/references/Example.md` — walkthrough examples (informational, rarely loaded)
- `duck-review/references/review-comment-examples.md` — wording examples (loaded when prefix unclear)
- `quack/references/Examples.md` — UX micro-spec (loaded on disambiguation calibration request)

**Loading behavior:** Conditional, triggered by specific scenarios in Method.

## Asset Metadata

All assets should include metadata header:

```markdown
# Asset Title

<!-- 
asset-type: runtime-data | reference
loading: always (trigger) | conditional (trigger)
format: brief description
last-updated: YYYY-MM-DD
-->

Content starts here...
```

**For JSON assets:**

```json
{
  "version": 1,
  "asset-type": "runtime-data",
  "loading": "always (trigger)",
  "last-updated": "YYYY-MM-DD",
  "notes": "Description..."
}
```

## Loading Convention

### In SKILL.md Method section:

**Always-loaded (assets/):**
```markdown
1. Load `assets/route-aliases.json` and attempt case-insensitive match.
```

**Conditionally-loaded (references/):**
```markdown
If prefix choice unclear or reviewer needs wording examples, load `references/review-comment-examples.md`.
```

### Reference section (optional):

Skills may include a References section listing available conditional assets:

```markdown
## References

- [TradeoffMatrix.md](references/TradeoffMatrix.md) — Matrix dimensions and fill guidance
- [DesignPatterns.md](references/DesignPatterns.md) — Common architectural patterns and decision prompts
- [Example.md](references/Example.md) — End-to-end design session walkthrough
```
