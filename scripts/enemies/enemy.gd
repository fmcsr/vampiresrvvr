class_name Enemy
extends CharacterBody3D
## Horde enemy: walks toward the player and swings at them when close. The hit lands after a
## short windup, so stepping out of reach in time avoids it. Reused from the EnemySpawner pool.
## Types with a model show an animated KayKit character (merged into one mesh, with a blob
## shadow) that collapses when it dies and sinks into the ground before going back to the pool.

## Emitted the moment it dies (to drop an XP gem).
signal died(enemy: Enemy)
## Emitted once it has left the scene and is ready to return to the pool.
signal returned_to_pool(enemy: Enemy)

const BASE_RADIUS := 0.4
const BASE_HEIGHT := 1.7
const CONTACT_MARGIN := 0.25
## Extra reach (m at size 1) when the swing lands: the weapon reaches past the body.
const HIT_REACH := 0.5
## After its hit lands, an enemy holds still this long before it chases again.
const SWING_RECOVERY := 0.25
const KNOCKBACK_DECAY := 30.0
const FLASH_TIME := 0.08
## The model squashes for a moment when hit.
const SQUASH_TIME := 0.12
const BURN_TICK := 0.5
const BURN_COLOR := Color(1.0, 0.55, 0.2)
const TURN_SHARPNESS := 12.0
## Climbing out of the ground takes this long; it can be hit meanwhile but doesn't move or attack.
const RISE_TIME := 1.2
const RISE_DUST := Color(0.42, 0.36, 0.3, 0.6)
## A dead enemy lies this long, then sinks this deep into the ground over SINK_TIME.
const CORPSE_TIME := 1.3
const SINK_TIME := 0.6
const SINK_DEPTH := 0.9
## Blob shadow diameter at size 1 (m).
const BLOB_SIZE := 1.3
## Above this many enemies, each model's animation advances every other frame (staggered).
## Off-screen models don't animate at all.
const ANIMATION_CROWD := 100
const WALK_BLEND := 0.15
## Skinned models are culled by this box (model space), wide enough for a lying corpse.
const MODEL_BOUNDS := AABB(Vector3(-1.5, -0.5, -2.0), Vector3(3.0, 3.2, 4.0))

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
var _squash_time := 0.0
var _rise_left := 0.0
var _swing_left := 0.0
var _hit_left := 0.0
var _dying_left := 0.0
## The type whose model is built; the spawner pools enemies per type, so it's built only once.
var _built_for: EnemyType
var _meshes: Array[GeometryInstance3D] = []
var _animation: AnimationPlayer
var _animation_delta := 0.0
var _animation_slot := 0
var _on_screen: VisibleOnScreenNotifier3D
var _blob: MeshInstance3D

static var _flash_material: StandardMaterial3D
static var _frozen_material: StandardMaterial3D
static var _burning_material: StandardMaterial3D
static var _blob_mesh: PlaneMesh

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _model: Node3D = $Model


func _ready() -> void:
	# Duplicate the shape so each enemy can set its own size.
	_shape.shape = _shape.shape.duplicate()
	_animation_slot = randi() % 2
	if _flash_material == null:
		_flash_material = _make_overlay(Color(1.0, 1.0, 1.0, 0.9))
		_frozen_material = _make_overlay(Color(0.4, 0.75, 1.0, 0.6))
		_burning_material = _make_overlay(Color(1.0, 0.4, 0.1, 0.5))
		_blob_mesh = _make_blob_mesh()


## Builds the type's model up front (the spawner does this for its pools).
func prepare(enemy_type: EnemyType) -> void:
	if _built_for != enemy_type:
		_build(enemy_type)


## Called when taken from the pool: applies the type and activates the enemy in the scene.
## rising: it climbs out of the ground first (siege waves, summons).
func spawn(enemy_type: EnemyType, at: Vector3, health_multiplier: float, rising := false) -> void:
	prepare(enemy_type)
	type = enemy_type
	max_health = type.max_health * health_multiplier
	health = max_health
	body_radius = BASE_RADIUS * type.size
	var capsule := _shape.shape as CapsuleShape3D
	capsule.radius = body_radius
	capsule.height = BASE_HEIGHT * type.size
	_shape.position.y = capsule.height * 0.5
	_shape.set_deferred("disabled", false)
	_model.scale = Vector3.ONE * type.size
	_model.position = Vector3.ZERO
	_knockback = Vector3.ZERO
	_attack_cooldown = 0.0
	_freeze_time = 0.0
	_burn_time = 0.0
	_burn_dps = 0.0
	_flash_time = 0.0
	_squash_time = 0.0
	_swing_left = 0.0
	_hit_left = 0.0
	_dying_left = 0.0
	_rise_left = RISE_TIME if rising and _animation else 0.0
	_refresh_material()
	global_position = at
	velocity = Vector3.ZERO
	is_alive = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if Game.player:
		var to_player := Game.player.global_position - at
		_model.rotation.y = atan2(-to_player.x, -to_player.z)
	if _blob:
		_blob.scale = Vector3.ONE * BLOB_SIZE * type.size
	if _animation:
		if rising:
			var clip := _animation.get_animation(type.rise_animation)
			_play(type.rise_animation, clip.length / RISE_TIME, 0.0)
			Fx.burst(&"dust", at, RISE_DUST, 0.5)
		else:
			_play_walk(0.0)
			# Out of step with the rest of the horde.
			_animation.seek(randf() * _animation.current_animation_length, true)
	reset_physics_interpolation()
	Game.enemies.append(self)


