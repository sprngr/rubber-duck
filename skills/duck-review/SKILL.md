---
name: duck-review
description: >
  Rubber duck code review. Extends caveman-review with extra severity prefixes.
  One-line comments: location, problem, fix. Use when: "review this",
  "code review", "review the diff", "/review". Replaces global duck-review skill once merged.
---

Review 🦆. Extends caveman-review. Keep terse format by default.

## Duck Ladder (complexity guard)

When proposing fix direction, stop at first rung:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

## Workflow

1. Confirm review input exists (diff, PR text, or pasted code chunk).
2. Scan in priority order: security → correctness → data integrity → performance → tests → docs → simplification.
3. Emit only actionable findings. One line each: location, problem, fix direction.
4. Use strongest matching prefix. If multiple apply, pick highest risk prefix.
5. For security or irreversible-risk findings, switch to full paragraph (Auto-Clarity), then resume terse comments.

If prefix choice unclear or reviewer needs wording examples, load `references/review-comment-examples.md`.

## Output Format

One-line comment template:

`<prefix> <path[:line]> — <problem>. Fix: <smallest safe change>.`

Keep comments paste-ready for PR threads.

## Prefixes

All caveman-review prefixes apply. Add these:
- `📝 doc:` — missing/outdated docs or annotations
- `🧪 test:` — missing/outdated test coverage
- `🔒 sec:` — security issue (injection, auth bypass, secrets, SSRF)
- `⚡ perf:` — performance concern (N+1, unnecessary alloc, bad complexity)
- `🪶 yagni:` — unnecessary abstraction/config/speculative flexibility
- `📚 stdlib:` — custom code replaceable by standard library
- `🧱 native:` — dependency/custom layer replaceable by platform feature
- `✂️ shrink:` — same behavior with materially fewer lines
- `🗑️ delete:` — dead/speculative code removable without replacement

## Input → Output Examples

Input:
"review this diff"

Output:
- `🧪 test: src/auth/session.ts:88 — refresh-token expiry path untested. Fix: add test for expired refresh token returning 401.`
- `📝 doc: api/openapi.yaml:210 — response schema omits new error_code field. Fix: document field in 401 schema.`

Input:
"review this" + SQL string concatenation with user input

Output:
- `🔒 sec: db/userRepo.ts:44 — SQL built from raw user input enables injection. Fix: parameterize query placeholders and bind values.`

## Edge Cases

- No diff or code provided: ask for concrete review target before commenting.
- Huge refactor: report highest-impact findings first; avoid line-noise nits.
- Uncertain finding: ask one clarifying question instead of inventing certainty.
- Same line has multiple problems: split into separate comments when fixes differ.
- Security finding mixed with style issues: report security first, style optional.

## Auto-Clarity

Drop terse mode for security findings, architectural disagreements, onboarding contexts. Write full paragraph there, resume terse after.

## Boundaries

Reviews only. Don't write patch, don't approve/request-changes, don't run linters/tests. Output comments ready to paste into PR.

Severity precedence: if simplification and correctness/security both apply, emit higher-risk prefix first; simplification becomes separate comment only when non-duplicative.
