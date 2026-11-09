class_name CoreTreePanel
extends HubPanel
## Core tree tab: click a node, then unlock it from the panel on the right. A node can be unlocked
## once one of the nodes it connects to is unlocked and there are enough cores. Each node shows
## its stat's icon and its cost; its name and effect are in the tooltip and the side panel.

## Pixels per radius unit of the tree.
const UNIT := 68.0
const NODE_SIZE := 58.0
const KEYSTONE_SIZE := 74.0
const BRANCH_LABEL_WIDTH := 170.0
const LOCKED_COLOR := Color(0.3, 0.29, 0.28)
## Keystone node at the tip of each branch; the branch name is placed next to it.
const BRANCH_ANCHORS := {"Might": "a6", "Resilience": "b6", "Fortune": "c6"}
const BRANCH_ICONS := {"": "crystal-cluster", "Might": "fist", "Resilience": "visored-helm", "Fortune": "clover"}


## Draws the lines between nodes; the node buttons are its children.
class TreeCanvas extends Control:
	const LINE_LOCKED_COLOR := Color(0.24, 0.23, 0.22)

	## Node centers (local coordinates).
	var centers: Dictionary = {}

	func _draw() -> void:
		for node_id: String in CoreTree.NODES:
			if not centers.has(node_id):
				return
			var node: Dictionary = CoreTree.NODES[node_id]
			for required: String in node["requires"]:
				var both_open := (CoreTree.is_unlocked(node_id, Profile.unlocked)
						and CoreTree.is_unlocked(required, Profile.unlocked))
				var color: Color = CoreTree.BRANCH_COLORS[node["branch"]] if both_open else LINE_LOCKED_COLOR
				if both_open:
					draw_line(centers[required], centers[node_id], Color(color, 0.25), 11.0, true)
				draw_line(centers[required], centers[node_id], color, 4.0 if both_open else 3.0, true)


var _canvas: TreeCanvas
var _buttons: Dictionary[String, Button] = {}
var _icons: Dictionary[String, TextureRect] = {}
var _costs: Dictionary[String, Label] = {}
var _branch_labels: Dictionary[String, HBoxContainer] = {}
var _selected := "a1"
var _info_icon: PanelContainer
var _info_title: Label
var _info_branch: Label
var _info_effect: Label
var _info_cost: Label
var _unlock_button: Button


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	_canvas = TreeCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.resized.connect(_layout)
	row.add_child(_canvas)
	for node_id: String in CoreTree.NODES:
		_add_node_button(node_id)
	for branch: String in BRANCH_ANCHORS:
		var label := HBoxContainer.new()
		label.add_theme_constant_override("separation", 8)
		label.custom_minimum_size.x = BRANCH_LABEL_WIDTH
		label.add_child(UiKit.icon(UiKit.icon_texture(BRANCH_ICONS[branch]), 24.0, CoreTree.BRANCH_COLORS[branch]))
		label.add_child(UiKit.title(branch, 20, CoreTree.BRANCH_COLORS[branch], false, 700))
		_canvas.add_child(label)
		_branch_labels[branch] = label

	var info := UiKit.plate(UiTheme.GOLD, 18.0)
	info.custom_minimum_size.x = 340
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	info.add_child(column)
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
	_info_branch = UiKit.label("", 15, DIM_COLOR)
	names.add_child(_info_branch)
	_info_title = UiKit.title("", 24)
	names.add_child(_info_title)
	_info_effect = UiKit.wrapped("", 20, UiTheme.TEXT)
	column.add_child(_info_effect)
	_info_cost = UiKit.label("", 17, UiTheme.CORE)
	column.add_child(_info_cost)
	_unlock_button = UiKit.icon_button("Unlock", "crystal-cluster", UiTheme.Kind.PRIMARY, 18)
	_unlock_button.pressed.connect(_on_unlock_pressed)
	column.add_child(_unlock_button)
	column.add_child(HSeparator.new())
	column.add_child(UiKit.wrapped("Cores drop from bosses: mini-bosses give 1 (yours if you escape), the final boss gives 3 (secured at once).", 14, DIM_COLOR))


func refresh() -> void:
	for node_id in _buttons:
		_style_node(node_id)
	_canvas.queue_redraw()
	_update_info()


func _add_node_button(node_id: String) -> void:
	var node: Dictionary = CoreTree.NODES[node_id]
	var is_large: bool = node["cost"] >= 4 or node_id == CoreTree.ROOT
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2.ONE * (KEYSTONE_SIZE if is_large else NODE_SIZE)
	button.pressed.connect(_select.bind(node_id))
	button.pressed.connect(Audio.play.bind("ui_click"))
	button.mouse_entered.connect(Audio.play.bind("ui_hover"))
	_canvas.add_child(button)
	_buttons[node_id] = button
	var icon_name: String = BRANCH_ICONS[""] if node_id == CoreTree.ROOT else Stats.DEFS[node["stat"]]["icon"]
	var icon := UiKit.icon(UiKit.icon_texture(icon_name), button.size.x * 0.52)
	UiKit.place(icon, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-button.size.x * 0.26, -button.size.y * 0.26, button.size.x * 0.26, button.size.y * 0.26))
	button.add_child(icon)
	_icons[node_id] = icon
	if node_id == CoreTree.ROOT:
		button.tooltip_text = "Essence: where every branch starts"
		return
	var cost := UiKit.title(str(node["cost"]), 15, UiTheme.CORE, true, 700)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place(cost, Vector4(0.5, 1, 0.5, 1), Vector4(-16, -14, 16, 8))
	button.add_child(cost)
	_costs[node_id] = cost
	button.tooltip_text = "%s\n%s\nCost: %d cores" % [node["title"], CoreTree.describe(node_id), node["cost"]]


