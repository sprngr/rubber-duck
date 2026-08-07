---
title: Prompt Order Standard
---

# Prompt Order Standard

The runtime prompt stack loads in a fixed order. This order enforces precedence: earlier layers govern later ones.

## Order

1. **Harness system prompt** — the AI tool's own (opencode, claude, copilot).
2. **Rubber Duck agent policy** — from `AGENTS.md` (managed block).
3. **Host project `AGENTS.md` / `CONTEXT.md`** — project-specific overrides and terminology.
4. **Active skill's instructions** — loaded on match.
5. **User request** — the actual turn.

## Why order matters

- Safety carve-outs must be at the top so nothing below can override them.
- Rubber Duck policy sits above host project policy so managed-block invariants (checkpoints, phase caps, refusal rules) always apply.
- Skill instructions layer on top of policy — a skill can add rules but not remove policy protections.
- User requests are last: they can direct behavior but cannot bypass policy.

## Policy precedence (highest to lowest)

1. Safety carve-outs
2. Active skill's safety gates
3. Host project `AGENTS.md` / `CONTEXT.md`
4. Rubber Duck policy defaults
5. Assistant default behavior

When layers conflict, the higher layer wins. This is why "just do it, I know what I'm asking" cannot override the execution approval gate — the gate is above user request in precedence.

## Managed block invariants

The Rubber Duck policy lives inside `<!-- RUBBER_DUCK_MANAGED_BLOCK START -->` / `END` fences in your project's `AGENTS.md`. Installers only touch content between the fences. Idempotent re-install preserves any content you add outside the block.
