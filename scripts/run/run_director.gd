class_name RunDirector
extends Node3D
## Drives the run's extraction flow: boss timings, exit gates, the final countdown,
## run loot (gold, items, cores) and how the run ends (escape, death, gate closed).

## Emitted when gold, items or cores change.
signal loot_changed
## Emitted when the run ends: {"success", "reason", "gold", "items", "xp", "run_cores", "secured_cores", "core"}
signal run_ended(result: Dictionary)

enum PortalRequest { NONE, EARLY, FINAL }

const GOLD_COLOR := Color(1.0, 0.8, 0.3)
const CORE_COLOR := Color(0.45, 1.0, 0.7)
## A new gate should be at least this far from the previous one.
const PORTAL_SPACING := 25.0
## Number of items the final boss drops (mini-bosses drop 1).
const FINAL_BOSS_ITEMS := 2
## The clock ticks every second for the last this many seconds before the gate closes.
const TICK_SECONDS := 10

@export var boss_scene: PackedScene
## Mini-bosses in spawn order; their spawn times are in mini_boss_times.
@export var mini_bosses: Array[BossType] = []
@export var mini_boss_times: Array[float] = [300.0, 600.0]
@export var final_boss: BossType
@export var final_boss_time := 900.0

@export_group("Extraction")
## How long the final gate stays open after the final boss dies (s).
@export var final_countdown := 90.0
@export var early_portal_min_distance := 22.0
@export var final_portal_min_distance := 40.0
## Enemy spawn rate is multiplied by this once the final boss dies.
@export var escape_spawn_multiplier := 2.5

var gold := 0
## Items found; they only reach the stash if you escape.
var items: Array[Item] = []
## Mini-boss cores: yours if you escape, lost if you fail.
var run_cores := 0
## Final boss cores: secured the moment the boss is killed.
var secured_cores := 0
var core_secured := false
## The currently open gate (null if none).
var portal: ExitPortal
var bosses: Array[Boss] = []
## Time left until the final gate closes; -1 when no countdown is running.
var countdown_left := -1.0

var _next_mini_boss := 0
var _final_spawned := false
var _ended := false
## Picking a gate spot needs a physics query, so the gate opens on the next physics frame.
var _portal_request := PortalRequest.NONE
var _has_last_portal := false
var _last_portal_position := Vector3.ZERO
var _last_tick := -1


func _physics_process(delta: float) -> void:
	if _ended or Game.player == null:
		return
	if _portal_request != PortalRequest.NONE:
		_open_portal(_portal_request == PortalRequest.FINAL)
		_portal_request = PortalRequest.NONE
	var mini_boss_due := (_next_mini_boss < mini_bosses.size() and _next_mini_boss < mini_boss_times.size()
			and Game.run_time >= mini_boss_times[_next_mini_boss])
	if mini_boss_due:
		_spawn_boss(mini_bosses[_next_mini_boss])
		_next_mini_boss += 1
	if final_boss and not _final_spawned and Game.run_time >= final_boss_time:
		_final_spawned = true
		_spawn_boss(final_boss)
	if countdown_left > 0.0:
		countdown_left = maxf(countdown_left - delta, 0.0)
		var seconds := ceili(countdown_left)
		if seconds <= TICK_SECONDS and seconds != _last_tick and seconds > 0:
			_last_tick = seconds
			# Each tick a little higher, so the last seconds feel urgent.
			Audio.play("tick", 1.0 + 0.04 * (TICK_SECONDS - seconds))
		if countdown_left <= 0.0:
			Audio.play("gong", 0.6)
			end_run(false, "The gate closed")


## The Gold find bonus is applied here.
func add_gold(amount: int, at: Vector3) -> void:
	var final_amount := roundi(amount * (1.0 + Game.player.meta_value("gold_pct")))
	gold += final_amount
	loot_changed.emit()
	Fx.floating_text(at + Vector3.UP * 2.0, "+%d gold" % final_amount, GOLD_COLOR)
	Audio.play("gold")


func add_item(item: Item, at: Vector3) -> void:
	items.append(item)
	loot_changed.emit()
	Fx.floating_text(at + Vector3.UP * 2.8, item.title, item.color())
	Fx.burst(&"glints", at + Vector3.UP * 1.5, item.color())
	Audio.play("item")


func end_run(success: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	countdown_left = -1.0
	if success:
		Audio.play("extract")
	Audio.play_music("")
	run_ended.emit({
		"success": success,
		"reason": reason,
		"gold": gold,
		"items": items,
		"xp": Game.player.run_xp,
		"run_cores": run_cores,
		"secured_cores": secured_cores,
		"core": core_secured,
	})


func _spawn_boss(boss_type: BossType) -> void:
	var boss := boss_scene.instantiate() as Boss
	add_child(boss)
	boss.spawn(boss_type, Game.spawner.random_spawn_point(Game.player.global_position), 1.0)
	boss.died.connect(_on_boss_died)
	bosses.append(boss)
	Fx.burst(&"dust", boss.global_position, Color(0.45, 0.4, 0.35, 0.7))
	Game.announce("%s has awakened!" % boss_type.display_name)
	Game.shake(0.4)
	Audio.play("boss_roar")
	Audio.play_music("boss")


func _on_boss_died(enemy: Enemy) -> void:
	var boss := enemy as Boss
	var at := boss.global_position
	bosses.erase(boss)
	add_gold(boss.boss_type.gold_reward, at)
	Game.pickups.spawn_xp(at, boss.boss_type.xp_value)
	if boss.boss_type.is_final:
		core_secured = true
		secured_cores += boss.boss_type.core_reward
		for i in FINAL_BOSS_ITEMS:
			add_item(ItemGenerator.roll_drop(ItemGenerator.Source.FINAL_BOSS), at + Vector3.UP * i)
		_portal_request = PortalRequest.FINAL
		countdown_left = final_countdown
		Game.spawner.intensity = escape_spawn_multiplier
		Game.announce("Core secured — run for the gate!")
		# The boss music keeps playing through the escape.
		Audio.play("bell")
	else:
		run_cores += boss.boss_type.core_reward
		add_item(ItemGenerator.roll_drop(ItemGenerator.Source.MINI_BOSS), at)
		if not core_secured:
			_portal_request = PortalRequest.EARLY
			Game.announce("An exit gate has opened")
		if bosses.is_empty() and countdown_left <= 0.0:
			Audio.play_music("run")
	var core_text := "+%d core" if boss.boss_type.core_reward == 1 else "+%d cores"
	Fx.floating_text(at + Vector3.UP * 3.6, core_text % boss.boss_type.core_reward, CORE_COLOR)
	Audio.play("core")
	loot_changed.emit()


## Closes the old gate if there is one and opens a new one away from both the player and the old gate.
func _open_portal(is_final: bool) -> void:
	if portal:
		_has_last_portal = true
		_last_portal_position = portal.global_position
		portal.close()
	portal = ExitPortal.new()
	portal.is_final = is_final
	portal.position = _pick_portal_point(is_final)
	add_child(portal)
	portal.extracted.connect(end_run.bind(true, "Escaped"))
	Fx.burst(&"glints", portal.global_position + Vector3.UP, portal.color())
	Audio.play("gong")


func _pick_portal_point(is_final: bool) -> Vector3:
	var center := Game.player.global_position
	var min_distance := final_portal_min_distance if is_final else early_portal_min_distance
	var limit := Game.spawner.arena_half_size - ExitPortal.RADIUS - 2.0
	var best := Vector3.ZERO
	var best_score := -1.0
	for attempt in 60:
		var point := Vector3(randf_range(-limit, limit), 0.0, randf_range(-limit, limit))
		if not _area_is_free(point):
			continue
		var from_player := point.distance_to(center)
		var from_last := point.distance_to(_last_portal_position) if _has_last_portal else PORTAL_SPACING
		if from_player >= min_distance and from_last >= PORTAL_SPACING:
			return point
		var score := minf(from_player / min_distance, from_last / PORTAL_SPACING)
		if score > best_score:
			best_score = score
			best = point
	return best


func _area_is_free(point: Vector3) -> bool:
	var r := ExitPortal.RADIUS
	for offset in [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		if not Game.spawner.is_point_free(point + offset):
			return false
	return true
