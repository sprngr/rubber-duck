<!--
asset-type: reference
loading: conditional (Method step 2/4, state read/write)
last-updated: 2026-08-24
-->
# State Schema v3 (.duck-adventure/state.json)

Script-owned JSON state. The script reads/writes this file; the LLM narrates
from its output and renders `.duck-adventure/state.md` summary at run end.

```json
{
  "version": 3,
  "permanent": {
    "gold_hoard": 0,
    "inventory": ["<item>", ...],
    "achievements": ["<achievement>", ...],
    "quest_log": [{"quest": "<name>", "category": "<cat>", "outcome": "complete|death|exit"}]
  },
  "run": {
    "current_quest": "<name>",
    "quest_category": "<category>",
    "flags": {
      "won_combat": false,
      "opened_chest": false,
      "bought_item": false,
      "fled_fight": false,
      "floor_reached": 1,
      "boss_defeated": false
    },
    "floors_cleared": 0,
    "hp": 20,
    "max_hp": 20,
    "atk": 2,
    "ac": 12,
    "floor": 1,
    "room": "<room name>",
    "last_room": "<room name|null>",
    "run_gold": 0,
    "diagram": {"rooms": {}, "exits": {}, "contents": {}}
  }
}
```

## Rules
- Script owns state.json. LLM never writes it directly — all mutations via
  script subcommands.
- Permanent survives death. Run resets on death.
- Run gold banks to hoard at run end (exit, death, or complete).
- Quest log records every run end with outcome.
- LLM renders state.md summary at run end (human-readable), overwrite each run.
- Write only state.json + state.md + `.duck-adventure/.gitignore`. Redact secrets.