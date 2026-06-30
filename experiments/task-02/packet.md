# Task Packet — task-02

## Task ID

`task-02`

## Task type

- [ ] review
- [x] debug
- [ ] design
- [ ] triage

## Prompt to assistant (exact text)

```text
My Node/TS API has a data integrity bug: updating one user's default address sometimes changes another user's default address.
Help me debug this.

Relevant code:

// src/api/address/updateDefaultAddress.ts
export async function updateDefaultAddress(req: Request, res: Response) {
  const userId = req.auth.userId;
  const { addressId } = req.body;

  await db.tx(async (trx) => {
    await trx("addresses")
      .where({ is_default: true })
      .update({ is_default: false });

    await trx("addresses")
      .where({ id: addressId })
      .update({ is_default: true, updated_at: new Date() });
  });

  return res.status(204).send();
}

// src/repo/addressRepo.ts
export async function getDefaultAddress(userId: string) {
  return db("addresses")
    .where({ user_id: userId, is_default: true })
    .first();
}

// src/db/schema.sql
// addresses(id uuid pk, user_id uuid not null, is_default boolean not null default false)
// index on (user_id)

Observed behavior:
- User A sets default address successfully.
- User B sets default address after that.
- User A now has no default address, or User B's default flips unexpectedly under load.

Recent log snippets:
[info] PATCH /me/addresses/default user=uA address=a1 status=204
[info] PATCH /me/addresses/default user=uB address=b7 status=204
[warn] invariant check failed: expected exactly 1 default address for user=uA, found=0

Please find likely root cause and smallest safe fix direction.
```

## Context artifact(s)

- Handler snippet
- Repo read path
- Schema summary
- observed behavior + logs

## Intentional gaps (inject 1-3)

- [x] acceptance criteria ambiguity
- [x] missing edge-case requirement
- [x] rollback requirement omitted
- [ ] trust-boundary/security constraint implicit only
- [ ] compatibility constraint omitted
- [ ] test expectation underspecified

Gap details:

1. No explicit constraint whether exactly one default per user is required at all times vs eventually.
2. No concurrency/isolation policy provided.
3. No explicit rollback/recovery behavior if second update fails mid-transaction.

## Hidden oracle (for evaluator only)

Ground truth expectations:

- Required root-cause direction:
  - unset query is global (`where is_default = true`) and not scoped by `user_id`, so one user's write affects others.
- Required minimal fix direction:
  - scope unset to current user and target row ownership checks:
    - unset: `where { user_id: userId, is_default: true }`
    - set: `where { id: addressId, user_id: userId }`
  - keep changes inside transaction.
- Strong recommendation expected:
  - add DB-level integrity guard (partial unique index) if supported, e.g. one default per user.
- Required debugging quality:
  - ask/confirm expected invariant and race behavior before proposing broad refactor.

Forbidden outcomes:
- patching each caller without fixing shared write path
- suggesting removal of transaction as simplification

## Acceptance criteria (scored)

1. Identifies global `is_default` unset as cross-user data corruption root cause.
2. Proposes smallest safe scoped fix in shared write path.
3. Mentions ownership guard on `addressId` update (prevent cross-user write).
4. Considers concurrency/invariant reinforcement (test + optional DB constraint).
5. Preserves transactional integrity in fix direction.

## Constraints

- time budget: 30 minutes per condition
- max files intended to change: 1-2 for minimal patch direction
- non-goals: full repo refactor, ORM replacement, architecture migration

## Repro/verification commands

```bash
# optional if environment available
# npm test -- address.default.spec.ts
```

## Scoring notes

- expected failure modes:
  - misses user scope in unset query
  - suggests symptom-level caller checks only
  - no mention of ownership check on `addressId`
  - no concurrency/invariant test suggestion
