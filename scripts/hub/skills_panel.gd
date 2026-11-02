class_name SkillsPanel
extends HubPanel
## Skills tab (Diablo-style): 10 abilities arranged in tiers, with rank / Enhanced / option
## upgrades, refunds paid in gold and a 4-slot loadout. Click an ability to manage it in the right panel.

const CARD_SIZE := Vector2(252, 82)
const PIP_SIZE := Vector2(16, 6)
const LOCKED_COLOR := Color(0.35, 0.33, 0.4)
const ERROR_COLOR := Color(1.0, 0.45, 0.35)

var _selected := "fire_wave"
var _message := ""
var _level_label: Label
var _points_label: Label
var _respec_button: Button
var _loadout_row: HBoxContainer
var _tiers_box: VBoxContainer
var _info_tier: Label
var _info_title: Label
var _info_text: Label
var _rank_label: Label
var _rank_add: Button
var _rank_refund: Button
var _enhanced_label: Label
var _enhanced_button: Button
var _choice_labels: Dictionary[String, Label] = {}
var _choice_buttons: Dictionary[String, Button] = {}
var _slot_buttons: Array[Button] = []
var _message_label: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	left.add_child(top)
	_level_label = UiKit.label("", 18, Color(0.75, 0.65, 1.0))
	top.add_child(_level_label)
	_points_label = UiKit.label("", 20, Color(0.45, 1.0, 0.7))
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_points_label)
	_respec_button = UiKit.button("", GOLD_COLOR, 14)
	_respec_button.pressed.connect(func() -> void: _act(Profile.respec_all()))
	top.add_child(_respec_button)

	_loadout_row = HBoxContainer.new()
	_loadout_row.add_theme_constant_override("separation", 10)
	left.add_child(_loadout_row)

	_tiers_box = VBoxContainer.new()
	_tiers_box.add_theme_constant_override("separation", 10)
	left.add_child(_tiers_box)

	row.add_child(_build_info())


func refresh() -> void:
	_level_label.text = "Level %d  (%d / %d XP)" % [Profile.char_level, Profile.char_xp, Profile.xp_to_next_level()]
	_points_label.text = "Skill points: %d free / %d" % [Profile.skill_points_free(), Profile.skill_points_total()]
	_respec_button.text = "Reset all — %d gold" % Profile.respec_cost()
	_respec_button.disabled = Profile.skill_points_spent() == 0
	_build_loadout_row()
	_build_tiers()
	_update_info()


## On failure, shows the reason; on success the profile changes and the panel refreshes by itself.
func _act(error: String) -> void:
	_message = error
	if error != "":
		refresh()


func _select(skill_id: String) -> void:
	_selected = skill_id
	_message = ""
	# The pressed card is freed by this refresh, so refresh at the end of the frame.
	refresh.call_deferred()


func _build_loadout_row() -> void:
	UiKit.clear(_loadout_row)
	_loadout_row.add_child(heading("LOADOUT"))
	for i in Profile.loadout.size():
		var skill_id := Profile.loadout[i]
		var accent := SkillLibrary.color(skill_id) if skill_id != "" else LOCKED_COLOR
		var chip := UiKit.button("%s  %s" % [UiKit.key_name(Player.ABILITY_ACTIONS[i]),
				SkillLibrary.title(skill_id) if skill_id != "" else "Empty"], accent, 15)
		chip.custom_minimum_size = Vector2(200, 38)
		if skill_id != "":
			chip.pressed.connect(_select.bind(skill_id))
		_loadout_row.add_child(chip)


func _build_tiers() -> void:
	UiKit.clear(_tiers_box)
	for tier_index in SkillLibrary.TIERS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_tiers_box.add_child(row)
		var is_open := Profile.tier_unlocked(tier_index)
		var label_box := VBoxContainer.new()
		label_box.custom_minimum_size.x = 150
		label_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label_box)
		label_box.add_child(UiKit.label(SkillLibrary.TIERS[tier_index]["title"].to_upper(), 18,
				HEADING_COLOR if is_open else LOCKED_COLOR.lightened(0.2)))
		var gate := SkillLibrary.gate(tier_index)
		var gate_text := "open" if is_open else "%d points required (%d/%d)" % [gate, Profile.points_below_tier(tier_index), gate]
		label_box.add_child(UiKit.label(gate_text, 13, DIM_COLOR))
		for skill_id in SkillLibrary.ids_in_tier(tier_index):
			row.add_child(_skill_card(skill_id, is_open))


