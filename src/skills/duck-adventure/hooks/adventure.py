#!/usr/bin/env python3
"""duck-adventure deterministic engine. Stateless logic, JSON state.

Subcommands: init | resume | state | map | move <dir> | look [obj] |
attack <monster> | flee | rest | take <obj> | drop <obj> | inventory |
open <container> | merchant [buy|sell <item>] | use <item> | roll <XdY> |
exit | save

All output is JSON (compact) for the LLM to narrate. State lives in
.duck-adventure/state.json (script-owned). Narrative flavor comes from
skill assets, not from this script.
"""
import argparse
import json
import os
import random
import sys

STATE_PATH = os.path.join(".duck-adventure", "state.json")

# --- data tables (deterministic mechanics) -------------------------------
# Room types, monster stat blocks, loot table, merchant stock, item effects
# live here as Python structures. Narrative assets stay in skill markdown.

ROOM_TYPES = {
    "Entrance": "🕯️", "Guard Post": "🛡️", "Vault": "💰",
    "Merchant Stall": "📦", "Odd Clearing": "❓",
    "Boss Chamber": "👑", "Stairs Down": "➡️",
    "Storage Room": "📚", "Shrine": "⛩️",
    "Trap Room": "🪤", "Healing Spring": "⛲", "Treasure Hoard": "💎",
}

ROOM_FLAVOR = {
    "Entrance": "Dust motes dance in the doorway light.",
    "Guard Post": "A bored goblin guards a dented shield.",
    "Vault": "Coin light glints through a cracked chest.",
    "Merchant Stall": "Bells jingle; the smell of soup is strong.",
    "Odd Clearing": "The walls shimmer like they are not sure.",
    "Boss Chamber": "Something large breathes slowly here.",
    "Stairs Down": "Cool air rises from below.",
    "Storage Room": "Crates stacked taller than kindness.",
    "Shrine": "A tiny altar glows with polite candlelight.",
    "Trap Room": "A suspicious click echoes from the floor.",
    "Healing Spring": "Water glows with gentle insistence.",
    "Treasure Hoard": "Gold glints in organized piles.",
}

MONSTERS = {
    1: [("Goblin", 8, 1, 10), ("Rat", 5, 0, 9), ("Goblin Warlord", 12, 2, 11)],
    2: [("Skeleton", 12, 2, 11), ("Slime", 10, 1, 10), ("Skeleton Captain", 16, 3, 12)],
    3: [("Orc", 16, 3, 12), ("Bat Swarm", 9, 2, 11), ("Orc Chieftain", 22, 4, 13)],
    4: [("Wraith", 20, 4, 13), ("Mimic", 14, 3, 12), ("Dread Wraith", 26, 5, 14)],
    5: [("Duckling Guard", 10, 1, 10), ("Royal Duck", 18, 3, 12), ("Duck King", 30, 5, 14)],
    6: [("Cave Troll", 24, 4, 13), ("Giant Spider", 18, 3, 12), ("Troll Elder", 30, 5, 14)],
    7: [("Shadow Stalker", 28, 5, 13), ("Stone Golem", 32, 4, 12), ("Shadow Tyrant", 36, 6, 15)],
    8: [("Void Wisp", 26, 5, 13), ("Obsidian Knight", 34, 5, 14), ("Duck Emperor", 40, 6, 15)],
}

BOSSES = {
    5: ("Duck King", 30, 5, 14),
    8: ("Duck Emperor", 40, 6, 15),
}

LOOT_TABLE = [
    (0.30, "gold"),
    (0.20, "Potion of Coziness"),
    (0.15, "inventory item"),
    (0.10, "Rusty Sword"),
    (0.10, "Certified Button"),
    (0.05, "Glimmer Shield"),
    (0.05, "Elixir of Second Wind"),
    (0.05, "Lucky Pebble"),
]
MERCHANT_STOCK = [
    ("Potion of Coziness", 15),
    ("Elixir of Second Wind", 40),
    ("Rusty Sword", 25),
    ("Glimmer Shield", 25),
    ("Lucky Pebble", 30),
    ("Certified Button", 1),
    ("Soup Coupon", 1),
    ("Bandage", 8),
    ("Floor Map Fragment", 12),
    ("Compass of Confidence", 20),
    ("Portable Campfire", 18),
]

