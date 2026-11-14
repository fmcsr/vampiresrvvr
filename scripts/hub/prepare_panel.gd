class_name PreparePanel
extends HubPanel
## Camp home: everything you take into the next run on one screen. The Knight stands in the
## middle (drag to turn it), the three gear slots are on the left, the total bonuses on the
## right and the four powers on keys 1–4 below. Slots and powers open their tabs when clicked.

const GEAR_SLOT_SIZE := 64.0
const POWER_SLOT_SIZE := 76.0


## The Knight on a stone disc in its own little 3D world, lit by the campfire from the front.
class KnightPreview extends SubViewportContainer:
	const MODEL := preload("res://models/kaykit/adventurers/Knight.glb")
	const PROPS: Array[String] = ["1H_Sword", "Badge_Shield"]
	const TURN_PER_PIXEL := 0.01

	var _pivot: Node3D

	func _ready() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		tooltip_text = "Drag to turn"
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)

		var environment := Environment.new()
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.35, 0.33, 0.42)
		environment.ambient_light_energy = 0.6
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var world := WorldEnvironment.new()
		world.environment = environment
		viewport.add_child(world)

		var fire := OmniLight3D.new()
		fire.position = Vector3(-1.2, 1.2, 2.6)
		fire.light_color = Color(1.0, 0.62, 0.32)
		fire.light_energy = 2.4
		fire.omni_range = 9.0
		viewport.add_child(fire)
		var moon := DirectionalLight3D.new()
		moon.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
		moon.light_color = Color(0.5, 0.6, 0.95)
		moon.light_energy = 0.9
		viewport.add_child(moon)

		var disc := MeshInstance3D.new()
		var stone := CylinderMesh.new()
		stone.top_radius = 1.25
		stone.bottom_radius = 1.35
		stone.height = 0.16
		stone.radial_segments = 10
		var stone_material := StandardMaterial3D.new()
		stone_material.albedo_color = Color(0.2, 0.18, 0.17)
		stone_material.roughness = 0.95
		stone.material = stone_material
		disc.mesh = stone
		disc.position.y = -0.08
		viewport.add_child(disc)

		_pivot = Node3D.new()
		viewport.add_child(_pivot)
		var model := MODEL.instantiate() as Node3D
		ModelTools.keep_props(model, PROPS)
		_pivot.add_child(model)
		_pivot.rotation.y = deg_to_rad(-18.0)
		var player := model.get_node("AnimationPlayer") as AnimationPlayer
		player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")

		var camera := Camera3D.new()
		camera.fov = 30.0
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(0.0, 1.9, 6.4), Vector3(0.0, 1.05, 0.0))

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pivot.rotation.y += motion.relative.x * TURN_PER_PIXEL
			accept_event()


var _gear_box: VBoxContainer
var _bonus_box: VBoxContainer
var _power_row: HBoxContainer


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(heading("Gear you take in"))
	_gear_box = VBoxContainer.new()
	_gear_box.add_theme_constant_override("separation", 8)
	left.add_child(_gear_box)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	row.add_child(middle)
	var preview := KnightPreview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(300, 300)
	middle.add_child(preview)
	middle.add_child(heading("Powers"))
	_power_row = HBoxContainer.new()
	_power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_power_row.add_theme_constant_override("separation", 8)
	middle.add_child(_power_row)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 280
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	right.add_child(heading("Bonuses"))
	_bonus_box = VBoxContainer.new()
	_bonus_box.add_theme_constant_override("separation", 6)
	right.add_child(_bonus_box)


func refresh() -> void:
	UiKit.clear(_gear_box)
	for slot in Item.SLOTS:
		_gear_box.add_child(_gear_slot(slot))
	UiKit.clear(_power_row)
	for i in Profile.loadout.size():
		_power_row.add_child(_power_slot(i, Profile.loadout[i]))
	UiKit.clear(_bonus_box)
	var totals := Profile.bonuses()
	if totals.is_empty():
		_bonus_box.add_child(UiKit.wrapped("No bonuses yet. Gear and the Core Tree add them.", 16, DIM_COLOR))
	for stat in Stats.DEFS:
		if totals.has(stat):
			_bonus_box.add_child(UiKit.stat_line(stat, totals[stat], UiTheme.TEXT, 17))


## An equipped item (or the empty slot) as a button that opens the Gear tab.
func _gear_slot(slot: String) -> Button:
	var item: Item = Profile.equipped.get(slot)
	var button := UiKit.button("", UiTheme.Kind.QUIET)
	button.custom_minimum_size = Vector2(0, GEAR_SLOT_SIZE + 16.0)
	button.pressed.connect(func() -> void: navigate_requested.emit(1, slot))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	UiKit.place(row, Vector4(0, 0, 1, 1), Vector4(8, 0, -8, 0))
	button.add_child(row)
	var accent := item.color() if item else UiTheme.TEXT_MUTED
	var frame := UiKit.icon_slot(UiKit.icon_texture(Item.SLOT_ICONS[slot]), GEAR_SLOT_SIZE, accent,
			item != null and item.rarity >= Item.Rarity.RARE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if item == null:
		frame.modulate.a = 0.55
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	if item:
		text.add_child(UiKit.title(item.title, 17, item.color(), false, 700))
		var at_risk := "free kit" if item.free else "at risk"
		text.add_child(UiKit.label("%s %s  ·  %s" % [item.rarity_name(), item.slot_name().to_lower(), at_risk], 14,
				UiTheme.TEXT_MUTED if item.free else Color(1.0, 0.62, 0.48)))
	else:
		text.add_child(UiKit.title("Empty %s slot" % Item.SLOT_NAMES[slot].to_lower(), 16, UiTheme.TEXT_DIM, false, 600))
		text.add_child(UiKit.label("Take the free %s in Gear" % ItemGenerator.BASIC_TITLES[slot], 14, UiTheme.GOOD))
	return button


## A loadout slot: key, icon, name and rank; opens the power in the Skills tab.
func _power_slot(index: int, skill_id: String) -> Button:
	var button := UiKit.button("", UiTheme.Kind.QUIET)
	button.custom_minimum_size = Vector2(132, POWER_SLOT_SIZE + 64.0)
	button.pressed.connect(func() -> void: navigate_requested.emit(2, skill_id))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	UiKit.place(column, Vector4(0, 0, 1, 1), Vector4.ZERO)
	button.add_child(column)
	var learned := skill_id != ""
	var accent := SkillLibrary.color(skill_id) if learned else UiTheme.TEXT_MUTED
	var frame := UiKit.icon_slot(SkillLibrary.icon(skill_id) if learned else null, POWER_SLOT_SIZE, accent, learned)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(frame)
	# The frame lays out its children, so the key sits in a plain Control on top of the icon.
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(corner)
	var key := UiKit.title(UiKit.key_name(Player.ABILITY_ACTIONS[index]), 15, UiTheme.GOLD, true, 700)
	UiKit.place(key, Vector4(0, 0, 0, 0), Vector4(-1, -4, 24, 18))
	corner.add_child(key)
	var title := UiKit.title(SkillLibrary.title(skill_id) if learned else "Empty", 15, accent if learned else UiTheme.TEXT_MUTED, false, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if learned:
		var pips := UiKit.pips(Profile.skill_state(skill_id)["rank"], SkillLibrary.MAX_RANK, accent, Vector2(14, 4))
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(pips)
	return button
