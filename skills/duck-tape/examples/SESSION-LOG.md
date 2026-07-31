# Session-Log Examples

## Minimal entry (no status change)
```markdown
### 2025-01-15 14:30 — auth implementation
- Completed token refresh flow
- Added rate limiting to auth endpoints
```

## Entry with status change
```markdown
### 2025-01-15 14:30 — auth implementation
- Status: implementing JWT middleware
- Completed token refresh flow
- Added rate limiting to auth endpoints
```

## Entry with decision
```markdown
### 2025-01-14 09:15 — database migration
- Status: running schema migrations
- Migrated user table to new schema
- Decided to keep legacy table for 30-day grace period
```

## Entry with question
```markdown
### 2025-01-13 11:00 — multi-region planning
- Status: evaluating deployment options
- Opened question: should we support multi-region deployment?
- Benchmarked latency between US-EAST and EU-WEST
```

## Rotation note
```markdown
### 2025-01-16 10:00 — session state rotation
- Rotated out session state: 2025-01-01-0900
- Rotated out: initial setup (2025-01-01)
```