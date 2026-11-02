class_name Hud
extends CanvasLayer
## In-run HUD: XP, time, kills, gold, health, ability cooldowns, boss health,
## exit compass, gate countdown and announcements. Main calls setup() once the player is ready.

const SLOT_SIZE := Vector2(104, 84)
const GOLD_COLOR := Color(1.0, 0.8, 0.3)
const CORE_COLOR := Color(0.45, 1.0, 0.7)
const ALERT_COLOR := Color(1.0, 0.3, 0.25)
## Distance of the compass arrow from the character (pixels).
const COMPASS_DISTANCE := 90.0


class Slot:
	var ability: Ability
	var overlay: ProgressBar
	var time_label: Label

	func _init(p_ability: Ability, p_overlay: ProgressBar, p_time_label: Label) -> void:
		ability = p_ability
		overlay = p_overlay
		time_label = p_time_label


## Arrow that circles the character and points roughly toward the exit gate (8 directions).
class CompassArrow extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var points := PackedVector2Array([Vector2(18, 0), Vector2(-10, -12), Vector2(-4, 0), Vector2(-10, 12)])
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, Color(0.0, 0.0, 0.0, 0.8), 2.0, true)


var _player: Player
var _slots: Array[Slot] = []
var _xp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _gold_label: Label
var _core_label: Label
var _bag_label: Label
var _countdown_label: Label
var _boss_panel: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _channel_panel: VBoxContainer
var _channel_bar: ProgressBar
var _health_bar: ProgressBar
var _shield_bar: ProgressBar
var _health_label: Label
var _compass: CompassArrow
var _compass_label: Label
var _announcement: Label
var _announcement_tween: Tween


func setup(player: Player) -> void:
	_player = player
	_build()
	player.health_changed.connect(_on_health_changed)
	player.shield_changed.connect(func(_amount: float) -> void: _refresh_health())
	player.xp_changed.connect(_on_xp_changed)
	Game.announced.connect(_on_announced)
	Game.director.loot_changed.connect(_on_loot_changed)
	_on_health_changed(player.health, player.max_health)
	_on_xp_changed(player.xp, player.xp_required(), player.level)
	_on_loot_changed()


func _process(_delta: float) -> void:
	if _player == null:
		return
	_time_label.text = UiKit.format_time(Game.run_time)
	_kills_label.text = "Kills: %d" % Game.kills
	for slot in _slots:
		var ratio := slot.ability.cooldown_ratio()
		slot.overlay.value = ratio
		slot.time_label.text = _format_cooldown(slot.ability.cooldown_left) if ratio > 0.0 else ""
	var director := Game.director
	if director:
		_update_boss_bar(director)
		_update_escape(director)
		_update_compass(director)


func _update_boss_bar(director: RunDirector) -> void:
	var boss: Boss = director.bosses[0] if not director.bosses.is_empty() else null
	_boss_panel.visible = boss != null
	if boss:
		_boss_name.text = boss.boss_type.display_name
		_boss_bar.value = boss.health / boss.max_health


func _update_escape(director: RunDirector) -> void:
	_countdown_label.visible = director.countdown_left > 0.0
	if _countdown_label.visible:
		_countdown_label.text = "GATE CLOSING  %s" % UiKit.format_time(ceilf(director.countdown_left))
	var portal := director.portal
	var progress := portal.progress if portal and portal.is_open() else 0.0
	_channel_panel.visible = progress > 0.0
	_channel_bar.value = progress


## Shows the gate's rough direction (in 45-degree steps); the player has to find the exact spot.
func _update_compass(director: RunDirector) -> void:
	var portal := director.portal
	var camera := get_viewport().get_camera_3d()
	var to_portal := Vector3.ZERO
	if portal and portal.is_open() and camera:
		to_portal = portal.global_position - _player.global_position
		to_portal.y = 0.0
	var show_arrow := to_portal.length() > ExitPortal.RADIUS * 1.5
	_compass.visible = show_arrow
	_compass_label.visible = show_arrow
	if not show_arrow:
		return
	var right := camera.global_basis.x
	right.y = 0.0
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var screen_direction := Vector2(to_portal.dot(right.normalized()), -to_portal.dot(forward.normalized()))
	var angle := snappedf(screen_direction.angle(), PI / 4.0)
	var direction := Vector2.from_angle(angle)
	var center := camera.unproject_position(_player.global_position + Vector3.UP)
	_compass.position = center + direction * COMPASS_DISTANCE
	_compass.rotation = angle
	_compass.color = portal.color()
	_compass.queue_redraw()
	_compass_label.add_theme_color_override("font_color", portal.color())
	_compass_label.position = center + direction * (COMPASS_DISTANCE + 34.0) - _compass_label.size * 0.5


