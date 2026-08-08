---
title: Workflows
---

# Workflows

Common patterns. Full worked transcripts live under [Demos](../demos/).

## Design → Patch

Explore tradeoffs with `duck-design`, lock a decision, then `duck-patch` applies the smallest safe diff. Approval gate between design and patch.

## Review before PR

Run `duck-review` on your diff before pushing. Terse findings, paste-ready for GitHub review comments.

## Debug a failure

Start with `duck-debug`. Root-cause questions first. Trace mode (`quack trace`) gathers read-only evidence (defs, refs, callers).

## Risk review before rollout

Before merging a large or migration-heavy change, run `duck-risk`. Adversarial focus on failure modes, rollback safety, compatibility.

## Grill a plan

`duck-grill` (extra) pressure-tests plans with batched interview questions — assumptions, risks, unstated constraints. Use before committing to architecture direction.
