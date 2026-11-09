class_name SettingsTab
extends HubPanel
## Camp tab with the same settings as the pause screen.


func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 640
	column.add_theme_constant_override("separation", 16)
	row.add_child(column)
	column.add_child(heading("Sound and display"))
	column.add_child(SettingsPanel.new())
	column.add_child(UiKit.label("Changes are saved right away.", 15, DIM_COLOR))
