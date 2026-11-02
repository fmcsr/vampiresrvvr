class_name SettingsPanel
extends VBoxContainer
## Volume sliders and gameplay toggles. Used in the pause screen and the camp's Settings tab;
## every change goes straight to Settings, which saves it.

const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const DIM_COLOR := Color(1.0, 1.0, 1.0, 0.6)


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_slider("Master volume", "master_volume")
	_slider("Music", "music_volume")
	_slider("Effects", "effects_volume")
	_toggle("Damage numbers", "damage_numbers")
	_toggle("Screen shake", "screen_shake")


func _slider(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label := UiKit.label(title, 18, TEXT_COLOR)
	label.custom_minimum_size.x = 170
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get(key)
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := UiKit.label(_percent(slider.value), 16, DIM_COLOR)
	value_label.custom_minimum_size.x = 56
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _percent(value)
		Settings.set_value(key, value))
	# A click after dragging lets you hear the new effects volume.
	slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play("ui_click"))


func _toggle(title: String, key: String) -> void:
	var box := CheckBox.new()
	box.text = title
	box.button_pressed = Settings.get(key)
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 18)
	box.add_theme_color_override("font_color", TEXT_COLOR)
	box.toggled.connect(func(enabled: bool) -> void:
		Audio.play("ui_click")
		Settings.set_value(key, enabled))
	add_child(box)


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
