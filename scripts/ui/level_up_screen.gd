class_name LevelUpScreen
extends CanvasLayer
## Boon picker shown on level-up. Runs while the game is paused.
## Mouse only: keys 1-4 are ability keys, so there are no keyboard shortcuts and the cards never
## take focus; that way pressing an ability key can't pick a card by accident.

signal boon_chosen(boon_id: String)

const CARD_SIZE := Vector2(320, 420)
const ICON_SIZE := 104.0
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
	_title.text = "Level %d" % shown_level
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
	Audio.play("boon")
	# The pressed card may be freed by this signal, so the choice is emitted at the end of the frame.
	boon_chosen.emit.call_deferred(_choices[index])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.01, 0.78)
	UiKit.place(dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	UiTheme.use_on(center)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

	_title = UiKit.title("", 50, UiTheme.GOLD_BRIGHT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var subtitle := UiKit.title("Choose a boon", 22, UiTheme.TEXT_DIM, true, 600)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	column.add_child(gap)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 26)
	column.add_child(_cards)

	var hint := UiKit.label("Pick a card with the mouse", 16, UiTheme.TEXT_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _make_card(index: int, boon_id: String, player: Player) -> Button:
	var info := BoonLibrary.info(boon_id)
	var accent := BoonLibrary.accent(boon_id)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	var styles := UiTheme.button_styles(UiTheme.Kind.SECONDARY, accent)
	for state: String in styles:
		var style := styles[state] as StyleBox
		if style is IronFrame:
			(style as IronFrame).corner = 18.0
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(_choose.bind(index))
	card.mouse_entered.connect(Audio.play.bind("ui_hover"))

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	UiKit.place(column, Vector4(0, 0, 1, 1), Vector4(22, 22, -22, -22))
	card.add_child(column)

	var tag := UiKit.title(String(info["tag"]), 14, accent, false, 600)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	var frame := UiKit.icon_slot(BoonLibrary.icon(boon_id), ICON_SIZE, accent, true)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(frame)
	var title := UiKit.title(info["title"], 25, UiTheme.GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var current := player.rank(boon_id)
	var max_rank: int = info["max_rank"]
	if max_rank > 0:
		var pips := UiKit.pips(current, max_rank, accent, Vector2(22, 5), current)
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(pips)
	var rank_text := "Instant" if max_rank == 0 else ("New" if current == 0 else "Rank %d → %d" % [current, current + 1])
	var rank := UiKit.label(rank_text, 15, UiTheme.GOOD if current == 0 and max_rank > 0 else UiTheme.TEXT_MUTED)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rank)

	var description := UiKit.wrapped(BoonLibrary.describe(boon_id), 19, UiTheme.TEXT)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	if current > 0 and max_rank > 0:
		var total := UiKit.bold(_total_text(info, current), 16, accent.lightened(0.2))
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(total)
	return card


## "Total +10% → +20%": what the boon adds now and after this pick.
static func _total_text(info: Dictionary, rank: int) -> String:
	var text: String = info["text"]
	var sign := "−" if text.contains("−{v}") else "+"
	var unit := "%" if info["percent"] else ""
	var factor := 100.0 if info["percent"] else 1.0
	var value: float = info["value"]
	return "Total %s%s%s → %s%s%s" % [sign, UiKit.format_number(value * rank * factor), unit,
			sign, UiKit.format_number(value * (rank + 1) * factor), unit]
