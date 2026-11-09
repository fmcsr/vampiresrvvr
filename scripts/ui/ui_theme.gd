class_name UiTheme
extends RefCounted
## The game's look: dark iron plates with gold trim (IronFrame), Cinzel for titles and buttons,
## Alegreya Sans for text. Builds the Theme that every screen uses (set on the root window) and
## hands out the fonts and plate styles the code-built screens ask for.

const GOLD := Color(0.86, 0.68, 0.38)
const GOLD_BRIGHT := Color(1.0, 0.86, 0.56)
const GOLD_DIM := Color(0.48, 0.38, 0.24)
const TEXT := Color(0.9, 0.86, 0.78)
const TEXT_DIM := Color(0.66, 0.62, 0.55)
const TEXT_MUTED := Color(0.47, 0.44, 0.4)
const GOOD := Color(0.56, 0.86, 0.46)
const DANGER := Color(0.94, 0.4, 0.32)
const BLOOD := Color(0.5, 0.1, 0.07)
const GOLD_COIN := Color(1.0, 0.78, 0.3)
const CORE := Color(0.45, 0.95, 0.75)
const XP := Color(0.66, 0.54, 1.0)
const IRON_TOP := Color(0.105, 0.095, 0.085, 0.97)
const IRON_BOTTOM := Color(0.055, 0.05, 0.045, 0.97)

const TITLE_FONT := "res://ui/fonts/Cinzel-Variable.ttf"
const BODY_FONT := "res://ui/fonts/AlegreyaSans-Regular.ttf"
const BOLD_FONT := "res://ui/fonts/AlegreyaSans-Medium.ttf"
const BODY_SIZE := 18
## Alegreya Sans looks small for its size, so body text is set this much larger than asked.
const BODY_SCALE := 1.1

## Button looks: secondary (iron), primary (blood red, the one main action on a screen), danger,
## and quiet (no plate until hovered: navigation and list rows).
enum Kind { SECONDARY, PRIMARY, DANGER, QUIET }

static var _theme: Theme
static var _fonts: Dictionary = {}


## Sets the theme on the root window and shapes text as English: the game's text is English, and
## with the system's locale (Turkish, for example) Cinzel would keep the dot on its small-capital i.
## A theme only passes down through Controls and Windows, so UI under a CanvasLayer or a 3D node
## also sets it on its own top Control (see use_on).
static func apply(tree: SceneTree) -> void:
	TranslationServer.set_locale("en")
	tree.root.theme = theme()


## Gives a top-level Control (under a CanvasLayer, for example) the game's theme.
static func use_on(control: Control) -> void:
	control.theme = theme()


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Cinzel at the given weight (400 to 900).
static func title_font(weight := 700) -> Font:
	var key := "title_%d" % weight
	if not _fonts.has(key):
		var font := FontVariation.new()
		font.base_font = load(TITLE_FONT)
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = font
	return _fonts[key]


static func body_font() -> Font:
	return _font("body", BODY_FONT)


static func bold_font() -> Font:
	return _font("bold", BOLD_FONT)


## A plate for panels and cards. accent tints the trim (gold by default).
static func plate(accent := GOLD, ornate := true, padding := 16.0) -> IronFrame:
	var style := IronFrame.new()
	style.trim = Color(accent, 0.75)
	style.corner = 18.0 if ornate else 0.0
	style.set_content_margin_all(padding)
	return style


## A small square frame for an icon (power, item or stat), with its trim in the given color.
static func slot(accent: Color, lit := false) -> IronFrame:
	var style := IronFrame.new()
	style.fill_top = Color(0.08, 0.07, 0.065, 0.95)
	style.fill_bottom = Color(0.03, 0.028, 0.026, 0.95)
	style.trim = accent if lit else Color(accent.darkened(0.35), 0.85)
	style.trim_inset = 3.0
	style.corner = 6.0
	style.glow = Color(accent, 0.28) if lit else Color(0.0, 0.0, 0.0, 0.0)
	style.set_content_margin_all(6.0)
	return style


