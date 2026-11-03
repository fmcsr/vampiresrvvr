class_name EquipmentPanel
extends HubPanel
## Equipment tab: the three equipped slots, total permanent bonuses and the stash (equip / sell).

var _slots_box: VBoxContainer
var _bonus_box: VBoxContainer
var _stash_title: Label
var _stash_list: VBoxContainer


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(heading("EQUIPPED — at risk during runs"))
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 8)
	left.add_child(_slots_box)

	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 270
	middle.add_theme_constant_override("separation", 6)
	row.add_child(middle)
	middle.add_child(heading("TOTAL PERMANENT BONUSES"))
	_bonus_box = VBoxContainer.new()
	_bonus_box.add_theme_constant_override("separation", 4)
	middle.add_child(_bonus_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	_stash_title = heading("")
	right.add_child(_stash_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_stash_list = VBoxContainer.new()
	_stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_stash_list)


func refresh() -> void:
	UiKit.clear(_slots_box)
	for slot in Item.SLOTS:
		_slots_box.add_child(_slot_card(slot))

	UiKit.clear(_bonus_box)
	var totals := Profile.bonuses()
	if totals.is_empty():
		_bonus_box.add_child(UiKit.label("No bonuses yet", 16, DIM_COLOR))
	for stat in Stats.DEFS:
		if totals.has(stat):
			_bonus_box.add_child(UiKit.label(Stats.describe(stat, totals[stat]), 17, Color(0.9, 0.88, 0.8)))

	UiKit.clear(_stash_list)
	_stash_title.text = "STASH (%s)" % UiKit.count_text(Profile.stash.size(), "item", "items")
	var items := Profile.stash.duplicate()
	items.sort_custom(_stash_order)
	if items.is_empty():
		_stash_list.add_child(UiKit.label("Your stash is empty. Escape with loot or buy items in the Shop.", 16, DIM_COLOR))
	for item in items:
		_stash_list.add_child(_stash_row(item))


func _slot_card(slot: String) -> Control:
	var item: Item = Profile.equipped.get(slot)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(item.color() if item else Color(0.35, 0.33, 0.4)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var slot_label := UiKit.label(Item.SLOT_NAMES[slot].to_upper(), 14, DIM_COLOR)
	slot_label.custom_minimum_size.x = 64
	row.add_child(slot_label)
	if item:
		var card := UiKit.item_card(item)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var remove := UiKit.button("Unequip", Color(0.7, 0.7, 0.75), 14)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove.pressed.connect(Profile.unequip.bind(slot))
		remove.pressed.connect(func() -> void: Audio.play("unequip"))
		row.add_child(remove)
	else:
		var empty := UiKit.label("Empty", 17, DIM_COLOR)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(empty)
		if not Profile.has_free_basic(slot):
			var take := UiKit.button("Take %s (free)" % ItemGenerator.BASIC_TITLES[slot], Color(0.5, 0.9, 0.65), 14)
			take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			take.pressed.connect(Profile.take_free_basic.bind(slot))
			take.pressed.connect(func() -> void: Audio.play("equip"))
			row.add_child(take)
	return panel


func _stash_row(item: Item) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(item.color()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var card := UiKit.item_card(item)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)
	var equip := UiKit.button("Equip", Color(0.5, 0.9, 0.65), 15)
	equip.pressed.connect(Profile.equip.bind(item))
	equip.pressed.connect(func() -> void: Audio.play("equip"))
	buttons.add_child(equip)
	if item.free:
		buttons.add_child(UiKit.label("Free kit: can't be sold", 13, DIM_COLOR))
		return panel
	var sell := UiKit.button("Sell  +%d" % item.sell_price(), GOLD_COLOR, 15)
	sell.pressed.connect(Profile.sell.bind(item))
	sell.pressed.connect(func() -> void: Audio.play("gold"))
	buttons.add_child(sell)
	return panel


## Sorts by slot order, then by rarity (highest first).
func _stash_order(a: Item, b: Item) -> bool:
	if a.slot != b.slot:
		return Item.SLOTS.find(a.slot) < Item.SLOTS.find(b.slot)
	return a.rarity > b.rarity
