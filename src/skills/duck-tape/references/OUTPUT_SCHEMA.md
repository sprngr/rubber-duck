# Output Schema

Strict output specifications for duck-tape artifacts.

## CONTEXT.md Output Rules

### Section headers
- Always `## <Section>` (two hash marks, space, section name)
- Section names are case-sensitive: `Goals`, `Decisions`, `Conventions`, `Glossary`, `Deferred-Debt`, `Open-Questions`, `Session-Log`, `Notes`
- No markdown formatting in headers (no bold, no links)

### Entry format by section

**Goals**
```markdown
## Goals
- **<name>**: <what we optimize for>
```

**Decisions**
```markdown
## Decisions
- **<name>**: <decision> (date: <YYYY-MM-DD>)
```

**Conventions**
```markdown
## Conventions
- **<name>**: <convention>
```

**Glossary**
```markdown
## Glossary
- **<term>**: <definition>
```

**Deferred-Debt**
```markdown
## Deferred-Debt
- TODO(decision-debt): <YYYY-MM-DD> <what deferred> [status: open|resolved]
- TODO(decision-debt,#<issue>): <YYYY-MM-DD> <what> [resolved: <decision>]
```

**Open-Questions**
```markdown
## Open-Questions
- <question> (date: <YYYY-MM-DD>)
- <question> (date: <YYYY-MM-DD>) [resolved: <answer>]
```

**Session-Log**
```markdown
## Session-Log
### <YYYY-MM-DD HH:MM> — <session topic>
- Status: <current state>
- <entry>
```

**Notes**
```markdown
## Notes
### <YYYY-MM-DD HH:MM>
<freeform content>
```

### Blank lines
- One blank line between sections
- No trailing blank lines at end of file
- Entries within a section are contiguous (no blank lines between entries)

## State File Output Rules

### Header format
```markdown
# Agent State

Session: <YYYY-MM-DD-HHMM> | Cwd: <absolute-path> | Repo/Branch: <repo>@<branch>
Created: <ISO-8601> | Updated: <ISO-8601> | Compactions: <integer>
```

### Section requirements
- All sections present on first write
- Empty sections use `None` marker
- Position.Current is single line
- Position.Done is ordered list (newest last)
- Position.Remaining is ordered list (next first)
- Decision Log entries are append-only
- Established Facts are verbatim
- Re-derivation is verbatim
- Suggested Skills is optional (omit if empty)

## Changelog Output Rules

### Format
```markdown
Changelog:
- Added: <section> <key>
- Superseded: <section> <key> (<old value> -> <new value>)
- Dropped: <section> <key> (<reason>)
```

### Rules
- One line per change
- Section names match schema exactly
- Key is the bold identifier (name/term)
- Supersede shows old and new values
- Drop shows explicit reason
- No changelog if no changes (emit "No changes to CONTEXT.md")

## Session-Log Entry Rules

### Format
```markdown
### <YYYY-MM-DD HH:MM> — <session topic>
- Status: <current state>
- <entry>
```

### Rules
- Timestamp is ISO 8601 local time (YYYY-MM-DD HH:MM)
- Session topic is one phrase (no period)
- Status line is optional (only if meaningful change)
- Entries are single lines
- Max 50 entries total (rotate oldest)
- Rotation note: "Rotated out: <topic> (<YYYY-MM-DD>)"

## Rotation Rules

### State files
- Max 10 files in `.duck-tape/`
- Drop oldest by session ID (lexicographic order)
- Note in Session-Log: "Rotated out session state: <YYYY-MM-DD-HHMM>"

### Session-Log
- Max 50 entries
- Drop oldest when cap exceeded
- Note in changelog: "Dropped: Session-Log <topic> (rotation cap)"

## Redaction Output Rules

### Detection output
```markdown
Redaction: detected <count> potential secret(s) in <section>.
Flagged: <type> at line <N>: <masked preview>
Action: user confirmation required before masking with <REDACTED>.
```

### Rules
- Never show full secret value
- Masked preview shows first 4 characters + `...`
- Reject flagged content until user confirms
- Apply `<REDACTED>` marker on confirmation
- Log redaction in changelog: "Redacted: <section> <count> secret(s)"