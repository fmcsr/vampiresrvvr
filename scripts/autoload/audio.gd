extends Node
## Sound effects and music. Effects are played by id from SOUNDS; their files are
## audio/sfx/<id>_<n>.wav (built by tools/import_sfx.py and tools/synth_sfx.py). A shared pool
## of players keeps the cost flat, and every id has a voice limit and a minimum gap, so a hundred
## hits in one frame stay a few sounds. Looping sounds (gate hum, heartbeat) get their own
## players. Music crossfades between the tracks in MUSIC. Volumes come from Settings.

const SFX_PATH := "res://audio/sfx/%s_%d.wav"
const POOL_SIZE := 32
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
## Used when a SOUNDS entry leaves the field out.
const DEFAULT_VOICES := 3
const DEFAULT_GAP := 0.03
const DEFAULT_PITCH_SPREAD := 0.05
## play_at(): sounds farther than NEAR_DISTANCE from the player get quieter; past FAR_DISTANCE
## they don't play at all (m).
const NEAR_DISTANCE := 14.0
const FAR_DISTANCE := 40.0
const FAR_ATTENUATION_DB := 18.0
const MUSIC_FADE := 1.5
const SILENT_DB := -60.0

## id: {"count": variations, "volume": dB, "pitch": random ± ratio, "voices": how many can play
## at once, "gap": minimum seconds between two plays}. Tune the mix here.
const SOUNDS := {
	# Combat
	"swing": {"count": 3, "volume": -15.0, "pitch": 0.08, "voices": 2},
	"hit": {"count": 3, "volume": -10.0, "pitch": 0.1, "gap": 0.05},
	"kill_bone": {"count": 4, "volume": -12.0, "pitch": 0.12, "voices": 4, "gap": 0.04},
	"kill_flesh": {"count": 3, "volume": -14.0, "pitch": 0.12, "gap": 0.05},
	"kill_heavy": {"count": 3, "volume": -8.0, "pitch": 0.08, "voices": 2, "gap": 0.08},
	"player_hurt": {"count": 3, "volume": -7.0, "pitch": 0.06, "voices": 1, "gap": 0.12},
	"player_death": {"count": 1, "volume": -3.0, "pitch": 0.0, "voices": 1},
	"heartbeat": {"count": 1, "volume": -9.0},
	# Pickups and loot
	"xp": {"count": 1, "volume": -19.0, "pitch": 0.0, "voices": 4},
	"gold": {"count": 3, "volume": -11.0, "pitch": 0.08, "voices": 2, "gap": 0.06},
	"chest": {"count": 1, "volume": -8.0, "voices": 2},
	"item": {"count": 1, "volume": -9.0, "voices": 2},
	"core": {"count": 1, "volume": -6.0, "pitch": 0.0, "voices": 1},
	"level_up": {"count": 1, "volume": -8.0, "pitch": 0.0, "voices": 1},
	"boon": {"count": 2, "volume": -11.0, "voices": 1},
	# Powers
	"fire_wave": {"count": 2, "volume": -6.0, "pitch": 0.06, "voices": 2},
	"soul_chain": {"count": 2, "volume": -8.0, "voices": 2},
	"frost_nova": {"count": 3, "volume": -8.0, "pitch": 0.06, "voices": 2},
	"bone_shield": {"count": 2, "volume": -8.0, "voices": 2},
	"slam": {"count": 2, "volume": -5.0, "pitch": 0.06, "voices": 2, "gap": 0.08},
	"war_cry": {"count": 2, "volume": -7.0, "pitch": 0.04, "voices": 1},
	"thunder": {"count": 1, "volume": -4.0, "pitch": 0.08, "gap": 0.08},
	"sword_drop": {"count": 3, "volume": -14.0, "pitch": 0.1, "gap": 0.05},
	"blade": {"count": 3, "volume": -10.0, "pitch": 0.05, "voices": 2},
	# Bosses and the run
	"boss_roar": {"count": 2, "volume": -4.0, "pitch": 0.04, "voices": 1},
	"boss_growl": {"count": 3, "volume": -7.0, "pitch": 0.05, "voices": 1},
	"boss_summon": {"count": 2, "volume": -7.0, "voices": 1},
	"gong": {"count": 1, "volume": -6.0, "pitch": 0.0, "voices": 1},
	"bell": {"count": 1, "volume": -7.0, "pitch": 0.0, "voices": 1},
	"extract": {"count": 1, "volume": -5.0, "pitch": 0.0, "voices": 1},
	"howl": {"count": 1, "volume": -9.0, "pitch": 0.05, "voices": 1},
	"bong": {"count": 1, "volume": -10.0, "pitch": 0.0, "voices": 1},
	"gate_hum": {"count": 1, "volume": -12.0},
	"gate_break": {"count": 1, "volume": -10.0, "pitch": 0.0, "voices": 1, "gap": 0.3},
	"tick": {"count": 1, "volume": -10.0, "pitch": 0.0, "voices": 1},
	# Camp and menus
	"equip": {"count": 2, "volume": -10.0, "voices": 1},
	"unequip": {"count": 1, "volume": -11.0, "voices": 1},
	"ui_click": {"count": 2, "volume": -14.0, "voices": 2},
	"ui_hover": {"count": 1, "volume": -22.0, "pitch": 0.03, "voices": 1, "gap": 0.04},
	"ui_confirm": {"count": 1, "volume": -12.0, "voices": 1},
	"ui_error": {"count": 1, "volume": -12.0, "voices": 1},
	"ui_back": {"count": 1, "volume": -12.0, "voices": 1},
	"ui_tab": {"count": 1, "volume": -14.0, "voices": 1},
	"ui_open": {"count": 1, "volume": -13.0, "voices": 1},
	"ui_close": {"count": 1, "volume": -13.0, "voices": 1},
}

