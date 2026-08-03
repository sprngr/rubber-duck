# Fixture Project Context

## Purpose

Synthetic project for rubber-duck validation tests. Provides realistic
codebase context for design, risk, grill, and tape tests.

## Decisions

- 2024-01-15: Use TypeScript strict mode for all new modules
- 2024-02-20: Adopt monorepo layout (packages/auth, packages/api, packages/web)
- 2024-03-10: PostgreSQL as primary data store; Redis for session cache

## Conventions

- All public functions require JSDoc
- Error handling via Result<T, E> pattern, no thrown exceptions
- Test files colocated with source: `*.test.ts`
- Import order: stdlib -> external -> internal

## Glossary

- Auth Middleware: validates JWT in Authorization header, attaches `req.user`
- Trust Boundary: any boundary crossing network, process, or persistence layer
- Rollout: staged deployment of a new version (canary -> 10% -> 50% -> 100%)

## Deferred-Debt

- TODO(test): 2024-02-01 add integration tests for auth refresh-token flow
- TODO(security): 2024-03-05 audit rate-limiting on /login endpoint

## Open-Questions

- Should we migrate from REST to gRPC for internal services?

## Notes

- 2024-01-20: initial fixture scaffold for validation suite
