---
title: Verify
---

# Verify

Confirm rubber-duck loaded correctly after install. Four quick checks.

## Step 0: Enable the agent

In your harness, activate the rubber-duck agent (opencode: agent picker; claude: skill activation; copilot: agent switch). This loads the policy from `AGENTS.md`.

## Step 1: Heartbeat

Type `quack` (nothing else). Expected: one heartbeat line + quick-help + closing prompt.

If you get an ad-hoc response instead of the fixed heartbeat template, the quack skill isn't installed or isn't loading.

## Step 2: Review behavior

Ask for a code review on a small diff. Expected: terse, one-line findings with location + problem + fix. No filler prose.

If output is long-form paragraphs, `duck-review` isn't routing.

## Step 3: Debug behavior

Ask "why is this failing?" with a small snippet. Expected: root-cause questions before any speculation. No fix suggestions until evidence is on the table.

If it jumps straight to fixes, `duck-debug` isn't routing.

## Extras verification

If you installed with `--extras`, verify `duck-tape` initialized correctly: `duck-tape init` should confirm a persistent `CONTEXT.md` bootstrap ran. Re-run safely if unsure — it's idempotent.

Trouble? See [Invocation](./invocation.md) for routing basics.