func _skill_card(skill_id: String, tier_open: bool) -> Button:
	var state := Profile.skill_state(skill_id)
	var learned: bool = state["rank"] > 0
	var accent := SkillLibrary.color(skill_id)
	var border := Color.WHITE if skill_id == _selected else (accent if learned else accent.darkened(0.55))
	var background := Color(0.13, 0.11, 0.16, 0.96) if tier_open else Color(0.07, 0.065, 0.08, 0.9)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	for state_name in ["normal", "hover", "pressed"]:
		var bg := background.lightened(0.06) if state_name == "hover" else background
		card.add_theme_stylebox_override(state_name, UiKit.flat_style(bg, border, 3 if skill_id == _selected else 2, 8))
	card.pressed.connect(_select.bind(skill_id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	UiKit.place(margin, Vector4(0, 0, 1, 1), Vector4.ZERO)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var title_text := SkillLibrary.title(skill_id)
	if SkillLibrary.is_ultimate(skill_id):
		title_text += "  (ultimate)"
	column.add_child(UiKit.label(title_text, 17, accent if learned else DIM_COLOR))
	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 4)
	column.add_child(pips)
	for i in SkillLibrary.MAX_RANK:
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = accent if i < state["rank"] else Color(1.0, 1.0, 1.0, 0.12)
		pips.add_child(pip)
	column.add_child(UiKit.label(_status_text(skill_id, state), 13, Color(1.0, 1.0, 1.0, 0.6)))
	return card


func _status_text(skill_id: String, state: Dictionary) -> String:
	if state["rank"] <= 0:
		return "Not learned"
	var parts: Array[String] = []
	if state["enhanced"]:
		parts.append("Enhanced")
	if state["choice"] != "":
		parts.append(SkillLibrary.choice_title(skill_id, state["choice"]))
	var slot := Profile.loadout.find(skill_id)
	if slot != -1:
		parts.append("Slot %s" % UiKit.key_name(Player.ABILITY_ACTIONS[slot]))
	return " · ".join(parts) if not parts.is_empty() else "Learned"


func _build_info() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.add_theme_stylebox_override("panel", card_style(HEADING_COLOR))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_info_tier = UiKit.label("", 14, DIM_COLOR)
	column.add_child(_info_tier)
	_info_title = UiKit.label("", 28)
	column.add_child(_info_title)
	_info_text = _wrapped("", 16, Color(0.88, 0.86, 0.82))
	column.add_child(_info_text)
	column.add_child(HSeparator.new())

	_rank_label = _wrapped("", 16, Color.WHITE)
	column.add_child(_rank_label)
	var rank_buttons := HBoxContainer.new()
	rank_buttons.add_theme_constant_override("separation", 8)
	column.add_child(rank_buttons)
	_rank_add = UiKit.button("+1 rank  (1 point)", Color(0.45, 1.0, 0.7), 14)
	_rank_add.pressed.connect(func() -> void: _act(Profile.add_skill_rank(_selected)))
	rank_buttons.add_child(_rank_add)
	_rank_refund = UiKit.button("", GOLD_COLOR, 14)
	_rank_refund.pressed.connect(func() -> void: _act(Profile.refund_skill(_selected, "rank")))
	rank_buttons.add_child(_rank_refund)
	column.add_child(HSeparator.new())

	_enhanced_label = _wrapped("", 16, Color.WHITE)
	column.add_child(_enhanced_label)
	_enhanced_button = UiKit.button("", Color(0.45, 1.0, 0.7), 14)
	_enhanced_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_enhanced_button.pressed.connect(_on_enhanced_pressed)
	column.add_child(_enhanced_button)
	column.add_child(HSeparator.new())

	for choice in ["a", "b"]:
		var label := _wrapped("", 16, Color.WHITE)
		column.add_child(label)
		_choice_labels[choice] = label
		var button := UiKit.button("", Color(0.45, 1.0, 0.7), 14)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.pressed.connect(_on_choice_pressed.bind(choice))
		column.add_child(button)
		_choice_buttons[choice] = button
	column.add_child(HSeparator.new())

	column.add_child(UiKit.label("Put in loadout (slot):", 15, DIM_COLOR))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	column.add_child(slots)
	for i in Player.ABILITY_ACTIONS.size():
		var button := UiKit.button(UiKit.key_name(Player.ABILITY_ACTIONS[i]), HEADING_COLOR, 16)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(48, 36)
		button.pressed.connect(_on_slot_pressed.bind(i))
		slots.add_child(button)
		_slot_buttons.append(button)

	_message_label = _wrapped("", 15, ERROR_COLOR)
	column.add_child(_message_label)
	return panel


func _update_info() -> void:
	var info := SkillLibrary.info(_selected)
	var state := Profile.skill_state(_selected)
	var accent := SkillLibrary.color(_selected)
	var tier_title: String = SkillLibrary.TIERS[SkillLibrary.tier(_selected)]["title"]
	_info_tier.text = tier_title.to_upper() + ("  ·  ULTIMATE (only one in your loadout)" if SkillLibrary.is_ultimate(_selected) else "")
	_info_title.text = info["title"]
	_info_title.add_theme_color_override("font_color", accent)
	_info_text.text = info["text"]
	var cost := Profile.refund_cost()

	_rank_label.text = "Rank %d / %d — each rank adds %d%% power." % [state["rank"], SkillLibrary.MAX_RANK, roundi(SkillLibrary.RANK_POWER * 100.0)]
	_rank_add.disabled = state["rank"] >= SkillLibrary.MAX_RANK
	_rank_refund.text = "−1 rank  (%d gold)" % cost
	_rank_refund.disabled = state["rank"] <= 0

	_enhanced_label.text = "Enhanced: %s" % info["enhanced"]
	if state["enhanced"]:
		_enhanced_button.text = "Owned — refund (%d gold)" % cost
	else:
		_enhanced_button.text = "Take  (1 point)"
	_enhanced_button.disabled = state["rank"] <= 0

	for choice in ["a", "b"]:
		var label := _choice_labels[choice]
		var button := _choice_buttons[choice]
		label.text = "Option %s — %s: %s" % [choice.to_upper(), SkillLibrary.choice_title(_selected, choice),
				SkillLibrary.choice_text(_selected, choice)]
		button.disabled = not state["enhanced"]
		if not state["enhanced"]:
			button.text = "Take the Enhanced upgrade first"
		elif state["choice"] == choice:
			button.text = "Selected — refund (%d gold)" % cost
		elif state["choice"] == "":
			button.text = "Choose  (1 point)"
		else:
			button.text = "Switch to this  (%d gold)" % cost

	var slot := Profile.loadout.find(_selected)
	for i in _slot_buttons.size():
		_slot_buttons[i].set_pressed_no_signal(i == slot)
		_slot_buttons[i].disabled = state["rank"] <= 0
	_message_label.text = _message


func _on_enhanced_pressed() -> void:
	if Profile.skill_state(_selected)["enhanced"]:
		_act(Profile.refund_skill(_selected, "enhanced"))
	else:
		_act(Profile.enhance_skill(_selected))


func _on_choice_pressed(choice: String) -> void:
	if Profile.skill_state(_selected)["choice"] == choice:
		_act(Profile.refund_skill(_selected, "choice"))
	else:
		_act(Profile.choose_skill(_selected, choice))


## Pressing the same slot again removes the ability from the loadout.
func _on_slot_pressed(slot: int) -> void:
	if Profile.loadout[slot] == _selected:
		_act(Profile.set_loadout(slot, ""))
	else:
		_act(Profile.set_loadout(slot, _selected))


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
