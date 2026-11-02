extends Node
## Shared meeting point where systems find each other during a run.
## Main resets it at the start of every run and fills in the references.

## Shows a short announcement on the HUD (e.g. "Surrounded!").
signal announced(text: String)
## Shakes the camera; strength ranges from 0 to 1.
signal camera_shake_requested(strength: float)

var player: Player
## Root node that projectiles and effects are added to.
var world: Node3D
var pickups: PickupManager
var spawner: EnemySpawner
var director: RunDirector
var particles: ParticleBursts
var damage_numbers: DamageNumbers
## Enemies currently alive in the scene.
var enemies: Array[Enemy] = []
var run_time := 0.0
var kills := 0

## Unscaled seconds left in the current hit-stop.
var _slow_left := 0.0


func reset() -> void:
	player = null
	world = null
	pickups = null
	spawner = null
	director = null
	particles = null
	damage_numbers = null
	enemies.clear()
	run_time = 0.0
	kills = 0
	_slow_left = 0.0
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _slow_left <= 0.0:
		return
	# delta is scaled by Engine.time_scale; dividing it back out counts unscaled seconds.
	_slow_left -= delta / maxf(Engine.time_scale, 0.001)
	if _slow_left <= 0.0:
		Engine.time_scale = 1.0


func announce(text: String) -> void:
	announced.emit(text)


func shake(strength: float) -> void:
	camera_shake_requested.emit(strength)


## Hit-stop: slows time for a moment so a big hit lands harder (a boss dying slows longer and
## gentler). A call shorter than what is left of the current one is ignored. The countdown
## pauses with the game.
func hit_stop(duration: float, time_scale := 0.05) -> void:
	if duration <= _slow_left:
		return
	_slow_left = duration
	Engine.time_scale = time_scale


func nearest_enemy(origin: Vector3, max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_distance_squared := max_distance * max_distance
	for enemy in enemies:
		var distance_squared := _flat_distance_squared(origin, enemy.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = enemy
	return best


func enemies_in_radius(center: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies:
		var reach := radius + enemy.body_radius
		if _flat_distance_squared(center, enemy.global_position) <= reach * reach:
			result.append(enemy)
	return result


## Cone on the ground opening from origin towards direction (half_angle in radians).
func enemies_in_cone(origin: Vector3, direction: Vector3, reach: float, half_angle: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	var min_dot := cos(half_angle)
	for enemy in enemies:
		var offset := enemy.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > reach + enemy.body_radius:
			continue
		# Enemies right next to the player are hit regardless of direction.
		if distance <= enemy.body_radius + 0.6 or forward.dot(offset / distance) >= min_dot:
			result.append(enemy)
	return result


## Enemies within radius of the segment from a to b (dash path).
func enemies_near_segment(a: Vector3, b: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var start := Vector2(a.x, a.z)
	var end := Vector2(b.x, b.z)
	for enemy in enemies:
		var point := Vector2(enemy.global_position.x, enemy.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(point, start, end)
		var reach := radius + enemy.body_radius
		if point.distance_squared_to(closest) <= reach * reach:
			result.append(enemy)
	return result


func _flat_distance_squared(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz
