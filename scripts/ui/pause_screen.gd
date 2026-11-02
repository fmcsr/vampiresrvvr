class_name PauseScreen
extends CanvasLayer
## Pause screen opened with Esc: the list of controls next to the settings. Main handles the
## pausing itself.

signal toggle_requested
## The player wants to withdraw from the run; it counts as a failure and the equipment is lost.
signal abandon_requested

const HEADING_COLOR := Color(1.0, 0.85, 0.55)

var _column: VBoxContainer
var _controls: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	hide()


## Fills the control list with the player's ability names and keys.
func setup(player: Player) -> void:
	_add_line("WASD", "Move — your character faces the mouse")
	_add_line("AUTO", "Sword Swing: a quarter-circle slash at the nearest enemy")
	for i in player.abilities.size():
		var ability := player.abilities[i]
		_add_line(UiKit.key_name(Player.ABILITY_ACTIONS[i]), ability.display_name if ability else "Empty slot")
	_add_line("GATE", "Stand inside for 3 s without taking damage to escape")
	_add_line(UiKit.key_name("pause"), "Resume")
	if OS.is_debug_build():
		_add_line("SHIFT+T", "Test: skip ahead 1 minute")
	var abandon := UiKit.button("Withdraw from Run — equipped gear is lost", Color(0.9, 0.35, 0.3), 18)
	abandon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	abandon.pressed.connect(abandon_requested.emit)
	_column.add_child(abandon)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle_requested.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	UiKit.place(dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(center)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 24)
	center.add_child(_column)

	var title := UiKit.label("PAUSED", 52, HEADING_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)

	# Controls on the left, settings on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	_column.add_child(columns)
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	columns.add_child(_controls)
	_controls.add_child(UiKit.label("CONTROLS", 22, HEADING_COLOR))
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 14)
	columns.add_child(settings)
	settings.add_child(UiKit.label("SETTINGS", 22, HEADING_COLOR))
	settings.add_child(SettingsPanel.new())


func _add_line(key: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var key_label := UiKit.label(key, 20, Color(1.0, 0.9, 0.6))
	key_label.custom_minimum_size.x = 110
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(key_label)
	row.add_child(UiKit.label(description, 20, Color(0.92, 0.9, 0.86)))
	_controls.add_child(row)
