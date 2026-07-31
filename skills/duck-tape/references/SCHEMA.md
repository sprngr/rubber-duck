# CONTEXT.md Schema

## Sections

### 1. Goals

What the project optimizes for. Keyed by goal name.

```
## Goals
- **<name>**: <what we optimize for>
```

Merge:
- Dedupe by name.
- Supersede on conflict.
- Append new.

### 2. Decisions

Explicit decisions made in session. Keyed by decision name.

```
## Decisions
- **<name>**: <decision> (date: <YYYY-MM-DD>)
```

Merge:
- Dedupe by name.
- On conflict: supersede. Old entry archived to changelog. New entry replaces.
- Append new names.

### 3. Conventions

Project conventions and patterns. Keyed by convention name.

```
## Conventions
- **<name>**: <convention>
```

Merge:
- Dedupe by name.
- Supersede on conflict.
- Append new.

### 4. Glossary

Domain terms and definitions. Keyed by term.

```
## Glossary
- **<term>**: <definition>
```

Merge:
- Dedupe by term.
- Supersede on conflict.
- Append new.

### 5. Deferred-Debt

Deferred work and decisions. Append-only with status markers.

```
## Deferred-Debt
- TODO(decision-debt): <date> <what deferred> [status: open|resolved]
- TODO(decision-debt,#<issue>): <date> <what> [resolved: <decision>]
```

Merge:
- Append new. Never modify existing entries except status update on resolution.
- Status update: append resolution marker, keep original line.

### 6. Open-Questions

Unresolved questions. Append new.

```
## Open-Questions
- <question> (date: <YYYY-MM-DD>)
```

Merge:
- Append new questions.
- Dedupe by question text (normalized whitespace).
- No supersede. Resolved questions stay with `[resolved: <answer>]` marker.

### 7. Session-Log

Timestamped session entries. Append + rotate.

```
## Session-Log
### <YYYY-MM-DD HH:MM> — <session topic>
- <entry>
- <entry>
```

Merge:
- Append new timestamped entry.
- Cap at 50 entries (default). Rotate oldest out.
- Rotation drops oldest entry with changelog note: "Rotated out: <topic> (<date>)".
- Recommended: first entry of a session's new block is `Status: <current state>` when a meaningful status change occurred. Omit when no meaningful status change. Not required.

### 8. Notes

User-defined freeform content. Timestamped append-only.

```
## Notes
### <YYYY-MM-DD HH:MM>
<freeform content>
```

Merge:
- Append new timestamped block at end.
- Never rewrite existing blocks.
- Prune via `/duck-tape prune` only.
- Status detail (blockers, in-progress detail, next-up) belongs in Notes subsection `### Status`. Uses Notes append-only semantics.

## Merge Algorithm

Merge input is translated from session state file (`.duck-tape/<id>.state.md`), not raw session content. Translation uses rigid map in `references/STATE_SCHEMA.md`. See that file for state-section to CONTEXT.md-section mapping.

0. **Redact incoming state content** before translation + merge:
   - Scan for secrets/PII: API keys, passwords, tokens, connection strings, env var values, personally identifiable information.
   - On detection: reject flagged content. Report findings. Ask user to redact source or confirm mask-in-place (`<REDACTED>`).
   - Never merge raw secrets into CONTEXT.md. Masked content only after user confirmation.
   - Applies to all sections including Notes freeform.
1. Parse existing CONTEXT.md into sections by `##` headers.
2. Translate redacted state file into CONTEXT.md sections using rigid map in `references/STATE_SCHEMA.md`. Parse subsections within each top-level section by `###` headers.
3. Per section, apply merge rules above.
4. Generate changelog:
   - `Added: <section> <key>`
   - `Superseded: <section> <key> (<old> -> <new>)`
   - `Dropped: <section> <key> (<reason>)`
5. Write merged CONTEXT.md.
6. Emit changelog to user.

## Conflict Resolution

Conflict = same key exists in existing and incoming with different values.

- Decisions/Conventions/Glossary: incoming supersedes existing. Session content is newer truth.
- Goals: incoming supersedes existing. Session content is newer truth.
- Deferred-Debt: no conflict possible (append-only with status).
- Open-Questions: no supersede. Incoming resolved marker updates existing question.
- Session-Log/Notes: no conflict possible (append-only).

## Subsection Merge Rules

Top-level sections may contain `###` subsections for visual grouping. Subsections are presentational. Merge operates at key level within each top-level section.

- Keys dedupe across all subsections within a top-level section. Same key in different subsections is a conflict. Supersede per section rules.
- Entries merge into existing subsections by key. If key exists in `### Routing`, incoming supersedes in place.
- New subsections (not present in existing file) appended at end of top-level section with their entries.
- Subsection headers preserved as-is. Never rename or reorder existing subsections.
- Subsection position of new entries follows: existing key -> merge in place within its subsection. New key with no existing subsection match -> append to the subsection that contains it in incoming. If incoming subsection is new -> append entire subsection to end of top-level section.

## Missing Sections

If existing CONTEXT.md lacks one or more schema sections:
1. Abort merge.
2. Report missing sections to user.
3. Prompt: "CONTEXT.md lacks schema sections: <list>. Run /duck-tape migrate to add empty sections before merge."
4. Do not infer or auto-add sections silently.

Migration (`/duck-tape migrate` — defined in SKILL.md) appends missing section headers + bootstrap markers to existing file. Preserves all existing content above appended sections. Requires execution approval per SKILL.md Migrate section.
