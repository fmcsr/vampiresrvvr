class_name GameOverScreen
extends CanvasLayer
## End-of-run screen: escape or failure, a run summary, and what became of the loot and equipment.
## "Return to Camp" (Enter or the button) goes back to the camp.

signal continue_requested

## Short delay so keys still held down at death don't skip the screen right away.
const INPUT_LOCK_TIME := 0.6
## Items beyond this many are not listed one by one.
const MAX_LISTED_ITEMS := 8
const SUCCESS_COLOR := Color(0.45, 1.0, 0.7)
const FAIL_COLOR := Color(0.9, 0.2, 0.15)
const GOLD_COLOR := Color(1.0, 0.8, 0.3)
const XP_COLOR := Color(0.75, 0.65, 1.0)
const LOST_COLOR := Color(0.65, 0.5, 0.5)
const DIM_COLOR := Color(1.0, 1.0, 1.0, 0.5)

var _dim: ColorRect
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
	_title.text = summary.get("reason", "").to_upper()
	_title.add_theme_color_override("font_color", SUCCESS_COLOR if success else FAIL_COLOR)
	_dim.color = Color(0.0, 0.06, 0.05, 0.85) if success else Color(0.08, 0.0, 0.0, 0.8)
	_summary.text = "Time %s   ·   Level %d   ·   %d kills" % [UiKit.format_time(run_time), level, kills]
	UiKit.clear(_details)
	var gold: int = summary.get("gold", 0)
	var run_cores: int = summary.get("run_cores", 0)
	var secured_cores: int = summary.get("secured_cores", 0)
	var items: Array = summary.get("items", [])
	var lost_equipment: Array = summary.get("lost_equipment", [])
	var xp: int = summary.get("xp", 0)
	if success:
		_line("Gold: +%d added to your vault" % gold if gold > 0 else "Gold: none collected", GOLD_COLOR if gold > 0 else DIM_COLOR)
		var levels: int = summary.get("levels_gained", 0)
		var level_text := ("   ·   New character level: %d" % summary.get("char_level", 1)) if levels > 0 else ""
		_line("XP: +%d%s" % [xp, level_text], XP_COLOR)
		if run_cores + secured_cores > 0:
			_line("Cores: +%d" % (run_cores + secured_cores), SUCCESS_COLOR)
		if items.is_empty():
			_line("No items found", DIM_COLOR)
		else:
			_line("Items added to your stash:", Color.WHITE)
			_item_lines(items)
	else:
		_line("Gold: %d lost" % gold if gold > 0 else "Gold: none collected", LOST_COLOR)
		if xp > 0:
			_line("XP: %d lost" % xp, LOST_COLOR)
		if secured_cores > 0:
			_line("Cores: +%d secured" % secured_cores, SUCCESS_COLOR)
		if run_cores > 0:
			_line("Cores: %d lost" % run_cores, LOST_COLOR)
		if not items.is_empty():
			_line("%s lost" % UiKit.count_text(items.size(), "found item", "found items"), LOST_COLOR)
		# The free basic kit is not a real loss; it can be taken again in the camp.
		var valuable := lost_equipment.filter(func(item: Item) -> bool: return not item.free)
		if not valuable.is_empty():
			_line("Lost equipment:", FAIL_COLOR)
			_item_lines(valuable)
		elif not lost_equipment.is_empty():
			_line("Only free basic gear was lost; take a new set in the camp", DIM_COLOR)
		else:
			_line("You went in without gear; nothing was lost", DIM_COLOR)
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


func _line(text: String, color: Color) -> void:
	var label := UiKit.label(text, 22, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.add_child(label)


func _item_lines(items: Array) -> void:
	for i in mini(items.size(), MAX_LISTED_ITEMS):
		var item := items[i] as Item
		var label := UiKit.label("%s  (%s)" % [item.title, item.rarity_name()], 19, item.color())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_details.add_child(label)
	if items.size() > MAX_LISTED_ITEMS:
		_line("and %d more" % (items.size() - MAX_LISTED_ITEMS), DIM_COLOR)


func _build() -> void:
	_dim = ColorRect.new()
	UiKit.place(_dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(_dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	_title = UiKit.label("", 72)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_summary = UiKit.label("", 24, Color(0.92, 0.88, 0.85))
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	column.add_child(_details)

	column.add_child(Control.new())

	var button := UiKit.button("Return to Camp  [Enter]", Color(0.85, 0.7, 1.0), 22)
	button.custom_minimum_size = Vector2(320, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_request_continue)
	column.add_child(button)
