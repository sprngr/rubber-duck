# Output Schema

Strict output specifications for duck-tape artifacts.

## CONTEXT.md Output Rules

### Section headers

- If emitting a section header, use exactly `## <Section>` (two hash marks, space, section name)
- Section names are case-sensitive: `Goals`, `Decisions`, `Conventions`, `Glossary`, `Deferred-Debt`, `Open-Questions`, `Notes`
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
- TODO(<debt type>): <YYYY-MM-DD> <what deferred> [status: open|resolved]
- TODO(<debt type>,#<issue>): <YYYY-MM-DD> <what> [resolved: <decision>]
```

**Open-Questions**

```markdown
## Open-Questions
- <question> (date: <YYYY-MM-DD>)
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
Created: <ISO-8601>
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

## Rotation Rules

### State files

- Max 10 files in `.duck-tape/`
- Drop oldest by session ID (lexicographic order)

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