## Centers the tree (including the branch names) in the pane.
func _layout() -> void:
	var points := {}
	var min_point := Vector2.INF
	var max_point := -Vector2.INF
	for node_id: String in CoreTree.NODES:
		var node: Dictionary = CoreTree.NODES[node_id]
		var point := Vector2.from_angle(deg_to_rad(node["angle"])) * float(node["radius"]) * UNIT
		points[node_id] = point
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	# Leave room for a branch name above and branch names at the sides.
	var half := KEYSTONE_SIZE * 0.5
	min_point -= Vector2(half + BRANCH_LABEL_WIDTH, half + 40.0)
	max_point += Vector2(half + BRANCH_LABEL_WIDTH, half + 16.0)
	var offset := _canvas.size * 0.5 - (min_point + max_point) * 0.5
	for node_id: String in points:
		var center: Vector2 = points[node_id] + offset
		_canvas.centers[node_id] = center
		var button := _buttons[node_id]
		button.position = center - button.size * 0.5
	for branch: String in BRANCH_ANCHORS:
		var label := _branch_labels[branch]
		var center: Vector2 = _canvas.centers[BRANCH_ANCHORS[branch]]
		var label_size := label.get_combined_minimum_size()
		match branch:
			"Might":
				label.position = center + Vector2(-label_size.x * 0.5, -half - 40.0)
			"Resilience":
				label.position = center + Vector2(half + 14.0, -label_size.y * 0.5)
			_:
				label.position = center + Vector2(-half - 14.0 - label_size.x, -label_size.y * 0.5)
	_canvas.queue_redraw()


func _style_node(node_id: String) -> void:
	var node: Dictionary = CoreTree.NODES[node_id]
	var button := _buttons[node_id]
	var color: Color = CoreTree.BRANCH_COLORS[node["branch"]]
	var is_open := CoreTree.is_unlocked(node_id, Profile.unlocked)
	var available := CoreTree.can_unlock(node_id, Profile.unlocked, Profile.cores)
	var reachable := CoreTree.is_reachable(node_id, Profile.unlocked)
	var ring := LOCKED_COLOR
	if is_open or available:
		ring = color
	elif reachable:
		ring = color.darkened(0.45)
	if node_id == _selected:
		ring = UiTheme.GOLD_BRIGHT
	var fill := Color(color.darkened(0.55), 1.0) if is_open else Color(0.07, 0.065, 0.06)
	var radius := int(button.size.x * 0.5)
	var width := 4 if available or node_id == _selected else 3
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.12) if state == "hover" else fill
		style.border_color = ring.lightened(0.2) if state == "hover" else ring
		style.set_border_width_all(width)
		style.set_corner_radius_all(radius)
		style.shadow_color = Color(color, 0.45) if available or is_open else Color(0.0, 0.0, 0.0, 0.5)
		style.shadow_size = 8 if available else 4
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_icons[node_id].self_modulate = color.lightened(0.35) if is_open else (color if reachable else LOCKED_COLOR.lightened(0.3))
	if _costs.has(node_id):
		_costs[node_id].visible = not is_open
		_costs[node_id].add_theme_color_override("font_color", UiTheme.CORE if available else UiTheme.TEXT_MUTED)
	button.modulate.a = 1.0 if is_open or reachable else 0.55


func _update_info() -> void:
	var node: Dictionary = CoreTree.NODES[_selected]
	var branch: String = node["branch"]
	var color: Color = CoreTree.BRANCH_COLORS[branch]
	UiKit.clear(_info_icon)
	var icon_name: String = BRANCH_ICONS[""] if _selected == CoreTree.ROOT else Stats.DEFS[node["stat"]]["icon"]
	_info_icon.add_child(UiKit.icon_slot(UiKit.icon_texture(icon_name), 64.0, color, CoreTree.is_unlocked(_selected, Profile.unlocked)))
	_info_branch.text = branch if branch != "" else "Center"
	_info_branch.add_theme_color_override("font_color", color)
	_info_title.text = node["title"]
	_info_effect.text = CoreTree.describe(_selected)
	if CoreTree.is_unlocked(_selected, Profile.unlocked):
		_info_cost.text = "Unlocked"
		_info_cost.add_theme_color_override("font_color", UiTheme.GOOD)
		_unlock_button.hide()
		return
	_info_cost.text = "Cost: %d cores  ·  you have %d" % [node["cost"], Profile.cores]
	_info_cost.add_theme_color_override("font_color", UiTheme.CORE)
	_unlock_button.show()
	_unlock_button.disabled = not CoreTree.can_unlock(_selected, Profile.unlocked, Profile.cores)
	if not CoreTree.is_reachable(_selected, Profile.unlocked):
		_unlock_button.text = "Unlock a connected node first"
	elif Profile.cores < CoreTree.cost(_selected):
		_unlock_button.text = "Not enough cores"
	else:
		_unlock_button.text = "Unlock"


func _select(node_id: String) -> void:
	_selected = node_id
	refresh()


func _on_unlock_pressed() -> void:
	Audio.play("core" if Profile.unlock_node(_selected) else "ui_error")