## Styles for every state of a button of the given kind; accent tints secondary buttons.
static func button_styles(kind: Kind, accent := GOLD) -> Dictionary:
	var normal := IronFrame.new()
	var hover := IronFrame.new()
	var pressed := IronFrame.new()
	var disabled := IronFrame.new()
	for style: IronFrame in [normal, hover, pressed, disabled]:
		style.corner = 6.0
		style.trim_inset = 3.0
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 7.0
		style.content_margin_bottom = 7.0
	match kind:
		Kind.PRIMARY:
			normal.fill_top = Color(0.42, 0.09, 0.06, 0.98)
			normal.fill_bottom = Color(0.2, 0.04, 0.03, 0.98)
			normal.trim = GOLD
			hover.fill_top = Color(0.55, 0.13, 0.08, 1.0)
			hover.fill_bottom = Color(0.27, 0.06, 0.04, 1.0)
			hover.trim = GOLD_BRIGHT
			hover.glow = Color(1.0, 0.6, 0.3, 0.3)
			pressed.fill_top = Color(0.22, 0.05, 0.03, 1.0)
			pressed.fill_bottom = Color(0.34, 0.08, 0.05, 1.0)
			pressed.trim = GOLD_BRIGHT
		Kind.DANGER:
			normal.fill_top = Color(0.2, 0.06, 0.05, 0.97)
			normal.fill_bottom = Color(0.1, 0.03, 0.03, 0.97)
			normal.trim = Color(0.75, 0.28, 0.22)
			hover.fill_top = Color(0.32, 0.08, 0.06, 1.0)
			hover.fill_bottom = Color(0.15, 0.04, 0.03, 1.0)
			hover.trim = DANGER
			hover.glow = Color(1.0, 0.3, 0.2, 0.25)
			pressed.fill_top = Color(0.12, 0.03, 0.03, 1.0)
			pressed.fill_bottom = Color(0.22, 0.06, 0.05, 1.0)
			pressed.trim = DANGER
		Kind.QUIET:
			for style: IronFrame in [normal, hover, pressed, disabled]:
				style.content_margin_left = 10.0
				style.content_margin_right = 10.0
			for style: IronFrame in [normal, disabled]:
				style.fill_top = Color(0.0, 0.0, 0.0, 0.0)
				style.fill_bottom = Color(0.0, 0.0, 0.0, 0.0)
				style.edge = Color(0.0, 0.0, 0.0, 0.0)
				style.trim = Color(0.0, 0.0, 0.0, 0.0)
				style.grain = 0.0
			hover.fill_top = Color(0.14, 0.12, 0.1, 0.8)
			hover.fill_bottom = Color(0.08, 0.07, 0.06, 0.8)
			hover.trim = Color(accent, 0.5)
			hover.corner = 0.0
			pressed.trim = accent
			pressed.glow = Color(accent, 0.2)
		_:
			normal.trim = Color(accent.darkened(0.3), 0.9)
			hover.fill_top = Color(0.15, 0.13, 0.11, 0.98)
			hover.fill_bottom = Color(0.08, 0.07, 0.06, 0.98)
			hover.trim = accent.lightened(0.15)
			hover.glow = Color(accent, 0.18)
			pressed.fill_top = Color(0.05, 0.045, 0.04, 1.0)
			pressed.fill_bottom = Color(0.11, 0.1, 0.09, 1.0)
			pressed.trim = accent.lightened(0.2)
			pressed.glow = Color(accent, 0.25)
	disabled.fill_top = Color(0.07, 0.065, 0.06, 0.85)
	disabled.fill_bottom = Color(0.04, 0.038, 0.035, 0.85)
	disabled.trim = Color(0.32, 0.3, 0.28, 0.7)
	disabled.corner = 0.0
	disabled.grain = 0.0
	return {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed,
			"disabled": disabled, "focus": StyleBoxEmpty.new()}


static func _font(key: String, path: String) -> Font:
	if not _fonts.has(key):
		_fonts[key] = load(path)
	return _fonts[key]


