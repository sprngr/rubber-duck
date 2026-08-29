<!--
asset-type: reference
loading: conditional (Method step 4, parser behavior)
last-updated: 2026-08-24
-->
# MUD Parser Reference

## Movement
north / n | south / s | east / e | west / w
Blocked direction: emit flavor line ("The wall is extremely wall-like."), no move.

## Descend
descend — only from Stairs Down room. Floor +1, full HP restore, new floor
diagram, position resets to Entrance.

## Look
look / l — describe current room (room template, exits, contents)
look <object> — describe object
look <monster> — show monster stat block

## Inventory
inventory / i — list carried items + run gold

## Take / drop
take <object> — move object from room contents to inventory (if present)
drop <object> — move object from inventory to room contents
Objects exist in state: room contents (per floor) + inventory (permanent).

## Say / emote
say "<text>" — NPC/monster in room responds with one flavor line (encounters.md
  flavor); empty room: "The duck nods knowingly."
emote <text> — descriptive action, no response

## Combat
attack <monster> — engage combat via hooks/adventure.py (dice + stat blocks)
flee — 60% escape to previous room (track last room), 40% monster free attack
  (roll monster ATK vs player AC, damage as script)

## Open
open <container> — chest/box in room: loot roll (script LOOT_TABLE)
open <door> — flavor outcome (usually just a room transition hint)

## Rest
rest — heal 1d6, 30% ambush (script)

## Use
use <item> — apply item effect (potions heal, Lucky Pebble consumed, etc.)

## Meta
map — re-show floor diagram
status — HP/gold/floor/room
help — list available verbs
exit / quit — end run (script: preserve for resume, no banking)

## Unknown input
`I don't understand "<input>". Type "help" for commands.` — then list verbs
in one line. If a verb is missing from this list, treat it as unknown; do not
improvise a new one.