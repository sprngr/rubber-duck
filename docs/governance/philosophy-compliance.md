# Rubber Duck Philosophy Compliance Charter

## Purpose

This charter defines how Rubber Duck verifies that all agents and skills adhere to the project philosophy before release.

## Scope

In scope for compliance review:

- Router: `agents/rubber-duck.agent.md`
- Duckling agents:
  - `agents/duck-investigator.agent.md`
  - `agents/duck-reviewer.agent.md`
  - `agents/duck-adversary.agent.md`
  - `agents/duck-simple.agent.md`
  - `agents/duck-dry.agent.md`
  - `agents/duck-builder.agent.md`
- Skills:
  - `skills/duck-debug/SKILL.md`
  - `skills/duck-review/SKILL.md`
  - `skills/duck-design/SKILL.md`
  - `skills/duck-explain/SKILL.md`
  - `skills/duck-teach/SKILL.md`
  - `skills/duck-triage/SKILL.md`
  - `skills/duck-debt/SKILL.md`

## Non-negotiable philosophy checks

Every reviewed artifact must preserve these principles:

1. **Human decision ownership**
   - Assistant supports decisions; does not silently make them.
2. **Socratic collaboration**
   - Assistant asks targeted clarifying questions and reveals assumptions.
3. **Evidence before action**
   - Claims and recommendations are grounded in repository evidence.
4. **Bounded execution discipline**
   - Implementation/action requires explicit approval with clear scope.
5. **Minimal-change and safety discipline**
   - Prefer root-cause minimal fixes and never simplify away security/trust/data/accessibility requirements.

## Compliance artifacts

Each review cycle must produce:

- Rubric results using `docs/governance/rubric.md`
- Behavior test evidence using `docs/governance/behavior-tests.md`
- Completed templates from `docs/governance/templates/`

## Failure severity

- **Critical**: direct conflict with non-negotiable philosophy checks.
- **Major**: behavior ambiguity likely to bypass philosophy in real sessions.
- **Minor**: wording/clarity issue that does not change intent.

## Release expectation

No release is considered philosophy-compliant when any critical finding remains unresolved.
