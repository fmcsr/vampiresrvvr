class_name Hud
extends CanvasLayer
## In-run HUD: XP, time, kills, gold, health, ability cooldowns, boss health,
## exit compass, gate countdown and announcements. Main calls setup() once the player is ready.

const SLOT_SIZE := 78.0
const ALERT_COLOR := Color(1.0, 0.32, 0.26)
## Distance of the compass arrow from the character (pixels).
const COMPASS_DISTANCE := 90.0
## Below this share of health the screen edges pulse red and a heartbeat plays.
const LOW_HEALTH := 0.3
## Length of the heartbeat loop (s); the red pulse follows it.
const HEARTBEAT_PERIOD := 0.95
const HURT_FADE_PER_SECOND := 2.5
const VIGNETTE_SHADER := "
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.7, 0.02, 0.02, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.45, 1.35, length(p * vec2(1.0, 0.8)));
	COLOR = vec4(tint.rgb, edge * strength);
}
"


class Slot:
	var ability: Ability
	var sweep: CooldownSweep
	var time_label: Label
	var icon: TextureRect

	func _init(p_ability: Ability, p_sweep: CooldownSweep, p_time_label: Label, p_icon: TextureRect) -> void:
		ability = p_ability
		sweep = p_sweep
		time_label = p_time_label
		icon = p_icon


## Dark slice over an ability icon for the part of the cooldown still left, shrinking clockwise.
class CooldownSweep extends Control:
	var ratio := 0.0

	func _draw() -> void:
		if ratio <= 0.0:
			return
		var center := size * 0.5
		var radius := size.length()
		var points := PackedVector2Array([center])
		var steps := maxi(3, ceili(48.0 * ratio))
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * (1.0 - ratio) + TAU * ratio * i / steps
			points.append(center + Vector2.from_angle(angle) * radius)
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.68))


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
var _core_row: HBoxContainer
var _core_label: Label
var _bag_row: HBoxContainer
var _bag_label: Label
var _countdown_label: Label
var _boss_panel: PanelContainer
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
## Red screen edges; strength is the larger of the hit flash and the low-health pulse.
var _vignette: ColorRect
var _hurt_flash := 0.0
var _pulse_time := 0.0


func setup(player: Player) -> void:
	_player = player
	_build()
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.shield_changed.connect(func(_amount: float) -> void: _refresh_health())
	player.xp_changed.connect(_on_xp_changed)
	Game.announced.connect(_on_announced)
	Game.director.loot_changed.connect(_on_loot_changed)
	_on_health_changed(player.health, player.max_health)
	_on_xp_changed(player.xp, player.xp_required(), player.level)
	_on_loot_changed()


func _process(delta: float) -> void:
	if _player == null:
		return
	_update_danger(delta)
	_time_label.text = UiKit.format_time(Game.run_time)
	_kills_label.text = str(Game.kills)
	for slot in _slots:
		var ratio := slot.ability.cooldown_ratio()
		if not is_equal_approx(slot.sweep.ratio, ratio):
			slot.sweep.ratio = ratio
			slot.sweep.queue_redraw()
		slot.time_label.text = _format_cooldown(slot.ability.cooldown_left) if ratio > 0.0 else ""
		slot.icon.self_modulate.a = 0.55 if ratio > 0.0 else 1.0
	var director := Game.director
	if director:
		_update_boss_bar(director)
		_update_escape(director)
		_update_compass(director)


## Red screen edges: a flash on every hit, and a pulse with a heartbeat while health is low.
func _update_danger(delta: float) -> void:
	_hurt_flash = maxf(_hurt_flash - delta * HURT_FADE_PER_SECOND, 0.0)
	var ratio := _player.health / maxf(_player.max_health, 1.0)
	var low := ratio < LOW_HEALTH and _player.health > 0.0
	var pulse := 0.0
	var severity := 0.0
	if low:
		_pulse_time += delta
		severity = 1.0 - ratio / LOW_HEALTH
		pulse = (0.25 + 0.35 * severity) * (0.5 + 0.5 * cos(TAU * _pulse_time / HEARTBEAT_PERIOD))
	else:
		_pulse_time = 0.0
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", maxf(_hurt_flash, pulse))
	Audio.set_loop("heartbeat", "heartbeat", low, 1.0, -6.0 + 6.0 * severity)


func _update_boss_bar(director: RunDirector) -> void:
	var boss: Boss = director.bosses[0] if not director.bosses.is_empty() else null
	_boss_panel.visible = boss != null
	if boss:
		_boss_name.text = boss.boss_type.display_name
		_boss_bar.value = boss.health / boss.max_health


