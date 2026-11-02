class_name EnemyType
extends Resource
## Tunable values for an enemy type. New type = new .tres under resources/enemies.

@export var display_name := "Enemy"
@export var color := Color(0.8, 0.8, 0.8)
@export_range(0.5, 3.0) var size := 1.0
@export var max_health := 20.0
@export var move_speed := 3.0
@export var contact_damage := 6.0
## Time between contact hits (s).
@export var attack_interval := 0.8
@export_range(0.0, 1.0) var knockback_resistance := 0.0
@export var xp_value := 1

@export_group("Spawning")
## Run time (s) from which this type can spawn.
@export var unlock_time := 0.0
## Spawn weight relative to the other types.
@export var spawn_weight := 1.0

var _material: StandardMaterial3D


func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = color
		_material.roughness = 0.85
	return _material
