extends Node
## Everything that persists between runs: gold, cores, stash, equipped items, unlocked core
## nodes, shop wares, character level, the skill tree and the power loadout.
## Saved to user://profile.json.
## A run marks run_in_progress when it starts; if the game closes mid-run, the next launch
## counts that run as a failure and the equipped gear is lost (the Tarkov rule).

signal changed

const SAVE_PATH := "user://profile.json"
## 2: skill tree and character level. 3: English item names.
const SAVE_VERSION := 3
const STARTING_GOLD := 50
const SHOP_STOCK_SIZE := 3
const MAX_CHAR_LEVEL := 40
## Skill points at level 1; every level after that adds one.
const STARTING_SKILL_POINTS := 4
const STARTER_LOADOUT: Array[String] = ["fire_wave", "shadow_dash", "frost_nova", "whirlwind"]
## Gold cost of refunding a skill point: a base plus an increase per level.
const REFUND_BASE_COST := 10
const REFUND_COST_PER_LEVEL := 3

## When false nothing is read from or written to disk (tests run with --no-save).
var persist := true
var gold := 0
var cores := 0
var stash: Array[Item] = []
var equipped: Dictionary[String, Item] = {}
var unlocked: Array[String] = []
var shop_stock: Array[Item] = []
var runs := 0
var extractions := 0
var failures := 0
var run_in_progress := false
var char_level := 1
var char_xp := 0
## Learned skills: {skill_id: {"rank": int, "enhanced": bool, "choice": "a" | "b" | ""}}
var skills: Dictionary[String, Dictionary] = {}
## The four power slots (keys 1–4); an empty slot is "".
var loadout: Array[String] = ["", "", "", ""]
## Summary of an abandoned run found while loading; the camp screen shows it once.
var abandoned_summary: Dictionary = {}


func _ready() -> void:
	if "--no-save" in OS.get_cmdline_user_args():
		persist = false
		reset()
		return
	load_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		reset()
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary):
		push_warning("Could not read the profile; starting a new one.")
		reset()
		return
	from_dict(data)
	if run_in_progress:
		abandoned_summary = apply_run_result({"success": false, "reason": "Run abandoned"})


## A new profile: starter gear equipped, the four starter powers and a little gold.
func reset() -> void:
	gold = STARTING_GOLD
	cores = 0
	stash.clear()
	equipped.clear()
	for slot in Item.SLOTS:
		equipped[slot] = ItemGenerator.basic(slot)
	unlocked.clear()
	shop_stock = ItemGenerator.roll_shop_stock(SHOP_STOCK_SIZE)
	runs = 0
	extractions = 0
	failures = 0
	run_in_progress = false
	char_level = 1
	char_xp = 0
	_reset_skills()
	abandoned_summary = {}
	_commit()


func equip(item: Item) -> void:
	if not stash.has(item):
		return
	stash.erase(item)
	if equipped.has(item.slot):
		stash.append(equipped[item.slot])
	equipped[item.slot] = item
	_commit()


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	stash.append(equipped[slot])
	equipped.erase(slot)
	_commit()


## Shop wares leave the stock; basic items are unlimited. The item goes to the stash.
func buy(item: Item) -> bool:
	if gold < item.price():
		return false
	gold -= item.price()
	shop_stock.erase(item)
	stash.append(item)
	_commit()
	return true


func sell(item: Item) -> void:
	if not stash.has(item):
		return
	stash.erase(item)
	gold += item.sell_price()
	_commit()


func unlock_node(node_id: String) -> bool:
	if not CoreTree.can_unlock(node_id, unlocked, cores):
		return false
	cores -= CoreTree.cost(node_id)
	unlocked.append(node_id)
	_commit()
	return true


## Total permanent bonuses from equipped items and unlocked core nodes: {stat: value}.
func bonuses() -> Dictionary:
	var totals := {}
	for item in equipped.values():
		for affix in (item as Item).affixes:
			totals[affix["stat"]] = totals.get(affix["stat"], 0.0) + float(affix["value"])
	for node_id in unlocked:
		var node: Dictionary = CoreTree.NODES[node_id]
		if node["stat"] != "":
			totals[node["stat"]] = totals.get(node["stat"], 0.0) + float(node["value"])
	for stat in totals.keys():
		totals[stat] = Stats.capped(stat, totals[stat])
	return totals


# --- Character level -------------------------------------------------------------------

func xp_to_next_level() -> int:
	return 400 + 100 * (char_level - 1)


## Adds XP; returns how many levels were gained.
func add_char_xp(amount: int) -> int:
	var gained := 0
	char_xp += amount
	while char_level < MAX_CHAR_LEVEL and char_xp >= xp_to_next_level():
		char_xp -= xp_to_next_level()
		char_level += 1
		gained += 1
	if char_level >= MAX_CHAR_LEVEL:
		char_xp = 0
	if gained > 0 or amount > 0:
		_commit()
	return gained


# --- Skill tree --------------------------------------------------------------------------
# Functions that change the tree return "" on success, otherwise the reason it failed.

func skill_points_total() -> int:
	return STARTING_SKILL_POINTS + char_level - 1