func _update_escape(director: RunDirector) -> void:
	_countdown_label.visible = director.countdown_left > 0.0
	if _countdown_label.visible:
		_countdown_label.text = "Gate closing  %s" % UiKit.format_time(ceilf(director.countdown_left))
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
	UiTheme.use_on(root)
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = shader
	_vignette.material = vignette_material
	UiKit.place(_vignette, Vector4(0, 0, 1, 1), Vector4.ZERO)
	root.add_child(_vignette)

	_xp_bar = UiKit.bar(UiTheme.XP.darkened(0.15), Color(0.03, 0.02, 0.05, 0.85))
	UiKit.place(_xp_bar, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 10))
	root.add_child(_xp_bar)

	_level_label = UiKit.title("Lv 1", 24, UiTheme.GOLD_BRIGHT, true)
	UiKit.place(_level_label, Vector4(0, 0, 0, 0), Vector4(18, 18, 220, 52))
	root.add_child(_level_label)

	_time_label = UiKit.title("00:00", 40, UiTheme.TEXT, true)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place(_time_label, Vector4(0.5, 0, 0.5, 0), Vector4(-120, 14, 120, 70))
	root.add_child(_time_label)

	_countdown_label = UiKit.title("", 28, ALERT_COLOR, true)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.visible = false
	UiKit.place(_countdown_label, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 68, 300, 108))
	root.add_child(_countdown_label)

	_boss_panel = UiKit.plate(Color(0.8, 0.22, 0.18), 10.0, false)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	UiKit.place(_boss_panel, Vector4(0.5, 0, 0.5, 0), Vector4(-280, 108, 280, 178))
	root.add_child(_boss_panel)
	var boss_column := VBoxContainer.new()
	boss_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_column.add_theme_constant_override("separation", 6)
	_boss_panel.add_child(boss_column)
	var boss_title := HBoxContainer.new()
	boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_title.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_title.add_theme_constant_override("separation", 8)
	boss_column.add_child(boss_title)
	boss_title.add_child(UiKit.icon(UiKit.icon_texture("crowned-skull"), 22.0, Color(1.0, 0.72, 0.6)))
	_boss_name = UiKit.title("", 19, Color(1.0, 0.8, 0.68), true)
	boss_title.add_child(_boss_name)
	_boss_bar = UiKit.bar(Color(0.72, 0.1, 0.12), Color(0.06, 0.02, 0.02, 0.9))
	_boss_bar.custom_minimum_size.y = 14
	boss_column.add_child(_boss_bar)

	var counters := VBoxContainer.new()
	counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counters.add_theme_constant_override("separation", 2)
	UiKit.place(counters, Vector4(1, 0, 1, 0), Vector4(-320, 16, -18, 150))
	root.add_child(counters)
	_kills_label = _counter(counters, "skull-crossed-bones", UiTheme.TEXT, 22).get_child(1) as Label
	_gold_label = _counter(counters, "two-coins", UiTheme.GOLD_COIN, 22).get_child(1) as Label
	_core_row = _counter(counters, "crystal-cluster", UiTheme.CORE, 18)
	_core_label = _core_row.get_child(1) as Label
	_core_row.visible = false
	_bag_row = _counter(counters, "backpack", Color(0.85, 0.8, 1.0), 18)
	_bag_label = _bag_row.get_child(1) as Label
	_bag_row.visible = false

	_announcement = UiKit.title("", 46, UiTheme.GOLD_BRIGHT, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.modulate.a = 0.0
	UiKit.place(_announcement, Vector4(0.5, 0.25, 0.5, 0.25), Vector4(-500, -30, 500, 30))
	root.add_child(_announcement)

	_compass = CompassArrow.new()
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.visible = false
	root.add_child(_compass)
	_compass_label = UiKit.title("Exit", 15, Color.WHITE, true)
	_compass_label.visible = false
	root.add_child(_compass_label)

	_channel_panel = VBoxContainer.new()
	_channel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_channel_panel.add_theme_constant_override("separation", 4)
	_channel_panel.visible = false
	UiKit.place(_channel_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-170, -214, 170, -166))
	root.add_child(_channel_panel)
	var channel_label := UiKit.title("Extracting: don't get hit", 16, UiTheme.CORE, true)
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_panel.add_child(channel_label)
	_channel_bar = UiKit.bar(UiTheme.CORE.darkened(0.2), Color(0.02, 0.06, 0.05, 0.85))
	_channel_bar.custom_minimum_size.y = 12
	_channel_panel.add_child(_channel_bar)

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)
	UiKit.place(bottom, Vector4(0.5, 1, 0.5, 1), Vector4(-250, -140, 250, -16))
	root.add_child(bottom)

	_health_bar = UiKit.bar(Color(0.7, 0.1, 0.1), Color(0.07, 0.02, 0.02, 0.9))
	_health_bar.custom_minimum_size.y = 24
	bottom.add_child(_health_bar)
	# Bone Shield: a light-colored layer over the health bar.
	_shield_bar = ProgressBar.new()
	_shield_bar.show_percentage = false
	_shield_bar.max_value = 1.0
	_shield_bar.step = 0.0
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.95, 0.92, 0.8, 0.55)
	shield_fill.set_corner_radius_all(2)
	_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	UiKit.place(_shield_bar, Vector4(0, 0, 1, 1), Vector4.ZERO)
	_health_bar.add_child(_shield_bar)
	_health_label = UiKit.title("", 15, Color.WHITE, true, 600)
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

	var hint := UiKit.label("Esc: pause, settings, controls", 14, UiTheme.TEXT_MUTED, true)
	UiKit.place(hint, Vector4(0, 1, 0, 1), Vector4(16, -34, 400, -12))
	root.add_child(hint)


