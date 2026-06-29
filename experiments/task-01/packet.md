# Task Packet — task-01

## Task ID

`task-01`

## Task type

- [x] review
- [ ] debug
- [ ] design
- [ ] triage

## Prompt to assistant (exact text)

```text
Review this TypeScript API diff for correctness, safety, and simplification. Focus on high-risk findings first.

diff --git a/src/auth/parseAge.ts b/src/auth/parseAge.ts
index 1111111..2222222 100644
--- a/src/auth/parseAge.ts
+++ b/src/auth/parseAge.ts
@@ -1,8 +1,8 @@
 export function parseAge(input: string): number {
-  const n = Number.parseInt(input, 10);
-  if (Number.isNaN(n)) {
-    throw new Error("invalid age");
-  }
-  return n;
+  const n = Number(input);
+  if (!n) return 0;
+  return n;
 }

diff --git a/src/auth/register.ts b/src/auth/register.ts
index 3333333..4444444 100644
--- a/src/auth/register.ts
+++ b/src/auth/register.ts
@@ -10,15 +10,12 @@ export async function register(req: Request, res: Response) {
   const { email, password, age } = req.body;

-  if (!email || !password) {
-    return res.status(400).json({ error: "missing required fields" });
-  }
+  // assume gateway validates required fields

   const parsedAge = parseAge(age);

-  if (parsedAge < 13) {
+  if (parsedAge <= 12) {
     return res.status(400).json({ error: "must be 13+" });
   }

   const user = await userRepo.create({ email, passwordHash: hash(password), age: parsedAge });
   return res.status(201).json({ id: user.id });
 }
```

## Context artifact(s)

- The diff above is the only artifact provided to assistant.
- Assume Node + TypeScript + Express-like request/response handlers.

## Intentional gaps (inject 1-3)

- [x] acceptance criteria ambiguity
- [x] trust-boundary/security constraint implicit only
- [x] test expectation underspecified
- [ ] missing rollback requirement
- [ ] compatibility constraint omitted

Gap details:

1. No explicit product statement whether invalid age should throw, coerce, or default.
2. No explicit statement about trust boundary ownership (gateway vs handler validation).
3. No explicit minimum test list for edge inputs.

## Hidden oracle (for evaluator only)

Ground truth expectations:

- Required behavior:
  - invalid age inputs must be rejected (not coerced to 0)
  - handler must not assume external gateway validation for required auth fields
  - underage rule remains 13+ equivalent behavior (no silent expansion/restriction without spec)
- Forbidden behavior:
  - silent coercion of invalid input into valid age
  - removal of trust-boundary validation without replacement in same boundary
- Required safety checks:
  - preserve required field validation at handler boundary (or explicit equivalent in shared middleware proven in diff context)
- Required tests:
  - edge cases for age parse: "", "   ", "abc", "0", "12abc", "1.5", "Infinity"

## Acceptance criteria (scored)

1. Flags age parsing regression and explicit invalid-input coercion risk.
2. Flags trust-boundary risk from removed required field checks.
3. Prioritizes correctness/safety over simplification.
4. Provides concrete fix directions.
5. Suggests tests for relevant edge cases.

## Constraints

- time budget: 30 minutes per condition
- max files intended to change: N/A (review-only task)
- non-goals: style-only comments, naming nits without risk impact

## Repro/verification commands

```bash
# review-only task: no execution required
```

## Scoring notes

- tricky edge case: output-format drift (e.g., `- HIGH` bullets) should be scored separately from technical finding quality
- expected failure modes:
  - misses trust-boundary regression
  - over-focus on syntax simplification
  - no test recommendations
