class_name SkillsPanel
extends HubPanel
## Skills tab (Diablo-style): 10 abilities arranged in tiers, with rank / Enhanced / option
## upgrades, refunds paid in gold and a 4-slot loadout. Click an ability to manage it in the right
## panel, where badges say what you own and buttons say what you can do.

const CARD_SIZE := Vector2(232, 80)
const TIER_LABEL_WIDTH := 124.0
const LOCKED_COLOR := Color(0.36, 0.34, 0.32)

var _selected := "fire_wave"
var _message := ""
var _level_label: Label
var _points_badge: PanelContainer
var _respec_button: Button
var _loadout_row: HBoxContainer
var _tiers_box: VBoxContainer
var _info_icon: PanelContainer
var _info_tier: Label
var _info_title: Label
var _info_text: Label
var _rank_pips: HBoxContainer
var _rank_label: Label
var _rank_add: Button
var _rank_refund: Button
var _enhanced_badge: PanelContainer
var _enhanced_label: Label
var _enhanced_button: Button
var _choice_titles: Dictionary[String, Label] = {}
var _choice_texts: Dictionary[String, Label] = {}
var _choice_badges: Dictionary[String, PanelContainer] = {}
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
	top.add_theme_constant_override("separation", 12)
	left.add_child(top)
	top.add_child(UiKit.title("Skill points", 20, UiTheme.GOLD, false, 600))
	_points_badge = UiKit.badge("", UiTheme.GOOD)
	_points_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_points_badge)
	_level_label = UiKit.label("", 16, DIM_COLOR)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_level_label)
	_respec_button = UiKit.icon_button("", "two-coins", UiTheme.Kind.SECONDARY, 14, UiTheme.GOLD_COIN)
	_respec_button.tooltip_text = "Refunds every skill point"
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
	_level_label.text = "Level %d  ·  %d / %d XP  ·  a point every level" % [Profile.char_level, Profile.char_xp, Profile.xp_to_next_level()]
	(_points_badge.get_child(0) as Label).text = "%d free / %d" % [Profile.skill_points_free(), Profile.skill_points_total()]
	_respec_button.text = "Reset all  %d" % Profile.respec_cost()
	_respec_button.disabled = Profile.skill_points_spent() == 0
	_build_loadout_row()
	_build_tiers()
	_update_info()


## From the Prepare tab: show this power.
func focus_on(focus: String) -> void:
	if SkillLibrary.SKILLS.has(focus):
		_select(focus)


## On failure, shows the reason; on success the profile changes and the panel refreshes by itself.
func _act(error: String) -> void:
	Audio.play("ui_confirm" if error == "" else "ui_error")
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
	var label := UiKit.title("Loadout", 17, UiTheme.GOLD, false, 600)
	label.custom_minimum_size.x = TIER_LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_loadout_row.add_child(label)
	for i in Profile.loadout.size():
		var skill_id := Profile.loadout[i]
		var chip := UiKit.button("", UiTheme.Kind.QUIET)
		chip.custom_minimum_size = Vector2(62, 62)
		chip.tooltip_text = SkillLibrary.title(skill_id) if skill_id != "" else "Empty slot"
		if skill_id != "":
			chip.pressed.connect(_select.bind(skill_id))
		_loadout_row.add_child(chip)
		var accent := SkillLibrary.color(skill_id) if skill_id != "" else LOCKED_COLOR
		var frame := UiKit.icon_slot(SkillLibrary.icon(skill_id) if skill_id != "" else null, 54.0, accent, skill_id == _selected)
		UiKit.place(frame, Vector4(0, 0, 1, 1), Vector4(4, 4, -4, -4))
		chip.add_child(frame)
		var key := UiKit.title(UiKit.key_name(Player.ABILITY_ACTIONS[i]), 14, UiTheme.GOLD_BRIGHT, true)
		UiKit.place(key, Vector4(0, 0, 0, 0), Vector4(8, 4, 30, 22))
		chip.add_child(key)
	var hint := UiKit.label("Click a power, then pick its key on the right.", 15, DIM_COLOR)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_loadout_row.add_child(hint)


func _build_tiers() -> void:
	UiKit.clear(_tiers_box)
	for tier_index in SkillLibrary.TIERS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_tiers_box.add_child(row)
		var is_open := Profile.tier_unlocked(tier_index)
		var label_box := VBoxContainer.new()
		label_box.custom_minimum_size.x = TIER_LABEL_WIDTH
		label_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label_box)
		label_box.add_child(UiKit.title(SkillLibrary.TIERS[tier_index]["title"], 18,
				UiTheme.GOLD if is_open else LOCKED_COLOR.lightened(0.2), false, 700))
		var gate := SkillLibrary.gate(tier_index)
		var gate_text := "open" if is_open else "%d points spent first (%d/%d)" % [gate, Profile.points_below_tier(tier_index), gate]
		label_box.add_child(UiKit.wrapped(gate_text, 13, DIM_COLOR))
		for skill_id in SkillLibrary.ids_in_tier(tier_index):
			row.add_child(_skill_card(skill_id, is_open))