func _build() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(root, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(root)

	_xp_bar = UiKit.bar(Color(0.55, 0.4, 1.0), Color(0.05, 0.04, 0.08, 0.85))
	UiKit.place(_xp_bar, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 12))
	root.add_child(_xp_bar)

	_level_label = UiKit.label("Lv. 1", 22, Color(0.8, 0.7, 1.0))
	UiKit.place(_level_label, Vector4(0, 0, 0, 0), Vector4(16, 18, 220, 50))
	root.add_child(_level_label)

	_time_label = UiKit.label("00:00", 40)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place(_time_label, Vector4(0.5, 0, 0.5, 0), Vector4(-120, 16, 120, 70))
	root.add_child(_time_label)

	_countdown_label = UiKit.label("", 30, ALERT_COLOR)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.visible = false
	UiKit.place(_countdown_label, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 70, 300, 110))
	root.add_child(_countdown_label)

	_boss_panel = VBoxContainer.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_theme_constant_override("separation", 4)
	_boss_panel.visible = false
	UiKit.place(_boss_panel, Vector4(0.5, 0, 0.5, 0), Vector4(-260, 112, 260, 166))
	root.add_child(_boss_panel)
	_boss_name = UiKit.label("", 20, Color(1.0, 0.75, 0.6))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_panel.add_child(_boss_name)
	_boss_bar = UiKit.bar(Color(0.75, 0.12, 0.2), Color(0.06, 0.02, 0.03, 0.85))
	_boss_bar.custom_minimum_size.y = 14
	_boss_panel.add_child(_boss_bar)

	_kills_label = UiKit.label("Kills: 0", 22, Color(0.9, 0.85, 0.8))
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiKit.place(_kills_label, Vector4(1, 0, 1, 0), Vector4(-280, 18, -16, 50))
	root.add_child(_kills_label)

	_gold_label = UiKit.label("", 22, GOLD_COLOR)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiKit.place(_gold_label, Vector4(1, 0, 1, 0), Vector4(-280, 48, -16, 80))
	root.add_child(_gold_label)

	_core_label = UiKit.label("", 18, CORE_COLOR)
	_core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_core_label.visible = false
	UiKit.place(_core_label, Vector4(1, 0, 1, 0), Vector4(-320, 80, -16, 106))
	root.add_child(_core_label)

	_bag_label = UiKit.label("", 18, Color(0.85, 0.8, 1.0))
	_bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bag_label.visible = false
	UiKit.place(_bag_label, Vector4(1, 0, 1, 0), Vector4(-320, 106, -16, 132))
	root.add_child(_bag_label)

	_announcement = UiKit.label("", 46, Color(1.0, 0.85, 0.55))
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.modulate.a = 0.0
	UiKit.place(_announcement, Vector4(0.5, 0.25, 0.5, 0.25), Vector4(-500, -30, 500, 30))
	root.add_child(_announcement)

	_compass = CompassArrow.new()
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.visible = false
	root.add_child(_compass)
	_compass_label = UiKit.label("EXIT", 14)
	_compass_label.visible = false
	root.add_child(_compass_label)

	_channel_panel = VBoxContainer.new()
	_channel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_channel_panel.add_theme_constant_override("separation", 4)
	_channel_panel.visible = false
	UiKit.place(_channel_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-160, -200, 160, -150))
	root.add_child(_channel_panel)
	var channel_label := UiKit.label("EXTRACTING — don't get hit!", 16, CORE_COLOR)
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_panel.add_child(channel_label)
	_channel_bar = UiKit.bar(CORE_COLOR, Color(0.02, 0.06, 0.05, 0.85))
	_channel_bar.custom_minimum_size.y = 12
	_channel_panel.add_child(_channel_bar)

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 8)
	UiKit.place(bottom, Vector4(0.5, 1, 0.5, 1), Vector4(-240, -136, 240, -16))
	root.add_child(bottom)

	_health_bar = UiKit.bar(Color(0.8, 0.15, 0.15), Color(0.08, 0.02, 0.02, 0.85))
	_health_bar.custom_minimum_size.y = 22
	bottom.add_child(_health_bar)
	# Bone Shield: a light-colored layer over the health bar.
	_shield_bar = ProgressBar.new()
	_shield_bar.show_percentage = false
	_shield_bar.max_value = 1.0
	_shield_bar.step = 0.0
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_shield_bar.add_theme_stylebox_override("fill", UiKit.flat_style(Color(0.95, 0.92, 0.8, 0.55), Color.TRANSPARENT, 0, 4))
	UiKit.place(_shield_bar, Vector4(0, 0, 1, 1), Vector4.ZERO)
	_health_bar.add_child(_shield_bar)
	_health_label = UiKit.label("", 15)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.place(_health_label, Vector4(0, 0, 1, 1), Vector4.ZERO)
	_health_bar.add_child(_health_label)

	var slot_row := HBoxContainer.new()
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 12)
	bottom.add_child(slot_row)
	for i in _player.abilities.size():
		slot_row.add_child(_make_slot(_player.abilities[i], Player.ABILITY_ACTIONS[i]))

	var hint := UiKit.label("Esc: pause / controls", 14, Color(1, 1, 1, 0.5))
	UiKit.place(hint, Vector4(0, 1, 0, 1), Vector4(16, -34, 400, -12))
	root.add_child(hint)


