class_name Boss
extends Enemy
## Boss: chases like a horde enemy and, in between, uses telegraphed special attacks
## (ground slam, charge, skeleton summon). Not pooled; freed on death.

enum State { CHASE, WINDUP, CHARGE }

## Frost Nova freezes bosses for only this fraction of the duration.
const FREEZE_MULTIPLIER := 0.25
const SLAM_COLOR := Color(1.0, 0.3, 0.2)
const CHARGE_COLOR := Color(1.0, 0.55, 0.2)
const SUMMON_COLOR := Color(0.7, 0.5, 1.0)
const SUMMON_WINDUP := 0.8
const SUMMON_RADIUS := 4.0

var boss_type: BossType

var _state := State.CHASE
var _special_timer := 0.0
var _windup_left := 0.0
var _pending_attack := &""
var _attack_count := 0
var _charge_direction := Vector3.ZERO
var _charge_time_left := 0.0
var _charge_hit := false


func spawn(enemy_type: EnemyType, at: Vector3, health_multiplier: float) -> void:
	boss_type = enemy_type as BossType
	super(enemy_type, at, health_multiplier)
	_state = State.CHASE
	_special_timer = boss_type.special_interval


func freeze(duration: float) -> void:
	super(duration * FREEZE_MULTIPLIER)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_update_status(delta)
	var player := Game.player
	if not is_alive or player == null or _freeze_time > 0.0:
		return
	match _state:
		State.CHASE:
			_chase(player, delta)
			_special_timer -= delta
			if _special_timer <= 0.0:
				_begin_special(player)
		State.WINDUP:
			_windup_left -= delta
			if _windup_left <= 0.0:
				_execute_special(player)
		State.CHARGE:
			_update_charge(player, delta)


## Picks an attack and draws its warning on the ground; the attack lands when the warning ends.
func _begin_special(player: Player) -> void:
	_attack_count += 1
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if boss_type.summon_count > 0 and _attack_count % 3 == 0:
		_pending_attack = &"summon"
		_windup_left = SUMMON_WINDUP
		Fx.telegraph(global_position, SUMMON_RADIUS + 1.0, SUMMON_COLOR, _windup_left)
	elif to_player.length() <= boss_type.slam_radius + 1.0:
		_pending_attack = &"slam"
		_windup_left = boss_type.slam_windup
		Fx.telegraph(global_position, boss_type.slam_radius, SLAM_COLOR, _windup_left)
	else:
		_pending_attack = &"charge"
		_windup_left = boss_type.charge_windup
		_charge_direction = to_player.normalized()
		_model.rotation.y = atan2(-_charge_direction.x, -_charge_direction.z)
		Fx.lane(global_position, _charge_direction, boss_type.charge_distance, body_radius * 2.0, CHARGE_COLOR, _windup_left)
	_state = State.WINDUP


func _execute_special(player: Player) -> void:
	match _pending_attack:
		&"slam":
			var offset := player.global_position - global_position
			offset.y = 0.0
			if offset.length() <= boss_type.slam_radius + Player.BODY_RADIUS:
				player.take_damage(boss_type.slam_damage)
			Fx.ring(global_position, boss_type.slam_radius, SLAM_COLOR)
			Game.shake(0.5)
			_end_special()
		&"charge":
			_state = State.CHARGE
			_charge_time_left = boss_type.charge_distance / boss_type.charge_speed
			_charge_hit = false
			# Don't get stuck on its own horde while charging.
			collision_mask &= ~Player.ENEMY_COLLISION_BIT
		&"summon":
			Game.spawner.spawn_ring(global_position, boss_type.summon_count, SUMMON_RADIUS)
			Game.shake(0.3)
			_end_special()


func _update_charge(player: Player, delta: float) -> void:
	_charge_time_left -= delta
	velocity = _charge_direction * boss_type.charge_speed
	move_and_slide()
	if absf(global_position.y) > 0.001:
		global_position.y = 0.0
	var offset := player.global_position - global_position
	offset.y = 0.0
	if not _charge_hit and offset.length() <= body_radius + Player.BODY_RADIUS + 0.4:
		_charge_hit = true
		player.take_damage(boss_type.charge_damage)
		Game.shake(0.4)
	var blocked := get_real_velocity().length() < boss_type.charge_speed * 0.3
	if _charge_time_left <= 0.0 or _charge_hit or blocked:
		collision_mask |= Player.ENEMY_COLLISION_BIT
		_end_special()


func _end_special() -> void:
	_state = State.CHASE
	_pending_attack = &""
	_special_timer = boss_type.special_interval


func _return_to_pool() -> void:
	queue_free()
