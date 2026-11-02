class_name SettingsTab
extends HubPanel
## Camp tab with the same settings as the pause screen.


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(heading("SETTINGS"))
	column.add_child(SettingsPanel.new())
	column.add_child(UiKit.label("Changes are saved right away.", 15, DIM_COLOR))
