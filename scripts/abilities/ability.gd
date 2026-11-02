class_name Ability
extends Node
## Shared base for active powers with a cooldown. At the start of a run, Player creates these
## nodes from the profile's loadout and passes in their skill tree progress (rank, Enhanced,
## option) via setup(). A new power = a script extending this class + an entry in SkillLibrary.

@export var display_name := "Power"
@export var base_cooldown := 5.0
## Color used in the UI and in effects.
@export var color := Color.WHITE

var player: Player
var skill_id := ""
var rank := 1
var enhanced := false
## "a", "b" or "" (no option chosen).
var choice := ""
var cooldown_left := 0.0


func setup(owner_player: Player, id: String, state: Dictionary) -> void:
	player = owner_player
	skill_id = id
	rank = maxi(int(state.get("rank", 1)), 1)
	enhanced = state.get("enhanced", false)
	choice = state.get("choice", "")
	display_name = SkillLibrary.title(id)
	color = SkillLibrary.color(id)
	_configure()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	cooldown_left = maxf(cooldown_left - delta * player.modifier(Player.Modifier.COOLDOWN_RATE), 0.0)
	_tick(delta)


func cooldown_duration() -> float:
	return base_cooldown * player.cooldown_multiplier


## 1 = just used, 0 = ready.
func cooldown_ratio() -> float:
	return clampf(cooldown_left / cooldown_duration(), 0.0, 1.0)


func try_activate() -> bool:
	if cooldown_left > 0.0:
		return false
	activate()
	cooldown_left = cooldown_duration()
	return true


## Multiplier from rank and the run's "<Power> Mastery" boon (damage, shield, buff...).
func power() -> float:
	var rank_bonus := 1.0 + SkillLibrary.RANK_POWER * (rank - 1)
	return rank_bonus * (1.0 + BoonLibrary.total(player, BoonLibrary.power_id(skill_id)))


## For damaging powers: power × the player's damage multiplier.
func damage_scale() -> float:
	return power() * player.damage_multiplier()


## Subclasses apply the Enhanced upgrade and the chosen option to their values here.
func _configure() -> void:
	pass


## Subclasses apply the power's effect here.
func activate() -> void:
	pass


## Subclasses do their per-physics-frame work here.
func _tick(_delta: float) -> void:
	pass


## Damages enemies within the radius, pushing them outward from the center; returns the enemies hit.
func _blast(center: Vector3, radius: float, damage: float, knockback: float) -> Array[Enemy]:
	var hit := Game.enemies_in_radius(center, radius)
	for enemy in hit:
		var push := enemy.global_position - center
		push.y = 0.0
		enemy.take_damage(damage, push.normalized() * knockback, true, color)
	return hit