static func _build() -> Theme:
	var built := Theme.new()
	built.default_font = body_font()
	built.default_font_size = BODY_SIZE

	built.set_color("font_color", "Label", TEXT)
	built.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.85))

	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		built.set_stylebox(state, "Button", button_styles(Kind.SECONDARY)[state])
	built.set_font("font", "Button", title_font(600))
	built.set_font_size("font_size", "Button", 16)
	built.set_color("font_color", "Button", TEXT)
	built.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	built.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	built.set_color("font_hover_pressed_color", "Button", GOLD_BRIGHT)
	built.set_color("font_focus_color", "Button", TEXT)
	built.set_color("font_disabled_color", "Button", TEXT_MUTED)
	built.set_constant("h_separation", "Button", 8)

	built.set_stylebox("panel", "PanelContainer", plate())
	built.set_stylebox("panel", "Panel", plate())
	built.set_stylebox("panel", "TooltipPanel", plate(GOLD, false, 10.0))
	built.set_color("font_color", "TooltipLabel", TEXT)
	built.set_font("font", "TooltipLabel", body_font())
	built.set_font_size("font_size", "TooltipLabel", 16)

	var line := StyleBoxLine.new()
	line.color = Color(GOLD_DIM, 0.7)
	line.grow_begin = -6.0
	line.grow_end = -6.0
	built.set_stylebox("separator", "HSeparator", line)
	built.set_constant("separation", "HSeparator", 12)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.028, 0.025, 0.9)
	track.border_color = Color(GOLD_DIM, 0.8)
	track.set_border_width_all(1)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(GOLD, 0.85)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	built.set_stylebox("slider", "HSlider", track)
	built.set_stylebox("grabber_area", "HSlider", filled)
	built.set_stylebox("grabber_area_highlight", "HSlider", filled)
	built.set_icon("grabber", "HSlider", _diamond(18, GOLD))
	built.set_icon("grabber_highlight", "HSlider", _diamond(18, GOLD_BRIGHT))

	built.set_icon("unchecked", "CheckBox", _check_icon(false))
	built.set_icon("checked", "CheckBox", _check_icon(true))
	built.set_font("font", "CheckBox", body_font())
	built.set_font_size("font_size", "CheckBox", BODY_SIZE)
	built.set_color("font_color", "CheckBox", TEXT)
	built.set_color("font_hover_color", "CheckBox", GOLD_BRIGHT)
	built.set_color("font_pressed_color", "CheckBox", TEXT)
	built.set_color("font_hover_pressed_color", "CheckBox", GOLD_BRIGHT)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		built.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	built.set_constant("h_separation", "CheckBox", 10)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(GOLD_DIM, 0.9)
	grabber.set_corner_radius_all(3)
	var grabber_lit := grabber.duplicate() as StyleBoxFlat
	grabber_lit.bg_color = GOLD
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	scroll.set_corner_radius_all(3)
	scroll.content_margin_left = 4.0
	scroll.content_margin_right = 4.0
	built.set_stylebox("scroll", "VScrollBar", scroll)
	built.set_stylebox("grabber", "VScrollBar", grabber)
	built.set_stylebox("grabber_highlight", "VScrollBar", grabber_lit)
	built.set_stylebox("grabber_pressed", "VScrollBar", grabber_lit)
	return built


## A filled diamond, used as the slider grabber.
static func _diamond(size: int, color: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	for y in size:
		for x in size:
			var distance := absf(x - center) + absf(y - center)
			var alpha := clampf(center - distance + 0.5, 0.0, 1.0)
			var shade := color.darkened(0.45) if distance > center - 2.0 else color
			image.set_pixel(x, y, Color(shade, alpha))
	return ImageTexture.create_from_image(image)


## Check box: a gold square, with a diamond inside when checked.
static func _check_icon(checked: bool) -> ImageTexture:
	var size := 22
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var border := x < 2 or y < 2 or x >= size - 2 or y >= size - 2
			var color := Color(GOLD, 0.9) if border else Color(0.03, 0.028, 0.025, 0.9)
			if checked and not border and absf(x - 10.5) + absf(y - 10.5) <= 6.0:
				color = GOLD_BRIGHT
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
