extends Ability
## Earthquake Leap: leaps to the aim point (no damage taken while airborne), deals area damage on
## landing and stuns enemies. Enhanced: stun +0.6 s. Aftershock: the landing spot keeps shaking for a while.
## Winged Leap: cooldown −3 s.

@export var damage := 45.0
@export var radius := 4.0
@export var max_distance := 9.0
@export var leap_duration := 0.35
@export var stun_duration := 0.6
@export var quake_dps := 15.0
@export var quake_duration := 3.0
@export var quake_tick := 0.5

var _leaping := false
var _quake_left := 0.0
var _quake_timer := 0.0
var _quake_center := Vector3.ZERO
var _quake_radius := 0.0


func _init() -> void:
	base_cooldown = 9.0


func _configure() -> void:
	if enhanced:
		stun_duration += 0.6
	if choice == "b":
		base_cooldown -= 3.0


func activate() -> void:
	var offset := player.aim_point - player.global_position
	offset.y = 0.0
	offset = offset.limit_length(max_distance)
	player.start_dash(offset / leap_duration, leap_duration)
	_leaping = true


func _tick(delta: float) -> void:
	if _leaping and not player.is_dashing():
		_leaping = false
		_land()
	if _quake_left > 0.0:
		_quake_left -= delta
		_quake_timer -= delta
		if _quake_timer <= 0.0:
			_quake_timer = quake_tick
			_blast(_quake_center, _quake_radius, quake_dps * quake_tick * damage_scale(), 0.0)


func _land() -> void:
	var center := player.global_position
	var final_radius := radius * player.area_multiplier
	for enemy in _blast(center, final_radius, damage * damage_scale(), 6.0):
		if enemy.is_alive:
			enemy.freeze(stun_duration)
	Fx.ring(center, final_radius, color)
	Game.shake(0.45)
	if choice == "a":
		_quake_center = center
		_quake_radius = final_radius
		_quake_left = quake_duration
		_quake_timer = quake_tick
		Fx.zone(center, final_radius, color, quake_duration)
