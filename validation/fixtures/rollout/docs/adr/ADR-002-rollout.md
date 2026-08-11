# ADR-002: Rollout strategy — RollingUpdate v2.0.0

**Date:** 2024-04-10
**Status:** Proposed

## Context

Migrating from v1.4.x to v2.0.0. Includes:

- breaking API contract changes (v2 removes legacy /v1 endpoints)
- database schema migration (ALTER TABLE users ADD COLUMN status TEXT)
- new Redis session format (incompatible with v1 sessions)

## Decision

Use Kubernetes RollingUpdate with maxSurge=1, maxUnavailable=0.
Canary stage skipped to hit Q2 deadline.

## Tradeoffs

- Pro: faster than canary (hours vs days)
- Pro: zero downtime if schema compatible
- Con: breaking API contract requires all clients update simultanously
- Con: schema migration not reversible (ALTER TABLE without default)
- Con: v1/v2 pods coexist during rollout — Redis session format incompatible
