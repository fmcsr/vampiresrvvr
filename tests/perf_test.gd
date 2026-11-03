extends Node3D
## Art pass benchmark: many animated KayKit skeletons walking on screen under the game's camera
## and lighting. Prints frame, process (animation) and render times, then quits.
## Run it windowed, since rendering is part of what it measures (G = Godot.app/Contents/MacOS/Godot):
##   G --path . res://tests/perf_test.tscn -- --count=300 [--merge] [--no-shadows] [--throttle=2]
## --merge      draws each skeleton as one mesh instead of nine parts
## --no-shadows the skeletons cast no shadows
## --throttle=N each skeleton's animation advances every N frames (staggered)
## --lineup     shows the planned cast instead: the Knight, the three adventurer bosses and a
##              mixed skeleton horde (add --screenshot=/absolute/file.png to save a picture)

const MODEL := "res://models/kaykit/skeletons/Skeleton_Minion.glb"
const ADVENTURERS := "res://models/kaykit/adventurers/"
const SKELETONS := "res://models/kaykit/skeletons/"
## Lineup: model, position, scale, animation, weapon meshes to keep (the rest are hidden).
const LINEUP := [
	["Knight", Vector3(0.0, 0.0, 2.0), 1.0, "Idle", ["1H_Sword", "Badge_Shield"]],
	["Rogue", Vector3(-7.0, 0.0, -3.0), 2.4, "2H_Ranged_Aiming", ["2H_Crossbow"]],
	["Barbarian", Vector3(0.0, 0.0, -6.0), 2.5, "2H_Melee_Idle", ["2H_Axe"]],
	["Mage", Vector3(7.0, 0.0, -3.0), 3.0, "Spellcasting", ["2H_Staff"]],
]
const WALK := "Walking_D_Skeletons"
const SPREAD_RADIUS := 12.0
const WARMUP_SECONDS := 2.0
const MEASURE_SECONDS := 6.0

var _count := 300
var _merge := false
var _shadows := true
var _throttle := 1
var _lineup := false
var _screenshot := ""
var _players: Array[AnimationPlayer] = []
var _elapsed := 0.0
var _frame := 0
var _frame_ms: PackedFloat32Array = []
var _process_ms: PackedFloat32Array = []
var _render_cpu_ms: PackedFloat32Array = []
var _render_gpu_ms: PackedFloat32Array = []
var _draw_calls := 0
var _merged_meshes: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			_count = int(arg.trim_prefix("--count="))
		elif arg == "--merge":
			_merge = true
		elif arg == "--no-shadows":
			_shadows = false
		elif arg.begins_with("--throttle="):
			_throttle = maxi(int(arg.trim_prefix("--throttle=")), 1)
		elif arg == "--lineup":
			_lineup = true
		elif arg.begins_with("--screenshot="):
			_screenshot = arg.trim_prefix("--screenshot=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_build_stage()
	if _lineup:
		_build_lineup()
		return
	var scene := load(MODEL) as PackedScene
	for i in _count:
		_spawn(scene, i)


func _process(delta: float) -> void:
	_frame += 1
	if _throttle > 1:
		for i in _players.size():
			if (i + _frame) % _throttle == 0:
				_players[i].advance(delta * _throttle)
	_elapsed += delta
	if _elapsed < WARMUP_SECONDS:
		return
	var viewport := get_viewport().get_viewport_rid()
	_frame_ms.append(delta * 1000.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _lineup and _elapsed >= WARMUP_SECONDS:
		if _screenshot != "":
			get_viewport().get_texture().get_image().save_png(_screenshot)
			print("saved %s" % _screenshot)
		get_tree().quit()
		return
	if _elapsed >= WARMUP_SECONDS + MEASURE_SECONDS:
		print("count=%d merge=%s shadows=%s throttle=%d | frame %.2f ms (p95 %.2f, %d fps) | process %.2f ms | render cpu %.2f gpu %.2f ms | draw calls %d" % [
				_count, _merge, _shadows, _throttle, _average(_frame_ms), _percentile(_frame_ms, 0.95),
				roundi(1000.0 / _average(_frame_ms)), _average(_process_ms), _average(_render_cpu_ms),
				_average(_render_gpu_ms), _draw_calls])
		get_tree().quit()


func _spawn(scene: PackedScene, index: int) -> void:
	var model := scene.instantiate() as Node3D
	add_child(model)
	var angle := randf() * TAU
	model.position = Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * SPREAD_RADIUS
	model.rotation.y = randf() * TAU
	if _merge:
		_merge_parts(model.get_node("Rig/Skeleton3D") as Skeleton3D)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var walk := player.get_animation(WALK)
	walk.loop_mode = Animation.LOOP_LINEAR
	player.play(WALK)
	player.seek(randf() * walk.length, true)
	player.speed_scale = randf_range(0.9, 1.1)
	if _throttle > 1:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_players.append(player)
	if index == 0:
		print("parts per skeleton: %d" % model.find_children("*", "MeshInstance3D", true, false).size())


## Replaces the skinned parts with one mesh per material; the merged mesh is shared by every copy.
func _merge_parts(skeleton: Skeleton3D) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			parts.append(child)
	if _merged_meshes.is_empty():
		_merged_meshes["mesh"] = ModelTools.merge_skinned_parts(parts)
	var merged := MeshInstance3D.new()
	merged.mesh = _merged_meshes["mesh"]
	merged.skin = parts[0].skin
	skeleton.add_child(merged)
	merged.skeleton = merged.get_path_to(skeleton)
	for part in parts:
		part.queue_free()


func _build_stage() -> void:
	# Same night lighting and arena as scenes/main.tscn.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.34, 0.45)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.04, 0.04, 0.07)
	environment.fog_density = 0.006
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	add_child((load("res://scenes/world/arena.tscn") as PackedScene).instantiate())
	# The player's torch.
	var torch := OmniLight3D.new()
	torch.position = Vector3(0.0, 3.0, 2.0 if _lineup else 0.0)
	torch.light_color = Color(1.0, 0.78, 0.55)
	torch.light_energy = 2.2
	torch.omni_range = 12.0
	add_child(torch)
	var camera := Camera3D.new()
	camera.fov = 45.0
	var pitch := deg_to_rad(55.0)
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * 24.0
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	add_child(camera)


## The planned cast: Knight in the middle, the adventurer bosses behind, skeletons around.
func _build_lineup() -> void:
	for entry: Array in LINEUP:
		var model := (load(ADVENTURERS + entry[0] + ".glb") as PackedScene).instantiate() as Node3D
		add_child(model)
		model.position = entry[1]
		model.scale = Vector3.ONE * float(entry[2])
		ModelTools.keep_props(model, entry[4])
		_play_looped(model.get_node("AnimationPlayer") as AnimationPlayer, entry[3])
	var horde := [["Skeleton_Minion", 1.0, 26], ["Skeleton_Rogue", 0.9, 10], ["Skeleton_Warrior", 1.6, 4]]
	for kind: Array in horde:
		var scene := load(SKELETONS + kind[0] + ".glb") as PackedScene
		for i in int(kind[2]):
			var model := scene.instantiate() as Node3D
			add_child(model)
			var angle := randf_range(0.15, 0.85) * PI
			model.position = Vector3(cos(angle) * randf_range(4.0, 11.0), 0.0, sin(angle) * randf_range(4.0, 7.0) + 1.0)
			model.scale = Vector3.ONE * float(kind[1])
			model.look_at(Vector3(0.0, 0.0, 2.0) + (model.global_position - Vector3(0.0, 0.0, 2.0)) * 2.0, Vector3.UP)
			_play_looped(model.get_node("AnimationPlayer") as AnimationPlayer, "Walking_D_Skeletons")


static func _play_looped(player: AnimationPlayer, animation: String) -> void:
	player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	player.play(animation)
	player.seek(randf() * player.get_animation(animation).length, true)


static func _average(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)


static func _percentile(values: PackedFloat32Array, ratio: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size() * ratio), 0, sorted.size() - 1)] if not sorted.is_empty() else 0.0
