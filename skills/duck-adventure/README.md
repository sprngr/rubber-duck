# duck-adventure: Easter-Egg Rogue Game 🦆🎲

Standalone opt-in game skill: multi-turn dungeon crawls with dice combat, random merchants, loot, and condition-tied achievements. Pure play — no productivity coupling, no handoff to work flows. Explicit opt-in ("duck adventure") and explicit exit ("done").

## Why It Exists

A cozy rogue RPG for engineers. The duck is not here to be understood; the duck is here so decisions feel less lonely. Derived from [chaos-duck](https://github.com/BreezeButter/chaos-duck) (MIT), adapted and extended for the rubber-duck harness.

## Gameplay

- **Scripted engine** (`hooks/adventure.py`): floors 1-8, d20/d6 dice combat, merchant trade, loot rolls, run-end banking. Deterministic mechanics live in code; the LLM narrates only.
- **Room-graph navigation**: position is a room name, not coordinates — no map drift. Rooms: Entrance, Guard Post, Vault, Merchant Stall, Odd Clearing, Boss Chamber, Stairs Down, Storage Room, Shrine, Trap Room (hazard), Healing Spring (free heal), Treasure Hoard (guaranteed loot).
- **Two victories**: floor 5 Duck King (Crown of the Duck King) or floor 8 Duck Emperor (Emperor's Gilded Feather).
- **Achievements**: tied to run events — won combat, opened chest, bought item, fled a fight, reached floor 3, defeated a boss.
- **Rogue-lite persistence**: permanent collection (gold hoard, inventory, achievements, quest log) survives death/reset; voluntary exit preserves the run for resume.

## Commands

MUD-style verbs, parsed per `references/PARSER.md`:

- **Movement:** `north`/`n` | `south`/`s` | `east`/`e` | `west`/`w`
- **Descend:** `descend` — only from Stairs Down; floor +1, full HP restore, new floor
- **Look:** `look` / `look <object>` / `look <monster>`
- **Inventory:** `inventory` / `i`
- **Objects:** `take <object>` / `drop <object>` / `open <container>`
- **Combat:** `attack <monster>` / `flee`
- **Merchant:** `merchant` (show stock) / `merchant buy <item>` / `merchant sell <item>`
- **Rest:** `rest` — heal 1d6, 30% ambush chance
- **Use:** `use <item>` — potions, elixirs, Lucky Pebble
- **Meta:** `map` | `status` | `help` | `exit`/`quit` (preserve run for resume)
- **Narrative:** `say "<text>"` / `emote <text>` — LLM-only, no script call

Unknown input: `I don't understand "<input>". Type "help" for commands.`

## Quick Start

1. Install manually (not in installer extras): `npx skills add --skill duck-adventure`
2. Say `duck adventure` — the skill requests one-time approval for the state-file scope (`.duck-adventure/state.json` + `state.md`).
3. Play. `exit` preserves your run; death or victory banks gold and resets the run.
4. Say `done` when finished.

Requires `python3` at play time (in the standard toolchain).

## File Layout

```
src/skills/duck-adventure/
  SKILL.md                      — skill definition (Method: opt-in gate, state
                                  approval, run setup, turn loop, combat, merchant,
                                  events, run end)
  hooks/adventure.py            — deterministic engine (17 subcommands, JSON state)
  assets/
    lore.md                     — duck lore (narrative)
    events.md                   — random events (narrative)
    quests.md                   — quest frames + choice paths (narrative)
    encounters.md               — duck/merchant/wizard encounters (narrative)
  references/
    ENGINE.md                   — mirror of script-owned tables (rooms, monsters,
                                  loot, items, merchant stock, achievements)
    PARSER.md                   — verb surface + command semantics
    STATE_SCHEMA.md             — state.json schema v3
    GUARDRAILS.md               — shared guardrails (injected)
  evals/evals.json              — behavior evaluations
```

Runtime state (not committed):

```
<project>/.duck-adventure/
  .gitignore                    — `*` (auto-created by script)
  state.json                    — script-owned state (schema v3)
  state.md                      — LLM-rendered summary at run end
```

## State Model

`.duck-adventure/state.json` is script-owned (schema v3): `permanent` (gold hoard, inventory, achievements, quest log) survives death/reset; `run` (quest, flags, HP, floor, room, run gold, diagram) resets on death, preserves on exit. Full schema in `references/STATE_SCHEMA.md`.

## Security

- State writes require one-time execution approval at game start (scope: state.json + state.md + `.gitignore`).
- Redaction before every write: secrets/PII rejected; mask-in-place (`<REDACTED>`) only on explicit confirmation.
- No other files written. No persistence beyond `.duck-adventure/`.

## Attribution

Adapted from **Chaos Duck** by BreezeButter — https://github.com/BreezeButter/chaos-duck (MIT license). Original concept: a whimsical AI personality that turns conversations into tiny RPG moments before helping with real decisions.

This skill preserves the spirit (cozy nonsense, dramatic micro-quests, magical bureaucracy) but reworks the mechanics:

- **Quest loop** → scripted rogue engine (deterministic dice, state, run-end semantics)
- **Choice templates** → deduplicated quest frames (12) + mechanical room variety
- **Content libraries** → narrative assets (lore, events, encounters) kept as LLM-flavor, tables moved to code
- **"Then help the user clearly"** → dropped: this is pure play with explicit exit, no productivity handoff

Changes are substantial: mechanics, structure, and integration are new. Upstream content (lore incidents, event types, encounter variants, quest frames) is deduplicated and extended under the same MIT license.

## References

- `references/ENGINE.md` — script-owned data tables (source of truth: `hooks/adventure.py`)
- `references/PARSER.md` — full verb surface and semantics
- `references/STATE_SCHEMA.md` — state.json schema v3
- `hooks/adventure.py` — the engine; `python3 hooks/adventure.py --help` for subcommands