## Ability slot; shows an "Empty" slot when ability is null.
func _make_slot(ability: Ability, action: String) -> Control:
	var accent := ability.color if ability else Color(0.35, 0.33, 0.4)
	var panel := Panel.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiKit.flat_style(Color(accent.darkened(0.65), 0.92), accent, 2, 8))

	var key_label := UiKit.label(UiKit.key_name(action), 14, Color(1.0, 0.9, 0.6))
	UiKit.place(key_label, Vector4(0, 0, 1, 0), Vector4(6, 2, -6, 22))
	panel.add_child(key_label)

	if ability == null:
		var empty := UiKit.label("Empty", 14, Color(1.0, 1.0, 1.0, 0.4))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiKit.place(empty, Vector4(0, 0, 1, 1), Vector4.ZERO)
		panel.add_child(empty)
		return panel

	var name_label := UiKit.label(ability.display_name, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(name_label, Vector4(0, 1, 1, 1), Vector4(2, -36, -2, -3))
	panel.add_child(name_label)

	var overlay := ProgressBar.new()
	overlay.show_percentage = false
	overlay.max_value = 1.0
	overlay.step = 0.0
	overlay.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	overlay.add_theme_stylebox_override("fill", UiKit.flat_style(Color(0.0, 0.0, 0.0, 0.7), Color.TRANSPARENT, 0, 8))
	UiKit.place(overlay, Vector4(0, 0, 1, 1), Vector4.ZERO)
	panel.add_child(overlay)

	var time_label := UiKit.label("", 24)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.place(time_label, Vector4(0, 0, 1, 1), Vector4.ZERO)
	panel.add_child(time_label)

	_slots.append(Slot.new(ability, overlay, time_label))
	return panel


func _on_health_changed(_current: float, _maximum: float) -> void:
	_refresh_health()


func _refresh_health() -> void:
	var maximum := maxf(_player.max_health, 1.0)
	_health_bar.value = _player.health / maximum
	_shield_bar.value = _player.shield / maximum
	_health_label.text = "%d / %d" % [ceili(_player.health), roundi(_player.max_health)]
	if _player.shield > 0.0:
		_health_label.text += "   +%d shield" % ceili(_player.shield)


func _on_xp_changed(current: int, required: int, level: int) -> void:
	_xp_bar.value = float(current) / required
	_level_label.text = "Lv. %d" % level


## Run loot: gold, cores (secured / at risk) and the number of items in the bag.
func _on_loot_changed() -> void:
	var director := Game.director
	_gold_label.text = "Gold: %d" % director.gold
	var core_parts: Array[String] = []
	if director.secured_cores > 0:
		core_parts.append("%d secured" % director.secured_cores)
	if director.run_cores > 0:
		core_parts.append("%d at risk" % director.run_cores)
	_core_label.visible = not core_parts.is_empty()
	_core_label.text = "Cores: %s" % " + ".join(core_parts)
	_bag_label.visible = not director.items.is_empty()
	_bag_label.text = "Bag: %s" % UiKit.count_text(director.items.size(), "item", "items")


func _on_announced(text: String) -> void:
	_announcement.text = text
	_announcement.modulate.a = 1.0
	if _announcement_tween:
		_announcement_tween.kill()
	_announcement_tween = create_tween()
	_announcement_tween.tween_interval(1.6)
	_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.6)


static func _format_cooldown(seconds: float) -> String:
	if seconds >= 10.0:
		return str(ceili(seconds))
	# Rounded up so an ability that isn't ready never shows "0.0".
	return "%.1f" % (ceilf(seconds * 10.0) / 10.0)
