# Game Design Document (GDD) — Working Title: *vampiresrvvr*

> Version 0.6 · 1 November 2026 · Status: prototype v0.4 playable

## 1. Concept

A single-player action-survivors game played from a Diablo 4 camera angle: you fight wave after wave of hordes with active skills, and after cutting down the bosses you have to **get out alive** with your loot.

**Hooks:**
- Survivors-genre horde chaos + Diablo-style active-skill combat
- Extraction tension: "Do I get out now, or risk it for more?"
- Entry gear can be lost, so every run carries real risk

## 2. Key Decisions

| Topic | Decision |
|---|---|
| Engine | Godot 4, 3D |
| Camera | Diablo 4 style: tilted ~50° from above, fixed-angle perspective that follows the character |
| Mode | Single-player |
| Combat | Melee: automatic Sword Swing (quarter circle) + 4 active powers (1 / 2 / 3 / 4) |
| Powers | 10 powers in a Diablo-style skill tree; 4 go into the loadout (at most 1 ultimate) |
| Skill points | From character level; XP is kept only if you escape; 1 point per level |
| Skill refunds | Gold per point; "Reset all" for a full redistribution |
| Cores | Used both for permanent stat upgrades and for unlocking new characters and powers |
| Loss rule | If you don't make it out, you lose the run loot **and your entry gear** (Tarkov style) |
| Map | Handcrafted fixed maps; gate, chest and elite positions are random each run |
| Visuals | Stylized low-poly (starting with KayKit, CC0), toon shader, dark, high-contrast lighting |
| Theme | Dark fantasy: cursed lands, skeletons, demons |
| Run length | 15 min to the final boss (~17 min including the exit) |
| Bosses | Mini-bosses at minutes 5 and 10, final boss at minute 15 |
| Final exit timer | 90 s countdown after the final boss dies |
| Camp | Menu screen with Equipment, Skills, Shop and Core Tree tabs |
| Items | Shop + run loot; Diablo-style rarity and random affixes |
| Core Tree | Branching tree: Might, Resilience, Fortune |
| Core sources | Mini-boss: 1 (run loot, at risk); final boss: 3 (safe immediately) |

## 3. Run Flow (Core Loop)

1. **Preparation (Camp):** Pick a character and equip gear (everything you equip is at risk).
2. **Entry:** The player enters the map and the waves begin.
3. **Survive and power up:** Collect XP, pick 1 of 3 boons on each level-up, and grab loot from chests.
4. **Mini-bosses:** A mini-boss arrives at minutes 5 and 10. Each time one dies, the **early exit gate** opens at a new spot on the map.
5. **Greed decision:** The player can head to the gate and leave with the current loot, or keep going until the final boss.
6. **Final boss (minute 15):** Killing it secures the **cores**. The final exit gate opens somewhere **completely different**, the horde thickens and a **90 s** countdown starts.
7. **Outcome:** (see Section 5)

## 4. Exit Gate System

- Each mini-boss death **relocates** the gate; the previous gate closes. The early gate opens at least 22 m from the player.
- The final gate opens at least 40 m from the player and at least 25 m from the previous gate. Once the final boss is down, the early gate never opens again.
- **Gate signal:** A compass arrow circling the character points to only one of 8 directions (a rough heading). The gate's pillar of light, reaching into the sky, is visible from afar. The player has to find the exact spot.
- **Exiting:** Stand inside the ring for 3 s. Taking damage resets the progress; stepping out of the ring rewinds it fast. To exit in a crowd, you have to clear space with Frost Nova.
- **Final escape:** When the final boss dies, the enemy spawn rate increases 2.5×. If you don't get out within 90 s, the gate closes; the result is the same as dying.

## 5. Reward and Loss Rules

| Layer | Example | Early exit | Exit after final boss | Death / timeout |
|---|---|---|---|---|
| In-run progression | Level, boons | Reset | Reset | Reset |
| Run loot | Gold, materials, items | **Banked** | **Banked** | Lost |
| XP | XP collected during the run | **Added to character level** | **Added** | Lost |
| Entry gear | Equipped weapon/armor | Kept | Kept | **Lost** |
| Core (mini-boss) | 1 core / boss | **Banked** | **Banked** | Lost |
| Core (final boss) | 3 cores | — | **Banked** | **Kept** (if the boss was killed) |

