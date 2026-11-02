class_name ItemGenerator
extends RefCounted
## Generates random items. Each slot has an implicit stat; higher rarity means bigger values
## plus random extra affixes (Magic 1, Rare 2, Legendary 3).

enum Source { CHEST, MINI_BOSS, FINAL_BOSS, SHOP }

const BASES := {
	"weapon": ["Sword", "Axe", "Staff", "Dagger"],
	"armor": ["Robe", "Hauberk", "Cloak", "Jerkin"],
	"trinket": ["Charm", "Ring", "Amulet", "Talisman"],
}
## The slot's implicit stat; if there are several, one is picked at random.
const IMPLICITS := {
	"weapon": ["damage_pct"],
	"armor": ["max_health", "damage_reduction_pct"],
	"trinket": ["move_speed_pct", "cooldown_pct", "pickup_pct", "gold_pct"],
}
## Value range (min, max) on a Common item; scaled up by the rarity multiplier.
const RANGES := {
	"damage_pct": [0.04, 0.10],
	"max_health": [10.0, 25.0],
	"move_speed_pct": [0.03, 0.06],
	"cooldown_pct": [0.03, 0.06],
	"attack_speed_pct": [0.05, 0.12],
	"area_pct": [0.05, 0.10],
	"pickup_pct": [0.10, 0.25],
	"regen": [0.2, 0.5],
	"damage_reduction_pct": [0.02, 0.05],
	"gold_pct": [0.05, 0.15],
	"item_find_pct": [0.05, 0.15],
}
const RARITY_MULTIPLIERS: Array[float] = [1.0, 1.25, 1.5, 2.0]
const EXTRA_AFFIXES: Array[int] = [0, 1, 2, 3]
## Rarity weights by source: Common, Magic, Rare, Legendary.
const DROP_WEIGHTS := {
	Source.CHEST: [0.0, 70.0, 25.0, 5.0],
	Source.MINI_BOSS: [0.0, 30.0, 60.0, 10.0],
	Source.FINAL_BOSS: [0.0, 0.0, 60.0, 40.0],
	Source.SHOP: [0.0, 65.0, 30.0, 5.0],
}
## The adjective in an item's name is chosen by its first extra affix.
const ADJECTIVES := {
	"damage_pct": "Keen", "max_health": "Sturdy", "move_speed_pct": "Nimble", "cooldown_pct": "Wise",
	"attack_speed_pct": "Swift", "area_pct": "Vast", "pickup_pct": "Magnetic", "regen": "Renewing",
	"damage_reduction_pct": "Warded", "gold_pct": "Greedy", "item_find_pct": "Lucky",
}
const LEGENDARY_NAMES: Array[String] = ["Shadoweater", "Ember Heart", "Frost Claw", "Bone King's", "Eternal Night", "Cursed"]
## Common items that are always for sale in the shop.
const BASIC_TITLES := {"weapon": "Rusty Sword", "armor": "Tattered Robe", "trinket": "Bone Charm"}


## The shop's basic item: fixed name and a fixed value in the middle of the range.
static func basic(slot: String) -> Item:
	var item := Item.new()
	item.id = _new_id()
	item.slot = slot
	item.rarity = Item.Rarity.COMMON
	item.title = BASIC_TITLES[slot]
	var stat: String = IMPLICITS[slot][0]
	var bounds: Array = RANGES[stat]
	item.affixes.append({"stat": stat, "value": _round(stat, lerpf(bounds[0], bounds[1], 0.5))})
	return item


## Gives an item from an older (Turkish) save a fresh English title.
static func retitle(item: Item) -> void:
	if item.affixes.is_empty():
		return
	if item.rarity == Item.Rarity.COMMON and item.affixes.size() == 1:
		item.title = BASIC_TITLES[item.slot]
	else:
		item.title = _make_title(item)


static func roll_drop(source: Source) -> Item:
	return roll(_pick_rarity(DROP_WEIGHTS[source]))


static func roll_shop_stock(count: int) -> Array[Item]:
	var stock: Array[Item] = []
	for i in count:
		stock.append(roll_drop(Source.SHOP))
	return stock


static func roll(rarity: int, slot := "") -> Item:
	var item := Item.new()
	item.id = _new_id()
	item.slot = slot if slot != "" else Item.SLOTS.pick_random()
	item.rarity = rarity
	var implicit: String = (IMPLICITS[item.slot] as Array).pick_random()
	item.affixes.append(_roll_affix(implicit, rarity))
	var pool: Array = RANGES.keys().filter(func(stat: String) -> bool: return stat != implicit)
	pool.shuffle()
	for i in EXTRA_AFFIXES[rarity]:
		item.affixes.append(_roll_affix(pool[i], rarity))
	item.title = _make_title(item)
	return item


static func _roll_affix(stat: String, rarity: int) -> Dictionary:
	var bounds: Array = RANGES[stat]
	var value: float = randf_range(bounds[0], bounds[1]) * RARITY_MULTIPLIERS[rarity]
	return {"stat": stat, "value": _round(stat, value)}


static func _round(stat: String, value: float) -> float:
	match stat:
		"max_health":
			return roundf(value)
		"regen":
			return snappedf(value, 0.1)
	return maxf(snappedf(value, 0.01), 0.01)


static func _make_title(item: Item) -> String:
	var base: String = (BASES[item.slot] as Array).pick_random()
	if item.rarity == Item.Rarity.LEGENDARY:
		return "%s %s" % [LEGENDARY_NAMES.pick_random(), base]
	var key: String = item.affixes[1]["stat"] if item.affixes.size() > 1 else item.affixes[0]["stat"]
	return "%s %s" % [ADJECTIVES[key], base]


static func _pick_rarity(weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var roll_value := randf() * total
	for i in weights.size():
		roll_value -= weights[i]
		if roll_value <= 0.0 and weights[i] > 0.0:
			return i
	return weights.size() - 1


static func _new_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]
