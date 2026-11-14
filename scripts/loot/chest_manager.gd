class_name ChestManager
extends Node3D
## Places loot chests around the map; a chest opens when the player gets close and gives gold
## and sometimes an item. This is run loot: you lose it if you don't make it out through a gate.

@export var initial_count := 8
@export var max_count := 10
## Interval at which a new chest is added while the count is below max_count (s).
@export var respawn_interval := 45.0
@export var open_distance := 1.8
## New chests are never placed closer than this to the player.
@export var min_spawn_distance := 12.0
@export var base_gold := 15
## Each minute of the run adds this much gold per chest.
@export var gold_per_minute := 4
## Chance that a chest drops an item; the "Item find" bonus raises it.
@export_range(0.0, 1.0) var item_chance := 0.25

var _chests: Array[Node3D] = []
var _respawn_timer := 0.0
var _started := false
var _body_mesh := BoxMesh.new()
var _band_mesh := BoxMesh.new()


func _ready() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.35, 0.2, 0.1)
	_body_mesh.material = body_material
	_body_mesh.size = Vector3(1.0, 0.6, 0.7)
	var band_material := StandardMaterial3D.new()
	band_material.albedo_color = Color(1.0, 0.75, 0.25)
	band_material.emission_enabled = true
	band_material.emission = Color(1.0, 0.7, 0.2)
	band_material.emission_energy_multiplier = 2.5
	_band_mesh.material = band_material
	_band_mesh.size = Vector3(1.05, 0.12, 0.75)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if player == null or Game.spawner == null or Game.director == null:
		return
	if not _started:
		_started = true
		for i in initial_count:
			_spawn_chest(player.global_position)
	_respawn_timer += delta
	if _respawn_timer >= respawn_interval:
		_respawn_timer = 0.0
		if _chests.size() < max_count:
			_spawn_chest(player.global_position)
	var open_squared := open_distance * open_distance
	for i in range(_chests.size() - 1, -1, -1):
		var offset := _chests[i].global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= open_squared:
			var chest := _chests[i]
			_chests.remove_at(i)
			_open(chest)


func _spawn_chest(avoid: Vector3) -> void:
	var limit := Game.spawner.arena_half_size - 3.0
	for attempt in 20:
		var point := Vector3(randf_range(-limit, limit), 0.0, randf_range(-limit, limit))
		if point.distance_to(avoid) < min_spawn_distance or not Game.spawner.is_point_free(point):
			continue
		var chest := Node3D.new()
		chest.position = point
		chest.rotation.y = randf() * TAU
		var body := MeshInstance3D.new()
		body.mesh = _body_mesh
		body.position.y = 0.3
		chest.add_child(body)
		var band := MeshInstance3D.new()
		band.mesh = _band_mesh
		band.position.y = 0.45
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chest.add_child(band)
		add_child(chest)
		_chests.append(chest)
		return


func _open(chest: Node3D) -> void:
	var amount := base_gold + int(gold_per_minute * Game.run_time / 60.0)
	Game.director.add_gold(amount, chest.global_position)
	if randf() < item_chance * (1.0 + Game.player.meta_value("item_find_pct")):
		Game.director.add_item(ItemGenerator.roll_drop(ItemGenerator.Source.CHEST), chest.global_position)
	Fx.ring(chest.global_position, 1.6, RunDirector.GOLD_COLOR)
	Fx.burst(&"glints", chest.global_position + Vector3.UP * 0.6, RunDirector.GOLD_COLOR)
	Audio.play("chest")
	chest.queue_free()