## Moved back near the player when it falls too far behind.
func relocate(at: Vector3) -> void:
	global_position = at
	_knockback = Vector3.ZERO
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _dying_left > 0.0:
		_update_status(delta)
		_update_dying(delta)
		return
	if not is_alive:
		return
	_update_status(delta)
	var player := Game.player
	if not is_alive or player == null:
		return
	_chase(player, delta)


## Advances the model's animation while it's on screen; in a big crowd only every other frame,
## half the models at a time. Time spent off screen is caught up in one step.
func _process(delta: float) -> void:
	if _animation == null or _freeze_time > 0.0:
		return
	_animation_delta += delta
	if not _on_screen.is_on_screen():
		return
	if Game.enemies.size() <= ANIMATION_CROWD or (Engine.get_process_frames() + _animation_slot) % 2 == 0:
		_animation.advance(_animation_delta)
		_animation_delta = 0.0


## Walks toward the player; in reach, swings at them (the hit lands after the windup).
func _chase(player: Player, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var direction := to_player / distance if distance > 0.001 else Vector3.ZERO
	var is_frozen := _freeze_time > 0.0
	var holds_still := is_frozen or _rise_left > 0.0 or _swing_left > 0.0
	velocity = (Vector3.ZERO if holds_still else direction * type.move_speed) + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	if absf(global_position.y) > 0.001:
		global_position.y = 0.0
	if is_frozen or _rise_left > 0.0:
		return
	if direction != Vector3.ZERO:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-TURN_SHARPNESS * delta))
	_attack_cooldown -= delta
	if _swing_left > 0.0:
		_update_swing(player, distance, delta)
	elif _attack_cooldown <= 0.0 and distance <= _reach():
		_attack_cooldown = type.attack_interval
		_hit_left = type.attack_windup
		_swing_left = type.attack_windup + SWING_RECOVERY
		_play(type.attack_animation, type.attack_hit_time / type.attack_windup, 0.08)


