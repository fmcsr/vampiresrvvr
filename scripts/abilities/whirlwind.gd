extends Ability
## Whirlwind: briefly spins in place, repeatedly hitting everything nearby.
## The player is slowed while spinning. Enhanced: duration +1 s. Relentless Spin: no slow.
## Blood Storm: every hit restores health.

const SLOW_SOURCE := "whirlwind"

@export var damage := 9.0
@export var radius := 3.2
@export var duration := 2.5
@export var tick_interval := 0.25
@export var slow_multiplier := 0.7
@export var heal_per_hit := 0.5

var _spin_left := 0.0
var _tick_timer := 0.0


func _init() -> void:
	base_cooldown = 9.0


func _configure() -> void:
	if enhanced:
		duration += 1.0


func activate() -> void:
	_spin_left = duration
	_tick_timer = 0.0
	player.set_spinning(true)
	if choice != "a":
		player.set_modifier(Player.Modifier.MOVE_SPEED, SLOW_SOURCE, slow_multiplier)


func _tick(delta: float) -> void:
	if _spin_left <= 0.0:
		return
	_spin_left -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		var final_radius := radius * player.area_multiplier
		var hit := _blast(player.global_position, final_radius, damage * damage_scale(), 2.0)
		if choice == "b" and not hit.is_empty():
			player.heal(heal_per_hit * hit.size())
		Fx.spin(player.global_position, final_radius, color)
	if _spin_left <= 0.0:
		player.set_spinning(false)
		player.clear_modifier(Player.Modifier.MOVE_SPEED, SLOW_SOURCE)
