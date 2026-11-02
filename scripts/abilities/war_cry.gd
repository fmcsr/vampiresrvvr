extends Ability
## War Cry: briefly boosts damage and attack speed and knocks nearby enemies back.
## Enhanced: duration +2 s. Terror: enemies are knocked back twice as far and freeze.
## Battle Fury: cooldowns recharge faster while the effect lasts.

const SOURCE := "war_cry"

## Buff that grows with rank (0.25 = 25%).
@export var bonus := 0.25
@export var duration := 6.0
@export var push_radius := 5.0
@export var push_strength := 10.0
@export var fear_duration := 1.0
@export var cooldown_rate := 1.25

var _buff_left := 0.0


func _init() -> void:
	base_cooldown = 18.0


func _configure() -> void:
	if enhanced:
		duration += 2.0


func activate() -> void:
	var amount := 1.0 + bonus * power()
	player.set_modifier(Player.Modifier.DAMAGE, SOURCE, amount)
	player.set_modifier(Player.Modifier.ATTACK_SPEED, SOURCE, amount)
	if choice == "b":
		player.set_modifier(Player.Modifier.COOLDOWN_RATE, SOURCE, cooldown_rate)
	_buff_left = duration
	var radius := push_radius * player.area_multiplier
	var strength := push_strength * (2.0 if choice == "a" else 1.0)
	for enemy in _blast(player.global_position, radius, 0.0, strength):
		if choice == "a" and enemy.is_alive:
			enemy.freeze(fear_duration)
	Fx.ring(player.global_position, radius, color)
	Game.shake(0.3)


func _tick(delta: float) -> void:
	if _buff_left <= 0.0:
		return
	_buff_left -= delta
	if _buff_left <= 0.0:
		for kind in [Player.Modifier.DAMAGE, Player.Modifier.ATTACK_SPEED, Player.Modifier.COOLDOWN_RATE]:
			player.clear_modifier(kind, SOURCE)