## Track: {"path": music file, "volume": dB}. A track with an empty path plays nothing.
## The volumes even out how differently loud the files are (integrated loudness measured with
## ffmpeg's ebur128: camp -22 LUFS, run -40, boss -7).
const MUSIC := {
	"camp": {"path": "res://audio/music/dark_shrine_loop.ogg", "volume": -3.0},
	"run": {"path": "res://audio/music/dungeon_ambience.ogg", "volume": 15.0},
	"boss": {"path": "res://audio/music/epic_boss_battle.ogg", "volume": -14.0},
}

var _pool: Array[AudioStreamPlayer] = []
## Sound id each pool player last played, and when it started (s).
var _pool_ids: Array[String] = []
var _pool_started: Array[float] = []
var _streams: Dictionary[String, Array] = {}
var _last_variation: Dictionary[String, int] = {}
var _last_played: Dictionary[String, float] = {}
var _loops: Dictionary[String, AudioStreamPlayer] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_tweens: Array[Tween] = [null, null]
var _music_index := 0
var _music_track := ""
## Set by quit_quietly(): nothing new starts while the game shuts down.
var _quitting := false


func _ready() -> void:
	# Keeps playing (and fading) while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(EFFECTS_BUS)
	# One limiter on the master bus keeps a pile of sounds from clipping.
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	for i in POOL_SIZE:
		_pool.append(_make_player(EFFECTS_BUS))
		_pool_ids.append("")
		_pool_started.append(-1.0)
	for i in 2:
		_music.append(_make_player(MUSIC_BUS))
	for id: String in SOUNDS:
		_load_streams(id)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func _exit_tree() -> void:
	stop_all()


## Stops every sound and the music.
func stop_all() -> void:
	_music_track = ""
	for player: AudioStreamPlayer in _pool + _music + _loops.values():
		player.stop()
		player.stream = null


## Stops everything, gives the audio thread a moment to let go of the sounds, then quits.
## Quitting while sounds play makes Godot report them as leaked; the tests quit this way. The
## wait is in real milliseconds because --fixed-fps runs frames faster than real time.
func quit_quietly(exit_code := 0) -> void:
	_quitting = true
	stop_all()
	for i in 5:
		OS.delay_msec(30)
		await get_tree().process_frame
	get_tree().quit(exit_code)


## Plays a sound effect by id. pitch multiplies the sound's random pitch; volume is added in dB.
func play(id: String, pitch := 1.0, volume := 0.0) -> void:
	if _quitting:
		return
	var sound: Dictionary = SOUNDS.get(id, {})
	if sound.is_empty():
		push_warning("Unknown sound: %s" % id)
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_played.get(id, -1000.0) < sound.get("gap", DEFAULT_GAP):
		return
	var index := _free_voice(id, sound.get("voices", DEFAULT_VOICES))
	if index < 0:
		return
	_last_played[id] = now
	var player := _pool[index]
	player.stream = _pick_stream(id)
	var spread: float = sound.get("pitch", DEFAULT_PITCH_SPREAD)
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-spread, spread)), 0.05)
	player.volume_db = sound.get("volume", 0.0) + volume
	player.play()
	_pool_ids[index] = id
	_pool_started[index] = now


