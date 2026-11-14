extends Ability
## Sword Rain (ultimate): for a few seconds, swords fall from the sky onto nearby enemies.
## Enhanced: duration +2 s. Blade Storm: twice as frequent. Razor Rain: each sword hits a small area.

@export var damage := 30.0
@export var radius := 8.0
@export var duration := 4.0
@export var interval := 0.15
@export var splash_radius := 1.6

var _rain_left := 0.0
var _timer := 0.0


func _init() -> void:
	base_cooldown = 50.0


func _configure() -> void:
	if enhanced:
		duration += 2.0
	if choice == "a":
		interval *= 0.5


func activate() -> void:
	_rain_left = duration
	_timer = 0.0
	Audio.play("blade")


func _tick(delta: float) -> void:
	if _rain_left <= 0.0:
		return
	_rain_left -= delta
	_timer -= delta
	while _timer <= 0.0:
		_timer += interval
		_strike()


func _strike() -> void:
	var center := player.global_position
	var final_radius := radius * player.area_multiplier
	var targets := Game.enemies_in_radius(center, final_radius)
	var hit_damage := damage * damage_scale()
	var point := center + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf() * final_radius
	if not targets.is_empty():
		var target := targets.pick_random() as Enemy
		point = target.global_position
		if choice != "b":
			target.take_damage(hit_damage, Vector3.ZERO, true, color)
	if choice == "b":
		_blast(point, splash_radius * player.area_multiplier, hit_damage, 2.0)
	Fx.sword_drop(point, color)
	# The clang plays when the sword reaches the ground.
	get_tree().create_timer(Fx.SWORD_DROP_TIME, false).timeout.connect(Audio.play_at.bind("sword_drop", point))
