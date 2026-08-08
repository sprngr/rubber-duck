---
title: Review before PR
---

# Review before PR

User pastes a diff before pushing. Duck returns one-line findings.

---

**User:** `quack review` — please review this diff:

```diff
+function processPayment(amount, userId) {
+  const user = db.users.findOne({ id: userId });
+  const fee = amount * 0.03;
+  db.transactions.insert({ userId, amount, fee });
+  return { success: true };
+}
```

**Duck:** Routing: duck-review.

Findings:

- **L2:** no null-check on `user`; if lookup misses, silent success returns. Fix: guard + explicit not-found error.
- **L3:** magic number `0.03`; not testable, not adjustable per user tier. Fix: pull from config or accept as arg.
- **L4:** no error handling on `insert`; DB failure returns `{success: true}` — false positive. Fix: try/catch, propagate failure.
- **L5:** return shape hides `fee` charged; caller can't verify. Fix: include `fee` + `transactionId`.
- **Cross-cutting:** no idempotency key. Duplicate submits will double-charge. Fix: idempotency-token param, deduplicate on insert.

Highest risk: idempotency + silent-success. Address those first.

**User:** thanks — will fix idempotency + null-check before opening PR.
