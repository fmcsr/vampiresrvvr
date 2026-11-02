class_name ExitPortal
extends Node3D
## Exit gate: a glowing ring on the ground, a beam reaching into the sky and a light source.
## Staying inside for channel_time wins the run. Taking damage resets the progress;
## stepping outside quickly drains it.

signal extracted

const RADIUS := 2.4
const BEAM_START_HEIGHT := 3.0
const EARLY_COLOR := Color(0.3, 1.0, 0.75)
const FINAL_COLOR := Color(1.0, 0.85, 0.4)

## How long you must stay inside (s).
@export var channel_time := 3.0

var is_final := false
## Channel progress, 0..1.
var progress := 0.0

var _is_open := true
var _fill: MeshInstance3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var tint := color()
	var glow := Color(tint.r * 2.5, tint.g * 2.5, tint.b * 2.5)
	_add_mesh(Fx.flat_mesh(RADIUS - 0.3, RADIUS, PI, 48), glow, 0.08)
	_fill = _add_mesh(Fx.flat_mesh(0.0, RADIUS - 0.3, PI, 48), Color(tint, 0.35), 0.07)
	_fill.scale = Vector3(0.01, 1.0, 0.01)
	# The beam starts above the character so the character stays visible inside the gate.
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.4
	beam_mesh.bottom_radius = 0.7
	beam_mesh.height = 40.0
	_add_mesh(beam_mesh, Color(glow, 0.22), BEAM_START_HEIGHT + 20.0)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position.y = 2.5
	add_child(light)
	scale = Vector3(0.01, 1.0, 0.01)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.player.damaged.connect(_on_player_damaged)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if not _is_open or player == null:
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= RADIUS:
		progress = minf(progress + delta / channel_time, 1.0)
		if progress >= 1.0:
			_is_open = false
			extracted.emit()
	else:
		progress = maxf(progress - delta * 2.0 / channel_time, 0.0)
	var fill := maxf(progress, 0.01)
	_fill.scale = Vector3(fill, 1.0, fill)


func color() -> Color:
	return FINAL_COLOR if is_final else EARLY_COLOR


func is_open() -> bool:
	return _is_open


## Plays the closing animation and frees itself.
func close() -> void:
	_is_open = false
	progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 1.0, 0.01), 0.4)
	tween.tween_callback(queue_free)


func _on_player_damaged(_amount: float) -> void:
	progress = 0.0


func _add_mesh(mesh: Mesh, tint: Color, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = Fx.unshaded_material(tint)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = height
	add_child(node)
	return node