func skill_points_spent() -> int:
	var spent := 0
	for skill_id in skills:
		spent += _state_points(skills[skill_id])
	return spent


func skill_points_free() -> int:
	return skill_points_total() - skill_points_spent()


func skill_rank(skill_id: String) -> int:
	return int(skills[skill_id]["rank"]) if skills.has(skill_id) else 0


## Returns a copy; an unlearned skill has rank 0.
func skill_state(skill_id: String) -> Dictionary:
	if skills.has(skill_id):
		return skills[skill_id].duplicate()
	return {"rank": 0, "enhanced": false, "choice": ""}


## Points spent in the tiers below, which is what opens a tier.
func points_below_tier(tier_index: int) -> int:
	return _points_below(_points_by_tier(), tier_index)


func tier_unlocked(tier_index: int) -> bool:
	return points_below_tier(tier_index) >= SkillLibrary.gate(tier_index)


func refund_cost() -> int:
	return REFUND_BASE_COST + REFUND_COST_PER_LEVEL * (char_level - 1)


func respec_cost() -> int:
	return refund_cost() * skill_points_spent()


func add_skill_rank(skill_id: String) -> String:
	var state := skill_state(skill_id)
	if state["rank"] >= SkillLibrary.MAX_RANK:
		return "Already at max rank."
	if skill_points_free() < 1:
		return "No free skill points."
	if not tier_unlocked(SkillLibrary.tier(skill_id)):
		return "This tier is still locked."
	state["rank"] += 1
	_store_skill(skill_id, state)
	_commit()
	return ""


func enhance_skill(skill_id: String) -> String:
	var state := skill_state(skill_id)
	if state["rank"] < 1:
		return "Learn the skill first."
	if state["enhanced"]:
		return "Already enhanced."
	if skill_points_free() < 1:
		return "No free skill points."
	state["enhanced"] = true
	_store_skill(skill_id, state)
	_commit()
	return ""


## Taking an option costs 1 point; switching to the other option costs no points, only the
## refund price in gold.
func choose_skill(skill_id: String, choice: String) -> String:
	var state := skill_state(skill_id)
	if not state["enhanced"]:
		return "Take the Enhanced upgrade first."
	if state["choice"] == choice:
		return "This option is already selected."
	if state["choice"] == "":
		if skill_points_free() < 1:
			return "No free skill points."
	else:
		if gold < refund_cost():
			return "%d gold needed to switch." % refund_cost()
		gold -= refund_cost()
	state["choice"] = choice
	_store_skill(skill_id, state)
	_commit()
	return ""


## Refunds one point for gold. part: "rank", "enhanced" or "choice".
func refund_skill(skill_id: String, part: String) -> String:
	var state := skill_state(skill_id)
	match part:
		"choice":
			if state["choice"] == "":
				return "No option taken."
			state["choice"] = ""
		"enhanced":
			if not state["enhanced"]:
				return "The Enhanced upgrade is not taken."
			if state["choice"] != "":
				return "Refund the option first."
			state["enhanced"] = false
		_:
			if state["rank"] <= 0:
				return "No rank to refund."
			if state["rank"] == 1 and state["enhanced"]:
				return "Refund the Enhanced upgrade first."
			state["rank"] -= 1
	var points := _points_by_tier()
	points[SkillLibrary.tier(skill_id)] -= 1
	if not _gates_hold(points):
		return "Refund points in higher tiers first."
	if gold < refund_cost():
		return "%d gold needed to refund." % refund_cost()
	gold -= refund_cost()
	_store_skill(skill_id, state)
	_commit()
	return ""


## Refunds every skill point; the loadout is emptied.
func respec_all() -> String:
	var cost := respec_cost()
	if skill_points_spent() == 0:
		return "No points spent."
	if gold < cost:
		return "%d gold needed to reset." % cost
	gold -= cost
	skills.clear()
	loadout.assign(["", "", "", ""])
	_commit()
	return ""


## Puts a power in a slot; if it is already in another slot the two swap. An empty id clears the slot.
func set_loadout(slot: int, skill_id: String) -> String:
	var next := loadout.duplicate()
	if skill_id != "":
		if skill_rank(skill_id) <= 0:
			return "Learn this skill first."
		var previous := next.find(skill_id)
		if previous != -1:
			next[previous] = next[slot]
	next[slot] = skill_id
	var ultimates := 0
	for id in next:
		if id != "" and SkillLibrary.is_ultimate(id):
			ultimates += 1
	if ultimates > 1:
		return "Only one ultimate is allowed in your loadout."
	loadout.assign(next)
	_commit()
	return ""


# --- Runs --------------------------------------------------------------------------------

func begin_run() -> void:
	run_in_progress = true
	runs += 1
	_commit()


