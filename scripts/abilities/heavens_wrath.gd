extends Ability
## Heaven's Wrath (ultimate): a large area blast at the aim point after a short warning.
## Enhanced: area +20%. Triple Strike: three smaller blasts in a row. Apocalypse: cooldown −15 s.

@export var damage := 150.0
@export var radius := 7.5
@export var max_cast_range := 14.0
## Time between the warning circle and the blast.
@export var delay := 0.55
@export var knockback := 12.0
## Triple Strike: each blast's damage and radius ratio, and the delay between blasts.
@export var triple_damage_ratio := 0.6
@export var triple_radius_ratio := 0.7
@export var triple_stagger := 0.18

## Pending blasts: {"position": Vector3, "time_left": float, "radius": float, "damage": float}
var _pending: Array[Dictionary] = []


func _init() -> void:
	base_cooldown = 45.0


func _configure() -> void:
	if enhanced:
		radius *= 1.2
	if choice == "b":
		base_cooldown -= 15.0


func activate() -> void:
	var offset := player.aim_point - player.global_position
	offset.y = 0.0
	var target := player.global_position + offset.limit_length(max_cast_range)
	var final_radius := radius * player.area_multiplier
	if choice == "a":
		var small := final_radius * triple_radius_ratio
		for i in 3:
			var spot := target + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0) * small * 0.8
			_queue(spot, small, damage * triple_damage_ratio, delay + triple_stagger * i)
	else:
		_queue(target, final_radius, damage, delay)


func _queue(at: Vector3, blast_radius: float, blast_damage: float, wait: float) -> void:
	_pending.append({"position": at, "time_left": wait, "radius": blast_radius, "damage": blast_damage})
	Fx.telegraph(at, blast_radius, color, wait)


func _tick(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var strike := _pending[i]
		strike["time_left"] -= delta
		if strike["time_left"] <= 0.0:
			_pending.remove_at(i)
			_explode(strike["position"], strike["radius"], strike["damage"])


func _explode(center: Vector3, blast_radius: float, blast_damage: float) -> void:
	_blast(center, blast_radius, blast_damage * damage_scale(), knockback)
	Fx.pillar(center, blast_radius, color)
	Game.shake(0.7)