func _skill_card(skill_id: String, tier_open: bool) -> Button:
	var state := Profile.skill_state(skill_id)
	var learned: bool = state["rank"] > 0
	var accent := SkillLibrary.color(skill_id)
	var selected := skill_id == _selected
	var card := UiKit.button("", UiTheme.Kind.SECONDARY, 16, accent if learned else LOCKED_COLOR)
	card.custom_minimum_size = CARD_SIZE
	card.toggle_mode = true
	card.set_pressed_no_signal(selected)
	card.pressed.connect(_select.bind(skill_id))
	card.modulate.a = 1.0 if tier_open or learned else 0.6

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	UiKit.place(row, Vector4(0, 0, 1, 1), Vector4(9, 8, -8, -8))
	card.add_child(row)
	var frame := UiKit.icon_slot(SkillLibrary.icon(skill_id), 56.0, accent if learned else LOCKED_COLOR.lightened(0.15), learned and selected)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var title_text := SkillLibrary.title(skill_id)
	column.add_child(UiKit.title(title_text, 14, accent if learned else UiTheme.TEXT_DIM, false, 700))
	column.add_child(UiKit.pips(state["rank"], SkillLibrary.MAX_RANK, accent, Vector2(16, 4)))
	column.add_child(UiKit.label(_status_text(skill_id, state), 12, UiTheme.TEXT_MUTED))
	return card


func _status_text(skill_id: String, state: Dictionary) -> String:
	if state["rank"] <= 0:
		return "Ultimate · not learned" if SkillLibrary.is_ultimate(skill_id) else "Not learned"
	var parts: Array[String] = []
	if state["enhanced"]:
		parts.append("Enhanced")
	if state["choice"] != "":
		parts.append(SkillLibrary.choice_title(skill_id, state["choice"]))
	var slot := Profile.loadout.find(skill_id)
	if slot != -1:
		parts.append("Key %s" % UiKit.key_name(Player.ABILITY_ACTIONS[slot]))
	return " · ".join(parts) if not parts.is_empty() else "Learned"


func _build_info() -> Control:
	var panel := UiKit.plate(UiTheme.GOLD, 16.0)
	panel.custom_minimum_size.x = 400
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_info_icon = PanelContainer.new()
	_info_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header.add_child(_info_icon)
	var names := VBoxContainer.new()
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 0)
	header.add_child(names)
	_info_tier = UiKit.label("", 14, DIM_COLOR)
	names.add_child(_info_tier)
	_info_title = UiKit.title("", 26)
	names.add_child(_info_title)
	_info_text = UiKit.wrapped("", 16, UiTheme.TEXT)
	column.add_child(_info_text)

	column.add_child(HSeparator.new())
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 10)
	column.add_child(rank_row)
	rank_row.add_child(UiKit.title("Rank", 16, UiTheme.GOLD, false, 600))
	_rank_pips = HBoxContainer.new()
	_rank_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(_rank_pips)
	_rank_label = UiKit.label("", 15, DIM_COLOR)
	rank_row.add_child(_rank_label)
	var rank_buttons := HBoxContainer.new()
	rank_buttons.add_theme_constant_override("separation", 8)
	column.add_child(rank_buttons)
	_rank_add = UiKit.button("Learn rank  ·  1 point", UiTheme.Kind.PRIMARY, 15)
	_rank_add.pressed.connect(func() -> void: _act(Profile.add_skill_rank(_selected)))
	rank_buttons.add_child(_rank_add)
	_rank_refund = UiKit.icon_button("", "two-coins", UiTheme.Kind.QUIET, 14, UiTheme.GOLD_COIN)
	_rank_refund.tooltip_text = "Take back one rank; the point returns"
	_rank_refund.pressed.connect(func() -> void: _act(Profile.refund_skill(_selected, "rank")))
	rank_buttons.add_child(_rank_refund)

	column.add_child(HSeparator.new())
	var enhanced_row := HBoxContainer.new()
	enhanced_row.add_theme_constant_override("separation", 10)
	column.add_child(enhanced_row)
	enhanced_row.add_child(UiKit.title("Enhanced", 16, UiTheme.GOLD, false, 600))
	_enhanced_badge = UiKit.badge("", UiTheme.GOOD)
	_enhanced_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enhanced_row.add_child(_enhanced_badge)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enhanced_row.add_child(gap)
	_enhanced_button = UiKit.button("", UiTheme.Kind.SECONDARY, 14)
	_enhanced_button.pressed.connect(_on_enhanced_pressed)
	enhanced_row.add_child(_enhanced_button)
	_enhanced_label = UiKit.wrapped("", 15, UiTheme.TEXT)
	column.add_child(_enhanced_label)

	column.add_child(HSeparator.new())
	for choice in ["a", "b"]:
		var option := HBoxContainer.new()
		option.add_theme_constant_override("separation", 10)
		column.add_child(option)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		option.add_child(texts)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		texts.add_child(title_row)
		var title := UiKit.title("", 15, UiTheme.TEXT, false, 700)
		title_row.add_child(title)
		_choice_titles[choice] = title
		var badge := UiKit.badge("Chosen", UiTheme.GOOD)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(badge)
		_choice_badges[choice] = badge
		var text := UiKit.wrapped("", 14, DIM_COLOR)
		texts.add_child(text)
		_choice_texts[choice] = text
		var button := UiKit.button("", UiTheme.Kind.SECONDARY, 13)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_choice_pressed.bind(choice))
		option.add_child(button)
		_choice_buttons[choice] = button

	column.add_child(HSeparator.new())
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	column.add_child(slots)
	var slot_label := UiKit.title("Key", 16, UiTheme.GOLD, false, 600)
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(slot_label)
	for i in Player.ABILITY_ACTIONS.size():
		var button := UiKit.button(UiKit.key_name(Player.ABILITY_ACTIONS[i]), UiTheme.Kind.SECONDARY, 16)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(52, 38)
		button.tooltip_text = "Put this power on this key (press again to take it off)"
		button.pressed.connect(_on_slot_pressed.bind(i))
		slots.add_child(button)
		_slot_buttons.append(button)

	_message_label = UiKit.wrapped("", 15, UiTheme.DANGER)
	column.add_child(_message_label)
	return panel


