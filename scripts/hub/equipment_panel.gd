class_name EquipmentPanel
extends HubPanel
## Gear tab: the three equipped slots, the stash as a grid of item icons (filter by slot, sort
## by rarity or slot) and the selected item compared with what you wear in its slot, where it
## can be equipped or sold. Rare and better items ask before they are sold.

const TILE_SIZE := 78.0
const GRID_COLUMNS := 5
## Filter buttons: slot ("" for all), label, icon.
const FILTERS := [["", "All", "backpack"], ["weapon", "Weapons", "broadsword"], ["armor", "Armor", "leather-armor"],
		["trinket", "Charms", "gem-pendant"]]

var _slots_box: VBoxContainer
var _stash_title: Label
var _filter_buttons: Array[Button] = []
var _sort_button: Button
var _grid: GridContainer
var _empty_label: Label
var _details: VBoxContainer
var _filter := ""
var _sort_by_rarity := true
var _selected: Item


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(heading("Equipped"))
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	left.add_child(_slots_box)
	var note := UiKit.wrapped("Everything you wear is at risk: fail to escape and it's gone. The free basic kit can always be taken again.", 15, DIM_COLOR)
	left.add_child(note)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	row.add_child(middle)
	var stash_heading := heading("")
	_stash_title = stash_heading.get_child(0) as Label
	middle.add_child(stash_heading)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	middle.add_child(tools)
	for filter: Array in FILTERS:
		var button := UiKit.icon_button(filter[1], filter[2], UiTheme.Kind.QUIET, 14)
		button.toggle_mode = true
		button.pressed.connect(_set_filter.bind(filter[0]))
		tools.add_child(button)
		_filter_buttons.append(button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(gap)
	_sort_button = UiKit.button("", UiTheme.Kind.QUIET, 14)
	_sort_button.pressed.connect(func() -> void:
		_sort_by_rarity = not _sort_by_rarity
		refresh())
	tools.add_child(_sort_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_empty_label = UiKit.wrapped("", 16, DIM_COLOR)
	middle.add_child(_empty_label)

	var right := UiKit.plate(UiTheme.GOLD, 16.0, false)
	right.custom_minimum_size.x = 340
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 10)
	right.add_child(_details)


func refresh() -> void:
	if _selected and not Profile.stash.has(_selected):
		_selected = null
	UiKit.clear(_slots_box)
	for slot in Item.SLOTS:
		_slots_box.add_child(_slot_row(slot))

	for i in FILTERS.size():
		_filter_buttons[i].set_pressed_no_signal(FILTERS[i][0] == _filter)
	_sort_button.text = "Sort: rarity" if _sort_by_rarity else "Sort: slot"
	var items := Profile.stash.filter(func(item: Item) -> bool: return _filter == "" or item.slot == _filter)
	items.sort_custom(_by_rarity if _sort_by_rarity else _by_slot)
	_stash_title.text = "Stash  ·  %s" % UiKit.count_text(Profile.stash.size(), "item", "items")
	UiKit.clear(_grid)
	for item: Item in items:
		_grid.add_child(_tile(item))
	_empty_label.visible = items.is_empty()
	if Profile.stash.is_empty():
		_empty_label.text = "Your stash is empty. Escape with loot or buy items in the Shop."
	else:
		_empty_label.text = "Nothing of this kind in your stash."
	_build_details()


## From the Prepare tab: show the stash items for that slot.
func focus_on(focus: String) -> void:
	if focus in Item.SLOTS:
		_filter = focus
		refresh()


func _set_filter(slot: String) -> void:
	_filter = slot
	refresh()


func _select(item: Item) -> void:
	_selected = item
	# The pressed tile is freed by this refresh, so refresh at the end of the frame.
	refresh.call_deferred()


func _slot_row(slot: String) -> Control:
	var item: Item = Profile.equipped.get(slot)
	var panel := UiKit.plate(item.color() if item else UiTheme.TEXT_MUTED, 10.0, false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	if item == null:
		var frame := UiKit.icon_slot(UiKit.icon_texture(Item.SLOT_ICONS[slot]), 52.0, UiTheme.TEXT_MUTED)
		frame.modulate.a = 0.55
		row.add_child(frame)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		text.add_child(UiKit.title("Empty %s slot" % Item.SLOT_NAMES[slot].to_lower(), 16, UiTheme.TEXT_DIM, false, 600))
		if not Profile.has_free_basic(slot):
			var take := UiKit.button("Take %s (free)" % ItemGenerator.BASIC_TITLES[slot], UiTheme.Kind.SECONDARY, 14, UiTheme.GOOD)
			take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			take.pressed.connect(Profile.take_free_basic.bind(slot))
			take.pressed.connect(func() -> void: Audio.play("equip"))
			text.add_child(take)
		return panel
	var card := UiKit.item_card(item, 52.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var remove := UiKit.button("Unequip", UiTheme.Kind.QUIET, 13)
	remove.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	remove.pressed.connect(Profile.unequip.bind(slot))
	remove.pressed.connect(func() -> void: Audio.play("unequip"))
	row.add_child(remove)
	return panel


## A stash item as an icon in a frame of its rarity color; the selected one glows.
func _tile(item: Item) -> Button:
	var button := UiKit.button("", UiTheme.Kind.QUIET)
	button.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	button.tooltip_text = "%s\n%s %s" % [item.title, item.rarity_name(), item.slot_name().to_lower()]
	button.pressed.connect(_select.bind(item))
	var frame := UiKit.icon_slot(item.icon(), TILE_SIZE - 8.0, item.color(), item == _selected)
	UiKit.place(frame, Vector4(0, 0, 1, 1), Vector4(4, 4, -4, -4))
	button.add_child(frame)
	if item.free:
		var tag := UiKit.label("kit", 12, UiTheme.TEXT_MUTED, true)
		UiKit.place(tag, Vector4(1, 1, 1, 1), Vector4(-28, -22, -8, -6))
		button.add_child(tag)
	return button


## The selected item, how it compares with what you wear in its slot, and what you can do with it.
func _build_details() -> void:
	UiKit.clear(_details)
	if _selected == null:
		_details.add_child(UiKit.title("No item selected", 18, UiTheme.TEXT_DIM, false, 600))
		_details.add_child(UiKit.wrapped("Pick an item in your stash to compare it with what you wear.", 16, DIM_COLOR))
		return
	var item := _selected
	_details.add_child(UiKit.item_card(item, 64.0))
	_details.add_child(HSeparator.new())
	var worn: Item = Profile.equipped.get(item.slot)
	if worn == null:
		_details.add_child(UiKit.wrapped("Nothing worn in this slot: every bonus is a gain.", 15, UiTheme.GOOD))
	else:
		_details.add_child(UiKit.label("Compared with %s" % worn.title, 15, UiTheme.TEXT_MUTED))
		var gains := _totals(item)
		var current := _totals(worn)
		for stat: String in Stats.DEFS:
			if gains.has(stat) or current.has(stat):
				_details.add_child(_compare_line(stat, gains.get(stat, 0.0), current.get(stat, 0.0), gains.has(stat)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_details.add_child(buttons)
	var equip := UiKit.button("Equip", UiTheme.Kind.PRIMARY, 17)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.pressed.connect(Profile.equip.bind(item))
	equip.pressed.connect(func() -> void: Audio.play("equip"))
	buttons.add_child(equip)
	if item.free:
		_details.add_child(UiKit.label("Free kit: can't be sold", 14, DIM_COLOR))
		return
	var sell := UiKit.icon_button("Sell  %d" % item.sell_price(), "two-coins", UiTheme.Kind.SECONDARY, 16, UiTheme.GOLD_COIN)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.pressed.connect(_on_sell_pressed.bind(item))
	buttons.add_child(sell)


## One stat: its value on the selected item and the difference from the worn one (green when
## it goes up, red when it goes down).
func _compare_line(stat: String, value: float, worn_value: float, on_item: bool) -> HBoxContainer:
	var line := UiKit.stat_line(stat, value if on_item else worn_value, UiTheme.TEXT if on_item else UiTheme.TEXT_MUTED, 16)
	var delta := value - worn_value
	var text := "same"
	var color := UiTheme.TEXT_MUTED
	if not on_item:
		text = "lost"
		color = UiTheme.DANGER
	elif absf(delta) > 0.0001:
		text = "%s%s" % ["+" if delta > 0.0 else "−", Stats.amount(stat, delta)]
		color = UiTheme.GOOD if delta > 0.0 else UiTheme.DANGER
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(gap)
	line.add_child(UiKit.bold(text, 15, color))
	return line


func _on_sell_pressed(item: Item) -> void:
	if item.rarity < Item.Rarity.RARE:
		_sell(item)
		return
	UiKit.confirm(get_tree().root, "Sell %s?" % item.title,
			"You get %d gold. A sold item is gone for good." % item.sell_price(), "Sell", _sell.bind(item))


func _sell(item: Item) -> void:
	Profile.sell(item)
	Audio.play("gold")


## Each stat's total on an item.
static func _totals(item: Item) -> Dictionary:
	var totals := {}
	for affix in item.affixes:
		totals[affix["stat"]] = totals.get(affix["stat"], 0.0) + float(affix["value"])
	return totals


static func _by_rarity(a: Item, b: Item) -> bool:
	if a.rarity != b.rarity:
		return a.rarity > b.rarity
	return Item.SLOTS.find(a.slot) < Item.SLOTS.find(b.slot)


static func _by_slot(a: Item, b: Item) -> bool:
	if a.slot != b.slot:
		return Item.SLOTS.find(a.slot) < Item.SLOTS.find(b.slot)
	return a.rarity > b.rarity
