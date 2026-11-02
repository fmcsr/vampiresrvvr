class_name HubPanel
extends MarginContainer
## Shared base for the camp screen tabs. refresh() is called when the profile changes or the tab is opened.

const DIM_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const HEADING_COLOR := Color(0.85, 0.7, 1.0)
const GOLD_COLOR := Color(1.0, 0.8, 0.3)


## Subclasses rebuild their content here.
func refresh() -> void:
	pass


static func card_style(accent: Color) -> StyleBoxFlat:
	var style := UiKit.flat_style(Color(0.11, 0.1, 0.13, 0.95), accent.darkened(0.3), 1, 8)
	style.set_content_margin_all(10)
	return style


static func heading(text: String) -> Label:
	return UiKit.label(text, 19, HEADING_COLOR)
