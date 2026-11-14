extends Node3D
## Diablo-style follow camera: fixed tilted angle, smooth follow and shake.
## Set the angle and distance here; the Camera3D position is computed in code.

@export var target: Node3D
@export_range(30.0, 89.0) var pitch_degrees := 55.0
@export_range(-180.0, 180.0) var yaw_degrees := 0.0
@export var distance := 24.0
## Higher values make the camera follow the target more tightly.
@export var follow_sharpness := 10.0
@export var max_shake_offset := 0.6

var _trauma := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	Game.camera_shake_requested.connect(add_trauma)
	if target:
		global_position = target.global_position
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target:
		var weight := 1.0 - exp(-follow_sharpness * delta)
		global_position = global_position.lerp(target.global_position, weight)
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var shake := _trauma * _trauma * max_shake_offset
	camera.h_offset = randf_range(-1.0, 1.0) * shake
	camera.v_offset = randf_range(-1.0, 1.0) * shake


func add_trauma(amount: float) -> void:
	if Settings.screen_shake:
		_trauma = minf(_trauma + amount, 1.0)
