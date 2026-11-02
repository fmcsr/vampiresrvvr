extends Ability
## Bone Shield: a shield that absorbs damage for a while. Enhanced: enemies that hit you while it holds take damage.
## Bone Burst: area damage when the shield breaks or expires. Hardened Bone: duration +4 s, speed +15%.

const SPEED_SOURCE := "bone_shield"

@export var shield_amount := 40.0
@export var duration := 6.0
@export var thorns := 8.0
@export var burst_damage := 40.0
@export var burst_radius := 4.0
@export var speed_bonus := 0.15


func _init() -> void:
	base_cooldown = 14.0


func _configure() -> void:
	if choice == "b":
		duration += 4.0
	player.shield_ended.connect(_on_shield_ended)


func activate() -> void:
	player.add_shield(shield_amount * power(), duration)
	if enhanced:
		player.thorns_damage = thorns * damage_scale()
	if choice == "b":
		player.set_modifier(Player.Modifier.MOVE_SPEED, SPEED_SOURCE, 1.0 + speed_bonus)
	Fx.ring(player.global_position, 1.8, color)
	Fx.burst(&"bones", player.global_position + Vector3.UP, color, 0.6)
	Audio.play("bone_shield")


func _on_shield_ended() -> void:
	player.thorns_damage = 0.0
	player.clear_modifier(Player.Modifier.MOVE_SPEED, SPEED_SOURCE)
	Audio.play("kill_bone", 0.85)
	if choice == "a":
		var radius := burst_radius * player.area_multiplier
		_blast(player.global_position, radius, burst_damage * damage_scale(), 8.0)
		Fx.ring(player.global_position, radius, color)
		Fx.burst(&"bones", player.global_position + Vector3.UP, color)
		Audio.play("slam", 1.2, -3.0)
		Game.shake(0.3)
