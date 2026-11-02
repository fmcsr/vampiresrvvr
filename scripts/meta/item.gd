class_name Item
extends RefCounted
## A piece of equipment: slot, rarity and stat bonuses. The first bonus is the slot's implicit stat;
## the rest are random affixes that come with rarity. Stored in the profile as a dictionary.

enum Rarity { COMMON, MAGIC, RARE, LEGENDARY }

const SLOTS: Array[String] = ["weapon", "armor", "trinket"]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "trinket": "Charm"}
const RARITY_NAMES: Array[String] = ["Common", "Magic", "Rare", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.82), Color(0.45, 0.65, 1.0), Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.15)]
## Shop price; the sell price is a quarter of it.
const RARITY_PRICES: Array[int] = [60, 180, 420, 900]

var id := ""
var slot := "weapon"
var rarity: int = Rarity.COMMON
var title := ""
## [{"stat": String, "value": float}]
var affixes: Array[Dictionary] = []


func price() -> int:
	return RARITY_PRICES[rarity]


func sell_price() -> int:
	return int(price() / 4.0)


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func slot_name() -> String:
	return SLOT_NAMES[slot]


func describe_affixes() -> Array[String]:
	var lines: Array[String] = []
	for affix in affixes:
		lines.append(Stats.describe(affix["stat"], affix["value"]))
	return lines


func to_dict() -> Dictionary:
	return {"id": id, "slot": slot, "rarity": rarity, "title": title, "affixes": affixes.duplicate(true)}


static func from_dict(data: Dictionary) -> Item:
	var item := Item.new()
	item.id = str(data.get("id", ""))
	item.slot = str(data.get("slot", "weapon"))
	item.rarity = clampi(int(data.get("rarity", 0)), Rarity.COMMON, Rarity.LEGENDARY)
	item.title = str(data.get("title", ""))
	for affix in data.get("affixes", []):
		item.affixes.append({"stat": str(affix["stat"]), "value": float(affix["value"])})
	return item
