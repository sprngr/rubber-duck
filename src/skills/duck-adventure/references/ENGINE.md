<!--
asset-type: reference
loading: conditional (player/reader reference; script is the source of truth)
last-updated: 2026-08-24
-->
# Engine Data (script-owned)

Mechanics live in `hooks/adventure.py`. This doc mirrors them for players;
the script is the source of truth. Do not edit here to change rules.

## Room types
🕯️ Entrance | 🛡️ Guard Post (monster) | 💰 Vault (loot) | 📦 Merchant Stall |
❓ Odd Clearing (event) | 👑 Boss Chamber (boss) | ➡️ Stairs Down |
📚 Storage Room (loot) | ⛩️ Shrine (event) | 🪤 Trap Room (hazard: d20 vs AC,
fail = 1d6 dmg) | ⛲ Healing Spring (free heal 1d6+2) | 💎 Treasure Hoard
(guaranteed loot)

## Player stats (start of run)
HP 20 | ATK +2 | AC 12

## Monsters by floor
F1: Goblin (8/1/10), Rat (5/0/9), Goblin Warlord (12/2/11)
F2: Skeleton (12/2/11), Slime (10/1/10), Skeleton Captain (16/3/12)
F3: Orc (16/3/12), Bat Swarm (9/2/11), Orc Chieftain (22/4/13)
F4: Wraith (20/4/13), Mimic (14/3/12), Dread Wraith (26/5/14)
F5: Duckling Guard (10/1/10), Royal Duck (18/3/12), Duck King (30/5/14)
F6: Cave Troll (24/4/13), Giant Spider (18/3/12), Troll Elder (30/5/14)
F7: Shadow Stalker (28/5/13), Stone Golem (32/4/12), Shadow Tyrant (36/6/15)
F8: Void Wisp (26/5/13), Obsidian Knight (34/5/14), Duck Emperor (40/6/15)

Bosses: F5 Duck King, F8 Duck Emperor (Boss Chamber rooms)

## Loot table
30% gold (1d6+2+floor) | 20% Potion of Coziness | 15% random item (ITEM_POOL) |
10% Rusty Sword | 10% Certified Button | 5% Glimmer Shield | 5% Elixir of
Second Wind | 5% Lucky Pebble

## Item pool
Pebble of the Comma | Certified Button | Heroic Bread | Extremely Normal Leaf |
Duck Feather | Soup Coupon | Tiny Wizard Hat | Mystery Box (unopened) |
Singing Spoon | Moonlit Pebble | Confetti Sack | Duck Whistle |
Goblin's Left Sock | Mothball of Destiny

## Merchant stock
Potion of Coziness 15g | Elixir of Second Wind 40g | Rusty Sword 25g |
Glimmer Shield 25g | Lucky Pebble 30g | Certified Button 1g | Soup Coupon 1g |
Bandage 8g | Floor Map Fragment 12g | Compass of Confidence 20g | Portable Campfire 18g

## Achievements (condition-tied, awarded at run end from event flags)
First Blood (won a combat) | Loot Goblin (opened a chest) |
Merchant's Friend (bought from a merchant) | Survivor (escaped a fight) |
Deep Delver (reached floor 3) | Boss Slayer (defeated a boss)

## Descend
From Stairs Down only: floor +1, full HP restore, new floor, reset to Entrance.

## Run end
Death: bank gold, log quest (death), award achievement, reset.
Complete (floor 5 or 8 boss): bank gold, trophy (Crown of the Duck King on F5,
Emperor's Gilded Feather on F8), log (complete), reset.
Exit: preserve run for resume (no banking).