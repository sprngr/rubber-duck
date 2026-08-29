---
name: duck-adventure
description: >
  Standalone easter-egg rogue game. Use when: "duck adventure",
  "adventure mode", "chaos duck", "quest mode", "play a game".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v3.1.0
---

Standalone easter-egg rogue game 🦆🎲. Multi-turn dungeon crawls, dice combat, then exit. No work involved.

## Purpose

Run a self-contained rogue RPG: multi-turn dungeon crawls with maps, dice
combat, random merchants, loot, and achievements tracked across sessions. Fun
for its own sake. No handoff to productivity flows.

Skill-specific delta:

- Opt-in only: game runs on explicit signal; if no signal, do not auto-inject into normal flows.
- Pure play: no productivity coupling, no handoff, no quack routing.
- Explicit exit: game ends when user says done/exit/quit. No implied return-to-work.
- Scripted engine: deterministic mechanics via `hooks/adventure.py`; LLM narrates output.
- State scope: writes only `.duck-adventure/state.json` + `state.md` (+ `.gitignore` if missing).
- One-time scope approval: game session approves state-file scope once at start; script writes state.json, LLM writes state.md summary at run end.
- Redaction: scan state content for secrets before any write; reject flagged content.

## Activation

Explicit opt-in signals only: "duck adventure", "adventure mode", "chaos duck",
"quest mode", "play a game", "make it fun", `/adventure`. No signal = no game.
Do not auto-activate from inferred intent.

## Method

### 1. Opt-in gate

Verify explicit signal. If absent, decline: no game. Continue normal flow.

### 2. State load + scope approval

Read `.duck-adventure/state.json` (schema v3, `references/STATE_SCHEMA.md`,
`references/PARSER.md` for verb surface) via `python3 hooks/adventure.py resume`.
If missing, request one-time execution approval for the state-file scope
(`.duck-adventure/state.json` + `state.md` + auto-created
`.duck-adventure/.gitignore`). Preflight: target files, expected = run +
permanent ledger, verification = `adventure.py state`. On approval, proceed.
Without approval, game runs
session-only or exits. Existing run in state: resume at saved floor/room/diagram.
Else: new run.

### 3. Run setup

New run: `python3 hooks/adventure.py init` (generates floor 1, player stats).
Resume: `python3 hooks/adventure.py resume`. Both return JSON state.
Name the quest from a `assets/quests.md` frame + category; record as
`current_quest` via `python3 hooks/adventure.py save` (script field; LLM
narrates the quest name).

### 4. Turn loop

Repeat until run end. Each turn:

1. Show room description from `python3 hooks/adventure.py look` + status from
   `state`. Diagram at floor entry + on `map`.
2. Player command: parse per `references/PARSER.md`. Mechanical verbs call the
   script (`move`, `look`, `take`, `drop`, `inventory`, `open`, `rest`, `use`,
   `attack`, `flee`, `merchant`, `map`). Narrative verbs (say/emote) stay in
   the LLM. Unknown input: parser unknown-input line.
3. Script returns JSON: room change, combat result, loot, merchant stock.
   LLM narrates the result in dungeon voice. Never re-roll or re-derive what
   the script returned.
4. At Stairs Down, `descend` (script): floor +1, full HP restore, new floor.
   Boss on floor 5 or 8 defeated = run complete (script flags it, end_run
   banks + awards trophy: Crown of the Duck King on F5, Emperor's Gilded
   Feather on F8).

### 5. Combat

`python3 hooks/adventure.py attack <monster>` — script rolls dice, applies
damage, checks HP 0 (run end), rolls loot on defeat (script LOOT_TABLE +
ITEM_POOL). Stat blocks + tables in `references/ENGINE.md`. LLM narrates.

### 6. Merchant

`python3 hooks/adventure.py merchant` — script shows stock + run gold.
`merchant buy <item>` / `merchant sell <item>` — script updates inventory/gold.
Stock + prices in `references/ENGINE.md`. LLM narrates the transaction.

### 7. Event

LLM-only: present 2-4 CYOA choices from `assets/quests.md` +
`assets/encounters.md`, flavored with `assets/lore.md` tone; optionally one
`assets/events.md` random event (max 1 per event). User picks; outcome applies
via script (gold/HP/loot/event). Continue loop.

### 8. Run end

Run-end is script-driven via `end_run`:
- Death (HP 0 in attack/flee/rest): script banks run gold, logs quest
  (outcome death), awards condition-tied achievements (event flags), resets run.
- Complete (floor 5 or 8 boss defeated): script banks gold, awards trophy
  (Crown of the Duck King on F5, Emperor's Gilded Feather on F8), awards
  condition-tied achievements, logs quest (outcome complete), resets run.
- Voluntary exit: script preserves run state for resume (no banking).
LLM renders `state.md` summary (schema v3), emits closing beat (one line).
No handoff to work flows.

## Boundaries

- Pure game: no productivity coupling, no handoff, no quack routing.
- Writes only `.duck-adventure/state.json` + `state.md` (+ `.gitignore` if missing). No other files.
- State is script-owned (schema v3); dedupe by name, no history rewrite.
- Redaction before writes: if state content contains secrets/PII, reject the write.
- State scope approval is one-time per game session; scope changes reopen approval.
- No mutating actions outside the approved state-file scope.
- Not routed via quack. Explicit opt-in and explicit exit only.
