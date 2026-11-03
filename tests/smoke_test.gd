extends Node
## Automated smoke test: runs the main scene (or the camp), plays a scenario and checks the
## outcome. Exits with code 1 on failure; script errors also show up in Godot's output.
## Always run with --no-save so the real save file is never touched.
##
## From the project folder (G = Godot.app/Contents/MacOS/Godot):
##   G --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn -- --no-save --scenario=<name>
## Scenarios:
##   systems     plays 4 minutes, uses every power, picks the first boon on each level-up (default);
##               also checks sounds, music, damage numbers and particles
##   death       stands still and dies → equipped gear is lost, then returns to camp
##   early_exit  kills the first boss and escapes through the early gate → gold, 1 core, item, XP
##   final_exit  kills every boss and escapes through the final gate → gold, 5 cores, items
##   timeout     kills the final boss but never reaches the gate → only the 3 secured cores remain
##   boss_view   spawns all three bosses and watches their attacks without killing them
##   hub         exercises profile and skill tree operations and shows every camp tab
##   powers      plays 30 s with loadout --set=A..F; the six sets cover all 20 options of the 10 powers
##   horde       one skeleton at a time: its swing can be stepped out of and lands after the
##               windup, ring spawns climb out of the ground first, corpses return to the pool
## For screenshots, drop --headless and append --screenshots=/absolute/folder/path
## (add --real-health to keep normal health so the HUD looks like a real run, and --time=<seconds>
## to start the systems or powers scenario later in the run, e.g. --time=170 for every enemy type).

const SYSTEMS_SECONDS := 240.0
const BOSS_VIEW_SECONDS := 26.0
const POWERS_SECONDS := 30.0
const HORDE_SECONDS := 20.0
const TIMEOUT_SECONDS := 1200.0
const STARTING_EQUIPMENT := 3
## The systems scenario opens the pause screen once at this time, for a screenshot of it.
const PAUSE_SHOT_TIME := 30.0
## XP that should reach the character level on an escape (the first level needs 400).
const TEST_RUN_XP := 450
## Loadouts for the powers scenario: {skill: option}; every power at rank 3 and enhanced.
const POWER_SETS := {
	"A": {"whirlwind": "a", "soul_chain": "a", "earthquake_leap": "a", "sword_rain": "a"},
	"B": {"whirlwind": "b", "soul_chain": "b", "earthquake_leap": "b", "sword_rain": "b"},
	"C": {"fire_wave": "a", "shadow_dash": "a", "bone_shield": "a", "heavens_wrath": "a"},
	"D": {"fire_wave": "b", "shadow_dash": "b", "bone_shield": "b", "heavens_wrath": "b"},
	"E": {"frost_nova": "a", "war_cry": "a", "whirlwind": "", "soul_chain": ""},
	"F": {"frost_nova": "b", "war_cry": "b", "bone_shield": "", "fire_wave": ""},
}

