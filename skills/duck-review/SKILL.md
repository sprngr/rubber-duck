---
name: duck-review
description: >
  Rubber duck code review with risk-first, terse, actionable findings.
  One-line comments: location, problem, fix. Use when: "review this",
  "code review", "review the diff", "/review".
---

Review 🦆. Keep terse, actionable format by default.

## Purpose

Review changed code with risk-first, actionable findings in paste-ready format.

## Philosophy Guardrails (skill-local)

- Decision ownership: user decides merge/approval outcomes; this skill provides findings and fix directions.
- Ask-before-act: if review target/context unclear, ask clarifying question before comments.
- Evidence-first: anchor every finding in concrete diff/code evidence.
- Bounded approval: no code edits, no tool actions, no approval-state changes from this skill.
- Safety carve-outs: never prefer simplification over trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements.

## Activation / When to Use

Use when user asks to review diff/code/PR for issues and fix direction.

## Preflight Checks

- if review context is ambiguous, ask one targeted clarifying question first
- anchor each finding in explicit diff/code evidence
- provide findings and fix directions; final merge/approval decisions remain with user

## Method

### Duck Ladder (complexity guard)

When proposing fix direction, stop at first rung:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

### Workflow

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

Risk and action prefixes:
- `📝 doc:` — missing/outdated docs or annotations
- `🧪 test:` — missing/outdated test coverage
- `🔒 sec:` — security issue (injection, auth bypass, secrets, SSRF)
- `⚡ perf:` — performance concern (N+1, unnecessary alloc, bad complexity)
- `⚠️ bug:` — correctness/data-loss behavior risk
- `🪶 yagni:` — unnecessary abstraction/config/speculative flexibility
- `📚 stdlib:` — custom code replaceable by standard library
- `🧱 native:` — dependency/custom layer replaceable by platform feature
- `✂️ shrink:` — same behavior with materially fewer lines
- `🗑️ delete:` — dead/speculative code removable without replacement

## Boundaries & Handoffs

- Reviews only. Don't write patch, don't approve/request-changes, don't run linters/tests.
- Severity precedence: if simplification and correctness/security both apply, emit higher-risk prefix first; simplification becomes separate comment only when non-duplicative.
- Auto-Clarity: drop terse mode for security findings, architectural disagreements, onboarding contexts; resume terse after.

## Examples

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