> Note: If the player dies after the final boss is killed, they keep the final boss's cores and lose everything else.
> If the game is closed mid-run, the run counts as failed on the next launch (equipped gear is lost). "Withdraw from Run" on the pause screen has the same result.

**Run loot:**
- **Gold:** The map starts with 8 chests; a new one is added every 45 s (up to 10). A chest gives 15 + (minute × 4) gold. Bosses drop 100 / 200 / 300 gold.
- **Items:** 25% chance from a chest (mostly Magic), 1 from a mini-boss (mostly Rare), 2 from the final boss (Rare or Legendary).
- Found items stay in the "Bag" and can't be used during that run; they move to the stash when you escape.

## 6. Meta Progression

**Camp:** The menu screen between runs, with Equipment, Skills, Shop and Core Tree tabs and a "Start Run" button. When a run ends, the results screen takes you back to Camp.

**Character level and skill points:** XP collected during a run is added to your character level only if you escape. Going from level n to n+1 takes 400 + 100 × (n − 1) XP; the max level is 40. Level 1 gives 4 points (for the starting powers) and every level after that gives 1: 43 points at level 40, while the full tree costs 70. So not every power can be maxed; you have to choose.

**Skill tree (Diablo style):**
- 10 powers in 4 tiers: **Basic** (unlocked), **Defensive** (2 points in lower tiers), **Power** (5 points), **Ultimate** (8 points).
- Each power takes 1–5 ranks (+12% power per rank). After the first rank, the **Enhanced** upgrade (1 point) unlocks, and after that a choice of one of two **options** (1 point).
- The loadout has 4 slots (keys 1–4), with at most 1 ultimate power. Putting an already-slotted power into another slot swaps the two.
- **Refunds:** Each point costs 10 + 3 × (level − 1) gold. Switching options costs no points, only this fee. "Reset all" refunds every point (fee × points spent). While a higher tier has points in it, you can't make a refund that would break a lower tier's gate.
- Starting setup: Fire Wave, Whirlwind, Frost Nova and Shadow Dash at rank 1 and slotted. Old saves are migrated to this setup.

**Equipment:**
- Three slots: Weapon, Armor, Charm. Equipped items go into the run and are lost if it fails.
- Rarity: Common (gray), Magic (blue), Rare (yellow), Legendary (orange). Each item has a base stat determined by its slot (weapon → damage, armor → health or damage reduction, charm → speed / cooldown / pickup / gold). Rarity raises the values and adds 1–3 random extra affixes.
- Stats: damage, max health, move speed, cooldown (capped at −50%), attack speed, power area, pickup radius, health regen, damage reduction (capped at 60%), gold find, item find.
- A new profile starts with three Common items equipped and 50 gold.