func _update_swing(player: Player, distance: float, delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left -= delta
		if _hit_left <= 0.0 and distance <= _reach() + HIT_REACH * type.size:
			player.take_damage(type.contact_damage)
			# Bone Shield (Enhanced): enemies that hit a shielded player take damage.
			if player.thorns_damage > 0.0:
				take_damage(player.thorns_damage, Vector3.ZERO, true, SkillLibrary.color("bone_shield"))
				if not is_alive:
					return
	_swing_left -= delta
	if _swing_left <= 0.0:
		_play_walk()


## Distance between centers at which it starts a swing.
func _reach() -> float:
	return body_radius + Player.BODY_RADIUS + CONTACT_MARGIN


## color tints the damage number (the source's color; white for the Sword Swing).
func take_damage(amount: float, knockback := Vector3.ZERO, flash := true, color := Color.WHITE) -> void:
	if not is_alive:
		return
	if _freeze_time > 0.0:
		amount *= 1.0 + Game.player.frozen_damage_bonus
	health -= amount
	if Game.damage_numbers:
		Game.damage_numbers.add(self, amount, color)
	if knockback != Vector3.ZERO:
		_knockback += knockback * (1.0 - type.knockback_resistance)
	if flash:
		_flash_time = FLASH_TIME
		_squash_time = SQUASH_TIME
		_refresh_material()
	if health <= 0.0:
		_die()


## Frozen enemies stop in place; a swing in progress is lost.
func freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	_swing_left = 0.0
	_hit_left = 0.0
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
	if _squash_time > 0.0:
		_squash_time = maxf(_squash_time - delta, 0.0)
		var squash := _squash_time / SQUASH_TIME
		_model.scale = Vector3(1.0 + 0.22 * squash, 1.0 - 0.18 * squash, 1.0 + 0.22 * squash) * type.size
	if _freeze_time > 0.0:
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			_refresh_material()
			if _rise_left <= 0.0:
				_play_walk()
	elif _rise_left > 0.0:
		_rise_left -= delta
		if _rise_left <= 0.0:
			_play_walk()
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			take_damage(_burn_dps * BURN_TICK, Vector3.ZERO, false, BURN_COLOR)
		if _burn_time <= 0.0:
			_burn_dps = 0.0
			_refresh_material()


## Status tints go on top of the model: hit flash, then frozen, then burning.
func _refresh_material() -> void:
	var overlay: Material = null
	if _flash_time > 0.0:
		overlay = _flash_material
	elif _freeze_time > 0.0:
		overlay = _frozen_material
	elif _burn_time > 0.0:
		overlay = _burning_material
	for mesh in _meshes:
		if mesh.material_overlay != overlay:
			mesh.material_overlay = overlay


func _die() -> void:
	is_alive = false
	Game.enemies.erase(self)
	Game.kills += 1
	_play_death()
	died.emit(self)
	if _animation:
		_start_dying()
	else:
		# The body can't be removed during a physics query; return to the pool at the end of the frame.
		_return_to_pool.call_deferred()


## Death sound and particles from the type; big enemies also kick up dust.
func _play_death() -> void:
	var center := global_position + Vector3.UP * (0.8 * type.size)
	Fx.burst(type.death_burst, center, type.death_color, clampf(0.6 * type.size, 0.4, 1.0))
	if type.size >= 1.4:
		Fx.burst(&"dust", global_position, Color(0.45, 0.4, 0.35, 0.6))
	Audio.play_at(type.death_sound, global_position)


## The model collapses and stays as a corpse that nothing collides with.
func _start_dying() -> void:
	_dying_left = CORPSE_TIME + SINK_TIME
	_freeze_time = 0.0
	_burn_time = 0.0
	_burn_dps = 0.0
	_rise_left = 0.0
	_swing_left = 0.0
	_hit_left = 0.0
	_refresh_material()
	_shape.set_deferred("disabled", true)
	_play(type.death_animation, 1.0, 0.05)


func _update_dying(delta: float) -> void:
	_dying_left -= delta
	# The killing blow still pushes the corpse.
	if _knockback != Vector3.ZERO:
		global_position += _knockback * delta
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	if _dying_left < SINK_TIME:
		var sunk := 1.0 - maxf(_dying_left, 0.0) / SINK_TIME
		_model.position.y = -SINK_DEPTH * type.size * sunk
		_blob.scale = Vector3.ONE * BLOB_SIZE * type.size * (1.0 - sunk)
	if _dying_left <= 0.0:
		_return_to_pool()


func _return_to_pool() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	returned_to_pool.emit(self)


func _play(animation: StringName, speed: float, blend: float) -> void:
	if _animation:
		_animation.play(animation, blend, speed)


## The walk cycle, sped up or slowed down to match the ground speed.
func _play_walk(blend := WALK_BLEND) -> void:
	var cycle_speed := type.walk_cycle_speed * type.model_scale * type.size
	_play(type.walk_animation, clampf(type.move_speed / cycle_speed, 0.5, 2.0), blend)


## Shows the type's KayKit model: its parts and weapons merged into one mesh (shared by the
## type), no shadow of its own unless the type asks for one, and a blob shadow underneath.
## Types without a model keep the scene's meshes, tinted with the type's color.
func _build(enemy_type: EnemyType) -> void:
	_built_for = enemy_type
	if enemy_type.model == null:
		var body := _model.get_node_or_null("Body") as MeshInstance3D
		if body:
			body.material_override = enemy_type.get_material()
			_meshes = [body]
		return
	var model := enemy_type.model.instantiate() as Node3D
	# KayKit models face +Z; the enemy's forward is -Z.
	model.rotation.y = PI
	model.scale = Vector3.ONE * enemy_type.model_scale
	_model.add_child(model)
	var skeleton := model.get_node("Rig/Skeleton3D") as Skeleton3D
	var parts: Array[MeshInstance3D] = []
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			parts.append(child)
	var mesh := MeshInstance3D.new()
	mesh.mesh = enemy_type.get_mesh(parts)
	mesh.skin = parts[0].skin
	# A new MeshInstance3D isn't bound to any skeleton; this one is its parent.
	mesh.skeleton = NodePath("..")
	mesh.custom_aabb = MODEL_BOUNDS
	mesh.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enemy_type.casts_shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for part in parts:
		part.free()
	skeleton.add_child(mesh)
	_meshes = [mesh]
	_animation = model.get_node("AnimationPlayer") as AnimationPlayer
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation.get_animation(enemy_type.walk_animation).loop_mode = Animation.LOOP_LINEAR
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = MODEL_BOUNDS
	model.add_child(_on_screen)
	_blob = MeshInstance3D.new()
	_blob.mesh = _blob_mesh
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.position.y = 0.03
	add_child(_blob)


static func _make_overlay(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	return material


## A soft dark disc lying on the ground.
static func _make_blob_mesh() -> PlaneMesh:
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.55))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	texture.gradient = gradient
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = material
	return mesh
