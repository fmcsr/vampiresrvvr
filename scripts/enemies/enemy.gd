class_name Enemy
extends CharacterBody3D
## Horde enemy: walks toward the player and deals damage on contact. Reused from the EnemySpawner pool.

## Emitted the moment it dies (to drop an XP gem).
signal died(enemy: Enemy)
## Emitted once it has left the scene and is ready to return to the pool.
signal returned_to_pool(enemy: Enemy)

const BASE_RADIUS := 0.4
const BASE_HEIGHT := 1.7
const CONTACT_MARGIN := 0.25
const KNOCKBACK_DECAY := 30.0
const FLASH_TIME := 0.08
const BURN_TICK := 0.5

var type: EnemyType
var is_alive := false
var body_radius := BASE_RADIUS
var health := 1.0
var max_health := 1.0

var _knockback := Vector3.ZERO
var _attack_cooldown := 0.0
var _freeze_time := 0.0
var _burn_time := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _flash_time := 0.0

static var _flash_material: StandardMaterial3D
static var _frozen_material: StandardMaterial3D
static var _burning_material: StandardMaterial3D

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _model: Node3D = $Model
@onready var _body_mesh: MeshInstance3D = $Model/Body


func _ready() -> void:
	# Duplicate the shape so each enemy can set its own size.
	_shape.shape = _shape.shape.duplicate()
	if _flash_material == null:
		_flash_material = _make_material(Color(1.0, 1.0, 1.0), 2.0)
		_frozen_material = _make_material(Color(0.55, 0.85, 1.0), 0.6)
		_burning_material = _make_material(Color(1.0, 0.45, 0.15), 0.8)


## Called when taken from the pool: applies the type and activates the enemy in the scene.
func spawn(enemy_type: EnemyType, at: Vector3, health_multiplier: float) -> void:
	type = enemy_type
	max_health = type.max_health * health_multiplier
	health = max_health
	body_radius = BASE_RADIUS * type.size
	var capsule := _shape.shape as CapsuleShape3D
	capsule.radius = body_radius
	capsule.height = BASE_HEIGHT * type.size
	_shape.position.y = capsule.height * 0.5
	_model.scale = Vector3.ONE * type.size
	_knockback = Vector3.ZERO
	_attack_cooldown = 0.0
	_freeze_time = 0.0
	_burn_time = 0.0
	_burn_dps = 0.0
	_flash_time = 0.0
	_refresh_material()
	global_position = at
	velocity = Vector3.ZERO
	is_alive = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	reset_physics_interpolation()
	Game.enemies.append(self)


## Moved back near the player when it falls too far behind.
func relocate(at: Vector3) -> void:
	global_position = at
	_knockback = Vector3.ZERO
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_update_status(delta)
	var player := Game.player
	if not is_alive or player == null:
		return
	_chase(player, delta)


## Walks toward the player; on contact, deals damage at fixed intervals.
func _chase(player: Player, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var direction := to_player / distance if distance > 0.001 else Vector3.ZERO
	var is_frozen := _freeze_time > 0.0
	velocity = (Vector3.ZERO if is_frozen else direction * type.move_speed) + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	if absf(global_position.y) > 0.001:
		global_position.y = 0.0
	if is_frozen:
		return
	if direction != Vector3.ZERO:
		_model.rotation.y = atan2(-direction.x, -direction.z)
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0 and distance <= body_radius + Player.BODY_RADIUS + CONTACT_MARGIN:
		_attack_cooldown = type.attack_interval
		player.take_damage(type.contact_damage)
		# Bone Shield (Enhanced): enemies that hit a shielded player take damage.
		if player.thorns_damage > 0.0:
			take_damage(player.thorns_damage)


func take_damage(amount: float, knockback := Vector3.ZERO, flash := true) -> void:
	if not is_alive:
		return
	if _freeze_time > 0.0:
		amount *= 1.0 + Game.player.frozen_damage_bonus
	health -= amount
	if knockback != Vector3.ZERO:
		_knockback += knockback * (1.0 - type.knockback_resistance)
	if flash:
		_flash_time = FLASH_TIME
		_refresh_material()
	if health <= 0.0:
		_die()


func freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	_refresh_material()


func apply_burn(damage_per_second: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, damage_per_second)
	_burn_time = maxf(_burn_time, duration)
	_refresh_material()


func _update_status(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_refresh_material()
	if _freeze_time > 0.0:
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			_refresh_material()
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			take_damage(_burn_dps * BURN_TICK, Vector3.ZERO, false)
		if _burn_time <= 0.0:
			_burn_dps = 0.0
			_refresh_material()


func _refresh_material() -> void:
	var material: Material = type.get_material()
	if _flash_time > 0.0:
		material = _flash_material
	elif _freeze_time > 0.0:
		material = _frozen_material
	elif _burn_time > 0.0:
		material = _burning_material
	if _body_mesh.material_override != material:
		_body_mesh.material_override = material


func _die() -> void:
	is_alive = false
	Game.enemies.erase(self)
	Game.kills += 1
	died.emit(self)
	# The body can't be removed during a physics query; return to the pool at the end of the frame.
	_return_to_pool.call_deferred()


func _return_to_pool() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	returned_to_pool.emit(self)


static func _make_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	return material
