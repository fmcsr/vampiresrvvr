extends Ability
## Frost Nova: freezes nearby enemies and deals light damage.
## Enhanced: freeze +1 s. Shatter: frozen enemies take 25% more damage. Frost Burst: area +40%.

@export var radius := 5.5
@export var damage := 12.0
@export var freeze_duration := 2.0
@export var shatter_bonus := 0.25


func _init() -> void:
	base_cooldown = 10.0


func _configure() -> void:
	if enhanced:
		freeze_duration += 1.0
	if choice == "a":
		player.frozen_damage_bonus = shatter_bonus
	elif choice == "b":
		radius *= 1.4


func activate() -> void:
	var center := player.global_position
	var hit_damage := damage * damage_scale()
	var final_radius := radius * player.area_multiplier
	for enemy in Game.enemies_in_radius(center, final_radius):
		# Freeze first so Shatter also applies to this hit.
		enemy.freeze(freeze_duration)
		enemy.take_damage(hit_damage)
	Fx.ring(center, final_radius, color)