ITEM_POOL = [
    "Pebble of the Comma",
    "Certified Button",
    "Heroic Bread",
    "Extremely Normal Leaf",
    "Duck Feather",
    "Soup Coupon",
    "Tiny Wizard Hat",
    "Mystery Box (unopened)",
    "Singing Spoon",
    "Moonlit Pebble",
    "Confetti Sack",
    "Duck Whistle",
    "Goblin's Left Sock",
    "Mothball of Destiny",
]

DIRECTIONS = {"north": (0, -1), "south": (0, 1), "east": (1, 0), "west": (-1, 0)}


def gen_floor(floor):
    """Generate an open room graph (5-7 rooms) for a floor.

    Returns dict: rooms (name -> type), exits (room -> {dir: room}),
    contents (room -> {"objects": [...], "monsters": [...]}).
    """
    n = random.randint(5, 7)
    pool = ["Guard Post", "Vault", "Merchant Stall", "Odd Clearing",
            "Storage Room", "Shrine", "Trap Room", "Healing Spring",
            "Treasure Hoard"]
    content = random.sample(pool, k=n - 2)
    if "Guard Post" not in content:
        content[0] = "Guard Post"
    if floor in BOSSES:
        content[-1] = "Boss Chamber"
    names = ["Entrance"] + content + ["Stairs Down"]
    # linear chain with one optional branch
    exits = {}
    contents = {}
    for i, name in enumerate(names):
        exits[name] = {}
        if i > 0:
            exits[name]["south"] = names[i - 1]
        if i < n - 1:
            exits[name]["north"] = names[i + 1]
        contents[name] = {"objects": [], "monsters": []}
    if n >= 6:
        fork_from = names[1]
        fork_to = names[-2]
        exits[fork_from]["east"] = fork_to
        exits[fork_to]["west"] = fork_from
    # content assignment
    for name in names:
        if name == "Entrance" or name == "Stairs Down":
            continue
        if name == "Boss Chamber":
            contents[name]["monsters"] = [list(BOSSES[floor])]
        elif name == "Guard Post":
            contents[name]["monsters"] = [list(random.choice(MONSTERS[floor]))]
        elif name in ("Vault", "Storage Room"):
            contents[name]["objects"] = ["chest"]
        elif name == "Treasure Hoard":
            contents[name]["objects"] = ["hoard"]
        elif name == "Trap Room":
            contents[name]["objects"] = ["trap"]
        elif name == "Healing Spring":
            contents[name]["objects"] = ["spring"]
        elif name == "Merchant Stall":
            contents[name]["objects"] = ["merchant"]
        elif name == "Shrine":
            contents[name]["objects"] = ["shrine"]
    return {"rooms": dict(zip(names, [ROOM_TYPES[nm] for nm in names])),
            "exits": exits, "contents": contents}


# --- dice + helpers ------------------------------------------------------

def d(n: int) -> int:
    """Single die roll (1..n)."""
    return random.randint(1, n)


def roll(spec):
    """Parse XdY[+Z] -> (total, parts). E.g. '2d6+1'."""
    # Phase 1: parse only, no distribution logic beyond random.
    import re
    m = re.match(r"^(\d*)d(\d+)([+-]\d+)?$", spec)
    if not m:
        return {"error": f"bad roll spec: {spec}", "expected": "XdY[+Z]"}
    n = int(m.group(1) or 1)
    d = int(m.group(2))
    mod = int(m.group(3) or 0)
    rolls = [random.randint(1, d) for _ in range(n)]
    return {"spec": spec, "rolls": rolls, "total": sum(rolls) + mod}


def roll_loot(floor):
    """Roll a loot drop per LOOT_TABLE; apply floor scaling to gold."""
    r = random.random()
    acc = 0.0
    for pct, kind in LOOT_TABLE:
        acc += pct
        if r <= acc:
            if kind == "gold":
                return {"kind": "gold", "amount": d(6) + 2 + floor}
            if kind == "inventory item":
                return {"kind": "item", "item": random.choice(ITEM_POOL)}
            return {"kind": kind}
    return {"kind": "Certified Button"}


