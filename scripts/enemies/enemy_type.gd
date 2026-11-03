class_name EnemyType
extends Resource
## Tunable values for an enemy type. New type = new .tres under resources/enemies.

## Emission strength of the eyes (the KayKit Glow material), so they read in the dark.
const EYE_GLOW := 3.0

@export var display_name := "Enemy"
@export var color := Color(0.8, 0.8, 0.8)
@export_range(0.5, 3.0) var size := 1.0
@export var max_health := 20.0
@export var move_speed := 3.0
@export var contact_damage := 6.0
## Time between attacks (s).
@export var attack_interval := 0.8
## Time from the start of a swing to the hit (s); a player who leaves reach by then takes no damage.
@export var attack_windup := 0.35
@export_range(0.0, 1.0) var knockback_resistance := 0.0
@export var xp_value := 1

@export_group("Spawning")
## Run time (s) from which this type can spawn.
@export var unlock_time := 0.0
## Spawn weight relative to the other types.
@export var spawn_weight := 1.0
## Enemies of this type built when the run starts, so the first waves don't stall on building them.
@export var prewarm_count := 40

@export_group("Model")
## KayKit character drawn for this type. Types without one keep the meshes in their scene (the
## bosses' capsule, for now).
@export var model: PackedScene
## Model scale at size 1.
@export var model_scale := 0.8
## KayKit weapons in the right and left hand (merged into the model's mesh).
@export var right_hand: PackedScene
@export var left_hand: PackedScene
## Casts a real shadow. The horde only gets a blob under its feet, which costs far less.
@export var casts_shadow := false

@export_group("Animation")
@export var walk_animation := &"Running_A"
## Ground speed (m/s) at which the walk clip's feet don't slide, for a model at scale 1.
@export var walk_cycle_speed := 3.4
@export var attack_animation := &"1H_Melee_Attack_Slice_Diagonal"
## When the weapon lands in the attack clip (s, at normal speed); the clip is sped up so this
## moment falls at the end of the windup.
@export var attack_hit_time := 0.4
@export var death_animation := &"Death_C_Skeletons"
## Played when it climbs out of the ground (siege waves, summons).
@export var rise_animation := &"Spawn_Ground_Skeletons"

@export_group("Feedback")
## Particle burst when it dies (a ParticleBursts kind) and its color.
@export var death_burst := &"bones"
@export var death_color := Color(0.88, 0.85, 0.75)
## Sound played when it dies (an id from Audio.SOUNDS).
@export var death_sound := "kill_bone"

var _material: StandardMaterial3D
var _mesh: ArrayMesh


func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = color
		_material.roughness = 0.85
	return _material


## The model's parts and weapons merged into one mesh, shared by every enemy of this type.
func get_mesh(parts: Array[MeshInstance3D]) -> ArrayMesh:
	if _mesh == null:
		_mesh = ModelTools.merge_skinned_parts(parts, {"handslot.r": right_hand, "handslot.l": left_hand})
		for surface in _mesh.get_surface_count():
			var material := _mesh.surface_get_material(surface) as BaseMaterial3D
			if material and material.emission_enabled:
				var eyes := material.duplicate() as BaseMaterial3D
				eyes.emission_energy_multiplier = EYE_GLOW
				_mesh.surface_set_material(surface, eyes)
	return _mesh
