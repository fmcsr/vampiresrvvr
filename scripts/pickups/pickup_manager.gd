class_name PickupManager
extends Node3D
## Pools XP gems and runs their magnet and pickup logic in a single loop.
## They are all updated here so hundreds of gems don't each run their own script.

const GEM_HEIGHT := 0.35
const COLLECT_DISTANCE := 0.8
const MAGNET_ACCELERATION := 45.0
const SPIN_SPEED := 2.0

var _active: Array[XpGem] = []
var _pool: Array[XpGem] = []
var _mesh := BoxMesh.new()
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_mesh.size = Vector3(0.3, 0.3, 0.3)
	for color in [Color(0.35, 0.65, 1.0), Color(0.4, 1.0, 0.5), Color(1.0, 0.35, 0.35)]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.5
		_materials.append(material)


func spawn_xp(at: Vector3, value: int) -> void:
	var gem: XpGem = _pool.pop_back() if not _pool.is_empty() else _create_gem()
	gem.value = value
	gem.is_magnetized = false
	gem.speed = 0.0
	gem.material_override = _materials[0 if value < 5 else (1 if value < 20 else 2)]
	gem.position = Vector3(at.x, GEM_HEIGHT, at.z)
	gem.visible = true
	gem.reset_physics_interpolation()
	_active.append(gem)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if player == null:
		return
	var target := player.global_position + Vector3.UP * 0.8
	var magnet_squared := player.pickup_radius * player.pickup_radius
	var collect_squared := COLLECT_DISTANCE * COLLECT_DISTANCE
	var i := _active.size() - 1
	while i >= 0:
		var gem := _active[i]
		gem.rotation.y += SPIN_SPEED * delta
		var to_player := target - gem.position
		var distance_squared := to_player.length_squared()
		if not gem.is_magnetized and distance_squared <= magnet_squared:
			gem.is_magnetized = true
		if gem.is_magnetized:
			gem.speed += MAGNET_ACCELERATION * delta
			var step := gem.speed * delta
			if distance_squared <= collect_squared or step * step >= distance_squared:
				player.add_xp(gem.value)
				_release(i)
			else:
				gem.position += to_player / sqrt(distance_squared) * step
		i -= 1


func _create_gem() -> XpGem:
	var gem := XpGem.new()
	gem.mesh = _mesh
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gem.rotation_degrees = Vector3(45.0, 0.0, 45.0)
	add_child(gem)
	return gem


func _release(index: int) -> void:
	var gem := _active[index]
	_active[index] = _active[_active.size() - 1]
	_active.pop_back()
	gem.visible = false
	_pool.append(gem)
