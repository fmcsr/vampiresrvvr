class_name EnemySpawner
extends Node3D
## Spawns enemies where the camera can't see them. Spawn rate and enemy health rise as time
## goes on; every minute a siege wave surrounds the player.

@export var enemy_scene: PackedScene
## The first type is used for siege waves and boss summons.
@export var enemy_types: Array[EnemyType] = []
## Number of enemies created up front (prevents hitches in the first minutes).
@export var prewarm_count := 120

@export_group("Arena")
@export var arena_half_size := 58.0
@export var spawn_distance_min := 24.0
@export var spawn_distance_max := 32.0
## Enemies that get this far from the player are moved back near them.
@export var relocate_distance := 44.0

@export_group("Difficulty")
@export var max_alive := 300
@export var spawns_per_second := 0.9
@export var spawns_per_second_per_minute := 0.65
## Enemy health increase per minute (0.1 = 10%).
@export var health_growth_per_minute := 0.1

@export_group("Siege Wave")
@export var wave_interval := 60.0
@export var wave_base_count := 18
@export var wave_count_per_minute := 6
@export var wave_radius := 21.0
## Siege waves and boss summons may exceed max_alive by at most this many.
@export var wave_overflow := 60

## Spawn rate multiplier; RunDirector raises it during the final escape.
var intensity := 1.0

var _pool: Array[Enemy] = []
var _spawn_budget := 0.0
var _next_wave_time := 0.0
var _relocate_timer := 0.0
var _point_query := PhysicsPointQueryParameters3D.new()


func _ready() -> void:
	_next_wave_time = wave_interval
	_point_query.collision_mask = 1
	for i in prewarm_count:
		_pool.append(_create_enemy())


func _physics_process(delta: float) -> void:
	var player := Game.player
	if player == null or enemy_types.is_empty():
		return
	var minutes := Game.run_time / 60.0
	_spawn_budget += (spawns_per_second + spawns_per_second_per_minute * minutes) * intensity * delta
	while _spawn_budget >= 1.0:
		_spawn_budget -= 1.0
		if Game.enemies.size() < max_alive:
			_spawn_one(_pick_type(), random_spawn_point(player.global_position))
	if Game.run_time >= _next_wave_time:
		# If time was fast-forwarded, missed waves don't pile up; only one wave arrives.
		_next_wave_time = (floorf(Game.run_time / wave_interval) + 1.0) * wave_interval
		Game.announce("Surrounded!")
		spawn_ring(player.global_position, wave_base_count + int(wave_count_per_minute * minutes), wave_radius)
	_relocate_timer -= delta
	if _relocate_timer <= 0.0:
		_relocate_timer = 1.0
		_relocate_stragglers(player.global_position)


## Spawns enemies in a ring around center (siege wave, boss summon).
func spawn_ring(center: Vector3, count: int, radius: float, enemy_type: EnemyType = null) -> void:
	var ring_type := enemy_type if enemy_type else enemy_types[0]
	var limit := arena_half_size - 1.5
	for i in count:
		if Game.enemies.size() >= max_alive + wave_overflow:
			break
		var angle := TAU * i / count
		var point := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		if absf(point.x) < limit and absf(point.z) < limit and is_point_free(point):
			_spawn_one(ring_type, point)


## Looks for an unobstructed point around the player, outside the camera's view.
func random_spawn_point(center: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var limit := arena_half_size - 1.5
	var fallback := center
	for attempt in 10:
		var angle := randf() * TAU
		var distance := randf_range(spawn_distance_min, spawn_distance_max)
		var point := center + Vector3(cos(angle), 0.0, sin(angle)) * distance
		point.x = clampf(point.x, -limit, limit)
		point.z = clampf(point.z, -limit, limit)
		if not is_point_free(point):
			continue
		fallback = point
		var visible_on_screen := camera != null and (camera.is_position_in_frustum(point)
				or camera.is_position_in_frustum(point + Vector3.UP * 2.0))
		if not visible_on_screen:
			return point
	return fallback


## True if there is no pillar or wall at the point. Only call during a physics frame.
func is_point_free(point: Vector3) -> bool:
	_point_query.position = point + Vector3.UP
	return get_world_3d().direct_space_state.intersect_point(_point_query, 1).is_empty()


func _spawn_one(enemy_type: EnemyType, at: Vector3) -> void:
	var enemy: Enemy = _pool.pop_back() if not _pool.is_empty() else _create_enemy()
	enemy.spawn(enemy_type, at, 1.0 + health_growth_per_minute * Game.run_time / 60.0)


func _create_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.visible = false
	enemy.died.connect(_on_enemy_died)
	enemy.returned_to_pool.connect(_on_enemy_returned)
	add_child(enemy)
	return enemy


func _pick_type() -> EnemyType:
	var total_weight := 0.0
	for enemy_type in enemy_types:
		if Game.run_time >= enemy_type.unlock_time:
			total_weight += enemy_type.spawn_weight
	var roll := randf() * total_weight
	for enemy_type in enemy_types:
		if Game.run_time >= enemy_type.unlock_time:
			roll -= enemy_type.spawn_weight
			if roll <= 0.0:
				return enemy_type
	return enemy_types[0]


func _relocate_stragglers(center: Vector3) -> void:
	var limit_squared := relocate_distance * relocate_distance
	for enemy in Game.enemies:
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length_squared() > limit_squared:
			enemy.relocate(random_spawn_point(center))


func _on_enemy_died(enemy: Enemy) -> void:
	Game.pickups.spawn_xp(enemy.global_position, enemy.type.xp_value)


func _on_enemy_returned(enemy: Enemy) -> void:
	_pool.append(enemy)
