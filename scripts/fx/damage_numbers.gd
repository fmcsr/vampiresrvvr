class_name DamageNumbers
extends Node3D
## Pooled floating damage numbers, updated in one loop. Bigger hits get bigger, warmer numbers;
## hits on the same enemy within MERGE_TIME add up into one number. Can be turned off in Settings.

const POOL_SIZE := 90
const LIFETIME := 0.75
const MERGE_TIME := 0.15
const RISE := 1.3
## The number starts larger and shrinks to its size over this time.
const POP_TIME := 0.09
const POP_SCALE := 0.6
## Hits this many times the Sword Swing's damage turn gold.
const BIG_HIT_RATIO := 4.0
const BIG_HIT_COLOR := Color(1.0, 0.82, 0.3)


class Number:
	var label: Label3D
	## Reaches LIFETIME when the number is free.
	var age := LIFETIME
	var pop_age := 0.0
	var amount := 0.0
	var enemy_id := 0
	var origin := Vector3.ZERO
	var drift := Vector3.ZERO
	var size := 1.0


var _numbers: Array[Number] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var label := Label3D.new()
		label.font_size = 48
		label.outline_size = 12
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 10
		label.outline_render_priority = 9
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		label.visible = false
		add_child(label)
		var number := Number.new()
		number.label = label
		_numbers.append(number)
	Settings.changed.connect(_on_settings_changed)


## Shows damage dealt to an enemy. color is the source's color (white for the Sword Swing).
func add(enemy: Enemy, amount: float, color := Color.WHITE) -> void:
	if not Settings.damage_numbers or amount <= 0.0:
		return
	var enemy_id := enemy.get_instance_id()
	for number in _numbers:
		if number.enemy_id == enemy_id and number.age < MERGE_TIME:
			number.amount += amount
			number.pop_age = 0.0
			_style(number, color)
			return
	var number := _numbers[_next]
	_next = (_next + 1) % POOL_SIZE
	number.enemy_id = enemy_id
	number.amount = amount
	number.age = 0.0
	number.pop_age = 0.0
	number.origin = enemy.global_position + Vector3.UP * (Enemy.BASE_HEIGHT * enemy.type.size + 0.3)
	number.drift = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.3, 0.3))
	_style(number, color)
	number.label.visible = true


## How many numbers are on screen (for the tests).
func active_count() -> int:
	var count := 0
	for number in _numbers:
		if number.age < LIFETIME:
			count += 1
	return count


func _process(delta: float) -> void:
	for number in _numbers:
		if number.age >= LIFETIME:
			continue
		number.age += delta
		number.pop_age += delta
		if number.age >= LIFETIME:
			number.label.visible = false
			number.enemy_id = 0
			continue
		var t := number.age / LIFETIME
		var rise := RISE * (1.0 - pow(1.0 - t, 3.0))
		number.label.position = number.origin + number.drift * t + Vector3.UP * rise
		var pop := 1.0 + POP_SCALE * maxf(1.0 - number.pop_age / POP_TIME, 0.0)
		number.label.scale = Vector3.ONE * number.size * pop
		var alpha := clampf((1.0 - t) / 0.4, 0.0, 1.0)
		number.label.modulate.a = alpha
		number.label.outline_modulate.a = alpha * 0.9


## Size grows with the hit compared to a Sword Swing; sword hits are white (gold when huge),
## power hits take the power's color.
func _style(number: Number, color: Color) -> void:
	var player := Game.player
	var reference := player.attack_damage * player.damage_multiplier() if player else 14.0
	var ratio := number.amount / maxf(reference, 1.0)
	number.size = clampf(0.75 + 0.3 * log(1.0 + ratio) / log(2.0), 0.75, 1.8)
	var tint := color.lerp(Color.WHITE, 0.3)
	if color == Color.WHITE and ratio >= BIG_HIT_RATIO:
		tint = BIG_HIT_COLOR
	number.label.modulate = Color(tint, number.label.modulate.a)
	number.label.text = _format(number.amount)


func _on_settings_changed() -> void:
	if Settings.damage_numbers:
		return
	for number in _numbers:
		number.age = LIFETIME
		number.enemy_id = 0
		number.label.visible = false


static func _format(amount: float) -> String:
	if amount >= 10000.0:
		return "%.1fk" % (amount / 1000.0)
	return str(maxi(roundi(amount), 1))
