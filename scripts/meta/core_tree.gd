class_name CoreTree
extends RefCounted
## Permanent upgrade tree unlocked with cores. Three branches grow from the "Essence" at the center:
## Might (offense), Resilience (defense), Fortune (loot and speed). A node can be unlocked once any
## node in its "requires" list is unlocked. "angle" (degrees, 0 = right, -90 = up) and
## "radius" are only used for the UI layout.

const ROOT := "root"
const BRANCH_COLORS := {
	"": Color(0.8, 0.7, 1.0),
	"Might": Color(1.0, 0.45, 0.2),
	"Resilience": Color(0.4, 0.85, 0.5),
	"Fortune": Color(1.0, 0.8, 0.3),
}
const NODES := {
	"root": {"title": "Essence", "stat": "", "value": 0.0, "cost": 0, "requires": [],
			"angle": 0.0, "radius": 0.0, "branch": ""},
	"a1": {"title": "Keen Spirit", "stat": "damage_pct", "value": 0.05, "cost": 1, "requires": ["root"],
			"angle": -90.0, "radius": 1.3, "branch": "Might"},
	"a2": {"title": "Quick Hands", "stat": "attack_speed_pct", "value": 0.08, "cost": 2, "requires": ["a1"],
			"angle": -110.0, "radius": 2.4, "branch": "Might"},
	"a3": {"title": "Wide Flame", "stat": "area_pct", "value": 0.08, "cost": 2, "requires": ["a1"],
			"angle": -70.0, "radius": 2.4, "branch": "Might"},
	"a4": {"title": "Ruin", "stat": "damage_pct", "value": 0.08, "cost": 3, "requires": ["a2"],
			"angle": -105.0, "radius": 3.5, "branch": "Might"},
	"a5": {"title": "Growing Power", "stat": "area_pct", "value": 0.10, "cost": 3, "requires": ["a3"],
			"angle": -75.0, "radius": 3.5, "branch": "Might"},
	"a6": {"title": "Doom Master", "stat": "cooldown_pct", "value": 0.10, "cost": 4, "requires": ["a4", "a5"],
			"angle": -90.0, "radius": 4.5, "branch": "Might"},
	"b1": {"title": "Sturdy Body", "stat": "max_health", "value": 15.0, "cost": 1, "requires": ["root"],
			"angle": 30.0, "radius": 1.3, "branch": "Resilience"},
	"b2": {"title": "Bone Skin", "stat": "damage_reduction_pct", "value": 0.04, "cost": 2, "requires": ["b1"],
			"angle": 10.0, "radius": 2.4, "branch": "Resilience"},
	"b3": {"title": "Blood Spring", "stat": "regen", "value": 0.4, "cost": 2, "requires": ["b1"],
			"angle": 50.0, "radius": 2.4, "branch": "Resilience"},
	"b4": {"title": "Iron Will", "stat": "max_health", "value": 25.0, "cost": 3, "requires": ["b2"],
			"angle": 15.0, "radius": 3.5, "branch": "Resilience"},
	"b5": {"title": "Life Essence", "stat": "regen", "value": 0.6, "cost": 3, "requires": ["b3"],
			"angle": 45.0, "radius": 3.5, "branch": "Resilience"},
	"b6": {"title": "Undying", "stat": "damage_reduction_pct", "value": 0.08, "cost": 4, "requires": ["b4", "b5"],
			"angle": 30.0, "radius": 4.5, "branch": "Resilience"},
	"c1": {"title": "Greedy Eye", "stat": "gold_pct", "value": 0.10, "cost": 1, "requires": ["root"],
			"angle": 150.0, "radius": 1.3, "branch": "Fortune"},
	"c2": {"title": "Nimble Step", "stat": "move_speed_pct", "value": 0.05, "cost": 2, "requires": ["c1"],
			"angle": 130.0, "radius": 2.4, "branch": "Fortune"},
	"c3": {"title": "Soul Magnet", "stat": "pickup_pct", "value": 0.25, "cost": 2, "requires": ["c1"],
			"angle": 170.0, "radius": 2.4, "branch": "Fortune"},
	"c4": {"title": "Treasure Hunter", "stat": "gold_pct", "value": 0.15, "cost": 3, "requires": ["c2"],
			"angle": 135.0, "radius": 3.5, "branch": "Fortune"},
	"c5": {"title": "Time Bender", "stat": "cooldown_pct", "value": 0.06, "cost": 3, "requires": ["c3"],
			"angle": 165.0, "radius": 3.5, "branch": "Fortune"},
	"c6": {"title": "Lucky Star", "stat": "item_find_pct", "value": 0.30, "cost": 4, "requires": ["c4", "c5"],
			"angle": 150.0, "radius": 4.5, "branch": "Fortune"},
}


static func is_unlocked(node_id: String, unlocked: Array[String]) -> bool:
	return node_id == ROOT or node_id in unlocked


## Is any of the nodes this one depends on unlocked?
static func is_reachable(node_id: String, unlocked: Array[String]) -> bool:
	for required in NODES[node_id]["requires"]:
		if is_unlocked(required, unlocked):
			return true
	return false


static func cost(node_id: String) -> int:
	return NODES[node_id]["cost"]


static func can_unlock(node_id: String, unlocked: Array[String], cores: int) -> bool:
	return not is_unlocked(node_id, unlocked) and is_reachable(node_id, unlocked) and cores >= cost(node_id)


static func describe(node_id: String) -> String:
	var node: Dictionary = NODES[node_id]
	if node["stat"] == "":
		return "The center of the tree. Three branches grow from here."
	return Stats.describe(node["stat"], node["value"])