## Applies a run result to the profile and returns a summary for the result screen.
## On an escape, gold, XP, run cores and found items are added. On a failure those are lost
## along with the equipped gear. Cores from the final boss (already secured) are always kept.
func apply_run_result(result: Dictionary) -> Dictionary:
	var success: bool = result.get("success", false)
	var lost_equipment: Array[Item] = []
	var levels_gained := 0
	cores += int(result.get("secured_cores", 0))
	if success:
		gold += int(result.get("gold", 0))
		cores += int(result.get("run_cores", 0))
		for item in result.get("items", []):
			stash.append(item)
		levels_gained = add_char_xp(int(result.get("xp", 0)))
		extractions += 1
	else:
		lost_equipment.assign(equipped.values())
		equipped.clear()
		failures += 1
	run_in_progress = false
	shop_stock = ItemGenerator.roll_shop_stock(SHOP_STOCK_SIZE)
	_commit()
	var summary := result.duplicate()
	summary["lost_equipment"] = lost_equipment
	summary["levels_gained"] = levels_gained
	summary["char_level"] = char_level
	return summary


# --- Saving ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_equipped := {}
	for slot in equipped:
		saved_equipped[slot] = equipped[slot].to_dict()
	return {
		"version": SAVE_VERSION,
		"gold": gold,
		"cores": cores,
		"stash": stash.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"equipped": saved_equipped,
		"unlocked": unlocked,
		"shop": shop_stock.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"runs": runs,
		"extractions": extractions,
		"failures": failures,
		"run_in_progress": run_in_progress,
		"char_level": char_level,
		"char_xp": char_xp,
		"skills": skills,
		"loadout": loadout,
	}


## Older saves load too: without skill data the starter powers are given, and items from
## saves before version 3 get English names.
func from_dict(data: Dictionary) -> void:
	var version := int(data.get("version", 1))
	gold = int(data.get("gold", 0))
	cores = int(data.get("cores", 0))
	stash.clear()
	for entry in data.get("stash", []):
		stash.append(Item.from_dict(entry))
	equipped.clear()
	var saved_equipped: Dictionary = data.get("equipped", {})
	for slot in saved_equipped:
		equipped[str(slot)] = Item.from_dict(saved_equipped[slot])
	unlocked.clear()
	for node_id in data.get("unlocked", []):
		if CoreTree.NODES.has(node_id):
			unlocked.append(str(node_id))
	shop_stock.clear()
	for entry in data.get("shop", []):
		shop_stock.append(Item.from_dict(entry))
	if version < 3:
		for item in _all_items():
			ItemGenerator.retitle(item)
	runs = int(data.get("runs", 0))
	extractions = int(data.get("extractions", 0))
	failures = int(data.get("failures", 0))
	run_in_progress = bool(data.get("run_in_progress", false))
	char_level = clampi(int(data.get("char_level", 1)), 1, MAX_CHAR_LEVEL)
	char_xp = maxi(int(data.get("char_xp", 0)), 0)
	if not data.has("skills"):
		_reset_skills()
		return
	skills.clear()
	var saved_skills: Dictionary = data["skills"]
	for skill_id in saved_skills:
		if not SkillLibrary.SKILLS.has(skill_id):
			continue
		var saved: Dictionary = saved_skills[skill_id]
		var choice := str(saved.get("choice", ""))
		_store_skill(str(skill_id), {
			"rank": clampi(int(saved.get("rank", 0)), 0, SkillLibrary.MAX_RANK),
			"enhanced": bool(saved.get("enhanced", false)),
			"choice": choice if choice in ["a", "b"] else "",
		})
	loadout.assign(["", "", "", ""])
	var saved_loadout: Array = data.get("loadout", [])
	for i in mini(saved_loadout.size(), loadout.size()):
		var skill_id := str(saved_loadout[i])
		if skill_rank(skill_id) > 0:
			loadout[i] = skill_id


func save() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the profile: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func _reset_skills() -> void:
	skills.clear()
	for skill_id in STARTER_LOADOUT:
		skills[skill_id] = {"rank": 1, "enhanced": false, "choice": ""}
	loadout.assign(STARTER_LOADOUT)


## A skill that drops to rank 0 is removed and taken out of the loadout.
func _store_skill(skill_id: String, state: Dictionary) -> void:
	if int(state["rank"]) <= 0:
		skills.erase(skill_id)
		var slot := loadout.find(skill_id)
		if slot != -1:
			loadout[slot] = ""
		return
	skills[skill_id] = state


func _points_by_tier() -> Array[int]:
	var points: Array[int] = []
	points.resize(SkillLibrary.TIERS.size())
	points.fill(0)
	for skill_id in skills:
		points[SkillLibrary.tier(skill_id)] += _state_points(skills[skill_id])
	return points


func _all_items() -> Array[Item]:
	var items: Array[Item] = []
	items.append_array(stash)
	items.append_array(equipped.values())
	items.append_array(shop_stock)
	return items


func _commit() -> void:
	changed.emit()
	save()


static func _state_points(state: Dictionary) -> int:
	return int(state["rank"]) + (1 if state["enhanced"] else 0) + (1 if state["choice"] != "" else 0)


static func _points_below(points: Array[int], tier_index: int) -> int:
	var total := 0
	for i in tier_index:
		total += points[i]
	return total


## Is every tier that has points still open in this distribution?
static func _gates_hold(points: Array[int]) -> bool:
	for tier_index in points.size():
		if points[tier_index] > 0 and _points_below(points, tier_index) < SkillLibrary.gate(tier_index):
			return false
	return true
