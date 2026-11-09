class_name UiKit
extends RefCounted
## Small helpers for building the UI from code: text, buttons, iron plates, icons, bars and
## layout. The look itself (colors, fonts, plate styles) lives in UiTheme.

const ICON_PATH := "res://ui/icons/%s.svg"


## Body text. outline: a dark outline for text drawn straight over the game world (the HUD).
static func label(text: String, font_size: int, color := UiTheme.TEXT, outline := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", roundi(font_size * UiTheme.BODY_SCALE))
	node.add_theme_color_override("font_color", color)
	if outline:
		node.add_theme_constant_override("outline_size", maxi(3, int(font_size / 5.0)))
	return node


## Text in Cinzel, for titles, names and numbers that matter.
static func title(text: String, font_size: int, color := UiTheme.GOLD_BRIGHT, outline := false, weight := 700) -> Label:
	var node := label(text, font_size, color, outline)
	node.add_theme_font_override("font", UiTheme.title_font(weight))
	node.add_theme_font_size_override("font_size", font_size)
	return node


## Body text in the medium weight (values, item names).
static func bold(text: String, font_size: int, color := UiTheme.TEXT) -> Label:
	var node := label(text, font_size, color)
	node.add_theme_font_override("font", UiTheme.bold_font())
	return node


## Body text that wraps at the width of its container.
static func wrapped(text: String, font_size: int, color := UiTheme.TEXT) -> Label:
	var node := label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## A section title: Cinzel text with a thin gold rule running to the right.
static func heading(text: String, font_size := 17) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title(text, font_size, UiTheme.GOLD, false, 600))
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## A button with click and hover sounds. It never takes focus, so the keyboard can't press it
## by accident. kind: UiTheme.Kind; accent tints the trim of secondary and quiet buttons.
static func button(text: String, kind := UiTheme.Kind.SECONDARY, font_size := 16, accent := UiTheme.GOLD) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(Audio.play.bind("ui_click"))
	node.mouse_entered.connect(func() -> void:
		if not node.disabled:
			Audio.play("ui_hover"))
	node.add_theme_font_size_override("font_size", font_size)
	var styles := UiTheme.button_styles(kind, accent)
	for state: String in styles:
		node.add_theme_stylebox_override(state, styles[state])
	match kind:
		UiTheme.Kind.PRIMARY:
			node.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
		UiTheme.Kind.DANGER:
			node.add_theme_color_override("font_color", UiTheme.DANGER.lightened(0.2))
			node.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.8))
	return node


## A button with an icon in front of its text; the icon takes the text's color.
static func icon_button(text: String, icon_name: String, kind := UiTheme.Kind.SECONDARY, font_size := 16, accent := UiTheme.GOLD) -> Button:
	var node := button(text, kind, font_size, accent)
	node.icon = icon_texture(icon_name)
	node.expand_icon = false
	node.add_theme_constant_override("icon_max_width", font_size + 6)
	var base := UiTheme.GOLD_BRIGHT if kind == UiTheme.Kind.PRIMARY else accent
	node.add_theme_color_override("icon_normal_color", base)
	node.add_theme_color_override("icon_hover_color", base.lightened(0.3))
	node.add_theme_color_override("icon_pressed_color", base.lightened(0.3))
	node.add_theme_color_override("icon_hover_pressed_color", base.lightened(0.3))
	node.add_theme_color_override("icon_disabled_color", Color(UiTheme.TEXT_MUTED, 0.7))
	return node


## A large button with its icon right next to the centered text (Start run, Resume).
static func big_button(text: String, icon_name: String, kind := UiTheme.Kind.PRIMARY, font_size := 24) -> Button:
	var node := button("", kind, font_size)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	place(row, Vector4(0, 0, 1, 1), Vector4.ZERO)
	node.add_child(row)
	var color := UiTheme.GOLD_BRIGHT if kind == UiTheme.Kind.PRIMARY else UiTheme.TEXT
	row.add_child(icon(icon_texture(icon_name), font_size + 4.0, color))
	row.add_child(title(text, font_size, color, false, 700))
	return node


static func icon_texture(icon_name: String) -> Texture2D:
	return load(ICON_PATH % icon_name)


## An icon tinted with color, size × size pixels.
static func icon(texture: Texture2D, size: float, color := Color.WHITE) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(size, size)
	node.self_modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return node


