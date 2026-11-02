class_name CoreTreePanel
extends HubPanel
## Core tree tab: click a node, then unlock it from the panel on the right. A node can be unlocked
## once one of the nodes it connects to is unlocked and there are enough cores.

## Pixels per radius unit of the tree.
const UNIT := 62.0
const NODE_SIZE := 54.0
const KEYSTONE_SIZE := 70.0
const TITLE_WIDTH := 130.0
const BRANCH_LABEL_WIDTH := 150.0
const LOCKED_COLOR := Color(0.3, 0.29, 0.34)
## Keystone node at the tip of each branch; the branch name is placed next to it.
const BRANCH_ANCHORS := {"Might": "a6", "Resilience": "b6", "Fortune": "c6"}


## Draws the lines between nodes; the node buttons are its children.
class TreeCanvas extends Control:
	const LINE_LOCKED_COLOR := Color(0.3, 0.29, 0.34)

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
				draw_line(centers[required], centers[node_id], color, 5.0 if both_open else 2.0, true)


var _canvas: TreeCanvas
var _buttons: Dictionary[String, Button] = {}
var _titles: Dictionary[String, Label] = {}
var _branch_labels: Dictionary[String, Label] = {}
var _selected := "a1"
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
	# Titles are added after all nodes so neighboring nodes don't cover them.
	for node_id: String in CoreTree.NODES:
		if node_id != CoreTree.ROOT:
			_add_node_title(node_id)
	for branch: String in BRANCH_ANCHORS:
		var label := UiKit.label(branch.to_upper(), 20, CoreTree.BRANCH_COLORS[branch])
		label.custom_minimum_size.x = BRANCH_LABEL_WIDTH
		_canvas.add_child(label)
		_branch_labels[branch] = label

	var info := PanelContainer.new()
	info.custom_minimum_size.x = 340
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_stylebox_override("panel", card_style(HEADING_COLOR))
	row.add_child(info)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	info.add_child(column)
	_info_branch = UiKit.label("", 15, DIM_COLOR)
	column.add_child(_info_branch)
	_info_title = UiKit.label("", 28)
	column.add_child(_info_title)
	_info_effect = UiKit.label("", 20, Color(0.9, 0.88, 0.8))
	_info_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info_effect)
	_info_cost = UiKit.label("", 18, Color(0.45, 1.0, 0.7))
	column.add_child(_info_cost)
	_unlock_button = UiKit.button("Unlock", Color(0.45, 1.0, 0.7), 18)
	_unlock_button.pressed.connect(_on_unlock_pressed)
	column.add_child(_unlock_button)
	var hint := UiKit.label("Cores drop from bosses: mini-bosses give 1 (yours if you escape), the final boss gives 3 (secured immediately).", 14, DIM_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)


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
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_select.bind(node_id))
	_canvas.add_child(button)
	_buttons[node_id] = button


func _add_node_title(node_id: String) -> void:
	var title := UiKit.label(CoreTree.NODES[node_id]["title"], 14, Color(0.9, 0.88, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = TITLE_WIDTH
	_canvas.add_child(title)
	_titles[node_id] = title


## Centers the tree (including node titles and branch names) in the pane.
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
	# Leave room for a branch name above, node titles below and branch names at the sides.
	var half := KEYSTONE_SIZE * 0.5
	min_point -= Vector2(half + BRANCH_LABEL_WIDTH, half + 36.0)
	max_point += Vector2(half + BRANCH_LABEL_WIDTH, half + 24.0)
	var offset := _canvas.size * 0.5 - (min_point + max_point) * 0.5
	for node_id: String in points:
		var center: Vector2 = points[node_id] + offset
		_canvas.centers[node_id] = center
		var button := _buttons[node_id]
		button.position = center - button.size * 0.5
		if _titles.has(node_id):
			_titles[node_id].position = center + Vector2(-TITLE_WIDTH * 0.5, button.size.y * 0.5 + 2.0)
	for branch: String in BRANCH_ANCHORS:
		var label := _branch_labels[branch]
		var center: Vector2 = _canvas.centers[BRANCH_ANCHORS[branch]]
		match branch:
			"Might":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.position = center + Vector2(-BRANCH_LABEL_WIDTH * 0.5, -half - 34.0)
			"Resilience":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				label.position = center + Vector2(half + 12.0, -14.0)
			_:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				label.position = center + Vector2(-half - 12.0 - BRANCH_LABEL_WIDTH, -14.0)
	_canvas.queue_redraw()


func _style_node(node_id: String) -> void:
	var node: Dictionary = CoreTree.NODES[node_id]
	var button := _buttons[node_id]
	var color: Color = CoreTree.BRANCH_COLORS[node["branch"]]
	var is_open := CoreTree.is_unlocked(node_id, Profile.unlocked)
	var available := CoreTree.can_unlock(node_id, Profile.unlocked, Profile.cores)
	var reachable := CoreTree.is_reachable(node_id, Profile.unlocked)
	var border := LOCKED_COLOR
	if node_id == _selected:
		border = Color.WHITE
	elif is_open or available:
		border = color
	elif reachable:
		border = color.darkened(0.45)
	var background := color.darkened(0.15) if is_open else Color(0.09, 0.08, 0.11)
	var radius := int(button.size.x * 0.5)
	var width := 4 if available or node_id == _selected else 2
	for state in ["normal", "hover", "pressed"]:
		var style := UiKit.flat_style(background.lightened(0.12) if state == "hover" else background, border, width, radius)
		button.add_theme_stylebox_override(state, style)
	if node_id == CoreTree.ROOT:
		button.text = node["title"]
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.14))
		return
	button.text = "" if is_open else str(node["cost"])
	button.add_theme_color_override("font_color", color if reachable else LOCKED_COLOR.lightened(0.3))
	_titles[node_id].modulate.a = 1.0 if is_open or reachable else 0.5


func _update_info() -> void:
	var node: Dictionary = CoreTree.NODES[_selected]
	var branch: String = node["branch"]
	_info_branch.text = branch.to_upper() if branch != "" else "CENTER"
	_info_branch.add_theme_color_override("font_color", CoreTree.BRANCH_COLORS[branch])
	_info_title.text = node["title"]
	_info_effect.text = CoreTree.describe(_selected)
	if CoreTree.is_unlocked(_selected, Profile.unlocked):
		_info_cost.text = "Unlocked"
		_unlock_button.hide()
		return
	_info_cost.text = "Cost: %d cores  (you have %d)" % [node["cost"], Profile.cores]
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
	Profile.unlock_node(_selected)
