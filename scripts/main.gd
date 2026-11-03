extends Node3D
## Manages a run: timer, pausing, level-ups and how the run ends (escape or failure).
## The result is applied to the profile; the result screen leads back to camp.

const HUB_SCENE := "res://scenes/hub.tscn"

@onready var player: Player = $Player
@onready var director: RunDirector = $RunDirector
@onready var hud: Hud = $HUD
@onready var level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var pause_screen: PauseScreen = $PauseScreen
@onready var game_over_screen: GameOverScreen = $GameOverScreen

var _pending_level_ups := 0
var _paused_by_player := false
var _is_over := false


func _enter_tree() -> void:
	Game.reset()


func _ready() -> void:
	Profile.begin_run()
	Game.player = player
	Game.world = $Dynamic
	Game.pickups = $Pickups
	Game.spawner = $EnemySpawner
	Game.director = director
	Game.particles = ParticleBursts.new()
	add_child(Game.particles)
	Game.damage_numbers = DamageNumbers.new()
	add_child(Game.damage_numbers)
	Audio.play_music("run")
	hud.setup(player)
	pause_screen.setup(player)
	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)
	director.run_ended.connect(_on_run_ended)
	level_up_screen.boon_chosen.connect(_on_boon_chosen)
	pause_screen.toggle_requested.connect(_on_pause_toggle_requested)
	pause_screen.abandon_requested.connect(_on_abandon_requested)
	game_over_screen.continue_requested.connect(_on_continue_requested)
	Game.announce("Survive!")


func _physics_process(delta: float) -> void:
	Game.run_time += delta


func _unhandled_input(event: InputEvent) -> void:
	# Test shortcut: Shift+T fast-forwards time by 1 minute (debug builds only).
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.shift_pressed and key.physical_keycode == KEY_T:
		Game.run_time += 60.0
		Game.announce("Test: %s" % UiKit.format_time(Game.run_time))
		get_viewport().set_input_as_handled()


func _on_player_leveled_up(_level: int) -> void:
	_pending_level_ups += 1
	if _pending_level_ups == 1:
		_open_level_up()
	_refresh_pause()


func _open_level_up() -> void:
	var shown_level := player.level - _pending_level_ups + 1
	level_up_screen.open(BoonLibrary.roll_choices(player, 3), player, shown_level)


func _on_boon_chosen(boon_id: String) -> void:
	if _is_over:
		return
	player.add_boon(boon_id)
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		_open_level_up()
	else:
		level_up_screen.close()
	_refresh_pause()


func _on_player_died() -> void:
	director.end_run(false, "You died")


func _on_abandon_requested() -> void:
	director.end_run(false, "You withdrew")


func _on_run_ended(result: Dictionary) -> void:
	_is_over = true
	_paused_by_player = false
	_pending_level_ups = 0
	level_up_screen.close()
	pause_screen.hide()
	Audio.stop_loops()
	var summary := Profile.apply_run_result(result)
	game_over_screen.open(summary, Game.run_time, player.level, Game.kills)
	_refresh_pause()


func _on_pause_toggle_requested() -> void:
	if _is_over or _pending_level_ups > 0:
		return
	_paused_by_player = not _paused_by_player
	pause_screen.visible = _paused_by_player
	Audio.play("ui_open" if _paused_by_player else "ui_close")
	_refresh_pause()


func _on_continue_requested() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(HUB_SCENE)


func _refresh_pause() -> void:
	get_tree().paused = _paused_by_player or _pending_level_ups > 0 or _is_over
