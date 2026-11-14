extends Ability
## Fire Wave: cone-shaped area damage and knockback in the aim direction.
## Enhanced: range +25%. Embers: sets enemies on fire. Firestorm: semicircle, cooldown +1 s.

@export var damage := 28.0
@export var reach := 6.5
@export_range(5.0, 90.0) var half_angle_degrees := 40.0
@export var knockback := 7.0
@export var burn_dps := 10.0
@export var burn_duration := 3.0


func _init() -> void:
	base_cooldown = 4.0


func _configure() -> void:
	if enhanced:
		reach *= 1.25
	if choice == "b":
		half_angle_degrees = 90.0
		base_cooldown += 1.0


func activate() -> void:
	var origin := player.global_position
	var direction := player.aim_direction()
	var final_reach := reach * player.area_multiplier
	var half_angle := deg_to_rad(half_angle_degrees)
	var scale := damage_scale()
	for enemy in Game.enemies_in_cone(origin, direction, final_reach, half_angle):
		var push := enemy.global_position - origin
		push.y = 0.0
		enemy.take_damage(damage * scale, push.normalized() * knockback, true, color)
		if choice == "a" and enemy.is_alive:
			enemy.apply_burn(burn_dps * scale, burn_duration)
	Fx.sector(origin, direction, final_reach, half_angle, color)
	for i in 3:
		var spread := direction.rotated(Vector3.UP, randf_range(-half_angle, half_angle) * 0.7)
		Fx.burst(&"embers", origin + spread * final_reach * (0.35 + 0.3 * i) + Vector3.UP * 0.4, color, 0.7)
	Audio.play("fire_wave")