**Shop:**
- Basic items are always for sale at 60 gold (so a player who loses everything isn't left empty-handed).
- "Today's wares": 3 random items, refreshed after every run. Prices: Magic 180, Rare 420, Legendary 900.
- Items in the stash sell for a quarter of their price.

**Core Tree:** Three branches grow from the central "Essence": **Might** (damage, attack speed, power area → Doom Master: cooldown −10%), **Resilience** (health, damage reduction, health regen → Undying: damage reduction 8%), **Fortune** (gold, speed, pickup radius, cooldown → Lucky Star: item find +30%). Each branch has 6 nodes costing 1-2-2-3-3-4; the full tree costs 45 cores. A node can be unlocked once any node it connects to is unlocked.

**Saving:** `user://profile.json` (on macOS: `~/Library/Application Support/Godot/app_userdata/vampiresrvvr/`). The game saves automatically after every change.

**Later:** Unlocking new characters with cores; character-specific power pools.

## 7. Combat

- **Movement:** WASD; the character faces the mouse.
- **Sword Swing (automatic, melee):** Sweeps a quarter circle (90°) toward the nearest enemy within reach (3 m); everyone in the arc is hit and pushed back slightly. 14 damage every 0.55 s. There are no projectiles.
- **Active powers:** 4 of the 10 powers in the skill tree are slotted.

| Tier | Power | Cooldown | Enhanced | Option A | Option B |
|---|---|---|---|---|---|
| Basic | Fire Wave — cone of fire, knockback | 4 s | Range +25% | Embers: 3 s burn | Firestorm: half circle, cooldown +1 s |
| Basic | Whirlwind — spins for 2.5 s, hitting repeatedly | 9 s | +1 s | Relentless Spin: no slowdown | Blood Storm: health per hit |
| Basic | Soul Chain — pulls enemies to you | 10 s | Range +30% | Shackles: 1.5 s freeze | Soul Harvest: health per enemy pulled |
| Defensive | Frost Nova — freezes everything around you | 10 s | Freeze +1 s | Shatter: +25% damage to frozen enemies | Frost Burst: area +40% |
| Defensive | Shadow Dash — invulnerable dash | 6 s | Cooldown −1 s | Shadow Trail: +30% damage for 2 s afterward | Shadow Burst: area damage at the end |
| Defensive | Bone Shield — 6 s damage-absorbing shield | 14 s | Thorns damage to attackers | Bone Burst: explodes when it ends | Hardened Bone: +4 s, +15% speed |
| Power | Earthquake Leap — leap to the aim point, stun on landing | 9 s | Stun +0.6 s | Aftershock: landing spot deals damage for 3 s | Winged Leap: cooldown −3 s |
| Power | War Cry — +25% damage and attack speed for 6 s | 18 s | +2 s | Terror: double knockback, freeze | Battle Fury: cooldown recharges 25% faster |
| Ultimate | Heaven's Wrath — huge blast at the aim point | 45 s | Area +20% | Triple Strike: 3 blasts | Apocalypse: cooldown −15 s |
| Ultimate | Sword Rain — swords fall from the sky for 4 s | 50 s | +2 s | Blade Storm: twice as dense | Razor Rain: each sword deals area damage |

- **Key bindings:** Powers are on keys 1-2-3-4, pressed with the same hand as WASD; the mouse only aims. Holding a power's key casts it automatically whenever it's ready. Boon cards can only be picked with the mouse, because keys 1-3 are powers. Keys can be rebound in Project Settings → Input Map.
- **Boons (Hades style, in-run):** General boons (damage, health, speed, cooldown, pickup, regeneration), sword boons (Swift Blade, Wide Swing, Long Blade) and a "<Power> Mastery" for each power in the loadout (+25% power, up to 3 times). Boons for unslotted powers don't show up.
- **Bosses:** Every special attack is telegraphed on the ground first: a red circle for a ground slam, an orange strip for a charge, a purple circle for a summon. Bosses can't be knocked back; Frost Nova freezes them for 25% of the normal duration.

| Boss | Minute | Health | Attacks | Reward |
|---|---|---|---|---|
| Grave Warden | 5 | 1200 | Ground slam, charge | 100 gold, 1 core, 1 item, early gate |
| Blood Butcher | 10 | 2600 | More frequent slams, longer and faster charges | 200 gold, 1 core, 1 item, gate relocates |
| Bone King | 15 | 5200 | Ground slam, charge, summons 10 skeletons every 3rd attack | 300 gold, 3 safe cores, 2 items, final gate |

- **Juice:** Hit-flash, screen shake, short hit-stop, particles, damage numbers.

## 8. Idea List (Beyond the Prototype)

- **Heavy load:** Carrying too much loot slows the player down.
- Elite enemies (tough horde enemies that drop loot)
- Gear insurance / safe slot
- Procedural map generation
- Co-op

## 9. Prototype Scope

### v0.1 — Playable core ✅ (31 October 2026)
- [x] Godot 4 project skeleton, folder structure
- [x] Diablo-angle follow camera
- [x] WASD movement, facing the mouse
- [x] Automatic basic attack
- [x] 4 fixed powers + cooldown UI
- [x] 3 enemy types, wave spawning, object pooling
- [x] XP, level-up, boon screen with 3 choices (15 boons)
- [x] Single greybox map
- [x] Extra: pause screen, death screen and restart, automated smoke test

### v0.2 — Extraction loop ✅ (1 November 2026)
- [x] Mini-boss + relocating early exit gate
- [x] Final boss + final gate at a new location + countdown
- [x] Gate signal (compass / light beam)
- [x] Run loot and results screen (gained / lost)
- [x] Extra: gold chests, 3 bosses with telegraphed attacks, powers moved to keys 1-4, Shift+T test shortcut, scenario-based automated tests

### v0.3 — Meta and equipment ✅ (1 November 2026)
- [x] Camp screen, simple equipment slots (weapon + armor + 1 accessory)
- [x] Equipment loss rule
- [x] Permanent stat tree bought with cores (branching, 19 nodes)
- [x] Save system
- [x] Extra: random items with rarities, shop, item and core drops during runs, abandoned-run rule, "Withdraw from Run", automated test for Camp

### v0.4 — Skill tree and melee ✅ (1 November 2026)
- [x] Automatic Sword Swing (quarter circle) instead of projectiles
- [x] Diablo-style skill tree with 10 powers: 4 tiers, 5 ranks, Enhanced upgrade, A/B options
- [x] 4-slot power loadout (at most 1 ultimate)
- [x] Refunds for gold and "Reset all"
- [x] Character level (XP is kept only on escape) and skill points
- [x] Extra: HUD shield indicator for Bone Shield, per-power Mastery boons, old save migration, automated test that tries every power option across 6 loadouts

### v0.5 — Visual pass
- [ ] KayKit models, toon shader, outline, lighting
- [ ] Juice effects

## 10. Open Questions

- The game's name

## 11. Prototype Notes (v0.4)

**Running:** Godot 4.7 → Import → `project.godot` in this folder → F5. The game opens in Camp; press "Start Run" to begin a run. To reset the profile, just delete the save file (see Section 6).

**Controls:** WASD to move (the character faces the mouse) · the sword swings automatically · 1-2-3-4 for loadout powers (chosen in the Skills tab) · Esc to pause · pick boons with the mouse · to exit through a gate, stand in the ring for 3 s without taking damage.

**Test shortcut:** Shift+T fast-forwards time by 1 minute (only in editor/debug runs). Press it 4–5 times to try out the bosses and gates.

**Enemies:** Skeleton Soldier (from the start), Ghoul (minute 1, fast), Bone Giant (minute 2.5, tank). Every minute, a siege wave ("Surrounded!") closes in around the player.

**Where to tune balance:**
- Enemy types: `resources/enemies/*.tres` (edited in the Inspector)
- Bosses: `resources/bosses/*.tres` (health, speed, attack values, gold reward)
- Boss timings, countdown, gate distances, intensity during the escape: `RunDirector` node in the Main scene
- Time to stand in the gate: `scripts/run/exit_portal.gd` → `channel_time`
- Chest count and gold amount: `Chests` node
- Spawn rate, waves, health scaling, enemy cap: `EnemySpawner` node
- Player values and Sword Swing (damage, speed, reach, angle): `Player` node
- Power values (damage, cooldown, area, option effects): `@export` values and `_configure()` in `scripts/abilities/*.gd`
- Power names, tiers, descriptions, per-rank scaling and tier gates: `scripts/skills/skill_library.gd`
- Character level curve, starting points, refund cost, starting loadout: `scripts/autoload/profile.gd`
- Boons: `scripts/progression/boon_library.gd` (card text and effect come from the same value)
- Camera angle and distance: `CameraRig` node
- Level curve: `Player.xp_required()`
- Item value ranges, rarity multipliers and drop chances: `scripts/meta/item_generator.gd`
- Prices: `scripts/meta/item.gd` → `RARITY_PRICES`
- Core Tree nodes, costs and effects: `scripts/meta/core_tree.gd`
- Stat names and caps: `scripts/meta/stats.gd`
- Starting gold and number of shop wares: `scripts/autoload/profile.gd`
- Chance of an item from a chest: `Chests` node → `item_chance`

**Automated tests** (from the project folder, using the binary inside the Godot app; `--no-save` protects the real save):
- `Godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn -- --no-save --scenario=<name>`
- Scenarios: `systems` (4 min of gameplay), `death` (death, equipment loss, return to Camp), `early_exit` (early escape, XP goes to character level), `final_exit` (final escape), `timeout` (gate closing, XP loss), `boss_view` (attacks of all three bosses), `hub` (shop, equipment, Core Tree, skill tree rules, saving, old save migration), `powers --set=A..F` (six loadouts that together run all 20 options of the 10 powers in a live run)
- A failing scenario exits with code 1; remove `--headless` and add `--screenshots=/absolute/folder` to take screenshots (add `--real-health` for a normal health bar).

**Known limitations:**
- Balance hasn't been playtested by hand yet; in particular boss health, how hard it is to stand still for 3 s without taking damage inside the horde at minute 15, the item/core economy, how the powers compare to each other, and the level curve need tuning through play.
- Ultimate powers unlock after 8 points (around level 5); a new character has no ultimate.
- Items can't be compared (no tooltip showing the difference from the equipped item); the stash is unlimited.
- Enemies walk in straight lines (no navigation); they slide around pillars.
- No damage numbers, sound or particle effects (planned for v0.5).