## Like play(), but quieter the farther `at` is from the player, and silent far off screen.
func play_at(id: String, at: Vector3, pitch := 1.0, volume := 0.0) -> void:
	var player := Game.player
	if player:
		var distance := player.global_position.distance_to(at)
		if distance >= FAR_DISTANCE:
			return
		volume -= remap(clampf(distance, NEAR_DISTANCE, FAR_DISTANCE), NEAR_DISTANCE, FAR_DISTANCE, 0.0, FAR_ATTENUATION_DB)
	play(id, pitch, volume)


## Starts, updates or stops a looping sound. key names the loop, so several can run at once;
## pitch and volume can follow a value every frame (e.g. the gate's channel progress).
func set_loop(key: String, id: String, active: bool, pitch := 1.0, volume := 0.0) -> void:
	var player: AudioStreamPlayer = _loops.get(key)
	if not active or _quitting:
		if player and player.playing:
			player.stop()
		return
	if player == null:
		player = _make_player(EFFECTS_BUS)
		_loops[key] = player
	var sound: Dictionary = SOUNDS[id]
	player.pitch_scale = maxf(pitch, 0.05)
	player.volume_db = sound.get("volume", 0.0) + volume
	if not player.playing:
		player.stream = _pick_stream(id)
		player.play()


func stop_loops() -> void:
	for player: AudioStreamPlayer in _loops.values():
		player.stop()


## Crossfades to a MUSIC track ("camp", "run", "boss"); "" fades the music out.
func play_music(track: String) -> void:
	if track == _music_track or _quitting:
		return
	_music_track = track
	_fade(_music_index, SILENT_DB, true)
	var info: Dictionary = MUSIC.get(track, {})
	var path: String = info.get("path", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	_music_index = 1 - _music_index
	var player := _music[_music_index]
	player.stream = load(path)
	_set_looping(player.stream)
	player.volume_db = SILENT_DB
	player.play()
	_fade(_music_index, info.get("volume", 0.0), false)


func music_track() -> String:
	return _music_track


## How many variations of a sound loaded (for the tests).
func variation_count(id: String) -> int:
	return _streams.get(id, []).size()


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## A pool index for this id, or -1 if the id already plays on all its voices. A silent player
## is used first, otherwise the one that started longest ago.
func _free_voice(id: String, voices: int) -> int:
	var in_use := 0
	var free := -1
	var oldest := 0
	for i in POOL_SIZE:
		if _pool[i].playing:
			if _pool_ids[i] == id:
				in_use += 1
			if _pool_started[i] < _pool_started[oldest]:
				oldest = i
		elif free < 0:
			free = i
	if in_use >= voices:
		return -1
	return free if free >= 0 else oldest


func _load_streams(id: String) -> void:
	var streams: Array[AudioStream] = []
	for n in range(1, int(SOUNDS[id].get("count", 1)) + 1):
		var path := SFX_PATH % [id, n]
		if ResourceLoader.exists(path):
			streams.append(load(path))
		else:
			push_warning("Missing sound file: %s" % path)
	_streams[id] = streams


## A random variation, never the same one twice in a row.
func _pick_stream(id: String) -> AudioStream:
	var streams: Array = _streams.get(id, [])
	if streams.is_empty():
		return null
	var choice := randi() % streams.size()
	if streams.size() > 1 and choice == _last_variation.get(id, -1):
		choice = (choice + 1) % streams.size()
	_last_variation[id] = choice
	return streams[choice]


## Fades a music player in linear amplitude (a dB-linear fade drops out too early).
func _fade(index: int, target_db: float, stop_after: bool) -> void:
	var player := _music[index]
	if _music_tweens[index]:
		_music_tweens[index].kill()
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_method(func(amount: float) -> void: player.volume_db = linear_to_db(maxf(amount, 0.001)),
			db_to_linear(player.volume_db), db_to_linear(target_db), MUSIC_FADE)
	if stop_after:
		tween.tween_callback(player.stop)
	_music_tweens[index] = tween


func _apply_volumes() -> void:
	_set_bus_volume(&"Master", Settings.master_volume)
	_set_bus_volume(MUSIC_BUS, Settings.music_volume)
	_set_bus_volume(EFFECTS_BUS, Settings.effects_volume)


static func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


static func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


static func _set_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
