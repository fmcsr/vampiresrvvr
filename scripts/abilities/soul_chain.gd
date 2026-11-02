extends Ability
## Soul Chain: pulls nearby enemies in and damages them; meant to be paired with area powers.
## Enhanced: range +30%. Shackles: pulled enemies freeze for 1.5 s. Soul Harvest: health per enemy pulled.

@export var damage := 15.0
@export var radius := 9.0
## Distance from the player (m) at which pulled enemies stop.
@export var pull_to := 2.0
@export var stun_duration := 1.5
@export var heal_per_enemy := 1.0


func _init() -> void:
	base_cooldown = 10.0


func _configure() -> void:
	if enhanced:
		radius *= 1.3


func activate() -> void:
	var center := player.global_position
	var final_radius := radius * player.area_multiplier
	var hit_damage := damage * damage_scale()
	var pulled := Game.enemies_in_radius(center, final_radius)
	for enemy in pulled:
		var offset := center - enemy.global_position
		offset.y = 0.0
		var travel := maxf(offset.length() - pull_to - enemy.body_radius, 0.0)
		# Knockback decays at a constant rate, so the initial speed needed to stop exactly at pull_to is v = √(2·a·d)
		var speed := sqrt(2.0 * Enemy.KNOCKBACK_DECAY * travel)
		enemy.take_damage(hit_damage, offset.normalized() * speed)
		if choice == "a" and enemy.is_alive:
			enemy.freeze(stun_duration)
	if choice == "b" and not pulled.is_empty():
		player.heal(heal_per_enemy * pulled.size())
	Fx.implode(center, final_radius, color)