var _scenario := "systems"
var _power_set := "A"
var _real_health := false
## Run time to start at (systems and powers scenarios); negative keeps the scenario's own.
var _start_time := -1.0
var _main: Node
## The camp scene (hub scenario); untyped because its script has no class_name.
var _hub
var _player: Player
var _level_up: LevelUpScreen
var _game_over: GameOverScreen
var _result: Dictionary = {}
var _elapsed := 0.0
var _frames := 0
var _next_report := 0.0
var _peak_enemies := 0
var _peak_numbers := 0
var _level_up_frames := 0
var _finished := false
var _failures: Array[String] = []
var _started_usec := 0
var _screenshot_dir := ""
var _screenshot_times: Array[float] = []
var _took_level_up_shot := false
var _took_channel_shot := false
var _portal_seen_at := -1.0
var _pause_shot_frames := -1
var _took_pause_shot := false
var _took_low_health_shot := false
var _horde_step := 0
var _horde_mark := 0.0
var _horde_health := 0.0
var _horde_enemy: Enemy
var _horde_ring: Array[Enemy] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_usec = Time.get_ticks_usec()
	if Profile.persist:
		print("Run the smoke test with --no-save so it never touches the real save.")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_screenshot_dir = arg.trim_prefix("--screenshots=")
		elif arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--set="):
			_power_set = arg.trim_prefix("--set=")
		elif arg == "--real-health":
			_real_health = true
		elif arg.begins_with("--time="):
			_start_time = float(arg.trim_prefix("--time="))
	print("Scenario: %s%s" % [_scenario, " (set %s)" % _power_set if _scenario == "powers" else ""])
	if _scenario == "hub":
		_start_hub_scenario()
		return
	if _scenario == "powers":
		_equip_power_set(POWER_SETS[_power_set])
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_level_up = _main.get_node("LevelUpScreen") as LevelUpScreen
	_game_over = _main.get_node("GameOverScreen") as GameOverScreen
	Game.director.run_ended.connect(func(result: Dictionary) -> void: _result = result)
	match _scenario:
		"systems":
			_screenshot_times = [4.0, 62.0, 170.0]
		"death":
			return
		"early_exit":
			Game.run_time = Game.director.mini_boss_times[0] - 2.0
		"final_exit", "timeout":
			Game.run_time = Game.director.final_boss_time - 2.0
		"boss_view":
			Game.run_time = Game.director.final_boss_time - 2.0
			_screenshot_times = [8.0, 14.0, 20.0]
		"horde":
			# Only the test's own enemies: no spawns, and the character neither moves nor attacks.
			Game.spawner.intensity = 0.0
			_player.set_physics_process(false)
		"powers":
			Game.run_time = 120.0
			# A burst of frames to catch short effects (swing, spin, swords).
			_screenshot_times = [6.0, 6.1, 6.2, 6.3, 6.4, 14.0, 24.0]
			var equipped := _player.abilities.filter(func(ability: Ability) -> bool: return ability != null)
			_expect(equipped.size() == 4, "all 4 loadout powers were built for the run")
	if _start_time >= 0.0 and _scenario in ["systems", "powers"]:
		Game.run_time = _start_time
	# The character must not die outside the death scenario.
	if not _real_health:
		_player.base_max_health = 1000000.0
		_player._recalculate_stats()
		_player.heal(1000000.0)
	if _scenario in ["early_exit", "timeout"]:
		_player.add_xp(TEST_RUN_XP)
	if _scenario in ["systems", "boss_view", "powers"]:
		for action in Player.ABILITY_ACTIONS:
			Input.action_press(action)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if _scenario == "hub":
		_drive_hub()
		return
	if _game_over.visible:
		_on_run_over()
		return
	if _level_up.visible:
		_level_up_frames += 1
		if _level_up_frames == 3 and not _took_level_up_shot:
			_took_level_up_shot = true
			_screenshot("level_up")
		if _level_up_frames >= 4:
			_level_up_frames = 0
			_level_up._lock_time = 0.0
			_level_up._choose(0)
		return
	if _pause_shot_frames >= 0:
		_drive_pause_shot()
		return
	_elapsed += delta
	match _scenario:
		"systems", "powers":
			_walk_in_circles()
		"early_exit", "final_exit":
			_drive_exit(_scenario == "final_exit")
		"timeout":
			_kill_bosses()
		"horde":
			_drive_horde()
	_peak_enemies = maxi(_peak_enemies, Game.enemies.size())
	_peak_numbers = maxi(_peak_numbers, Game.damage_numbers.active_count())
	if _elapsed >= _next_report:
		_next_report += 15.0
		print("[%s] enemies %d · kills %d · level %d · gold %d · physics %.2f ms" % [
				UiKit.format_time(Game.run_time), Game.enemies.size(), Game.kills, _player.level,
				Game.director.gold, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	if _scenario == "systems" and not _took_pause_shot and _elapsed >= PAUSE_SHOT_TIME:
		_main._on_pause_toggle_requested()
		_pause_shot_frames = 0
	if _scenario == "death" and not _took_low_health_shot and _player.health < 0.25 * _player.max_health:
		_took_low_health_shot = true
		_screenshot("low_health")
	if not _screenshot_times.is_empty() and _elapsed >= _screenshot_times[0]:
		_screenshot("t%05.1f" % _screenshot_times.pop_front())
	if _elapsed >= _time_limit():
		if _scenario in ["systems", "boss_view", "powers"]:
			if _scenario != "boss_view":
				_check_feedback()
			_finish("Time limit reached")
		else:
			_failures.append("The run did not end within %d s" % int(_time_limit()))
			_finish("Timed out")


## Sound and feel: every sound file loaded, the run music plays, damage numbers showed up and
## the setting clears them, and the particle pools exist.
func _check_feedback() -> void:
	var missing: Array[String] = []
	for id: String in Audio.SOUNDS:
		if Audio.variation_count(id) != int(Audio.SOUNDS[id].get("count", 1)):
			missing.append(id)
	_expect(missing.is_empty(), "every sound file loaded (missing: %s)" % ", ".join(missing))
	for track: String in Audio.MUSIC:
		_expect(ResourceLoader.exists(Audio.MUSIC[track]["path"]), "music file for the %s track" % track)
	_expect(Audio.music_track() == "run", "the run music is playing")
	_expect(_peak_numbers > 0, "damage numbers appeared")
	_expect(Game.particles.get_child_count() > 0, "particle pools were built")
	Settings.set_value("damage_numbers", false)
	_expect(Game.damage_numbers.active_count() == 0, "turning damage numbers off clears them")
	Settings.set_value("damage_numbers", true)
	print("Feedback: up to %d damage numbers at once, %d particle emitters" % [_peak_numbers, Game.particles.get_child_count()])


## Pause screen: checks it pauses the game, takes a screenshot, then resumes.
func _drive_pause_shot() -> void:
	_pause_shot_frames += 1
	if _pause_shot_frames == 1:
		_expect(get_tree().paused and _main.pause_screen.visible, "the pause screen opens and pauses the game")
	elif _pause_shot_frames == 3:
		_screenshot("pause")
	elif _pause_shot_frames >= 4:
		_pause_shot_frames = -1
		_took_pause_shot = true
		if _main.pause_screen.visible:
			_main._on_pause_toggle_requested()


func _time_limit() -> float:
	match _scenario:
		"systems":
			return SYSTEMS_SECONDS
		"boss_view":
			return BOSS_VIEW_SECONDS
		"powers":
			return POWERS_SECONDS
		"horde":
			return HORDE_SECONDS
	return TIMEOUT_SECONDS


func _walk_in_circles() -> void:
	var angle := _elapsed * 0.6
	_set_axis("move_right", "move_left", cos(angle))
	_set_axis("move_down", "move_up", sin(angle))


## Kills bosses instantly; once the wanted gate opens, clears the swarm and puts the
## character in the gate.
func _drive_exit(wants_final: bool) -> void:
	_kill_bosses()
	var portal := Game.director.portal
	if portal == null or not portal.is_open() or portal.is_final != wants_final:
		return
	if _portal_seen_at < 0.0:
		_portal_seen_at = _elapsed
		print("Gate opened (%s), %.0f m away" % ["final" if portal.is_final else "early",
				portal.global_position.distance_to(_player.global_position)])
	# Keep the gate and compass on screen for a moment (for screenshots), then move into the gate.
	if _elapsed - _portal_seen_at < 1.0:
		return
	if _player.global_position.distance_to(portal.global_position) > 0.5:
		_screenshot("portal_open")
		_player.global_position = portal.global_position
		_player.reset_physics_interpolation()
	for enemy in Game.enemies.duplicate():
		enemy.take_damage(1.0e9, Vector3.ZERO, false)
	if portal.progress > 0.5 and not _took_channel_shot:
		_took_channel_shot = true
		_screenshot("channel")


## One step at a time; each waits for the moment it checks.
func _drive_horde() -> void:
	var soldier: EnemyType = Game.spawner.enemy_types[0]
	var since := _elapsed - _horde_mark
	match _horde_step:
		0:
			_check_horde_models()
			_horde_enemy = _spawn_test_enemy(soldier, _player.global_position + Vector3(0.0, 0.0, 1.0))
			_horde_health = _player.health
			_horde_step = 1
		1:
			# In reach it starts a swing; the character steps away before it lands.
			if _horde_enemy._swing_left > 0.0:
				_screenshot("swing")
				_expect(_player.health == _horde_health, "no damage when a swing starts")
				_move_player(_player.global_position + Vector3(5.0, 0.0, 0.0))
				_horde_mark = _elapsed
				_horde_step = 2
		2:
			if since > soldier.attack_windup + 0.2:
				_expect(_player.health == _horde_health, "stepping out of reach avoids the swing")
				_horde_step = 3
		3:
			# It walks back into reach; standing still, the next swing lands after its windup.
			if _horde_enemy._hit_left > 0.0:
				_horde_mark = _elapsed
				_horde_step = 4
		4:
			if _player.health < _horde_health:
				print("Horde: the swing landed %.2f s after it started (windup %.2f s)" % [since, soldier.attack_windup])
				_expect(absf(since - soldier.attack_windup) <= 2.5 / 60.0, "the hit lands after the windup")
				_horde_enemy.take_damage(1.0e9)
				Game.spawner.spawn_ring(_player.global_position, 6, 3.0)
				_horde_ring.assign(Game.enemies.slice(-6))
				_horde_mark = _elapsed
				_horde_step = 5
			elif since > 1.0:
				_failures.append("The standing character was never hit")
				_finish("Horde: no hit")
		5:
			# Ring spawns climb out of the ground before they move.
			if since > 0.6:
				_screenshot("rising")
				_expect(_horde_ring.size() == 6 and _horde_ring.all(func(enemy: Enemy) -> bool: return enemy._rise_left > 0.0),
						"ring spawns are rising from the ground")
				_expect(_horde_ring.all(func(enemy: Enemy) -> bool: return enemy.get_real_velocity().length() < 0.01),
						"rising enemies don't move")
				_horde_step = 6
		6:
			if since > Enemy.RISE_TIME + 0.4:
				_expect(_horde_ring.any(func(enemy: Enemy) -> bool: return enemy.get_real_velocity().length() > 1.0),
						"risen enemies chase the character")
				var victim := _horde_ring[0]
				victim.take_damage(1.0e9)
				_expect(not Game.enemies.has(victim) and victim.visible, "a killed enemy stays as a corpse")
				_horde_mark = _elapsed
				_horde_step = 7
		7:
			if since > 0.5 and since < 0.6:
				_screenshot("corpse")
			var victim := _horde_ring[0]
			if since > Enemy.CORPSE_TIME + Enemy.SINK_TIME + 0.2:
				_expect(not victim.visible and victim.process_mode == Node.PROCESS_MODE_DISABLED
						and Game.spawner._pools[victim.type].has(victim), "the corpse sinks and returns to the pool")
				print("Horde: a corpse is back in the pool %.1f s after the kill" % since)
				_expect(_horde_enemy.process_mode == Node.PROCESS_MODE_DISABLED, "the first skeleton's corpse is back in the pool too")
				_finish("Horde checks done")


## Every horde type is drawn as one merged mesh (body and eyes) that also holds its weapons,
## and its pool was filled up front.
func _check_horde_models() -> void:
	for enemy_type in Game.spawner.enemy_types:
		var mesh: ArrayMesh = enemy_type._mesh
		_expect(mesh != null and mesh.get_surface_count() == 2, "%s is one merged mesh with body and eyes" % enemy_type.display_name)
		if mesh == null:
			continue
		var model := enemy_type.model.instantiate()
		var part_vertices := 0
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in part.mesh.get_surface_count():
				part_vertices += part.mesh.surface_get_array_len(surface)
		model.free()
		var merged_vertices := 0
		for surface in mesh.get_surface_count():
			merged_vertices += mesh.surface_get_array_len(surface)
		_expect(merged_vertices > part_vertices, "%s holds its weapons" % enemy_type.display_name)
		_expect(Game.spawner._pools[enemy_type].size() >= enemy_type.prewarm_count, "%s pool was built up front" % enemy_type.display_name)


## A tough enemy (so it lives through the test) standing at `at`.
func _spawn_test_enemy(enemy_type: EnemyType, at: Vector3) -> Enemy:
	Game.spawner._spawn_one(enemy_type, at)
	var enemy: Enemy = Game.enemies.back()
	enemy.max_health = 1.0e6
	enemy.health = enemy.max_health
	return enemy


func _move_player(to: Vector3) -> void:
	_player.global_position = to
	_player.reset_physics_interpolation()


func _kill_bosses() -> void:
	for boss in Game.director.bosses.duplicate():
		boss.take_damage(1.0e9)


## When the run ends, checks the result and how it was applied to the profile.
func _on_run_over() -> void:
	var gold: int = _result.get("gold", -1)
	var success: bool = _result.get("success", false)
	var reason: String = _result.get("reason", "")
	print("Run over: %s · success %s · gold %d · items %d · cores at risk %d / secured %d" % [
			reason, success, gold, (_result.get("items", []) as Array).size(),
			_result.get("run_cores", 0), _result.get("secured_cores", 0)])
	print("Profile: gold %d · cores %d · stash %d · equipped %d" % [
			Profile.gold, Profile.cores, Profile.stash.size(), Profile.equipped.size()])
	_screenshot("result")
	_expect(Audio.music_track() == "", "the music fades out when the run ends")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "no slow motion left after the run")
	var start_gold := Profile.STARTING_GOLD
	match _scenario:
		"death":
			_expect(not success and reason == "You died", "death result")
			_expect(Profile.equipped.is_empty() and Profile.failures == 1, "dying loses the equipped gear")
			_expect(Profile.gold == start_gold and Profile.cores == 0, "dying adds no gold or cores")
			_expect(Profile.take_free_basic("weapon") and (Profile.equipped.get("weapon") as Item).free,
					"the free basic kit can be taken again after dying")
			_finish_and_return_to_hub()
			return
		"early_exit":
			_expect(success and reason == "Escaped", "early escape result")
			_expect(Profile.gold == start_gold + gold and gold >= 100, "gold added to the vault")
			_expect(Profile.cores == 1, "mini-boss core added")
			_expect(Profile.stash.size() >= 1, "found item in the stash")
			_expect(Profile.equipped.size() == STARTING_EQUIPMENT, "gear kept")
			_expect(Profile.char_level >= 2 and Profile.skill_points_free() >= 1, "XP reached the character level")
		"final_exit":
			_expect(success, "final escape result")
			_expect(Profile.cores == 5, "cores: 1 + 1 + 3")
			_expect(Profile.stash.size() >= 4, "boss items in the stash")
			_expect(Profile.equipped.size() == STARTING_EQUIPMENT, "gear kept")
		"timeout":
			_expect(not success and reason == "The gate closed", "gate closed result")
			_expect(Profile.cores == 3, "only the 3 secured cores remain")
			_expect(Profile.gold == start_gold and Profile.stash.is_empty(), "gold and items lost")
			_expect(Profile.equipped.is_empty(), "gear lost")
			_expect(Profile.char_level == 1 and Profile.char_xp == 0, "XP lost")
		_:
			_failures.append("The run should not have ended in this scenario")
	_finish(reason)


## At the end of the death test, "Return to Camp" is pressed; the camp loads and the test
## quits a second later.
func _finish_and_return_to_hub() -> void:
	_finish("Death, then return to camp", false)
	# The test node is freed with the scene, so the autoload does the quitting.
	get_tree().create_timer(1.0).timeout.connect(Audio.quit_quietly.bind(0 if _failures.is_empty() else 1))
	_game_over._lock_time = 0.0
	_game_over._request_continue()


func _start_hub_scenario() -> void:
	Profile.reset()
	_expect(Profile.equipped.size() == STARTING_EQUIPMENT and Profile.equipped.values().all(func(item: Item) -> bool: return item.free),
			"a new profile starts with the free basic kit")
	_expect(not Profile.take_free_basic("weapon"), "only one free basic item per slot")
	Profile.gold = 2000
	Profile.cores = 12
	var stash_before := Profile.stash.size()
	var basic := ItemGenerator.basic("weapon")
	var stocked: Item = Profile.shop_stock[0]
	_expect(Profile.buy(basic) and Profile.buy(stocked), "buying")
	_expect(Profile.stash.size() == stash_before + 2 and Profile.shop_stock.size() == 2, "bought items in the stash, ware left the stock")
	Profile.equip(stocked)
	_expect(Profile.equipped.get(stocked.slot) == stocked and not Profile.stash.has(stocked), "equipping")
	var kit_item: Item = Profile.stash.filter(func(item: Item) -> bool: return item.free)[0]
	var gold_with_kit := Profile.gold
	Profile.sell(kit_item)
	_expect(Profile.gold == gold_with_kit and Profile.stash.has(kit_item) and kit_item.sell_price() == 0, "free kit items can't be sold")
	var gold_before := Profile.gold
	Profile.sell(basic)
	_expect(Profile.gold == gold_before + basic.sell_price() and not Profile.stash.has(basic), "selling")
	_expect(not Profile.unlock_node("a2"), "cannot skip past a locked node")
	_expect(Profile.unlock_node("a1") and Profile.unlock_node("a2") and Profile.cores == 9, "unlocking core nodes")
	_expect(Profile.bonuses().get("attack_speed_pct", 0.0) >= 0.08, "node bonus counted")
	var saved := JSON.stringify(Profile.to_dict())
	Profile.from_dict(JSON.parse_string(saved))
	_expect(JSON.stringify(Profile.to_dict()) == saved, "save round trip is identical")
	Profile.begin_run()
	var summary := Profile.apply_run_result({"success": false, "reason": "Run abandoned"})
	_expect(Profile.equipped.is_empty() and (summary["lost_equipment"] as Array).size() == STARTING_EQUIPMENT
			and not Profile.run_in_progress, "an abandoned run loses the equipped gear")
	var other_slot := "armor" if stocked.slot != "armor" else "weapon"
	_expect(Profile.take_free_basic(other_slot) and (Profile.equipped.get(other_slot) as Item).free,
			"after a loss a free basic item is equipped right away")
	_expect(not Profile.take_free_basic(stocked.slot), "a free kit item in the stash still counts")
	_check_skill_tree()

	# A filled profile for the screenshots.
	Profile.reset()
	Profile.gold = 1240
	Profile.cores = 6
	for rarity in [Item.Rarity.LEGENDARY, Item.Rarity.RARE, Item.Rarity.RARE, Item.Rarity.MAGIC, Item.Rarity.MAGIC]:
		Profile.stash.append(ItemGenerator.roll(rarity))
	Profile.equip(Profile.stash[0])
	# One empty slot, so the screenshots show the free basic kit offer.
	for slot in Item.SLOTS:
		if (Profile.equipped.get(slot) as Item).free:
			Profile.equipped.erase(slot)
			break
	Profile.unlocked.assign(["a1", "a3", "b1", "c1"])
	Profile.add_char_xp(400 + 500 + 600 + 700)
	Profile.add_skill_rank("fire_wave")
	Profile.enhance_skill("fire_wave")
	Profile.choose_skill("fire_wave", "a")
	_hub = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	add_child(_hub)


## Skill tree rules: points, tier gates, refunds, loadout and loading older saves.
func _check_skill_tree() -> void:
	Profile.reset()
	_expect(Profile.skill_points_free() == 0 and Profile.loadout == Profile.STARTER_LOADOUT, "starter powers equipped, no free points")
	_expect(Profile.add_skill_rank("fire_wave") != "", "no rank without a free point")
	Profile.add_char_xp(400 + 500 + 600)
	_expect(Profile.char_level == 4 and Profile.skill_points_free() == 3, "XP grants levels and points")
	_expect(Profile.add_skill_rank("earthquake_leap") != "", "a locked tier cannot be learned")
	_expect(Profile.add_skill_rank("fire_wave") == "" and Profile.skill_rank("fire_wave") == 2, "adding a rank")
	_expect(Profile.enhance_skill("fire_wave") == "" and Profile.choose_skill("fire_wave", "a") == "", "Enhanced upgrade and option")
	_expect(Profile.skill_points_free() == 0, "points spent")
	Profile.gold = 1000
	_expect(Profile.choose_skill("fire_wave", "b") == "" and Profile.gold == 1000 - Profile.refund_cost()
			and Profile.skill_state("fire_wave")["choice"] == "b", "switching options costs gold")
	_expect(Profile.refund_skill("fire_wave", "enhanced") != "", "Enhanced cannot be refunded while an option is taken")

	Profile.reset()
	Profile.gold = 1000
	_expect(Profile.refund_skill("whirlwind", "rank") != "", "a refund that breaks a lower tier gate is blocked")
	_expect(Profile.refund_skill("frost_nova", "rank") == "" and not Profile.loadout.has("frost_nova")
			and Profile.gold == 1000 - Profile.refund_cost(), "a power refunded to rank 0 leaves the loadout")
	Profile.add_char_xp(20000)
	for skill_id in ["soul_chain", "soul_chain", "fire_wave", "fire_wave", "earthquake_leap", "war_cry", "heavens_wrath", "sword_rain"]:
		_expect(Profile.add_skill_rank(skill_id) == "", "%s rank" % skill_id)
	_expect(Profile.set_loadout(0, "heavens_wrath") == "", "an ultimate can be slotted")
	_expect(Profile.set_loadout(1, "sword_rain") != "", "a second ultimate cannot be slotted")
	_expect(Profile.set_loadout(2, "heavens_wrath") == "" and Profile.loadout[2] == "heavens_wrath"
			and Profile.loadout[0] != "heavens_wrath", "swapping slots in the loadout")
	Profile.gold = Profile.respec_cost()
	_expect(Profile.respec_all() == "" and Profile.skill_points_spent() == 0 and Profile.gold == 0
			and Profile.loadout.count("") == 4, "reset all")

	var old_save := Profile.to_dict()
	for key in ["skills", "loadout", "char_level", "char_xp"]:
		old_save.erase(key)
	Profile.from_dict(old_save)
	_expect(Profile.loadout == Profile.STARTER_LOADOUT and Profile.skill_rank("whirlwind") == 1, "an old save gets the starter powers")

	# Saves before version 3 have Turkish item names; they must come back in English.
	Profile.reset()
	var turkish_save := Profile.to_dict()
	turkish_save["version"] = 2
	turkish_save["equipped"]["weapon"]["title"] = "Paslı Kılıç"
	(turkish_save["shop"] as Array)[0]["title"] = "Keskin Kılıç"
	Profile.from_dict(turkish_save)
	_expect(Profile.equipped["weapon"].title == "Rusty Sword" and Profile.shop_stock[0].title != "Keskin Kılıç",
			"old Turkish item names are replaced with English ones")


## Writes the loadout and the powers' upgrades straight into the profile (no rule checks).
func _equip_power_set(power_set: Dictionary) -> void:
	Profile.skills.clear()
	var ids: Array[String] = []
	for skill_id: String in power_set:
		Profile.skills[skill_id] = {"rank": 3, "enhanced": true, "choice": power_set[skill_id]}
		ids.append(skill_id)
	Profile.loadout.assign(ids)


func _drive_hub() -> void:
	_frames += 1
	match _frames:
		5:
			_screenshot("equipment")
			_hub.show_tab(1)
		10:
			_screenshot("skills")
			var skills_panel := _hub._panels[1] as SkillsPanel
			skills_panel._select("fire_wave")
		12:
			_screenshot("skills_selected")
			_hub.show_tab(2)
		17:
			_screenshot("shop")
			_hub.show_tab(3)
		22:
			_screenshot("tree")
			var tree_panel := _hub._panels[3] as CoreTreePanel
			tree_panel._select("a2")
			tree_panel._on_unlock_pressed()
			_expect(Profile.unlocked.has("a2") and Profile.cores == 4, "unlocking a node from the tree screen")
		27:
			_screenshot("tree_after")
			_hub.show_tab(4)
		30:
			_screenshot("settings")
			_finish("Camp")


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		print("  ✗ %s" % message)
	return condition


func _set_axis(positive: String, negative: String, value: float) -> void:
	if value >= 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_press(negative, -value)
		Input.action_release(positive)


func _screenshot(label: String) -> void:
	if _screenshot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(_screenshot_dir.path_join("%s_%s.png" % [_scenario, label]))


func _finish(message: String, quit := true) -> void:
	_finished = true
	var passed := _failures.is_empty()
	var real_seconds := (Time.get_ticks_usec() - _started_usec) / 1000000.0
	var details := ""
	if _player:
		details = " | game time %s, level %d, kills %d, peak %d enemies" % [
				UiKit.format_time(Game.run_time), _player.level, Game.kills, _peak_enemies]
	print("%s — %s: %s%s, real time %.1f s" % ["PASSED" if passed else "FAILED", _scenario, message, details, real_seconds])
	for action in Player.ABILITY_ACTIONS:
		Input.action_release(action)
	if quit:
		Audio.quit_quietly(0 if passed else 1)

