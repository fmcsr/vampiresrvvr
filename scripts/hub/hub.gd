extends Control
## Camp (base) screen between runs: equipment, skills, shop and core tree. Runs start from here.

const RUN_SCENE := "res://scenes/main.tscn"
const TAB_NAMES: Array[String] = ["Equipment", "Skills", "Shop", "Core Tree", "Settings"]
const ACCENT := Color(0.85, 0.7, 1.0)
const GOLD_COLOR := Color(1.0, 0.8, 0.3)
const CORE_COLOR := Color(0.45, 1.0, 0.7)

var _gold_label: Label
var _core_label: Label
var _record_label: Label
var _notice: Label
var _warning: Label
var _tab_buttons: Array[Button] = []
var _panels: Array[HubPanel] = []
var _current_tab := 0


func _ready() -> void:
	# Nothing from the run (slow motion, gate hum, heartbeat) carries over into the camp.
	Engine.time_scale = 1.0
	Audio.stop_loops()
	Audio.play_music("camp")
	_build()
	# Deferred so the UI isn't rebuilt from inside a button's own signal.
	Profile.changed.connect(_refresh, CONNECT_DEFERRED)
	show_tab(0)
	if not Profile.abandoned_summary.is_empty():
		var lost: Array = Profile.abandoned_summary.get("lost_equipment", [])
		_notice.text = "Your last run was abandoned: %s lost." % UiKit.count_text(lost.size(), "equipped item was", "equipped items were")
		_notice.show()
		Profile.abandoned_summary = {}


func show_tab(index: int) -> void:
	_current_tab = index
	for i in _panels.size():
		_panels[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)
	_refresh()


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % Profile.gold
	_core_label.text = "Cores: %d" % Profile.cores
	_record_label.text = "Level %d  ·  Runs %d  ·  Escapes %d  ·  Losses %d" % [
			Profile.char_level, Profile.runs, Profile.extractions, Profile.failures]
	if Profile.skill_points_free() > 0:
		_record_label.text += "  ·  %s unspent" % UiKit.count_text(Profile.skill_points_free(), "skill point", "skill points")
	var at_risk := Profile.equipped.size()
	if at_risk > 0:
		_warning.text = "Your %s at risk: fail to escape and you lose %s." % [
				UiKit.count_text(at_risk, "equipped item is", "equipped items are"), "it" if at_risk == 1 else "them"]
	else:
		_warning.text = "You're going in without gear. Basic items are available in the Shop."
	_panels[_current_tab].refresh()


func _start_run() -> void:
	Audio.play("blade")
	get_tree().change_scene_to_file(RUN_SCENE)


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.045, 0.065)
	UiKit.place(background, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(background)

	var margin := MarginContainer.new()
	UiKit.place(margin, Vector4(0, 0, 1, 1), Vector4.ZERO)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 28)
	column.add_child(header)
	header.add_child(UiKit.label("CAMP", 44, ACCENT))
	_record_label = UiKit.label("", 16, Color(1.0, 1.0, 1.0, 0.5))
	_record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_record_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_record_label)
	_gold_label = UiKit.label("", 28, GOLD_COLOR)
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_gold_label)
	_core_label = UiKit.label("", 28, CORE_COLOR)
	_core_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_core_label)

	_notice = UiKit.label("", 18, Color(1.0, 0.45, 0.35))
	_notice.hide()
	column.add_child(_notice)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for i in TAB_NAMES.size():
		var button := UiKit.button(TAB_NAMES[i], ACCENT, 18)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(210, 44)
		button.pressed.connect(show_tab.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_style := UiKit.flat_style(Color(0.08, 0.07, 0.1, 0.95), Color(0.25, 0.22, 0.3), 1, 10)
	content_style.set_content_margin_all(18)
	content.add_theme_stylebox_override("panel", content_style)
	column.add_child(content)
	for panel: HubPanel in [EquipmentPanel.new(), SkillsPanel.new(), ShopPanel.new(), CoreTreePanel.new(), SettingsTab.new()]:
		content.add_child(panel)
		_panels.append(panel)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	column.add_child(footer)
	_warning = UiKit.label("", 17, Color(1.0, 0.75, 0.6))
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_warning)
	var start := UiKit.button("START RUN", GOLD_COLOR, 24)
	start.custom_minimum_size = Vector2(300, 64)
	start.pressed.connect(_start_run)
	footer.add_child(start)
