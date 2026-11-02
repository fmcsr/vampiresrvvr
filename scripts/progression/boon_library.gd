class_name BoonLibrary
extends RefCounted
## Definitions of the boons picked on level-up (Hades style). Game code reads effects straight
## from the "value" field here, so the card text and the actual effect always match.
## Total effect = value × boon rank. If "percent" is true, value is shown as a percentage (0.1 = 10%).
## Each power in the loadout also gets a "<Power> Mastery" boon (id "power:<skill>").

const HEAL_ID := "heal"
const POWER_PREFIX := "power:"
const POWER_VALUE := 0.25
const POWER_MAX_RANK := 3

## "tag" sets the card's color and what the boon belongs to.
const BOONS := {
	"might": {"title": "Might", "text": "All damage +{v}%.",
			"value": 0.10, "percent": true, "max_rank": 5, "tag": "General"},
	"vitality": {"title": "Blood Bond", "text": "Max health +{v} and heal {v} health.",
			"value": 20.0, "percent": false, "max_rank": 5, "tag": "General"},
	"swiftness": {"title": "Wind Step", "text": "Move speed +{v}%.",
			"value": 0.08, "percent": true, "max_rank": 4, "tag": "General"},
	"haste": {"title": "Time Slip", "text": "Power cooldowns −{v}%.",
			"value": 0.08, "percent": true, "max_rank": 4, "tag": "General"},
	"magnet": {"title": "Soul Pull", "text": "XP pickup radius +{v}%.",
			"value": 0.30, "percent": true, "max_rank": 3, "tag": "General"},
	"regen": {"title": "Regeneration", "text": "Regenerate {v} health per second.",
			"value": 0.5, "percent": false, "max_rank": 4, "tag": "General"},
	"attack_speed": {"title": "Swift Blade", "text": "Sword Swing speed +{v}%.",
			"value": 0.15, "percent": true, "max_rank": 5, "tag": "Sword Swing"},
	"arc": {"title": "Wide Swing", "text": "Sword Swing arc +{v}°.",
			"value": 30.0, "percent": false, "max_rank": 3, "tag": "Sword Swing"},
	"reach": {"title": "Long Blade", "text": "Sword Swing reach +{v}%.",
			"value": 0.15, "percent": true, "max_rank": 3, "tag": "Sword Swing"},
}

## Offered when there are no boons left to pick; it has no rank.
const HEAL := {"title": "Healing Spring", "text": "Heal {v} health.",
		"value": 40.0, "percent": false, "max_rank": 0, "tag": "General"}

const TAG_COLORS := {
	"General": Color(0.85, 0.75, 0.5),
	"Sword Swing": Color(0.8, 0.85, 0.95),
}


static func power_id(skill_id: String) -> String:
	return POWER_PREFIX + skill_id


static func info(boon_id: String) -> Dictionary:
	if boon_id == HEAL_ID:
		return HEAL
	if boon_id.begins_with(POWER_PREFIX):
		var skill_title := SkillLibrary.title(boon_id.trim_prefix(POWER_PREFIX))
		return {"title": "%s Mastery" % skill_title, "text": "%s power +{v}%%." % skill_title,
				"value": POWER_VALUE, "percent": true, "max_rank": POWER_MAX_RANK, "tag": skill_title}
	return BOONS[boon_id]


static func value(boon_id: String) -> float:
	return info(boon_id)["value"]


## Total effect the player gets from this boon (value × rank).
static func total(player: Player, boon_id: String) -> float:
	return value(boon_id) * player.rank(boon_id)


static func describe(boon_id: String) -> String:
	var data := info(boon_id)
	var amount: float = data["value"]
	if data["percent"]:
		amount *= 100.0
	var text: String = data["text"]
	return text.format({"v": UiKit.format_number(amount)})


## The card's accent color; power boons use the power's color.
static func accent(boon_id: String) -> Color:
	if boon_id.begins_with(POWER_PREFIX):
		return SkillLibrary.color(boon_id.trim_prefix(POWER_PREFIX))
	return TAG_COLORS.get(info(boon_id)["tag"], Color.WHITE)


## Picks at random from the boons the player hasn't maxed out yet (including those for loadout powers).
static func roll_choices(player: Player, count: int) -> Array[String]:
	var available: Array[String] = []
	for boon_id: String in BOONS:
		var max_rank: int = BOONS[boon_id]["max_rank"]
		if player.rank(boon_id) < max_rank:
			available.append(boon_id)
	for ability in player.abilities:
		if ability and player.rank(power_id(ability.skill_id)) < POWER_MAX_RANK:
			available.append(power_id(ability.skill_id))
	available.shuffle()
	available.resize(mini(count, available.size()))
	if available.size() < count:
		available.append(HEAL_ID)
	return available
