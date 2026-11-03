class_name Player
extends CharacterBody3D
## The player character: movement, mouse aiming, automatic Sword Swing, the 4 loadout powers,
## health, shield and in-run level. Permanent bonuses (equipment, core tree) and the power
## loadout (skill tree) are read from the profile at the start of a run. The body is the KayKit
## Knight, animated by a CharacterAnimator.

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
const HURT_COLOR := Color(1.0, 0.25, 0.2)
const MODEL_SCENE := preload("res://models/kaykit/adventurers/Knight.glb")
## The Knight is about 2.5 m tall at scale 1; this brings it to the 2 m of the collision capsule.
const MODEL_SCALE := 0.8
const MODEL_PROPS: Array[String] = ["1H_Sword", "Badge_Shield"]
## Sword Swing animations, used in turn.
const SWING_ANIMATIONS: Array[StringName] = [&"1H_Melee_Attack_Slice_Horizontal", &"1H_Melee_Attack_Slice_Diagonal",
		&"1H_Melee_Attack_Chop"]
## A hit taking at least this share of max health makes the Knight flinch.
const FLINCH_DAMAGE_RATIO := 0.08
## The Knight turns to the enemy it swings at for this long, then back to the mouse.
const SWING_FACE_TIME := 0.3
## How quickly the model turns to its target direction (higher is snappier).
const TURN_SHARPNESS := 25.0
const SLASH_COLOR := Color(0.85, 0.9, 1.0)
const LEVEL_UP_COLOR := Color(0.75, 0.6, 1.0)
## Hit sparks are shown on at most this many enemies per swing.
const MAX_SWING_SPARKS := 3
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
var animator: CharacterAnimator

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
var _swing_index := 0
var _swing_direction := Vector3.ZERO
var _swing_face_left := 0.0
## The model's visible meshes, for the red hurt overlay.
var _meshes: Array[MeshInstance3D] = []

static var _hurt_material: StandardMaterial3D

@onready var _model: Node3D = $Model


func _ready() -> void:
	if _hurt_material == null:
		# Drawn over the model's own materials for a moment when hit.
		_hurt_material = StandardMaterial3D.new()
		_hurt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hurt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hurt_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_hurt_material.albedo_color = Color(1.0, 0.15, 0.1, 0.6)
	_build_model()
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
	_update_facing(delta)
	_update_locomotion()
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


## Whirlwind: the model turns while holding the spinning pose.
func set_spinning(enabled: bool) -> void:
	_is_spinning = enabled
	if enabled:
		animator.hold(&"2H_Melee_Attack_Spinning", 1.2)
	else:
		animator.release()


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
	_set_hurt_overlay(true)
	Fx.burst(&"sparks", global_position + Vector3.UP, HURT_COLOR, 0.5)
	Audio.play("player_hurt")
	Game.shake(0.2)
	if health <= 0.0:
		_is_dead = true
		Fx.burst(&"gore", global_position + Vector3.UP, HURT_COLOR)
		Audio.play("player_death")
		# The fall keeps playing under the result screen, which pauses the game.
		animator.process_mode = Node.PROCESS_MODE_ALWAYS
		animator.hold(&"Death_A")
		died.emit()
	elif amount >= FLINCH_DAMAGE_RATIO * max_health and not animator.is_upper_busy():
		animator.play_upper(&"Hit_A", 0.35)


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
		Fx.burst(&"ring", global_position + Vector3.UP * 0.5, LEVEL_UP_COLOR)
		Fx.burst(&"glints", global_position + Vector3.UP, LEVEL_UP_COLOR)
		Audio.play("level_up")
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


## Shadow Dash: the dodge roll that matches the dash direction relative to where the Knight faces.
func play_dodge(direction: Vector3, seconds: float) -> void:
	var forward := -_model.global_basis.z
	var right := _model.global_basis.x
	var along := direction.dot(forward)
	var across := direction.dot(right)
	var animation := &"Dodge_Forward" if along >= 0.0 else &"Dodge_Backward"
	if absf(across) > absf(along):
		animation = &"Dodge_Right" if across > 0.0 else &"Dodge_Left"
	animator.play_full(animation, seconds)


## The Knight model: turned to face -Z like the rest of the game, scaled to the collision
## capsule, holding only its sword and shield.
func _build_model() -> void:
	var model := MODEL_SCENE.instantiate() as Node3D
	model.rotation.y = PI
	model.scale = Vector3.ONE * MODEL_SCALE
	_model.add_child(model)
	ModelTools.keep_props(model, MODEL_PROPS)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible:
			_meshes.append(mesh)
	animator = CharacterAnimator.new()
	model.add_child(animator)
	animator.setup(MODEL_SCALE)


## Faces the mouse, except right after a swing (the enemy it swung at) and while spinning.
func _update_facing(delta: float) -> void:
	if _is_spinning:
		_model.rotation.y += SPIN_SPEED * delta
		return
	var target := aim_direction()
	if _swing_face_left > 0.0:
		_swing_face_left -= delta
		target = _swing_direction
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw_towards(target), 1.0 - exp(-TURN_SHARPNESS * delta))


## Feeds the animator the movement relative to where the Knight faces.
func _update_locomotion() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var forward := -_model.global_basis.z
	var right := _model.global_basis.x
	var direction := Vector2(flat.dot(right), flat.dot(forward)) / maxf(move_speed, 0.1)
	animator.set_locomotion(direction, flat.length())


func _set_hurt_overlay(enabled: bool) -> void:
	for mesh in _meshes:
		mesh.material_overlay = _hurt_material if enabled else null


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
			_set_hurt_overlay(false)


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
	var hit := Game.enemies_in_cone(global_position, direction, reach, half_angle)
	for i in hit.size():
		var enemy := hit[i]
		var push := enemy.global_position - global_position
		push.y = 0.0
		if i < MAX_SWING_SPARKS:
			Fx.burst(&"sparks", enemy.global_position + Vector3.UP * 0.9, SLASH_COLOR, 0.5)
		enemy.take_damage(damage, push.normalized() * attack_knockback)
	Fx.slash(global_position, direction, reach, half_angle, SLASH_COLOR)
	_swing_direction = direction
	_swing_face_left = minf(_attack_timer, SWING_FACE_TIME)
	animator.play_upper(SWING_ANIMATIONS[_swing_index], maxf(_attack_timer, 0.3))
	_swing_index = (_swing_index + 1) % SWING_ANIMATIONS.size()
	Audio.play("swing")
	if not hit.is_empty():
		Audio.play("hit")


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