func _update_info() -> void:
	var info := SkillLibrary.info(_selected)
	var state := Profile.skill_state(_selected)
	var accent := SkillLibrary.color(_selected)
	var learned: bool = state["rank"] > 0
	var cost := Profile.refund_cost()
	UiKit.clear(_info_icon)
	_info_icon.add_child(UiKit.icon_slot(SkillLibrary.icon(_selected), 76.0, accent, learned))
	var tier_title: String = SkillLibrary.TIERS[SkillLibrary.tier(_selected)]["title"]
	_info_tier.text = tier_title + ("  ·  ultimate: one per loadout" if SkillLibrary.is_ultimate(_selected) else "")
	_info_title.text = info["title"]
	_info_title.add_theme_color_override("font_color", accent)
	_info_text.text = info["text"]

	UiKit.clear(_rank_pips)
	_rank_pips.add_child(UiKit.pips(state["rank"], SkillLibrary.MAX_RANK, accent, Vector2(18, 5)))
	_rank_label.text = "%d / %d  ·  +%d%% power each" % [state["rank"], SkillLibrary.MAX_RANK, roundi(SkillLibrary.RANK_POWER * 100.0)]
	_rank_add.text = "Learn  ·  1 point" if not learned else "Rank up  ·  1 point"
	_rank_add.disabled = state["rank"] >= SkillLibrary.MAX_RANK or Profile.skill_points_free() <= 0
	_rank_add.tooltip_text = "Max rank" if state["rank"] >= SkillLibrary.MAX_RANK else ("No free skill points" if Profile.skill_points_free() <= 0 else "")
	_rank_refund.text = "Refund  %d" % cost
	_rank_refund.visible = learned

	_enhanced_label.text = info["enhanced"]
	(_enhanced_badge.get_child(0) as Label).text = "Owned"
	_enhanced_badge.visible = state["enhanced"]
	if state["enhanced"]:
		_enhanced_button.text = "Refund  %d gold" % cost
	else:
		_enhanced_button.text = "Take  ·  1 point"
	_enhanced_button.disabled = not learned
	_enhanced_button.tooltip_text = "" if learned else "Learn the power first"

	for choice in ["a", "b"]:
		var chosen: bool = state["choice"] == choice
		_choice_titles[choice].text = "Option %s  ·  %s" % [choice.to_upper(), SkillLibrary.choice_title(_selected, choice)]
		_choice_titles[choice].add_theme_color_override("font_color", accent if chosen else UiTheme.TEXT)
		_choice_texts[choice].text = SkillLibrary.choice_text(_selected, choice)
		_choice_badges[choice].visible = chosen
		var button := _choice_buttons[choice]
		button.disabled = not state["enhanced"]
		if not state["enhanced"]:
			button.text = "Needs Enhanced"
		elif chosen:
			button.text = "Refund  %d" % cost
		elif state["choice"] == "":
			button.text = "Choose  ·  1 point"
		else:
			button.text = "Switch  %d gold" % cost

	var slot := Profile.loadout.find(_selected)
	for i in _slot_buttons.size():
		_slot_buttons[i].set_pressed_no_signal(i == slot)
		_slot_buttons[i].disabled = not learned
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
