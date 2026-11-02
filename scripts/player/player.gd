class_name Player
extends CharacterBody3D
## The player character: movement, mouse aiming, automatic Sword Swing, the 4 loadout powers,
## health, shield and in-run level. Permanent bonuses (equipment, core tree) and the power
## loadout (skill tree) are read from the profile at the start of a run.

signal health_changed(current: float, maximum: float)
## Emitted when damage actually lands (hits during a dash or absorbed by the shield don't count). Interrupts the extraction channel.
signal damaged(amount: float)
signal shield_changed(amount: float)
## Emitted when the shield breaks or expires.
signal shield_ended
signal xp_changed(current: int, required: int, level: int)
signal leveled_up(level: int)
signal died

## Kinds of temporary multipliers applied by powers (War Cry, Whirlwind, Shadow Trail...).
enum Modifier { MOVE_SPEED, DAMAGE, ATTACK_SPEED, COOLDOWN_RATE }

const BODY_RADIUS := 0.45
const ABILITY_ACTIONS: Array[String] = ["ability_1", "ability_2", "ability_3", "ability_4"]
const ENEMY_COLLISION_BIT := 4
const HURT_FLASH_TIME := 0.12
const SLASH_COLOR := Color(0.85, 0.9, 1.0)
## Model spin speed during Whirlwind (rad/s).
const SPIN_SPEED := 18.0

@export_group("Base Stats")
@export var base_max_health := 100.0
@export var base_move_speed := 6.5
@export var base_pickup_radius := 3.0

@export_group("Sword Swing")
@export var base_attack_interval := 0.55
@export var attack_damage := 14.0
## Swings automatically at the nearest enemy within this distance (m).
@export var attack_reach := 3.0
## Swing arc; 90 degrees = a quarter ring.
@export var attack_arc_degrees := 90.0
@export var attack_knockback := 4.0

var max_health := 0.0
var health := 0.0
var shield := 0.0
## Thorns damage dealt to enemies that hit you while shielded (Bone Shield).
var thorns_damage := 0.0
## Extra damage taken by frozen enemies, as a ratio (Frost Nova option).
var frozen_damage_bonus := 0.0
var move_speed := 0.0
var pickup_radius := 0.0
var attack_interval := 0.0
var health_regen := 0.0
var cooldown_multiplier := 1.0
## Permanent damage reduction (0..1) and power area multiplier; both come from equipment and the core tree.
var damage_reduction := 0.0
var area_multiplier := 1.0
var level := 1
var xp := 0
## Total XP collected this run; counts toward the character level if you escape.
var run_xp := 0
## Mouse position projected onto the ground (y = 0).
var aim_point := Vector3.ZERO
## Powers in key order (ability_1..ability_4); an empty slot is null.
var abilities: Array[Ability] = []

var _boon_ranks: Dictionary[String, int] = {}
var _modifiers: Array[Dictionary] = [{}, {}, {}, {}]
var _attack_timer := 0.0
var _move_direction := Vector3.ZERO
var _dash_velocity := Vector3.ZERO
var _dash_time_left := 0.0
var _shield_time_left := 0.0
var _hurt_flash_time := 0.0
var _is_dead := false
var _is_spinning := false
## Permanent bonuses read from the profile at the start of the run: {stat: value}.
var _meta: Dictionary = {}

static var _hurt_material: StandardMaterial3D

@onready var _model: Node3D = $Model
@onready var _body_mesh: MeshInstance3D = $Model/Body


func _ready() -> void:
	if _hurt_material == null:
		_hurt_material = StandardMaterial3D.new()
		_hurt_material.albedo_color = Color(1.0, 0.25, 0.2)
		_hurt_material.emission_enabled = true
		_hurt_material.emission = Color(1.0, 0.1, 0.05)
	_meta = Profile.bonuses()
	_recalculate_stats()
	health = max_health
	aim_point = global_position + Vector3.FORWARD
	_build_abilities()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_update_aim()
	_tick_timers(delta)
	_move()
	if _is_spinning:
		_model.rotation.y += SPIN_SPEED * delta
	else:
		_model.rotation.y = _yaw_towards(aim_direction())
	_update_auto_attack(delta)
	for i in abilities.size():
		if abilities[i] and Input.is_action_pressed(ABILITY_ACTIONS[i]):
			abilities[i].try_activate()
	if health_regen > 0.0:
		heal(health_regen * delta)


## Horizontal direction from the character to the aim point.
func aim_direction() -> Vector3:
	var offset := aim_point - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return Vector3.FORWARD.rotated(Vector3.UP, _model.rotation.y)
	return offset.normalized()


## Direction of the latest movement input; zero when standing still.
func move_direction() -> Vector3:
	return _move_direction


func facing_yaw() -> float:
	return _model.rotation.y


## Permanent bonus from equipment and the core tree (0 if none).
func meta_value(stat: String) -> float:
	return _meta.get(stat, 0.0)


func damage_multiplier() -> float:
	var base := 1.0 + BoonLibrary.total(self, "might") + meta_value("damage_pct")
	return base * modifier(Modifier.DAMAGE)


## Sets a temporary multiplier under a source name; setting it again from the same source overwrites it.
func set_modifier(kind: Modifier, source: String, multiplier: float) -> void:
	_modifiers[kind][source] = multiplier


func clear_modifier(kind: Modifier, source: String) -> void:
	_modifiers[kind].erase(source)


## Product of all temporary multipliers of that kind (1 if none).
func modifier(kind: Modifier) -> float:
	var total := 1.0
	for value: float in _modifiers[kind].values():
		total *= value
	return total


