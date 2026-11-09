extends Control
## Camp (base) screen between runs: prepare, gear, skills, shop, core tree and settings, picked
## from the menu on the left. Runs start from here.

enum Tab { PREPARE, GEAR, SKILLS, SHOP, CORE_TREE, SETTINGS }

const RUN_SCENE := "res://scenes/main.tscn"
## Tab name and icon, in Tab order.
const TABS := [["Prepare", "campfire"], ["Gear", "backpack"], ["Skills", "spell-book"], ["Shop", "shop"],
		["Core Tree", "crystal-growth"], ["Settings", "cog"]]
const NAV_WIDTH := 220.0
## Campfire glow behind everything, flickering a little.
const BACKGROUND_SHADER := "
shader_type canvas_item;
uniform vec3 glow : source_color = vec3(0.6, 0.27, 0.08);
void fragment() {
	vec2 p = UV - vec2(0.5, 0.7);
	p.x *= 1.78;
	float flicker = 0.92 + 0.08 * sin(TIME * 3.1) * sin(TIME * 1.7 + 1.3);
	float light = smoothstep(1.0, 0.0, length(p)) * 0.3 * flicker;
	float vignette = smoothstep(0.35, 1.1, length(UV - 0.5) * 1.4);
	COLOR = vec4((vec3(0.03, 0.026, 0.026) + glow * light) * (1.0 - 0.6 * vignette), 1.0);
}
"

var _gold_label: Label
var _core_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _record_label: Label
var _notice: Label
var _warning: Label
var _warning_icon: TextureRect
var _tab_buttons: Array[Button] = []
var _tab_labels: Array[Label] = []
var _tab_icons: Array[TextureRect] = []
var _tab_badges: Array[PanelContainer] = []
var _panels: Array[HubPanel] = []
var _current_tab := 0


func _ready() -> void:
	UiTheme.apply(get_tree())
	UiTheme.use_on(self)
	# Nothing from the run (slow motion, gate hum, heartbeat) carries over into the camp.
	Engine.time_scale = 1.0
	Audio.stop_loops()
	Audio.play_music("camp")
	_build()
	# Deferred so the UI isn't rebuilt from inside a button's own signal.
	Profile.changed.connect(_refresh, CONNECT_DEFERRED)
	show_tab(Tab.PREPARE)
	if not Profile.abandoned_summary.is_empty():
		var lost := _valuable(Profile.abandoned_summary.get("lost_equipment", []))
		_notice.text = "Your last run was abandoned: %s lost." % UiKit.count_text(lost.size(), "equipped item was", "equipped items were")
		if lost.is_empty():
			_notice.text = "Your last run was abandoned; only free basic gear was lost."
		_notice.show()
		Profile.abandoned_summary = {}


func show_tab(index: int) -> void:
	_current_tab = index
	for i in _panels.size():
		var selected := i == index
		_panels[i].visible = selected
		_tab_buttons[i].set_pressed_no_signal(selected)
		_tab_labels[i].add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT if selected else UiTheme.TEXT_DIM)
		_tab_icons[i].self_modulate = UiTheme.GOLD_BRIGHT if selected else UiTheme.GOLD_DIM
	_refresh()


func _refresh() -> void:
	_gold_label.text = str(Profile.gold)
	_core_label.text = str(Profile.cores)
	_level_label.text = "Level %d" % Profile.char_level
	_xp_bar.value = float(Profile.char_xp) / maxf(Profile.xp_to_next_level(), 1.0)
	_xp_label.text = "%d / %d XP" % [Profile.char_xp, Profile.xp_to_next_level()]
	_record_label.text = "Runs %d  ·  Escapes %d  ·  Losses %d" % [Profile.runs, Profile.extractions, Profile.failures]
	_set_badge(Tab.SKILLS, str(Profile.skill_points_free()) if Profile.skill_points_free() > 0 else "")
	_set_badge(Tab.CORE_TREE, str(_unlockable_nodes()) if _unlockable_nodes() > 0 else "")
	_set_badge(Tab.SHOP, "free" if _free_kit_waiting() else "")
	var at_risk := _valuable(Profile.equipped.values())
	_warning_icon.texture = UiKit.icon_texture("padlock" if at_risk.is_empty() else "skull-crossed-bones")
	if not at_risk.is_empty():
		var names: Array[String] = []
		for item: Item in at_risk:
			names.append(item.title)
		_warning.text = "Die or let the gate close and you lose %s." % ", ".join(names)
		_warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.52))
		_warning_icon.self_modulate = UiTheme.DANGER
	elif not Profile.equipped.is_empty():
		_warning.text = "Only free basic gear equipped: nothing of value is at risk."
		_warning.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_warning_icon.self_modulate = UiTheme.GOLD_DIM
	else:
		_warning.text = "You're going in without gear. Take the free basic kit in Gear or the Shop."
		_warning.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_warning_icon.self_modulate = UiTheme.GOLD_DIM
	_panels[_current_tab].refresh()


## Items that cost something; the free basic kit is not a real loss.
static func _valuable(items: Array) -> Array:
	return items.filter(func(item: Item) -> bool: return not item.free)


func _unlockable_nodes() -> int:
	var count := 0
	for node_id: String in CoreTree.NODES:
		if CoreTree.can_unlock(node_id, Profile.unlocked, Profile.cores):
			count += 1
	return count