## An icon and a number for the top-right counters; returns the row (icon, label).
func _counter(parent: VBoxContainer, icon_name: String, color: Color, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(UiKit.icon(UiKit.icon_texture(icon_name), font_size + 4.0, color))
	row.add_child(UiKit.title("", font_size, color, true))
	return row


## Ability slot: the power's icon in a frame of its color, the key and a cooldown sweep; an
## empty frame when ability is null.
func _make_slot(ability: Ability, action: String) -> Control:
	var accent := ability.color if ability else Color(0.35, 0.33, 0.31)
	var frame := UiKit.icon_slot(SkillLibrary.icon(ability.skill_id) if ability else null, SLOT_SIZE, accent, ability != null)
	frame.tooltip_text = ability.display_name if ability else "Empty slot"
	# The frame lays out its children; the overlay is a plain Control so its parts can be placed.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	frame.add_child(overlay)
	var key_label := UiKit.title(UiKit.key_name(action), 15, UiTheme.GOLD_BRIGHT, true)
	UiKit.place(key_label, Vector4(0, 0, 0, 0), Vector4(2, 0, 28, 20))
	if ability == null:
		overlay.add_child(key_label)
		return frame

	var sweep := CooldownSweep.new()
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(sweep, Vector4(0, 0, 1, 1), Vector4.ZERO)
	overlay.add_child(sweep)
	var time_label := UiKit.title("", 22, Color.WHITE, true)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.place(time_label, Vector4(0, 0, 1, 1), Vector4.ZERO)
	overlay.add_child(time_label)
	overlay.add_child(key_label)
	_slots.append(Slot.new(ability, sweep, time_label, frame.get_child(0) as TextureRect))
	return frame


func _on_health_changed(_current: float, _maximum: float) -> void:
	_refresh_health()


func _on_player_damaged(amount: float) -> void:
	_hurt_flash = clampf(0.25 + 2.0 * amount / maxf(_player.max_health, 1.0), _hurt_flash, 0.6)


func _refresh_health() -> void:
	var maximum := maxf(_player.max_health, 1.0)
	_health_bar.value = _player.health / maximum
	_shield_bar.value = _player.shield / maximum
	_health_label.text = "%d / %d" % [ceili(_player.health), roundi(_player.max_health)]
	if _player.shield > 0.0:
		_health_label.text += "   +%d shield" % ceili(_player.shield)


func _on_xp_changed(current: int, required: int, level: int) -> void:
	_xp_bar.value = float(current) / required
	_level_label.text = "Lv %d" % level


## Run loot: gold, cores (secured / at risk) and the number of items in the bag.
func _on_loot_changed() -> void:
	var director := Game.director
	_gold_label.text = str(director.gold)
	var core_parts: Array[String] = []
	if director.secured_cores > 0:
		core_parts.append("%d secured" % director.secured_cores)
	if director.run_cores > 0:
		core_parts.append("%d at risk" % director.run_cores)
	_core_row.visible = not core_parts.is_empty()
	_core_label.text = " + ".join(core_parts)
	_bag_row.visible = not director.items.is_empty()
	_bag_label.text = UiKit.count_text(director.items.size(), "item", "items")


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
