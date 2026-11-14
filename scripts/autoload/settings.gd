extends Node
## Player preferences: volumes, damage numbers and screen shake. Saved to user://settings.cfg,
## except when the game runs with --no-save (tests), just like the profile.

signal changed

const PATH := "user://settings.cfg"
## Preference name: section in the settings file.
const SECTIONS := {
	"master_volume": "audio",
	"music_volume": "audio",
	"effects_volume": "audio",
	"damage_numbers": "gameplay",
	"screen_shake": "gameplay",
}

## Volumes are linear, 0..1.
var master_volume := 1.0
var music_volume := 0.7
var effects_volume := 0.9
var damage_numbers := true
var screen_shake := true

var _persist := true


func _ready() -> void:
	_persist = not "--no-save" in OS.get_cmdline_user_args()
	if not _persist:
		return
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key: String in SECTIONS:
		set(key, config.get_value(SECTIONS[key], key, get(key)))


## Changes a preference by name (e.g. "music_volume") and saves it.
func set_value(key: String, value: Variant) -> void:
	if not SECTIONS.has(key) or get(key) == value:
		return
	set(key, value)
	changed.emit()
	if _persist:
		var config := ConfigFile.new()
		for name: String in SECTIONS:
			config.set_value(SECTIONS[name], name, get(name))
		config.save(PATH)
