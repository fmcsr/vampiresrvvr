class_name HubPanel
extends MarginContainer
## Shared base for the camp screen tabs. refresh() is called when the profile changes or the tab is opened.

## Asks the camp to open another tab; focus names what to show there (a skill id, an item slot).
signal navigate_requested(tab: int, focus: String)

const DIM_COLOR := UiTheme.TEXT_MUTED
const HEADING_COLOR := UiTheme.GOLD
const GOLD_COLOR := UiTheme.GOLD_COIN


## Subclasses rebuild their content here.
func refresh() -> void:
	pass


## Subclasses show the thing named by focus (from navigate_requested) here.
func focus_on(_focus: String) -> void:
	pass


static func heading(text: String) -> HBoxContainer:
	return UiKit.heading(text)
