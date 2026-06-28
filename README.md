# Rubber Duck

🦆

## Quick Install

```bash
# Skills only (no router/agents)
npx skills add https://github.com/sprngr/rubber-duck

# Full system (AGENTS + router + subagents + skills)
bash scripts/install.sh
```

# Operator Manual

Operational guide for rubber-duck router, duckling subagents, and rubber-duck skills.

## Installation and Distribution

### Harness support matrix

| Harness | Status | Native plugin | Fallback mode | Commands available |
|---|---|---|---|---|
| OpenCode / skills CLI | Available | N/A | Local install + skills import | Yes (`quack`, skill triggers) |
| Claude Code | Planned | Planned | Instruction/file mapping | Fallback only |
| Codex | Planned | Planned | Instruction/file mapping | Fallback only |
| Cursor | Planned | Planned | Instruction/file mapping | Fallback only |
| Windsurf | Planned | Planned | Instruction/file mapping | Fallback only |
| Gemini / Antigravity CLI | Planned | Planned | Instruction/file mapping | Fallback only |
| GitHub Copilot (CLI + Editor) | Planned | Planned | Instruction/file mapping | Fallback only |

### OpenCode / skills CLI (Available)

Skills-only:

```bash
npx skills add https://github.com/sprngr/rubber-duck
```

Full system (policy + router + subagents + skills):

```bash
bash scripts/install.sh
```

Optional flags:

```bash
# install to custom location
bash scripts/install.sh --prefix "$HOME/.config/opencode"

# install subsets
bash scripts/install.sh --skills-only
bash scripts/install.sh --agents-only
bash scripts/install.sh --policy-only

# safety/automation
bash scripts/install.sh --dry-run
bash scripts/install.sh --force
```

Default install target:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/opencode/rubber-duck/
```

Installed path layout:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/opencode/rubber-duck/
  AGENTS.md
  agents/*.agent.md
  skills/**
```

### Claude Code (Planned)

Planned command:

