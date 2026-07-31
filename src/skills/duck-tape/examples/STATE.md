# Agent State

Session: 2025-01-15-1430 | Cwd: /project | Repo/Branch: myorg/myapp@main
Created: 2025-01-15T14:30:00Z | Updated: 2025-01-15T15:45:00Z | Compactions: 2

## Approved Workflow
Implement JWT authentication with refresh tokens. Reference: AUTH-101 spec.

## Position
- **Current:** Testing token refresh endpoint
- **Done:** Implemented login flow, Added JWT middleware, Built refresh token rotation
- **Remaining:** Add rate limiting, Write integration tests, Document auth API

## Decision Log
2025-01-15T14:45:00Z APPROVED: use 15-minute access token lifetime - balances security and UX
2025-01-15T15:10:00Z REJECTED: refresh token in localStorage - security risk from XSS
2025-01-15T15:15:00Z APPROVED: refresh token in httpOnly cookie - mitigates XSS risk

## Established Facts
JWT library is jose v5 with EdDSA support
Refresh tokens rotate on each use for security
Auth middleware runs before route handlers

## Re-derivation
To reproduce auth state:
1. Run `npm run dev` to start local server
2. POST to /auth/login with test credentials
3. Check /auth/refresh endpoint with expired access token
4. Verify token rotation in database auth_tokens table

## Suggested Skills
- duck-debug (for auth flow testing)
- duck-review (for security audit)