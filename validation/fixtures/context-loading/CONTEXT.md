# Project Context

## Conventions

- TypeScript strict mode enabled
- All API endpoints must validate input with zod schemas
- Database queries use parameterized statements (never string concatenation)
- Auth middleware required on all routes except /health and /login

## Architecture

- Monolith with shared PostgreSQL database
- Auth module handles JWT token generation and validation
- User service manages CRUD operations for user entities

## Deferred Decisions

- Migration to microservices deferred until Q3 (performance baseline needed first)
- Redis caching layer deferred (current DB performance acceptable under 1000 RPM)

## Non-Goals

- Real-time WebSocket features (out of scope for v1)
- Multi-tenancy (single-tenant deployment model)
