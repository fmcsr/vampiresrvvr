class_name SkillLibrary
extends RefCounted
## Skill tree definitions (Diablo style). Each power has ranks 1–5; after the first rank the
## "Enhanced" upgrade unlocks, and after that one of two options. A tier unlocks once a total of
## "gate" points has been spent in the tiers below it. A loadout can hold at most one ultimate power.

const MAX_RANK := 5
## Power increase per rank (rank 1 is the base value).
const RANK_POWER := 0.12
const TIERS: Array[Dictionary] = [
	{"title": "Basic", "gate": 0},
	{"title": "Defensive", "gate": 2},
	{"title": "Power", "gate": 5},
	{"title": "Ultimate", "gate": 8},
]
const SKILLS := {
	"fire_wave": {
		"title": "Fire Wave", "tier": 0, "color": Color(1.0, 0.45, 0.15),
		"script": "res://scripts/abilities/fire_wave.gd",
		"cast": ["Spellcast_Shoot", 0.5],
		"text": "Sprays a cone of flame in the aim direction, knocking enemies back.",
		"enhanced": "Range increases by 25%.",
		"a": ["Embers", "Enemies hit burn for 3 s."],
		"b": ["Firestorm", "The cone widens into a semicircle; cooldown is 1 s longer."],
	},
	"whirlwind": {
		"title": "Whirlwind", "tier": 0, "color": Color(0.75, 0.8, 0.95),
		"script": "res://scripts/abilities/whirlwind.gd",
		"text": "Spins in place for 2.5 s, repeatedly hitting everything nearby. You are slowed while spinning.",
		"enhanced": "The spin lasts 1 s longer.",
		"a": ["Relentless Spin", "You are not slowed while spinning."],
		"b": ["Blood Storm", "Each hit restores 0.5 health."],
	},
	"soul_chain": {
		"title": "Soul Chain", "tier": 0, "color": Color(0.55, 0.9, 0.85),
		"script": "res://scripts/abilities/soul_chain.gd",
		"cast": ["Throw", 0.55],
		"text": "Pulls nearby enemies to you and damages them. Pair it with area powers.",
		"enhanced": "Pull range increases by 30%.",
		"a": ["Shackles", "Pulled enemies freeze for 1.5 s."],
		"b": ["Soul Harvest", "Restores 1 health for each enemy pulled."],
	},
	"frost_nova": {
		"title": "Frost Nova", "tier": 1, "color": Color(0.45, 0.85, 1.0),
		"script": "res://scripts/abilities/frost_nova.gd",
		"cast": ["Spellcast_Raise", 0.6],
		"text": "Freezes enemies around you and deals light damage.",
		"enhanced": "Freeze lasts 1 s longer.",
		"a": ["Shatter", "Frozen enemies take 25% more damage."],
		"b": ["Frost Burst", "Area increases by 40%."],
	},
	"shadow_dash": {
		"title": "Shadow Dash", "tier": 1, "color": Color(0.6, 0.4, 1.0),
		"script": "res://scripts/abilities/shadow_dash.gd",
		"text": "Dashes in your move direction; you take no damage while dashing and hit enemies in your path.",
		"enhanced": "Cooldown is 1 s shorter.",
		"a": ["Shadow Trail", "Damage increases by 30% for 2 s after the dash."],
		"b": ["Shadow Burst", "Explodes where the dash ends, damaging nearby enemies."],
	},
	"bone_shield": {
		"title": "Bone Shield", "tier": 1, "color": Color(0.9, 0.88, 0.75),
		"script": "res://scripts/abilities/bone_shield.gd",
		"cast": ["Block", 0.5],
		"text": "Gain a shield that absorbs damage for 6 s.",
		"enhanced": "While the shield holds, enemies that hit you take damage.",
		"a": ["Bone Burst", "Damages nearby enemies when the shield breaks or expires."],
		"b": ["Hardened Bone", "The shield lasts 4 s longer; you run 15% faster while it holds."],
	},
	"earthquake_leap": {
		"title": "Earthquake Leap", "tier": 2, "color": Color(0.85, 0.6, 0.3),
		"script": "res://scripts/abilities/earthquake_leap.gd",
		"text": "Leaps to the aim point; on landing, deals area damage and stuns enemies.",
		"enhanced": "Stun lasts 0.6 s longer.",
		"a": ["Aftershock", "The landing spot shakes for 3 s, damaging enemies standing on it."],
		"b": ["Winged Leap", "Cooldown is 3 s shorter."],
	},
	"war_cry": {
		"title": "War Cry", "tier": 2, "color": Color(1.0, 0.3, 0.3),
		"script": "res://scripts/abilities/war_cry.gd",
		"cast": ["Cheer", 0.8],
		"text": "Your damage and attack speed increase by 25% for 6 s; nearby enemies are knocked back.",
		"enhanced": "The effect lasts 2 s longer.",
		"a": ["Terror", "Enemies are knocked back twice as far and freeze for 1 s."],
		"b": ["Battle Fury", "While the effect lasts, cooldowns recharge 25% faster."],
	},
	"heavens_wrath": {
		"title": "Heaven's Wrath", "tier": 3, "color": Color(1.0, 0.85, 0.35), "ultimate": true,
		"script": "res://scripts/abilities/heavens_wrath.gd",
		"cast": ["Spellcast_Raise", 0.7],
		"text": "After a short warning, calls down a huge blast of light on the aim point.",
		"enhanced": "Blast area increases by 20%.",
		"a": ["Triple Strike", "Three blasts land one after another; higher total damage."],
		"b": ["Apocalypse", "Cooldown is 15 s shorter."],
	},
	"sword_rain": {
		"title": "Sword Rain", "tier": 3, "color": Color(0.7, 0.85, 1.0), "ultimate": true,
		"script": "res://scripts/abilities/sword_rain.gd",
		"cast": ["Spellcast_Long", 0.9],
		"text": "For 4 s, swords rain down from the sky on enemies around you.",
		"enhanced": "The rain lasts 2 s longer.",
		"a": ["Blade Storm", "Swords fall twice as often."],
		"b": ["Razor Rain", "Each sword hits a small area where it lands."],
	},
}


static func info(skill_id: String) -> Dictionary:
	return SKILLS[skill_id]


## Upper-body animation played when the power fires: [animation, seconds], or [] when the
## power animates itself (Whirlwind, Shadow Dash, Earthquake Leap).
static func cast_animation(skill_id: String) -> Array:
	return info(skill_id).get("cast", [])


static func title(skill_id: String) -> String:
	return SKILLS[skill_id]["title"]


static func color(skill_id: String) -> Color:
	return SKILLS[skill_id]["color"]


static func tier(skill_id: String) -> int:
	return SKILLS[skill_id]["tier"]


static func gate(tier_index: int) -> int:
	return TIERS[tier_index]["gate"]


static func is_ultimate(skill_id: String) -> bool:
	return SKILLS[skill_id].get("ultimate", false)


static func ids_in_tier(tier_index: int) -> Array[String]:
	var ids: Array[String] = []
	for skill_id: String in SKILLS:
		if tier(skill_id) == tier_index:
			ids.append(skill_id)
	return ids


## The option's name and description; choice is "a" or "b".
static func choice_title(skill_id: String, choice: String) -> String:
	return SKILLS[skill_id][choice][0]


static func choice_text(skill_id: String, choice: String) -> String:
	return SKILLS[skill_id][choice][1]


## Creates the node that runs the power during a run.
static func create_ability(skill_id: String) -> Ability:
	var script: GDScript = load(SKILLS[skill_id]["script"])
	return script.new() as Ability
