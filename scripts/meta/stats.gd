class_name Stats
extends RefCounted
## Stat definitions for permanent bonuses (equipment and the core tree). Ratios are stored as 0.1 = 10%.
## If "cap" is set, the total can't go above it; "negative" stats are shown as a reduction.

const DEFS := {
	"damage_pct": {"name": "Damage", "kind": "percent"},
	"max_health": {"name": "Max health", "kind": "flat"},
	"move_speed_pct": {"name": "Move speed", "kind": "percent"},
	"cooldown_pct": {"name": "Cooldown", "kind": "percent", "negative": true, "cap": 0.5},
	"attack_speed_pct": {"name": "Attack speed", "kind": "percent"},
	"area_pct": {"name": "Power area", "kind": "percent"},
	"pickup_pct": {"name": "Pickup radius", "kind": "percent"},
	"regen": {"name": "Health regen", "kind": "per_second"},
	"damage_reduction_pct": {"name": "Damage reduction", "kind": "percent", "cap": 0.6},
	"gold_pct": {"name": "Gold find", "kind": "percent"},
	"item_find_pct": {"name": "Item find", "kind": "percent"},
}


## E.g. "Damage +8%", "Max health +20", "Cooldown −5%", "Health regen +0.4/s".
static func describe(stat: String, value: float) -> String:
	var def: Dictionary = DEFS[stat]
	var sign := "−" if def.get("negative", false) else "+"
	match def["kind"]:
		"percent":
			return "%s %s%s%%" % [def["name"], sign, UiKit.format_number(value * 100.0)]
		"per_second":
			return "%s %s%s/s" % [def["name"], sign, UiKit.format_number(value)]
	return "%s %s%s" % [def["name"], sign, UiKit.format_number(value)]


static func capped(stat: String, value: float) -> float:
	var def: Dictionary = DEFS[stat]
	return minf(value, def["cap"]) if def.has("cap") else value