```bash
# planned
/plugin marketplace add sprngr/rubber-duck
/plugin install rubber-duck@rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → project root `AGENTS.md`
- `agents/*.agent.md` → local reference docs for router/subagent contracts
- `skills/**` → imported skill prompts in Claude-compatible workflow

### Codex (Planned)

Planned command:

```bash
# planned
codex plugin marketplace add sprngr/rubber-duck
codex plugin install rubber-duck@rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → project root `AGENTS.md` (baseline behavior)
- `agents/*.agent.md` → project docs/reference for agent routing contracts
- `skills/**` → imported/registered skill prompts where Codex host supports skills

### Cursor (Planned)

Planned command:

```bash
# planned
cursor rules add https://github.com/sprngr/rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → project root instruction baseline
- `agents/*.agent.md` → reference docs for manual workflow routing
- `skills/**` → manually copied prompts into team snippets/rules where needed

### Windsurf (Planned)

Planned command:

```bash
# planned
windsurf rules add https://github.com/sprngr/rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → project root instruction baseline
- `agents/*.agent.md` → reference docs for manual workflow routing
- `skills/**` → manually copied prompts into Windsurf-compatible rule files

### Gemini / Antigravity CLI (Planned)

Planned command:

```bash
# planned
gemini extensions install https://github.com/sprngr/rubber-duck
# or
agy plugin install https://github.com/sprngr/rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → workspace-level always-on instruction text
- `agents/*.agent.md` → router/subagent contract references
- `skills/**` → extension skill payload reference for manual import

### GitHub Copilot (CLI + Editor) (Planned)

Planned command:

```bash
# planned
copilot plugin marketplace add sprngr/rubber-duck
copilot plugin install rubber-duck@rubber-duck
```

Current fallback mapping:

- `AGENTS.md` → project root behavior policy
- `agents/*.agent.md` → reference docs for manual routing/playbooks
- `skills/**` → copied/adapted prompts in Copilot instruction flow

### Verify installation

1. Confirm files exist under `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/rubber-duck/`.
2. Start a fresh session in your harness.
3. Send `quack` and verify router responds with 🦆 status.

### Upgrade

Re-run installer from latest checkout:

```bash
bash scripts/install.sh --force
```

### Uninstall

Remove all installed artifacts:

```bash
bash scripts/uninstall.sh
```

Optional flags:

```bash
# remove only one subset
bash scripts/uninstall.sh --skills-only
bash scripts/uninstall.sh --agents-only
bash scripts/uninstall.sh --policy-only

# custom location and non-destructive preview
bash scripts/uninstall.sh --prefix "$HOME/.config/opencode"
bash scripts/uninstall.sh --dry-run

# skip prompts
bash scripts/uninstall.sh --force
```

---

## 1) System Map

### Router

- [🦆 rubber-duck router](../../../agents/rubber-duck.agent.md)

### Duckling subagents

- [duck-investigator](../../../agents/duck-investigator.agent.md)
- [duck-reviewer](../../../agents/duck-reviewer.agent.md)
- [duck-adversary](../../../agents/duck-adversary.agent.md)
- [duck-simple](../../../agents/duck-simple.agent.md)
- [duck-dry](../../../agents/duck-dry.agent.md)
- [duck-builder](../../../agents/duck-builder.agent.md)

### Skills

- [duck-explain](./duck-explain/SKILL.md)
- [duck-debug](./duck-debug/SKILL.md)
- [duck-design](./duck-design/SKILL.md)
- [duck-review](./duck-review/SKILL.md)
- [duck-teach](./duck-teach/SKILL.md)
- [duck-triage](./duck-triage/SKILL.md)
- [duck-debt](./duck-debt/SKILL.md)

### Related policy docs

- [repo AGENTS policy](../../../AGENTS.md)
- [agents overview](../../../agents/README.md)
- [review comment examples](./duck-review/references/review-comment-examples.md)

---

## 2) Operating Model (How system runs)

1. Router classifies user input shape (review/debug/explain/design/teach/triage/debt).
2. Router activates primary skill.
3. Router chains ducklings for lens-specific analysis when needed.
4. Reviewer consolidates overlapping findings into one comment stream.
5. Builder is last mile only, for explicit bounded patch requests.

### Soft preflight before patching

Before `duck-builder`, prefer evidence pass that confirms:

- target artifact/path
- expected behavior
- smallest shared fix location (not only ticket path)

If missing, ask one clarifying question or route investigator.

---

## 3) Router Decision Table

| Input signal | Start with | Typical chain |
|---|---|---|
| “review this” + diff/code | `duck-review` | `duck-reviewer` + `duck-adversary` + `duck-simple` (+ `duck-dry` if duplication, + `duck-triage` if test gap) |
| “debug this” + complaint | `duck-debug` | `duck-investigator` first, then `duck-triage` if repro weak, then `duck-builder` only on explicit bounded patch request |
| “explain this” | `duck-explain` | escalate to `duck-debug` (bug) or `duck-review` (PR review output) |
| “teach me/how works” | `duck-teach` | escalate to `duck-debug` or `duck-review` if issue emerges |
| “design/tradeoffs” | `duck-design` | `duck-simple` + `duck-adversary` (+ `duck-dry` on shared-rule duplication) |
| “what to test/test coverage” | `duck-triage` | `duck-review` if inline PR comments needed |
| “what did we defer/duck debt” | `duck-debt` | report-only ledger of `duck-debt:` markers |
| Unclear request | ask 1 clarifying question | route after answer |

---

## 4) Duckling Responsibilities (strict boundaries)

### `duck-investigator`

- Evidence only: defs/refs/callers/tests/imports, with evidence IDs (`E1`, `E2`, ...).
- No fixes, no design decisions.
- Feeds debug/review/design/triage with facts.
- Reports coverage gaps explicitly (`not found` vs omitted) and names shared-path candidate when present.

### `duck-reviewer`

- Owns final review comment stream.
- Applies priority order during merge:
  - security/correctness
  - data integrity
  - rollback/compat
  - test gaps
  - simplification

### `duck-adversary`

- Failure modes, rollback, compatibility, security-misuse lens.
- No style/simplification/test-ownership feedback.
- Each finding carries explicit `Impact` and `Rollback` fields.

### `duck-simple`

- Complexity and overengineering lens.
- Uses simplification tags (`🪶 yagni`, `📚 stdlib`, `🧱 native`, `✂️ shrink`, `🗑️ delete`).

### `duck-dry`

- Meaningful duplication and divergence risk lens.
- Flags semantic duplication only (not superficial syntax repetition).
- Each finding includes `Diverges when` trigger and `Extract start` location.

### `duck-builder`

- Surgical implementation only.
- Scope: 1 file ideal, 2 files max.

---

## 5) Skill-by-Skill Operator Notes

### `duck-debug`

- Socratic root-cause flow.
- Requires root-cause locality: prefer shared-path fix over per-caller symptom patches.

### `duck-review`

- Review output contract source of truth.
- Prefixes include correctness/security/perf/test/doc plus simplification tags.
- If finding spans risk + simplification, emit higher-risk prefix first.

### `duck-triage`

- Coverage, severity, test scenario recommendations.
- Minimum runnable check rule for non-trivial logic changes.

### `duck-design`

- Tradeoff facilitation and constraint-first questioning.
- Escalates runtime bugs back to debug.

### `duck-explain`

- 4-block explanation mode (What/Why/Watch out/Next question).

### `duck-teach`

- Structured tutorials with depth scaling.

### `duck-debt`

- Reads `duck-debt:` comments and emits debt ledger.
- Report only; no edits.

---

## 6) Shared Ladder Policy (all duck skills)

Before new code/abstraction, climb ladder and stop early:

1. Need change at all?
2. Reuse existing local helper/pattern?
3. Use stdlib/native feature?
4. Use already-installed dependency?
5. Smallest safe bounded diff?
6. Only then add new abstraction/code.

Never simplify away trust-boundary validation, security, data-loss prevention, accessibility, or explicit user requirements.

---

## 7) Playbooks (copy/paste prompts)

### Review playbook

```text
Review this diff. Use duck-review contract. Prioritize security/correctness first.
If duplication appears, include duck-dry lens. If tests missing, include duck-triage.
```

### Debug playbook

```text
Debug this issue. Start with duck-investigator evidence map (defs/refs/callers/tests),
then run duck-debug root-cause questioning. Suggest patch target only after caller map.
```

### Design playbook

```text
Evaluate this design with duck-design. Challenge constraints and tradeoffs.
Include duck-simple and duck-adversary lenses. Keep one recommended next question.
```

### Triage playbook

```text
Triage this bug and test coverage. Classify severity, list missing tests,
and propose one minimum runnable check for non-trivial logic changes.
```

### Debt playbook

```text
Run duck-debt. Scan for `duck-debt:` markers and output grouped ledger with
ceiling + upgrade trigger + no-trigger counts.
```

---

## 8) `duck-debt:` Marker Standard

Use this exact format in code comments:

```text
duck-debt: <ceiling>, upgrade when <trigger>
```

Examples:

```text
duck-debt: O(n²) scan, upgrade when list >10k
duck-debt: global lock, upgrade when throughput contention observed
```

---

## 9) Common Failure Modes

- Reviewer duplicates same issue across ducklings.
  - Fix: merge by strongest priority prefix, emit one comment.
- Builder starts before evidence.
  - Fix: run soft preflight + investigator map first.
- Simplification comment hides security issue.
  - Fix: use risk prefix first, simplification second only if non-duplicative.
- “No tests needed” over-applied.
  - Fix: apply minimum runnable check rule for non-trivial logic.

---

## 10) Maintenance

- Keep router rules and skill boundaries synchronized with agent files.
- Update this README when adding/removing ducklings or skills.
- Validate harness adapters before release:

```bash
make adapters-check
# or run steps directly:
bash scripts/build-adapters.sh
bash scripts/smoke/all.sh
```

---

## Attribution

Parts of Rubber Duck operating model adapt ideas from [Ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert.

### Concept mapping (Ponytail → Rubber Duck adaptation)

- **Lazy ladder / first-rung decision policy**  
  Ponytail: YAGNI → reuse → stdlib → native → installed dep → minimal code.  
  Rubber Duck: shared “Duck Ladder” added across `duck-debug`, `duck-review`, `duck-triage`, `duck-design`, `duck-teach`, `duck-explain`.

- **Root cause over symptom patching**  
  Ponytail: fix shared path once, not caller-by-caller.  
  Rubber Duck: `duck-debug` root-cause locality + caller-map-before-patch guidance.

- **Overengineering review taxonomy**  
  Ponytail: `delete/stdlib/native/yagni/shrink` review lens.  
  Rubber Duck: simplification prefixes (`🪶 yagni`, `📚 stdlib`, `🧱 native`, `✂️ shrink`, `🗑️ delete`) in `duck-review` and `duck-simple`.

- **Risk-first precedence during review**  
  Ponytail: simplification never at expense of safety/correctness.  
  Rubber Duck: reviewer merge order and prefix precedence enforce security/correctness first.

- **Minimum-check discipline**  
  Ponytail: non-trivial logic leaves one runnable check.  
  Rubber Duck: `duck-triage` minimum runnable check rule.

- **Deferred simplification ledger**  
  Ponytail: `ponytail:` debt markers and debt harvesting.  
  Rubber Duck: `duck-debt:` marker convention + `duck-debt` skill for read-only debt ledger.

- **Safety carve-outs**  
  Ponytail: never simplify away trust-boundary validation, security, data-loss prevention, accessibility.  
  Rubber Duck: mirrored in repo [AGENTS policy](../../../AGENTS.md) minimal-change discipline and skill policy text.

### Notes

- Rubber Duck keeps its own Socratic + multi-duckling routing model.
- Attribution covers conceptual influence, not verbatim behavior parity.
