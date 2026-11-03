class_name CharacterAnimator
extends AnimationTree
## Animation tree for a KayKit character (they all share one rig and animation names), built in
## code. Three layers on top of each other:
## - locomotion: a 2D blend space of idle, running forward and backward and strafing, so the
##   character can face the mouse while moving any way;
## - upper body: one-shot actions on the spine, arms and head (sword swings, casts, flinches)
##   that play while the legs keep running;
## - full body: one-shot actions (dodges, leaps) and held poses (the Whirlwind spin, death).
## Add it as a child of the model's root (next to its AnimationPlayer) and call setup().

const UPPER_BONES: Array[String] = ["spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
		"handslot.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "elbowIK.l", "handIK.l",
		"elbowIK.r", "handIK.r"]
const LOOPED: Array[StringName] = [&"Idle", &"Running_A", &"Running_Strafe_Left", &"Running_Strafe_Right",
		&"2H_Melee_Attack_Spinning"]
## Ground speed (m/s) at which the run cycle's feet don't slide, for a model at scale 1.
const RUN_ANIMATION_SPEED := 6.0
const HOLD_FADE_PER_SECOND := 10.0

var _model_scale := 1.0
var _upper_animation: AnimationNodeAnimation
var _full_animation: AnimationNodeAnimation
var _hold_animation: AnimationNodeAnimation
var _hold_target := 0.0
var _hold_amount := 0.0
var _missing_warned: Dictionary = {}


## model_scale: the model's scale, so the run cycle matches the ground speed.
func setup(model_scale := 1.0) -> void:
	_model_scale = model_scale
	anim_player = NodePath("../AnimationPlayer")
	var player := get_node(anim_player) as AnimationPlayer
	for name in LOOPED:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	var tree := AnimationNodeBlendTree.new()

	var locomotion := AnimationNodeBlendSpace2D.new()
	locomotion.add_blend_point(_clip(&"Idle"), Vector2.ZERO, -1, &"idle")
	locomotion.add_blend_point(_clip(&"Running_A"), Vector2(0.0, 1.0), -1, &"forward")
	# No backward run in the set: the forward run played in reverse reads well from above.
	var backward := _clip(&"Running_A")
	backward.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
	locomotion.add_blend_point(backward, Vector2(0.0, -1.0), -1, &"backward")
	locomotion.add_blend_point(_clip(&"Running_Strafe_Left"), Vector2(-1.0, 0.0), -1, &"left")
	locomotion.add_blend_point(_clip(&"Running_Strafe_Right"), Vector2(1.0, 0.0), -1, &"right")
	tree.add_node(&"Locomotion", locomotion)
	tree.add_node(&"LocomotionSpeed", AnimationNodeTimeScale.new())
	tree.connect_node(&"LocomotionSpeed", 0, &"Locomotion")

	_upper_animation = _clip(&"Idle")
	tree.add_node(&"UpperClip", _upper_animation)
	tree.add_node(&"UpperSpeed", AnimationNodeTimeScale.new())
	tree.connect_node(&"UpperSpeed", 0, &"UpperClip")
	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.05
	upper.fadeout_time = 0.15
	upper.filter_enabled = true
	for bone in UPPER_BONES:
		upper.set_filter_path(NodePath("Rig/Skeleton3D:" + bone), true)
	tree.add_node(&"Upper", upper)
	tree.connect_node(&"Upper", 0, &"LocomotionSpeed")
	tree.connect_node(&"Upper", 1, &"UpperSpeed")

	_full_animation = _clip(&"Idle")
	tree.add_node(&"FullClip", _full_animation)
	tree.add_node(&"FullSpeed", AnimationNodeTimeScale.new())
	tree.connect_node(&"FullSpeed", 0, &"FullClip")
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.05
	full.fadeout_time = 0.12
	tree.add_node(&"Full", full)
	tree.connect_node(&"Full", 0, &"Upper")
	tree.connect_node(&"Full", 1, &"FullSpeed")

	_hold_animation = _clip(&"Idle")
	tree.add_node(&"HoldClip", _hold_animation)
	tree.add_node(&"HoldSeek", AnimationNodeTimeSeek.new())
	tree.connect_node(&"HoldSeek", 0, &"HoldClip")
	tree.add_node(&"HoldSpeed", AnimationNodeTimeScale.new())
	tree.connect_node(&"HoldSpeed", 0, &"HoldSeek")
	tree.add_node(&"Hold", AnimationNodeBlend2.new())
	tree.connect_node(&"Hold", 0, &"Full")
	tree.connect_node(&"Hold", 1, &"HoldSpeed")
	tree.connect_node(&"output", 0, &"Hold")

	tree_root = tree
	active = true


func _process(delta: float) -> void:
	_hold_amount = move_toward(_hold_amount, _hold_target, HOLD_FADE_PER_SECOND * delta)
	set(&"parameters/Hold/blend_amount", _hold_amount)


## direction: movement relative to where the model faces (x = right, y = forward), length 0..1;
## speed: ground speed in m/s, which sets how fast the feet move.
func set_locomotion(direction: Vector2, speed: float) -> void:
	set(&"parameters/Locomotion/blend_position", direction.limit_length(1.0))
	var cycle := speed / (RUN_ANIMATION_SPEED * _model_scale) if direction.length() > 0.1 else 1.0
	set(&"parameters/LocomotionSpeed/scale", clampf(cycle, 0.6, 2.2))


## Plays an action on the upper body only; seconds > 0 fits the clip into that time.
func play_upper(animation: StringName, seconds := 0.0) -> void:
	if _fit(_upper_animation, &"parameters/UpperSpeed/scale", animation, seconds):
		set(&"parameters/Upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## True while an upper-body action is playing.
func is_upper_busy() -> bool:
	return get(&"parameters/Upper/active")


## Plays an action on the whole body (dodge, leap); seconds > 0 fits the clip into that time.
func play_full(animation: StringName, seconds := 0.0) -> void:
	if _fit(_full_animation, &"parameters/FullSpeed/scale", animation, seconds):
		set(&"parameters/Full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Holds a whole-body animation (looped or not) until release(), e.g. the Whirlwind spin or death.
func hold(animation: StringName, speed := 1.0) -> void:
	if not _has(animation):
		return
	_hold_animation.animation = animation
	set(&"parameters/HoldSpeed/scale", speed)
	set(&"parameters/HoldSeek/seek_request", 0.0)
	_hold_target = 1.0


func release() -> void:
	_hold_target = 0.0


func _fit(clip: AnimationNodeAnimation, scale_parameter: StringName, animation: StringName, seconds: float) -> bool:
	if not _has(animation):
		return false
	clip.animation = animation
	var length := (get_node(anim_player) as AnimationPlayer).get_animation(animation).length
	set(scale_parameter, length / seconds if seconds > 0.0 else 1.0)
	return true


func _has(animation: StringName) -> bool:
	if (get_node(anim_player) as AnimationPlayer).has_animation(animation):
		return true
	if not _missing_warned.has(animation):
		_missing_warned[animation] = true
		push_warning("Missing animation: %s" % animation)
	return false


static func _clip(animation: StringName) -> AnimationNodeAnimation:
	var clip := AnimationNodeAnimation.new()
	clip.animation = animation
	return clip