def award_achievement(state, name):
    """Add achievement if not already owned."""
    perms = state["permanent"]["achievements"]
    if name not in perms:
        perms.append(name)
        return True
    return False


def evaluate_achievements(state):
    """Return names of all achievements whose run-event conditions are met."""
    flags = state["run"].get("flags", {})
    conditions = [
        ("First Blood (won a combat)", flags.get("won_combat", False)),
        ("Loot Goblin (opened a chest)", flags.get("opened_chest", False)),
        ("Merchant's Friend (bought from a merchant)", flags.get("bought_item", False)),
        ("Survivor (escaped a fight)", flags.get("fled_fight", False)),
        ("Deep Delver (reached floor 3)", flags.get("floor_reached", 1) >= 3),
        ("Boss Slayer (defeated a boss)", flags.get("boss_defeated", False)),
    ]
    return [name for name, met in conditions if met]


# --- state ---------------------------------------------------------------

def load_state() -> dict | None:
    try:
        with open(STATE_PATH) as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as e:
        return {"error": f"corrupt state: {e}"}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w") as f:
        json.dump(state, f, indent=2)


def fresh_state():
    return {
        "version": 3,
        "permanent": {
            "gold_hoard": 0,
            "inventory": [],
            "achievements": [],
            "quest_log": [],
        },
        "run": {
            "current_quest": "",
            "quest_category": "",
            "floors_cleared": 0,
            "flags": {
                "won_combat": False,
                "opened_chest": False,
                "bought_item": False,
                "fled_fight": False,
                "floor_reached": 1,
                "boss_defeated": False,
            },
            "hp": 20, "max_hp": 20,
            "atk": 2, "ac": 12,
            "floor": 1,
            "room": "Entrance",
            "last_room": None,
            "run_gold": 0,
            "diagram": {},
        },
    }


def end_run(state, outcome, bonus_items=None):
    """Bank run gold, log quest, apply bonus loot, reset run. Keeps permanent."""
    perm = state["permanent"]
    run = state["run"]
    banked = run["run_gold"]
    perm["gold_hoard"] += banked
    if run.get("current_quest"):
        perm["quest_log"].append({
            "quest": run["current_quest"],
            "category": run.get("quest_category", ""),
            "outcome": outcome,
        })
    for item in (bonus_items or []):
        perm["inventory"].append(item)
    for name in evaluate_achievements(state):
        award_achievement(state, name)
    state["run"] = fresh_state()["run"]
    save_state(state)
    return {
        "banked": banked,
        "outcome": outcome,
        "gold_hoard": perm["gold_hoard"],
        "inventory": perm["inventory"],
        "achievements": perm["achievements"],
        "quest_log": perm["quest_log"],
        "bonus_items": bonus_items or [],
        "run_reset": True,
    }


# --- subcommands (stubs — Phase 3 fills logic) ---------------------------

def cmd_init(args):
    state = load_state()
    if state is None:
        state = fresh_state()
    else:
        state["run"] = fresh_state()["run"]  # reset run, keep permanent
    state["run"]["diagram"] = gen_floor(state["run"]["floor"])
    save_state(state)
    return {"ok": True, "state": state}


def cmd_resume(args):
    state = load_state()
    if state is None:
        return {"error": "no state", "hint": "run 'init' first"}
    return {"ok": True, "state": state}


