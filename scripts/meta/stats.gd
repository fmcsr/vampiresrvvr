class_name Stats
extends RefCounted
## Stat definitions for permanent bonuses (equipment and the core tree). Ratios are stored as 0.1 = 10%.
## If "cap" is set, the total can't go above it; "negative" stats are shown as a reduction.
## "icon" names an icon in ui/icons.

const DEFS := {
	"damage_pct": {"name": "Damage", "kind": "percent", "icon": "sword-wound"},
	"max_health": {"name": "Max health", "kind": "flat", "icon": "heart-plus"},
	"move_speed_pct": {"name": "Move speed", "kind": "percent", "icon": "boots"},
	"cooldown_pct": {"name": "Cooldown", "kind": "percent", "negative": true, "cap": 0.5, "icon": "hourglass"},
	"attack_speed_pct": {"name": "Attack speed", "kind": "percent", "icon": "winged-sword"},
	"area_pct": {"name": "Power area", "kind": "percent", "icon": "aura"},
	"pickup_pct": {"name": "Pickup radius", "kind": "percent", "icon": "magnet"},
	"regen": {"name": "Health regen", "kind": "per_second", "icon": "heart-bottle"},
	"damage_reduction_pct": {"name": "Damage reduction", "kind": "percent", "cap": 0.6, "icon": "bolt-shield"},
	"gold_pct": {"name": "Gold find", "kind": "percent", "icon": "two-coins"},
	"item_find_pct": {"name": "Item find", "kind": "percent", "icon": "open-treasure-chest"},
}


## E.g. "Damage +8%", "Max health +20", "Cooldown −5%", "Health regen +0.4/s".
static func describe(stat: String, value: float) -> String:
	var def: Dictionary = DEFS[stat]
	var sign := "−" if def.get("negative", false) else "+"
	return "%s %s%s" % [def["name"], sign, amount(stat, value)]


## The size of a value with its unit and no sign: "8%", "20", "0.4/s".
static func amount(stat: String, value: float) -> String:
	match DEFS[stat]["kind"]:
		"percent":
			return "%s%%" % UiKit.format_number(absf(value) * 100.0)
		"per_second":
			return "%s/s" % UiKit.format_number(absf(value))
	return UiKit.format_number(absf(value))


static func icon(stat: String) -> Texture2D:
	return UiKit.icon_texture(DEFS[stat]["icon"])


static func capped(stat: String, value: float) -> float:
	var def: Dictionary = DEFS[stat]
	return minf(value, def["cap"]) if def.has("cap") else value
