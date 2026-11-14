class_name PauseScreen
extends CanvasLayer
## Pause screen opened with Esc: Resume, Settings, Controls and Withdraw from the run, which asks
## first and names what you'd lose. Main handles the pausing itself.

signal toggle_requested
## The player wants to withdraw from the run; it counts as a failure and the equipment is lost.
signal abandon_requested

const PANEL_WIDTH := 560.0

var _player: Player
var _run_info: Label
var _menu: VBoxContainer
var _settings_page: VBoxContainer
var _controls_page: VBoxContainer
var _controls: VBoxContainer
var _confirm: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	visibility_changed.connect(_on_visibility_changed)
	hide()


## Fills the control list with the player's ability names and keys.
func setup(player: Player) -> void:
	_player = player
	_add_line("WASD", "Move; your character faces the mouse")
	_add_line("AUTO", "Sword Swing: a quarter-circle slash at the nearest enemy")
	for i in player.abilities.size():
		var ability := player.abilities[i]
		_add_line(UiKit.key_name(Player.ABILITY_ACTIONS[i]), ability.display_name if ability else "Empty slot")
	_add_line("GATE", "Stand inside for 3 s without taking damage to escape")
	_add_line(UiKit.key_name("pause"), "Pause and resume")
	if OS.is_debug_build():
		_add_line("SHIFT+T", "Test: skip ahead 1 minute")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle_requested.emit()


## Every time it opens it starts on the menu, with the run's time, level and kills.
func _on_visibility_changed() -> void:
	if not visible:
		if is_instance_valid(_confirm):
			_confirm.queue_free()
		_confirm = null
		return
	_show_page(_menu)
	if _player:
		_run_info.text = "%s   ·   Level %d   ·   %d kills" % [UiKit.format_time(Game.run_time), _player.level, Game.kills]


func _show_page(page: Control) -> void:
	for each: Control in [_menu, _settings_page, _controls_page]:
		each.visible = each == page


func _ask_withdraw() -> void:
	var losses: Array[String] = []
	for item: Item in Profile.equipped.values():
		if not item.free:
			losses.append(item.title)
	var director := Game.director
	if director:
		if director.gold > 0:
			losses.append("%d gold" % director.gold)
		if not director.items.is_empty():
			losses.append(UiKit.count_text(director.items.size(), "found item", "found items"))
		if director.run_cores > 0:
			losses.append(UiKit.count_text(director.run_cores, "core", "cores"))
	var details := "It counts as a loss. You'd lose %s." % ", ".join(losses) if not losses.is_empty() \
			else "It counts as a loss, but you have nothing of value to lose yet."
	_confirm = UiKit.confirm(self, "Withdraw from the run?", details, "Withdraw", abandon_requested.emit)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.015, 0.78)
	UiKit.place(dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(dim)

	var center := CenterContainer.new()
	UiKit.place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	UiTheme.use_on(center)
	add_child(center)

	var panel := UiKit.plate(UiTheme.GOLD, 30.0)
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := UiKit.title("Paused", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_run_info = UiKit.label("", 17, UiTheme.TEXT_DIM)
	_run_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_run_info)
	column.add_child(HSeparator.new())

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	column.add_child(_menu)
	var resume := UiKit.big_button("Resume", "play-button", UiTheme.Kind.PRIMARY, 22)
	resume.custom_minimum_size.y = 58
	resume.pressed.connect(toggle_requested.emit)
	_menu.add_child(resume)
	var settings := UiKit.icon_button("Settings", "cog", UiTheme.Kind.SECONDARY, 18)
	settings.custom_minimum_size.y = 46
	settings.pressed.connect(func() -> void: _show_page(_settings_page))
	_menu.add_child(settings)
	var controls := UiKit.icon_button("Controls", "keyboard", UiTheme.Kind.SECONDARY, 18)
	controls.custom_minimum_size.y = 46
	controls.pressed.connect(func() -> void: _show_page(_controls_page))
	_menu.add_child(controls)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	_menu.add_child(gap)
	var withdraw := UiKit.icon_button("Withdraw from Run", "exit-door", UiTheme.Kind.DANGER, 17, UiTheme.DANGER)
	withdraw.custom_minimum_size.y = 44
	withdraw.pressed.connect(_ask_withdraw)
	_menu.add_child(withdraw)
	var note := UiKit.label("Withdrawing counts as a loss: your equipped gear is gone.", 14, UiTheme.TEXT_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(note)

	_settings_page = _page("Settings")
	_settings_page.add_child(SettingsPanel.new())
	_settings_page.move_child(_settings_page.get_child(_settings_page.get_child_count() - 1), 1)
	column.add_child(_settings_page)

	_controls_page = _page("Controls")
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	_controls_page.add_child(_controls)
	_controls_page.move_child(_controls, 1)
	column.add_child(_controls_page)


## A sub-page with a heading and a Back button at the bottom.
func _page(heading_text: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.add_child(UiKit.heading(heading_text, 18))
	var back := UiKit.button("Back", UiTheme.Kind.SECONDARY, 16)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 160
	back.pressed.connect(func() -> void: _show_page(_menu))
	page.add_child(back)
	return page


func _add_line(key: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var key_label := UiKit.title(key, 16, UiTheme.GOLD, false, 700)
	key_label.custom_minimum_size.x = 90
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(key_label)
	var text := UiKit.wrapped(description, 17, UiTheme.TEXT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_controls.add_child(row)
