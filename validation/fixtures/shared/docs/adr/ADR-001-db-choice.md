# ADR-001: Database choice — PostgreSQL

**Date:** 2024-02-20
**Status:** Accepted

## Context

Need persistent data store for user accounts, sessions, and audit logs.
Workload is read-heavy with write bursts on auth flows.

## Decision

Use PostgreSQL as primary data store. Redis for session cache only.

## Tradeoffs

- Pro: mature ecosystem, strong consistency, JSON support
- Pro: existing team familiarity
- Con: horizontal scaling harder than DynamoDB
- Con: requires connection pooling layer (PgBouncer)