def cmd_state(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    return state


def cmd_map(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    current = state["run"]["room"]
    lines = []
    for room, etype in diag.get("rooms", {}).items():
        marker = "@" if room == current else ""
        lines.append(f"{marker}{etype} {room}")
    return {"map": lines, "current": current}


def cmd_move(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    cur = state["run"]["room"]
    exits = diag.get("exits", {}).get(cur, {})
    if args.direction not in exits:
        return {"error": f"no exit {args.direction}", "exits": list(exits.keys())}
    state["run"]["last_room"] = cur
    state["run"]["room"] = exits[args.direction]
    room = state["run"]["room"]
    rtype = diag["rooms"].get(room, "?")
    trigger = {}
    contents = diag.get("contents", {}).get(room, {})
    if rtype == "🪤":  # Trap Room: d20 vs AC, fail = 1d6 damage
        roll_v = d(20)
        if roll_v < state["run"]["ac"]:
            dmg = d(6)
            state["run"]["hp"] -= dmg
            trigger = {"trap": True, "roll": roll_v, "damage": dmg,
                       "player_hp": state["run"]["hp"]}
        else:
            trigger = {"trap": True, "roll": roll_v, "damage": 0}
        contents["objects"] = [o for o in contents.get("objects", []) if o != "trap"]
    elif rtype == "⛲":  # Healing Spring: free heal 1d6+2
        heal = d(6) + 2
        state["run"]["hp"] = min(state["run"]["max_hp"], state["run"]["hp"] + heal)
        trigger = {"spring": True, "healed": heal,
                   "player_hp": state["run"]["hp"]}
        contents["objects"] = [o for o in contents.get("objects", []) if o != "spring"]
    elif rtype == "💎":  # Treasure Hoard: guaranteed loot roll
        loot = roll_loot(state["run"]["floor"])
        if loot["kind"] == "gold":
            state["run"]["run_gold"] += loot["amount"]
        trigger = {"hoard": True, "loot": loot,
                   "run_gold": state["run"]["run_gold"]}
        contents["objects"] = [o for o in contents.get("objects", []) if o != "hoard"]
    save_state(state)
    return {"moved": True, "from": cur, "to": state["run"]["room"],
            "room_type": rtype, "contents": contents, "trigger": trigger}


def cmd_look(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    room = state["run"]["room"]
    rtype = diag.get("rooms", {}).get(room, "?")
    flavor = ROOM_FLAVOR.get(room, "It is a room.")
    exits = diag.get("exits", {}).get(room, {})
    contents = diag.get("contents", {}).get(room, {})
    return {
        "room": room, "type": rtype, "flavor": flavor,
        "exits": exits, "contents": contents,
        "floor": state["run"]["floor"],
    }


def cmd_attack(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    monsters = contents.get("monsters", [])
    if not monsters:
        return {"error": "no monster here"}
    monster = monsters[0]
    mname, mhp, matk, mac = monster
    # player roll
    prowl = d(20) + state["run"]["atk"]
    phit = prowl >= mac
    pdam = d(6) + 1 if phit else 0
    if phit:
        mhp -= pdam
        monster[1] = mhp  # persist monster HP in-place
    # monster retaliation (if alive)
    mroll = d(20) + matk
    mdam = 0
    if mhp > 0 and mroll >= state["run"]["ac"]:
        mdam = max(1, d(4) + matk // 2)
        state["run"]["hp"] -= mdam
    result = {
        "monster": mname, "player_roll": prowl, "hit": phit,
        "damage": pdam, "monster_hp": mhp, "monster_roll": mroll,
        "player_damage": mdam, "player_hp": state["run"]["hp"],
    }
    if mhp <= 0:
        # defeat: roll loot
        result["defeated"] = True
        result["loot"] = roll_loot(state["run"]["floor"])
        if result["loot"]["kind"] == "gold":
            state["run"]["run_gold"] += result["loot"]["amount"]
        room = state["run"]["room"]
        is_boss = diag["rooms"].get(room) == "👑"
        if is_boss and state["run"]["floor"] in (5, 8):
            contents["monsters"].pop(0)
            result["completed"] = True
            state["run"]["flags"]["boss_defeated"] = True
            trophy = "Crown of the Duck King" if state["run"]["floor"] == 5 \
                else "Emperor's Gilded Feather"
            result.update(end_run(state, "complete", [trophy]))
            return result
        state["run"]["flags"]["won_combat"] = True
        contents["monsters"].pop(0)
    if state["run"]["hp"] <= 0:
        result["dead"] = True
        result.update(end_run(state, "death"))
        return result
    save_state(state)
    return result


def cmd_flee(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    last = state["run"].get("last_room")
    if not last:
        return {"error": "no room to flee to"}
    if random.random() < 0.6:
        state["run"]["room"] = last
        state["run"]["flags"]["fled_fight"] = True
        save_state(state)
        return {"fled": True, "to": last}
    # 40%: monster free attack
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    monsters = contents.get("monsters", [])
    mdam = 0
    if monsters:
        mname, mhp, matk, mac = monsters[0]
        if d(20) + matk >= state["run"]["ac"]:
            mdam = max(1, d(4) + matk // 2)
            state["run"]["hp"] -= mdam
    result = {"fled": False, "player_damage": mdam,
              "player_hp": state["run"]["hp"]}
    if state["run"]["hp"] <= 0:
        result["dead"] = True
        result.update(end_run(state, "death"))
        return result
    save_state(state)
    return result


def cmd_rest(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    heal = d(6)
    state["run"]["hp"] = min(state["run"]["max_hp"],
                             state["run"]["hp"] + heal)
    result = {"healed": heal, "player_hp": state["run"]["hp"]}
    if random.random() < 0.3:
        diag = state["run"]["diagram"]
        contents = diag.get("contents", {}).get(state["run"]["room"], {})
        monsters = contents.get("monsters", [])
        if monsters:
            mname, mhp, matk, mac = monsters[0]
            if d(20) + matk >= state["run"]["ac"]:
                mdam = max(1, d(4) + matk // 2)
                state["run"]["hp"] -= mdam
                result["ambushed"] = True
                result["ambush_damage"] = mdam
                result["player_hp"] = state["run"]["hp"]
    if state["run"]["hp"] <= 0:
        result["dead"] = True
        result.update(end_run(state, "death"))
        return result
    save_state(state)
    return result


def cmd_take(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    objects = contents.get("objects", [])
    if args.obj not in objects:
        return {"error": f"no {args.obj} here", "objects": objects}
    contents["objects"] = [o for o in objects if o != args.obj]
    state["permanent"]["inventory"].append(args.obj)
    save_state(state)
    return {"taken": args.obj}


def cmd_drop(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    inv = state["permanent"]["inventory"]
    if args.obj not in inv:
        return {"error": f"you don't have: {args.obj}", "inventory": inv}
    inv.remove(args.obj)
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    contents.setdefault("objects", []).append(args.obj)
    save_state(state)
    return {"dropped": args.obj}


def cmd_inventory(args):
    state = load_state()
    if state is None or "inventory" not in state.get("permanent", {}):
        return {"error": "no state"}
    return {
        "inventory": state["permanent"]["inventory"],
        "run_gold": state["run"]["run_gold"],
    }


def cmd_open(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    objects = contents.get("objects", [])
    if "chest" not in objects:
        return {"error": "no chest here"}
    loot = roll_loot(state["run"]["floor"])
    if loot["kind"] == "gold":
        state["run"]["run_gold"] += loot["amount"]
    state["run"]["flags"]["opened_chest"] = True
    contents["objects"] = [o for o in objects if o != "chest"]
    save_state(state)
    return {"opened": "chest", "loot": loot}


def cmd_descend(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    if state["run"]["room"] != "Stairs Down":
        return {"error": "descend only works from Stairs Down"}
    state["run"]["floor"] += 1
    state["run"]["floors_cleared"] += 1
    state["run"]["hp"] = state["run"]["max_hp"]  # full heal on stairs
    state["run"]["room"] = "Entrance"
    state["run"]["last_room"] = None
    state["run"]["flags"]["floor_reached"] = max(
        state["run"]["flags"]["floor_reached"], state["run"]["floor"])
    state["run"]["diagram"] = gen_floor(state["run"]["floor"])
    save_state(state)
    return {"descended": True, "floor": state["run"]["floor"],
            "healed": state["run"]["max_hp"]}


def cmd_merchant(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    diag = state["run"]["diagram"]
    contents = diag.get("contents", {}).get(state["run"]["room"], {})
    if "merchant" not in contents.get("objects", []):
        return {"error": "no merchant here"}
    action = getattr(args, "action", None)
    if not action:
        return {"stock": [{"item": n, "price": p} for n, p in MERCHANT_STOCK],
                "run_gold": state["run"]["run_gold"]}
    item = getattr(args, "item", None)
    if action == "buy":
        for name, price in MERCHANT_STOCK:
            if name.lower() == (item or "").lower():
                if state["run"]["run_gold"] < price:
                    return {"error": "not enough gold", "price": price,
                            "run_gold": state["run"]["run_gold"]}
                state["run"]["flags"]["bought_item"] = True
                state["run"]["run_gold"] -= price
                state["permanent"]["inventory"].append(name)
                save_state(state)
                return {"bought": name, "price": price,
                        "run_gold": state["run"]["run_gold"]}
        return {"error": f"no such item: {item}", "stock": [n for n, _ in MERCHANT_STOCK]}
    if action == "sell":
        inv = state["permanent"]["inventory"]
        if not item or item.lower() not in [i.lower() for i in inv]:
            return {"error": f"you don't have: {item}", "inventory": inv}
        sell_item = next(i for i in inv if i.lower() == item.lower())
        price = max(1, dict(MERCHANT_STOCK).get(sell_item, 2) // 2)
        state["permanent"]["inventory"].remove(sell_item)
        state["run"]["run_gold"] += price
        save_state(state)
        return {"sold": sell_item, "price": price,
                "run_gold": state["run"]["run_gold"]}
    return {"error": f"unknown action: {action}", "expected": "buy|sell"}


def cmd_use(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    inv = state["permanent"]["inventory"]
    if args.item not in inv:
        return {"error": f"you don't have: {args.item}", "inventory": inv}
    item = args.item.lower()
    if "potion" in item:
        heal = d(6) + 2
        state["run"]["hp"] = min(state["run"]["max_hp"], state["run"]["hp"] + heal)
        inv.remove(args.item)
        save_state(state)
        return {"used": args.item, "healed": heal, "player_hp": state["run"]["hp"]}
    if item == "elixir of second wind":
        state["run"]["hp"] = state["run"]["max_hp"]
        inv.remove(args.item)
        save_state(state)
        return {"used": args.item, "healed": state["run"]["max_hp"],
                "player_hp": state["run"]["hp"]}
    if item == "lucky pebble":
        inv.remove(args.item)
        save_state(state)
        return {"used": args.item, "effect": "one re-roll available this combat"}
    return {"error": f"{args.item} has no use effect", "inventory": inv}


def cmd_exit(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    save_state(state)  # preserve as-is for resume
    return {
        "preserved": True,
        "hint": "run resumes at same floor/room/HP/gold next session",
        "run": state["run"],
        "permanent": state["permanent"],
    }


def cmd_save(args):
    state = load_state()
    if state is None:
        return {"error": "no state"}
    save_state(state)
    return {"ok": True}


def main():
    parser = argparse.ArgumentParser(description="duck-adventure engine")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init")
    sub.add_parser("resume")
    sub.add_parser("state")
    sub.add_parser("map")
    sub.add_parser("descend")
    p = sub.add_parser("move"); p.add_argument("direction")
    p = sub.add_parser("look"); p.add_argument("target", nargs="?")
    p = sub.add_parser("attack"); p.add_argument("monster")
    sub.add_parser("flee")
    sub.add_parser("rest")
    p = sub.add_parser("take"); p.add_argument("obj")
    p = sub.add_parser("drop"); p.add_argument("obj")
    sub.add_parser("inventory")
    p = sub.add_parser("open"); p.add_argument("container")
    p = sub.add_parser("merchant"); p.add_argument("action", nargs="?")
    p.add_argument("item", nargs="?")
    p = sub.add_parser("use"); p.add_argument("item")
    p = sub.add_parser("roll"); p.add_argument("spec")
    sub.add_parser("exit")
    sub.add_parser("save")
    args = parser.parse_args()

    handlers = {
        "init": cmd_init, "resume": cmd_resume, "state": cmd_state,
        "map": cmd_map, "descend": cmd_descend, "move": cmd_move, "look": cmd_look,
        "attack": cmd_attack, "flee": cmd_flee, "rest": cmd_rest,
        "take": cmd_take, "drop": cmd_drop, "inventory": cmd_inventory,
        "open": cmd_open, "merchant": cmd_merchant, "use": cmd_use,
        "roll": lambda args: roll(args.spec),
        "exit": cmd_exit, "save": cmd_save,
    }
    result = handlers[args.cmd](args)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()