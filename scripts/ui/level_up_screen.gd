class_name LevelUpScreen
extends CanvasLayer
## Boon picker shown on level-up. Runs while the game is paused.
## Mouse only: keys 1-4 are ability keys, so there are no keyboard shortcuts and the cards never
## take focus; that way pressing an ability key can't pick a card by accident.

signal boon_chosen(boon_id: String)

const CARD_SIZE := Vector2(300, 360)
## Short delay so nothing gets picked by accident the moment the screen opens.
const INPUT_LOCK_TIME := 0.35

var _choices: Array[String] = []
var _lock_time := 0.0
var _title: Label
var _cards: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	hide()


func _process(delta: float) -> void:
	_lock_time = maxf(_lock_time - delta, 0.0)


func open(choices: Array[String], player: Player, shown_level: int) -> void:
	_choices = choices
	_title.text = "LEVEL %d — CHOOSE A BOON" % shown_level
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in choices.size():
		_cards.add_child(_make_card(i, choices[i], player))
	_lock_time = INPUT_LOCK_TIME
	show()


func close() -> void:
	hide()


func _choose(index: int) -> void:
	if _lock_time > 0.0 or index >= _choices.size():
		return
	_lock_time = INPUT_LOCK_TIME
	# The pressed card may be freed by this signal, so the choice is emitted at the end of the frame.
	boon_chosen.emit.call_deferred(_choices[index])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	UiKit.place(dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	_title = UiKit.label("", 40, Color(1.0, 0.85, 0.55))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 24)
	column.add_child(_cards)

	var hint := UiKit.label("Pick a card with the mouse", 16, Color(1, 1, 1, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _make_card(index: int, boon_id: String, player: Player) -> Button:
	var info := BoonLibrary.info(boon_id)
	var tag: String = info["tag"]
	var accent := BoonLibrary.accent(boon_id)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", UiKit.flat_style(Color(0.07, 0.06, 0.09, 0.96), accent.darkened(0.4), 2, 12))
	card.add_theme_stylebox_override("hover", UiKit.flat_style(Color(0.11, 0.09, 0.13, 0.98), accent, 4, 12))
	card.add_theme_stylebox_override("pressed", UiKit.flat_style(Color(0.14, 0.11, 0.16, 1.0), accent, 4, 12))
	card.pressed.connect(_choose.bind(index))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	UiKit.place(margin, Vector4(0, 0, 1, 1), Vector4.ZERO)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(UiKit.label(tag.to_upper(), 15, accent))

	var title := UiKit.label(info["title"], 28)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var current := player.rank(boon_id)
	var max_rank: int = info["max_rank"]
	var rank_text := "Rank %d → %d" % [current, current + 1]
	if max_rank == 0:
		rank_text = "Instant"
	elif current == 0:
		rank_text = "NEW"
	column.add_child(UiKit.label(rank_text, 16, Color(1, 1, 1, 0.6)))

	var description := UiKit.label(BoonLibrary.describe(boon_id), 19, Color(0.92, 0.9, 0.86))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	return card