## An icon in a small iron frame, trimmed in accent (lit: glowing, for the active or selected one).
static func icon_slot(texture: Texture2D, size: float, accent: Color, lit := false) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiTheme.slot(accent, lit))
	frame.custom_minimum_size = Vector2(size, size)
	if texture:
		frame.add_child(icon(texture, size - 16.0, accent.lightened(0.15) if lit else accent))
	return frame


## A PanelContainer with an iron plate (accent tints the trim).
static func plate(accent := UiTheme.GOLD, padding := 16.0, ornate := true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.plate(accent, ornate, padding))
	return panel


## A row of small bars showing a rank: filled ones in color, the rest dark.
static func pips(filled: int, total: int, color: Color, size := Vector2(14, 5), next := -1) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	for i in total:
		var pip := ColorRect.new()
		pip.custom_minimum_size = size
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < filled:
			pip.color = color
		elif i == next:
			pip.color = Color(color, 0.45)
		else:
			pip.color = Color(1.0, 1.0, 1.0, 0.1)
		row.add_child(pip)
	return row


## A small rounded tag with a number or word, used as a badge.
static func badge(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.darkened(0.6), 0.95)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(bold(text, 14, color.lightened(0.25)))
	return panel


## A bar for values from 0 to 1, with no percentage text: a dark iron groove and a fill that is
## lighter at the top.
static func bar(fill: Color, background := Color(0.03, 0.025, 0.02, 0.9)) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.max_value = 1.0
	node.step = 0.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.35)
	fill_style.border_width_top = 2
	fill_style.set_corner_radius_all(2)
	var groove := StyleBoxFlat.new()
	groove.bg_color = background
	groove.border_color = Color(UiTheme.GOLD_DIM, 0.9)
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(2)
	node.add_theme_stylebox_override("fill", fill_style)
	node.add_theme_stylebox_override("background", groove)
	return node


## An item: its icon in a frame of its rarity color, the name, rarity and slot, and the bonus
## lines with their stat icons.
static func item_card(item: Item, icon_size := 52.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var frame := icon_slot(item.icon(), icon_size, item.color(), item.rarity >= Item.Rarity.RARE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	column.add_child(title(item.title, 17, item.color(), false, 700))
	var kind := "%s %s" % [item.rarity_name(), item.slot_name().to_lower()]
	column.add_child(label(kind + ("  ·  free kit" if item.free else ""), 14, UiTheme.TEXT_MUTED))
	for affix in item.affixes:
		column.add_child(stat_line(affix["stat"], affix["value"]))
	return row


## One bonus: the stat's icon and its text ("Damage +8%").
static func stat_line(stat: String, value: float, color := UiTheme.TEXT, font_size := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(icon(Stats.icon(stat), font_size - 1.0, Color(UiTheme.GOLD, 0.85)))
	row.add_child(label(Stats.describe(stat, value), font_size, color))
	return row


## Asks before something that can't be undone: a dimmed overlay over parent with a plate, the
## question, what it costs and two buttons. on_confirm runs only if the player confirms.
static func confirm(parent: Node, question: String, details: String, confirm_text: String, on_confirm: Callable) -> Control:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	place(overlay, Vector4(0, 0, 1, 1), Vector4.ZERO)
	UiTheme.use_on(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	place(dim, Vector4(0, 0, 1, 1), Vector4.ZERO)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	place(center, Vector4(0, 0, 1, 1), Vector4.ZERO)
	overlay.add_child(center)
	var panel := plate(UiTheme.DANGER, 28.0)
	panel.custom_minimum_size.x = 460
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(title(question, 24, UiTheme.GOLD_BRIGHT))
	if details != "":
		column.add_child(wrapped(details, 17, UiTheme.TEXT_DIM))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var keep := button("Cancel", UiTheme.Kind.SECONDARY, 16)
	keep.pressed.connect(overlay.queue_free)
	buttons.add_child(keep)
	var go := button(confirm_text, UiTheme.Kind.DANGER, 16)
	go.pressed.connect(func() -> void:
		overlay.queue_free()
		on_confirm.call())
	buttons.add_child(go)
	parent.add_child(overlay)
	return overlay


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


## Removes all children from a container right away and frees them.
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(seconds / 60.0), total % 60]