func set_spinning(enabled: bool) -> void:
	_is_spinning = enabled


func take_damage(amount: float) -> void:
	if _is_dead or is_dashing():
		return
	amount *= 1.0 - damage_reduction
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		shield_changed.emit(shield)
		if shield <= 0.0:
			_end_shield()
		if amount <= 0.0:
			return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	_hurt_flash_time = HURT_FLASH_TIME
	_body_mesh.material_override = _hurt_material
	Game.shake(0.2)
	if health <= 0.0:
		_is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _is_dead:
		return
	var before := health
	health = minf(health + amount, max_health)
	if health != before:
		health_changed.emit(health, max_health)


## Bone Shield: replaces any existing shield.
func add_shield(amount: float, duration: float) -> void:
	shield = amount
	_shield_time_left = duration
	shield_changed.emit(shield)


func add_xp(amount: int) -> void:
	xp += amount
	run_xp += amount
	while xp >= xp_required():
		xp -= xp_required()
		level += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_required(), level)


## XP required for the next in-run level.
func xp_required() -> int:
	return 5 + (level - 1) * 6


func rank(boon_id: String) -> int:
	return _boon_ranks.get(boon_id, 0)


func add_boon(boon_id: String) -> void:
	if boon_id == BoonLibrary.HEAL_ID:
		heal(BoonLibrary.value(boon_id))
		return
	_boon_ranks[boon_id] = rank(boon_id) + 1
	_recalculate_stats()
	if boon_id == "vitality":
		heal(BoonLibrary.value(boon_id))


## Called by Shadow Dash and Earthquake Leap: moves at the given velocity for a short time,
## passing through enemies and taking no damage meanwhile.
func start_dash(dash_velocity: Vector3, duration: float) -> void:
	_dash_velocity = dash_velocity
	_dash_time_left = duration
	collision_mask &= ~ENEMY_COLLISION_BIT


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## Builds the power nodes from the profile's loadout.
func _build_abilities() -> void:
	for i in ABILITY_ACTIONS.size():
		var skill_id: String = Profile.loadout[i] if i < Profile.loadout.size() else ""
		var ability: Ability = null
		if skill_id != "" and Profile.skill_rank(skill_id) > 0:
			ability = SkillLibrary.create_ability(skill_id)
			$Abilities.add_child(ability)
			ability.setup(self, skill_id, Profile.skill_state(skill_id))
		abilities.append(ability)


func _update_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit != null:
		aim_point = hit


func _tick_timers(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			collision_mask |= ENEMY_COLLISION_BIT
	if _shield_time_left > 0.0:
		_shield_time_left -= delta
		if _shield_time_left <= 0.0 and shield > 0.0:
			_end_shield()
	if _hurt_flash_time > 0.0:
		_hurt_flash_time -= delta
		if _hurt_flash_time <= 0.0:
			_body_mesh.material_override = null


func _end_shield() -> void:
	shield = 0.0
	_shield_time_left = 0.0
	shield_changed.emit(shield)
	shield_ended.emit()


func _move() -> void:
	if is_dashing():
		velocity = _dash_velocity
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_move_direction = _camera_relative(input)
		velocity = _move_direction * move_speed * modifier(Modifier.MOVE_SPEED)
	move_and_slide()
	if absf(global_position.y) > 0.001:
		global_position.y = 0.0


## Maps WASD relative to the camera's facing (W = up on screen).
func _camera_relative(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input.x, 0.0, input.y)
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


## Sword Swing: a quarter ring towards the nearest enemy in reach; everyone in the arc is hit.
func _update_auto_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var reach := attack_reach * (1.0 + BoonLibrary.total(self, "reach"))
	var target := Game.nearest_enemy(global_position, reach + 0.5)
	if target == null:
		return
	_attack_timer = attack_interval / modifier(Modifier.ATTACK_SPEED)
	var direction := target.global_position - global_position
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0001 else aim_direction()
	var arc_degrees := minf(attack_arc_degrees + BoonLibrary.total(self, "arc"), 360.0)
	var half_angle := deg_to_rad(arc_degrees * 0.5)
	var damage := attack_damage * damage_multiplier()
	for enemy in Game.enemies_in_cone(global_position, direction, reach, half_angle):
		var push := enemy.global_position - global_position
		push.y = 0.0
		enemy.take_damage(damage, push.normalized() * attack_knockback)
	Fx.slash(global_position, direction, reach, half_angle, SLASH_COLOR)


## Boons (in-run) and permanent bonuses (equipment, core tree) are combined here.
func _recalculate_stats() -> void:
	max_health = base_max_health + BoonLibrary.total(self, "vitality") + meta_value("max_health")
	move_speed = base_move_speed * (1.0 + BoonLibrary.total(self, "swiftness") + meta_value("move_speed_pct"))
	pickup_radius = base_pickup_radius * (1.0 + BoonLibrary.total(self, "magnet") + meta_value("pickup_pct"))
	attack_interval = base_attack_interval / (1.0 + BoonLibrary.total(self, "attack_speed") + meta_value("attack_speed_pct"))
	health_regen = BoonLibrary.total(self, "regen") + meta_value("regen")
	cooldown_multiplier = pow(1.0 - BoonLibrary.value("haste"), rank("haste")) * (1.0 - meta_value("cooldown_pct"))
	damage_reduction = meta_value("damage_reduction_pct")
	area_multiplier = 1.0 + meta_value("area_pct")
	health = minf(health, max_health)
	health_changed.emit(health, max_health)


## Y angle that turns a model facing -Z towards the given direction.
static func _yaw_towards(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
