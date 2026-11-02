extends Ability
## Shadow Dash: a quick dash in the move direction (the aim direction when standing still). The
## player takes no damage while dashing, passes through enemies, and damages those in the way.
## Enhanced: cooldown −1 s. Shadow Trail: damage +30% for 2 s afterwards. Shadow Burst: area damage at the end.

const TRAIL_SOURCE := "shadow_trail"

@export var distance := 7.0
@export var duration := 0.18
@export var damage := 18.0
@export var hit_radius := 1.2
@export var trail_duration := 2.0
@export var trail_bonus := 0.3
@export var burst_damage := 25.0
@export var burst_radius := 3.0

var _active := false
var _last_position := Vector3.ZERO
var _hit: Dictionary[Enemy, bool] = {}
var _trail_left := 0.0


func _init() -> void:
	base_cooldown = 6.0


func _configure() -> void:
	if enhanced:
		base_cooldown -= 1.0


func activate() -> void:
	var direction := player.move_direction()
	if direction == Vector3.ZERO:
		direction = player.aim_direction()
	player.start_dash(direction * (distance / duration), duration)
	_active = true
	_last_position = player.global_position
	_hit.clear()


func _tick(delta: float) -> void:
	if _trail_left > 0.0:
		_trail_left -= delta
		if _trail_left <= 0.0:
			player.clear_modifier(Player.Modifier.DAMAGE, TRAIL_SOURCE)
	if not _active:
		return
	var current := player.global_position
	var hit_damage := damage * damage_scale()
	for enemy in Game.enemies_near_segment(_last_position, current, hit_radius):
		if not _hit.has(enemy):
			_hit[enemy] = true
			var push := enemy.global_position - current
			push.y = 0.0
			enemy.take_damage(hit_damage, push.normalized() * 4.0)
	Fx.ghost(current, player.facing_yaw(), color)
	_last_position = current
	if not player.is_dashing():
		_active = false
		_finish(current)


func _finish(at: Vector3) -> void:
	if choice == "a":
		_trail_left = trail_duration
		player.set_modifier(Player.Modifier.DAMAGE, TRAIL_SOURCE, 1.0 + trail_bonus)
	elif choice == "b":
		var radius := burst_radius * player.area_multiplier
		_blast(at, radius, burst_damage * damage_scale(), 6.0)
		Fx.ring(at, radius, color)
