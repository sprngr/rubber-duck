# Project Context

## Contents

- [Goals](#goals)
- [Decisions](#decisions)
- [Conventions](#conventions)
- [Glossary](#glossary)
- [Deferred-Debt](#deferred-debt)
- [Open-Questions](#open-questions)
- [Session-Log](#session-log)
- [Notes](#notes)

## Goals
- **performance**: sub-second API response times for all user-facing endpoints
- **developer experience**: minimal boilerplate, clear error messages

## Decisions
- **auth strategy**: use JWT with short-lived access tokens and refresh tokens (date: 2025-01-15)
- **database**: PostgreSQL 16 with Prisma ORM (date: 2025-01-10)

## Conventions
- **naming**: kebab-case for file names, PascalCase for components, camelCase for functions
- **error handling**: throw typed errors, catch at middleware boundary
- **testing**: one test file per module, describe/it structure, snapshot for UI

## Glossary
- **tenant**: isolated namespace with dedicated database schema and access controls
- **workspace**: collection of projects under a single tenant
- **pipeline**: automated workflow triggered by code changes

## Deferred-Debt
- TODO(decision-debt): 2025-01-15 evaluate message queue for async processing [status: open]
- TODO(decision-debt,#42): 2025-01-10 caching strategy [resolved: Redis with 5-minute TTL]
- TODO(decision-debt,spike): 2025-01-12 multi-region deployment feasibility
  spike: determine if we need active-active or active-passive replication
  unknowns:
    - latency requirements for cross-region queries
    - data sovereignty constraints by region
  success: ADR documenting chosen replication strategy with benchmarks

## Open-Questions
- Should we support multi-region deployment? (date: 2025-01-15)
- What is the acceptable cold-start time for serverless functions? (date: 2025-01-12) [resolved: under 200ms]

## Session-Log
### 2025-01-15 14:30 — auth implementation
- Status: implementing JWT middleware
- Completed token refresh flow
- Added rate limiting to auth endpoints

### 2025-01-14 09:15 — database migration
- Status: running schema migrations
- Migrated user table to new schema
- Verified data integrity post-migration

## Notes
### 2025-01-15 14:30
Investigated OAuth2 vs JWT tradeoffs. JWT wins for our use case due to stateless nature and existing infrastructure.

### 2025-01-14 09:15
Database migration ran successfully. All 12 tables migrated with zero downtime. Verified with checksum comparison.