## A slot is empty and its free basic item is still there to take.
func _free_kit_waiting() -> bool:
	for slot in Item.SLOTS:
		if not Profile.equipped.has(slot) and not Profile.has_free_basic(slot):
			return true
	return false


func _start_run() -> void:
	Audio.play("blade")
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_navigate(tab: int, focus: String) -> void:
	show_tab(tab)
	if focus != "":
		_panels[tab].focus_on(focus)


func _set_badge(tab: int, text: String) -> void:
	var badge := _tab_badges[tab]
	badge.visible = text != ""
	(badge.get_child(0) as Label).text = text


func _build() -> void:
	var background := ColorRect.new()
	var shader := Shader.new()
	shader.code = BACKGROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	background.material = material
	UiKit.place(background, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(background)
	add_child(_embers())

	var margin := MarginContainer.new()
	UiKit.place(margin, Vector4(0, 0, 1, 1), Vector4.ZERO)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_build_header())

	_notice = UiKit.label("", 17, UiTheme.DANGER)
	_notice.hide()
	column.add_child(_notice)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	body.add_child(_build_nav())

	var content := UiKit.plate(UiTheme.GOLD, 20.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	for panel: HubPanel in [PreparePanel.new(), EquipmentPanel.new(), SkillsPanel.new(), ShopPanel.new(),
			CoreTreePanel.new(), SettingsTab.new()]:
		content.add_child(panel)
		panel.navigate_requested.connect(_on_navigate)
		_panels.append(panel)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_warning_icon = UiKit.icon(UiKit.icon_texture("padlock"), 26.0, UiTheme.GOLD_DIM)
	_warning_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_warning_icon)
	_warning = UiKit.label("", 18)
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_warning)
	var start := UiKit.big_button("Start Run", "crossed-swords", UiTheme.Kind.PRIMARY, 26)
	start.custom_minimum_size = Vector2(340, 66)
	start.pressed.connect(_start_run)
	footer.add_child(start)


## Sparks drifting up from the campfire behind the menus.
func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.amount = 36
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.position = Vector2(800.0, 930.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700.0, 10.0)
	embers.direction = Vector2.UP
	embers.spread = 18.0
	embers.gravity = Vector2(0.0, -6.0)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 110.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.65, 0.3, 0.0))
	fade.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	fade.add_point(0.15, Color(1.0, 0.6, 0.25, 0.8))
	embers.color_ramp = fade
	return embers


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var fire := UiKit.icon(UiKit.icon_texture("campfire"), 40.0, UiTheme.GOLD)
	fire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(fire)
	header.add_child(UiKit.title("Camp", 42))
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 26
	header.add_child(spacer)

	var level := VBoxContainer.new()
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level.add_theme_constant_override("separation", 3)
	header.add_child(level)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	level.add_child(level_row)
	_level_label = UiKit.title("", 18, UiTheme.TEXT, false, 600)
	level_row.add_child(_level_label)
	_xp_label = UiKit.label("", 15, UiTheme.TEXT_MUTED)
	_xp_label.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(_xp_label)
	_xp_bar = UiKit.bar(UiTheme.XP.darkened(0.2))
	_xp_bar.custom_minimum_size = Vector2(260, 9)
	level.add_child(_xp_bar)

	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(filler)
	_gold_label = _currency(header, "two-coins", UiTheme.GOLD_COIN, "Gold: buys gear in the Shop and pays for refunds")
	_core_label = _currency(header, "crystal-cluster", UiTheme.CORE, "Cores: unlock nodes in the Core Tree")
	return header


## An icon and a large number; returns the number label.
func _currency(parent: HBoxContainer, icon_name: String, color: Color, tooltip: String) -> Label:
	var box := HBoxContainer.new()
	box.tooltip_text = tooltip
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var icon := UiKit.icon(UiKit.icon_texture(icon_name), 30.0, color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var label := UiKit.title("", 28, color)
	box.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 14
	box.add_child(gap)
	return label


## The menu: one button per tab with its icon, name and a badge for things waiting there.
func _build_nav() -> VBoxContainer:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = NAV_WIDTH
	nav.add_theme_constant_override("separation", 4)
	for i in TABS.size():
		var button := UiKit.button("", UiTheme.Kind.QUIET, 18)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(NAV_WIDTH, 50)
		button.pressed.connect(show_tab.bind(i))
		nav.add_child(button)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		UiKit.place(row, Vector4(0, 0, 1, 1), Vector4(16, 0, -12, 0))
		button.add_child(row)
		var icon := UiKit.icon(UiKit.icon_texture(TABS[i][1]), 26.0, UiTheme.GOLD_DIM)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var label := UiKit.title(TABS[i][0], 18, UiTheme.TEXT_DIM, false, 600)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var badge := UiKit.badge("", UiTheme.GOOD if i != Tab.SHOP else UiTheme.GOLD)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.hide()
		row.add_child(badge)
		_tab_buttons.append(button)
		_tab_labels.append(label)
		_tab_icons.append(icon)
		_tab_badges.append(badge)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(filler)
	_record_label = UiKit.label("", 15, UiTheme.TEXT_MUTED)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_record_label)
	return nav
