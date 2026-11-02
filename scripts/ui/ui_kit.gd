class_name UiKit
extends RefCounted
## Small helpers for building the UI from code (labels, styles, bars, layout).


static func label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	node.add_theme_constant_override("outline_size", maxi(2, int(font_size / 6.0)))
	return node


static func flat_style(background: Color, border := Color.TRANSPARENT, border_width := 0, radius := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


## A bar for values from 0 to 1, with no percentage text.
static func bar(fill: Color, background: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.max_value = 1.0
	node.step = 0.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("fill", flat_style(fill, Color.TRANSPARENT, 0, 4))
	node.add_theme_stylebox_override("background", flat_style(background, Color(0.0, 0.0, 0.0, 0.8), 2, 4))
	return node


## Places a control in its parent with anchors. anchors: (left, top, right, bottom) 0..1, offsets: pixels.
static func place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


## Name of the first keyboard key bound to an action (e.g. "Q", "SPACE").
static func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code).to_upper()
	return "?"


## A count with the right noun form: "1 item", "3 items".
static func count_text(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]


## Writes whole numbers without decimals, others with up to two decimal places (e.g. 0.75).
static func format_number(number: float) -> String:
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return str(snappedf(number, 0.01))


## Bordered, padded button. It never takes focus, so the keyboard can't press it by accident.
static func button(text: String, accent: Color, font_size := 16) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.3))
	var states := {
		"normal": flat_style(Color(0.1, 0.09, 0.12, 0.95), accent.darkened(0.35), 2, 8),
		"hover": flat_style(Color(0.16, 0.14, 0.18, 0.98), accent, 2, 8),
		"pressed": flat_style(Color(0.22, 0.18, 0.26, 1.0), accent, 3, 8),
		"hover_pressed": flat_style(Color(0.24, 0.2, 0.28, 1.0), accent, 3, 8),
		"disabled": flat_style(Color(0.08, 0.08, 0.09, 0.8), Color(0.3, 0.3, 0.32), 1, 8),
	}
	for state in states:
		var style: StyleBoxFlat = states[state]
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		node.add_theme_stylebox_override(state, style)
	return node


## Item card: colored name, rarity and slot, bonus lines.
static func item_card(item: Item) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.add_child(label(item.title, 18, item.color()))
	box.add_child(label("%s %s" % [item.rarity_name(), item.slot_name().to_lower()], 13, Color(1.0, 1.0, 1.0, 0.5)))
	for line in item.describe_affixes():
		box.add_child(label(line, 15, Color(0.86, 0.85, 0.8)))
	return box


## Removes all children from a container right away and frees them.
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(seconds / 60.0), total % 60]
