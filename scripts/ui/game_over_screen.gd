class_name GameOverScreen
extends CanvasLayer
## End-of-run screen: escape or failure, a run summary, and what became of the loot and equipment.
## "Return to Camp" (Enter or the button) goes back to the camp.

signal continue_requested

## Short delay so keys still held down at death don't skip the screen right away.
const INPUT_LOCK_TIME := 0.6
## Items beyond this many are not listed one by one.
const MAX_LISTED_ITEMS := 8
const SUCCESS_COLOR := Color(0.62, 0.9, 0.55)
const FAIL_COLOR := Color(0.92, 0.26, 0.2)
const LOST_COLOR := Color(0.68, 0.52, 0.5)

var _dim: ColorRect
var _panel: PanelContainer
var _emblem: TextureRect
var _title: Label
var _summary: Label
var _details: VBoxContainer
var _lock_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	hide()


func _process(delta: float) -> void:
	_lock_time = maxf(_lock_time - delta, 0.0)


## summary: the summary returned by Profile.apply_run_result.
func open(summary: Dictionary, run_time: float, level: int, kills: int) -> void:
	var success: bool = summary.get("success", false)
	var color := SUCCESS_COLOR if success else FAIL_COLOR
	_title.text = summary.get("reason", "")
	_title.add_theme_color_override("font_color", color)
	_emblem.texture = UiKit.icon_texture("laurels" if success else "skull-crossed-bones")
	_emblem.self_modulate = color
	_panel.add_theme_stylebox_override("panel", UiTheme.plate(color, 30.0))
	_dim.color = Color(0.0, 0.05, 0.04, 0.82) if success else Color(0.09, 0.0, 0.0, 0.8)
	_summary.text = "Time %s   ·   Level %d   ·   %d kills" % [UiKit.format_time(run_time), level, kills]
	UiKit.clear(_details)
	var gold: int = summary.get("gold", 0)
	var run_cores: int = summary.get("run_cores", 0)
	var secured_cores: int = summary.get("secured_cores", 0)
	var items: Array = summary.get("items", [])
	var lost_equipment: Array = summary.get("lost_equipment", [])
	var xp: int = summary.get("xp", 0)
	if success:
		_line("two-coins", "Gold: +%d added to your vault" % gold if gold > 0 else "Gold: none collected",
				UiTheme.GOLD_COIN if gold > 0 else UiTheme.TEXT_MUTED)
		var levels: int = summary.get("levels_gained", 0)
		var level_text := ("   ·   New character level: %d" % summary.get("char_level", 1)) if levels > 0 else ""
		_line("upgrade", "XP: +%d%s" % [xp, level_text], UiTheme.XP)
		if run_cores + secured_cores > 0:
			_line("crystal-cluster", "Cores: +%d" % (run_cores + secured_cores), UiTheme.CORE)
		if items.is_empty():
			_line("backpack", "No items found", UiTheme.TEXT_MUTED)
		else:
			_line("backpack", "Items added to your stash:", UiTheme.TEXT)
			_item_lines(items)
	else:
		_line("two-coins", "Gold: %d lost" % gold if gold > 0 else "Gold: none collected", LOST_COLOR)
		if xp > 0:
			_line("upgrade", "XP: %d lost" % xp, LOST_COLOR)
		if secured_cores > 0:
			_line("crystal-cluster", "Cores: +%d secured" % secured_cores, UiTheme.CORE)
		if run_cores > 0:
			_line("crystal-cluster", "Cores: %d lost" % run_cores, LOST_COLOR)
		if not items.is_empty():
			_line("backpack", "%s lost" % UiKit.count_text(items.size(), "found item", "found items"), LOST_COLOR)
		# The free basic kit is not a real loss; it can be taken again in the camp.
		var valuable := lost_equipment.filter(func(item: Item) -> bool: return not item.free)
		if not valuable.is_empty():
			_line("skull-crossed-bones", "Lost equipment:", FAIL_COLOR)
			_item_lines(valuable)
		elif not lost_equipment.is_empty():
			_line("padlock", "Only free basic gear was lost; take a new set in the camp", UiTheme.TEXT_MUTED)
		else:
			_line("padlock", "You went in without gear; nothing was lost", UiTheme.TEXT_MUTED)
	_lock_time = INPUT_LOCK_TIME
	show()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_request_continue()


func _request_continue() -> void:
	if _lock_time <= 0.0:
		continue_requested.emit()


func _line(icon_name: String, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.icon(UiKit.icon_texture(icon_name), 22.0, color))
	row.add_child(UiKit.label(text, 21, color))
	_details.add_child(row)


func _item_lines(items: Array) -> void:
	for i in mini(items.size(), MAX_LISTED_ITEMS):
		var item := items[i] as Item
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.icon(item.icon(), 20.0, item.color()))
		row.add_child(UiKit.title(item.title, 17, item.color(), false, 700))
		row.add_child(UiKit.label(item.rarity_name(), 15, UiTheme.TEXT_MUTED))
		_details.add_child(row)
	if items.size() > MAX_LISTED_ITEMS:
		var more := UiKit.label("and %d more" % (items.size() - MAX_LISTED_ITEMS), 16, UiTheme.TEXT_MUTED)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_details.add_child(more)


func _build() -> void:
	_dim = ColorRect.new()
	UiKit.place(_dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(_dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	UiTheme.use_on(center)
	add_child(center)

	_panel = UiKit.plate(UiTheme.GOLD, 30.0)
	_panel.custom_minimum_size.x = 640
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	_emblem = UiKit.icon(null, 72.0)
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_emblem)
	_title = UiKit.title("", 58)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_summary = UiKit.label("", 21, UiTheme.TEXT_DIM)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary)
	column.add_child(HSeparator.new())

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	column.add_child(_details)

	column.add_child(HSeparator.new())
	var button := UiKit.big_button("Return to Camp", "campfire", UiTheme.Kind.PRIMARY, 22)
	button.custom_minimum_size = Vector2(360, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_request_continue)
	column.add_child(button)
	var hint := UiKit.label("or press Enter", 14, UiTheme.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
