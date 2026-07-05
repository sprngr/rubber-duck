# Skill Assembly Phase 1 (duck-debug)

## Goal

Establish a source-first workflow where authored skill content lives in `src/skills/` and install-ready artifacts live in `skills/`.

Constraint: `npx skills` installs from `skills/`, so assembled output must be written there.

## Scope (Phase 1)

- Migrate one skill (`duck-debug`) to source layout.
- Keep behavior unchanged.
- Define assembly contract and validation invariants.
- Assembly script is introduced for duck-debug copy-through; CI runs `scripts/assemble-skills.sh --check` to detect drift.

## Directory Model

```text
src/
  skills/
    duck-debug/
      SKILL.md
      references/
        GUARDRAILS.md

skills/
  duck-debug/
    SKILL.md
    references/
      GUARDRAILS.md
```

Rule:
- `src/skills/**` = authored source of truth.
- `skills/**` = generated install artifacts for `npx skills`.

## Assembly Contract

Input:
- `src/skills/<name>/SKILL.md`
- `src/skills/<name>/references/**` (when present)

Output:
- `skills/<name>/SKILL.md`
- `skills/<name>/references/**`

Phase 1 behavior:
- Copy-through assembly (no templating/transforms yet).
- Byte-preserving output is preferred.

## Validation Invariants

Assembler/lint should fail when any invariant is violated:

1) **Install target invariant**
- Assembled artifact exists in `skills/<name>/...`.

2) **Parity invariant**
- `skills/<name>/...` matches assembled output from `src/skills/<name>/...`.

3) **Portability invariant**
- No repo-coupled references in skill text (examples: `AGENTS.md`, absolute local paths).

4) **Policy invariant**
- Skill includes or references canonical guardrails semantics:
  - decision ownership
  - ask-before-act
  - evidence-first
  - bounded approval
  - safety carve-outs

## Authoring Rules

- Edit only `src/skills/**`.
- Treat `skills/**` as generated output; no manual edits.
- Keep skill content environment-portable; avoid naming repo-local policy files.

## Current Commands (duck-debug)

Build artifacts into install path:

```bash
bash scripts/assemble-skills.sh
```

Check for drift without writing files:

```bash
bash scripts/assemble-skills.sh --check
```

## Suggested Next Steps

1. Add `src/skills/duck-debug/references/GUARDRAILS.md` (source mirror).
2. Add assembler script (copy-through initially).
3. Add drift check command in CI (fail if `skills/**` differs from assembly output).
4. Expand to remaining duck skills.
5. Add `src/agents/` in later phase with same source→artifact pattern.
