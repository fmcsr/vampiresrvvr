@tool
extends Node3D
## Arena: a dungeon swallowed by the desert. Dusky sand with the old stone floor showing through,
## broken pillars, rubble, barrels, graves, dead trees, bones and dry grass inside half-buried walls.
## Built in _ready from the tables below with a fixed seed, so every run looks the same; it also
## runs in the editor (the built nodes are never saved), so reopen the scene after editing a table.
## Obstacles get colliders on layer 1 (the player, the enemies and the spawner's free-point check
## see them); small props have none. Each mesh is drawn by one MultiMeshInstance3D wherever it
## appears, only big pieces cast shadows and the few lights cast none.

const SAND_SHADER := preload("res://shaders/sand.gdshader")
const PROP_SHADER := preload("res://shaders/desert_prop.gdshader")
const BROKEN_SHADER := preload("res://shaders/desert_prop_broken.gdshader")
const GRASS_SHADER := preload("res://shaders/dry_grass.gdshader")
const DUNGEON_ATLAS := preload("res://models/kaykit/dungeon/dungeon_texture.png")
const HALLOWEEN_ATLAS := preload("res://models/kaykit/halloween/halloweenbits_texture.png")
const DUNGEON_PATH := "res://models/kaykit/dungeon/%s.gltf.glb"
const HALLOWEEN_PATH := "res://models/kaykit/halloween/%s.gltf"
const DUNGEON_MODELS := ["barrel_large", "barrel_small", "barrel_small_stack", "box_large", "column",
		"crates_stacked", "floor_tile_large", "floor_tile_large_rocks", "floor_tile_small",
		"floor_tile_small_broken_A", "floor_tile_small_broken_B", "floor_tile_small_weeds_A",
		"floor_tile_small_weeds_B", "keg", "pillar", "pillar_decorated", "rubble_half", "rubble_large",
		"sword_shield_broken", "torch_lit", "torch_mounted", "wall_broken", "wall_cracked"]

const SEED := 1909
## The sand reaches well past the walls, where it rises into dunes (m).
const GROUND_SIZE := 200.0
## Center line of the edge walls; their colliders (arena.tscn) span 60..62 m from the center.
const WALL_LINE := 60.8
const WALL_SEGMENTS := 30
## Edge walls: name, yaw that turns the wall to face the arena (degrees), how deep the sand
## buries them (m). The camera looks over the south wall, so that one is buried deepest.
const WALL_SIDES := [["north", 0.0, 0.6, 1.3], ["south", 180.0, 2.3, 2.8],
		["west", 90.0, 0.9, 1.8], ["east", -90.0, 0.9, 1.8]]
## Height of the floor tiles' top above the sand (m); effects are drawn at 0.03 and up.
const FLOOR_TOP := 0.01
## Layout mask (see shaders/desert_sand.gdshaderinc): texels per side, covering MASK_EXTENT m.
const MASK_SIZE := 256
const MASK_EXTENT := 128.0
const EXPOSURE := 0
const HOLLOW := 1
const DAMP := 2
const LIGHT_COLOR := Color(1.0, 0.62, 0.32)

## Old stone floor showing through the sand: center (x, z), half size (m).
const FLOOR_PATCHES := [
	[Vector2(0, -1), Vector2(12, 11)],  # plaza around the start
	[Vector2(-4, -36), Vector2(15, 4.5)],  # colonnade
	[Vector2(34, -34), Vector2(7, 6)],  # collapsed hall
	[Vector2(-39, -7), Vector2(6, 6)],  # storeroom
	[Vector2(4, 40), Vector2(3.5, 6.5)],  # walk to the arch
	[Vector2(23, 25), Vector2(3, 3)],
	[Vector2(-24, 24), Vector2(2, 3)],
	[Vector2(47, -13), Vector2(3, 2)],
	[Vector2(-15, 48), Vector2(3, 2)],
	[Vector2(26, -50), Vector2(4, 3)],
	[Vector2(-48, 30), Vector2(2, 2)],
	[Vector2(-27, -12), Vector2(2.5, 2)],
	[Vector2(13, 31), Vector2(2.5, 2.5)],
	[Vector2(45, 27), Vector2(3, 2)],
	[Vector2(-50, -50), Vector2(3, 3)],
	[Vector2(50, 50), Vector2(2, 3)],
	[Vector2(-8, 55), Vector2(4, 2)],
]
## Solid obstacles: kind, position (x, z), yaw (degrees), size (pillar height, rubble scale...).
## Keep the middle clear: the start (10 m around the origin) and the smoke test's walking circle
## (x -11..11, z 0..22).
const OBSTACLES := [
	# Broken pillars around the plaza.
	["pillar", Vector2(-15, -13), 10.0, 2.9],
	["pillar", Vector2(15.5, -14), -20.0, 2.2],
	["pillar", Vector2(17, 7), 35.0, 1.6],
	["fallen_pillar", Vector2(-18.5, 5), 100.0, 3.2],
	# Colonnade of the old hall; the short one carries a torch.
	["pillar", Vector2(-16, -36), 0.0, 3.4],
	["pillar_decorated", Vector2(-8, -36), 0.0, 0.0],
	["pillar", Vector2(0, -36), 0.0, 1.9],
	["rubble_large", Vector2(37, -30), -15.0, 0.55],
	["rubble_half", Vector2(27, -4), 120.0, 0.55],
	# Graveyard.
	["grave", Vector2(40, 4), 0.0, 0.0],
	["grave", Vector2(44.5, 11), -15.0, 0.0],
	["tree_large", Vector2(47, -1), 20.0, 0.0],
	# Storeroom.
	["crates", Vector2(-41, -11), 15.0, 0.0],
	["barrels", Vector2(-35, -3), 30.0, 0.0],
	["arch", Vector2(4, 44), 0.0, 0.0],
	# Dead grove.
	["tree_large", Vector2(-38, 31), 30.0, 0.0],
	["tree_medium", Vector2(-31, 38), -60.0, 0.0],
	["shrine", Vector2(-34, 29.5), 20.0, 0.0],
	["ribcage", Vector2(-40, -40), 35.0, 0.0],
	["wall_ruin", Vector2(36, 38), 25.0, 0.8],
	["barrel_pile", Vector2(21, 17), -40.0, 0.0],
	["fallen_pillar", Vector2(-6, 31), 75.0, 3.4],
]
## Bones of fallen adventurers: position, yaw (degrees), whether a broken sword and shield lie there.
const REMAINS := [
	[Vector2(6, -8), 30.0, true], [Vector2(4, -29), 160.0, false], [Vector2(41, -41), 80.0, true],
	[Vector2(44, 16), -30.0, false], [Vector2(-31, 3), 210.0, true], [Vector2(-45, 39), 120.0, false],
	[Vector2(-44, -34), 10.0, true], [Vector2(29, 42), 250.0, false], [Vector2(-20, -50), 60.0, true],
	[Vector2(-22, 52), 300.0, false], [Vector2(53, -14), 140.0, true], [Vector2(-52, 8), 20.0, false],
	[Vector2(10, 54), 190.0, false], [Vector2(24, -22), 95.0, true], [Vector2(-26, -22), 330.0, false],
]
## Dry grass: center (x, z), radius (m).
const GRASS := [
	[Vector2(-12, 3), 3.5], [Vector2(11, -12), 2.5], [Vector2(14, -2), 2.0], [Vector2(-5, 13), 2.5],
	[Vector2(-36, 34), 8.0], [Vector2(-28, 30), 3.0], [Vector2(39, 9), 5.0], [Vector2(47, 2), 2.5],
	[Vector2(33, 41), 4.5], [Vector2(-43, -2), 3.0], [Vector2(-33, -12), 2.0], [Vector2(-17, -32), 3.0],
	[Vector2(6, -40), 2.5], [Vector2(34, -26), 3.0], [Vector2(-40, -45), 3.5], [Vector2(22, 20), 3.0],
	[Vector2(-8, 35), 3.0], [Vector2(28, -8), 2.0], [Vector2(6, 49), 3.0], [Vector2(-54, 30), 3.0],
	[Vector2(54, 26), 3.5], [Vector2(-25, 54), 3.0], [Vector2(51, -37), 3.0], [Vector2(-53, -20), 3.0],
	[Vector2(18, -53), 3.0], [Vector2(-30, 12), 2.5], [Vector2(30, 14), 2.0], [Vector2(-20, -24), 2.0],
	[Vector2(12, 30), 2.5], [Vector2(-14, 20), 2.0], [Vector2(43, 30), 3.0], [Vector2(-46, 14), 2.5],
	[Vector2(0, -52), 3.0], [Vector2(-36, -54), 2.5], [Vector2(46, -50), 2.5], [Vector2(24, 50), 2.5],
]
## Drums of fallen columns lying in the open sand: position, yaw (degrees).
const DRUMS := [
	[Vector2(25, 31), 40.0], [Vector2(-29, 19), 110.0], [Vector2(15, 49), 160.0], [Vector2(-48, -26), 20.0],
	[Vector2(47, 21), 75.0], [Vector2(-9, -47), 130.0], [Vector2(33, -45), 15.0], [Vector2(30.5, -37.5), 65.0],
]
## Heaps of loose stones in the open sand.
const STONE_HEAPS := [
	Vector2(9, 25), Vector2(-24, 38), Vector2(52, 10), Vector2(-11, -21), Vector2(31, -15),
	Vector2(-54, -8), Vector2(19, -40), Vector2(-33, 48), Vector2(54, -27), Vector2(-3, -56), Vector2(40, -36),
]

## One MultiMeshInstance3D worth of instances.
class Batch:
	var mesh: Mesh
	var material: ShaderMaterial
	var shadows := false
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _mask := PackedByteArray()
var _materials: Dictionary[StringName, ShaderMaterial] = {}
var _batches: Dictionary[String, Batch] = {}
## Model name -> [mesh, transform relative to the model's root] for each of its mesh parts.
var _parts_cache: Dictionary[String, Array] = {}
var _procedural: Dictionary[StringName, Mesh] = {}
## Footprints (x, z, radius) of obstacles and big props, which the scatter keeps out of.
var _footprints: Array[Vector3] = []
var _obstacles: Node3D
var _lights: Array[OmniLight3D] = []
var _light_energy := PackedFloat32Array()
var _time := 0.0


func _ready() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.06
	_mask.resize(MASK_SIZE * MASK_SIZE * 4)
	_obstacles = Node3D.new()
	_obstacles.name = "Obstacles"
	add_child(_obstacles)
	_build_materials()
	_build_ground()
	_build_floor()
	for entry: Array in OBSTACLES:
		_build_obstacle(entry)
	_build_walls()
	_build_dressing()
	_apply_mask()
	_flush_batches()


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var phase := _time * 6.0 + i * 11.3
		_lights[i].light_energy = _light_energy[i] * (0.9 + 0.07 * sin(phase) + 0.04 * sin(phase * 2.7 + 1.3))


# --- Materials and meshes ---------------------------------------------------------------------


func _build_materials() -> void:
	var warm := Vector3(1.2, 1.0, 0.75)
	var pale := Vector3(1.18, 1.0, 0.78)
	var sand := ShaderMaterial.new()
	sand.shader = SAND_SHADER
	_materials[&"sand"] = sand
	_materials[&"stone"] = _prop_material(PROP_SHADER, DUNGEON_ATLAS, warm, 0.55, 0.8)
	_materials[&"stone_broken"] = _prop_material(BROKEN_SHADER, DUNGEON_ATLAS, warm, 0.55, 0.8)
	_materials[&"floor"] = _prop_material(PROP_SHADER, DUNGEON_ATLAS, Vector3(1.32, 1.0, 0.66), 0.55, 0.55)
	_materials[&"floor"].set_shader_parameter("ground_dust", 0.0)
	_materials[&"floor"].set_shader_parameter("top_dust", 0.3)
	_materials[&"floor"].set_shader_parameter("drift_cover", 1.0)
	_materials[&"floor"].set_shader_parameter("shade_variation", 0.05)
	_materials[&"floor"].set_shader_parameter("stain", 0.6)
	_materials[&"halloween"] = _prop_material(PROP_SHADER, HALLOWEEN_ATLAS, pale, 0.55, 0.8)
	_materials[&"bone"] = _prop_material(PROP_SHADER, HALLOWEEN_ATLAS, Vector3(0.9, 0.78, 0.55), 0.6, 0.5)
	_materials[&"bone"].set_shader_parameter("ground_dust", 0.45)
	_materials[&"bone"].set_shader_parameter("dust_height", 0.3)
	_materials[&"glow"] = _prop_material(PROP_SHADER, DUNGEON_ATLAS, warm, 0.6, 0.8)
	_materials[&"glow"].set_shader_parameter("glow", 4.0)
	_materials[&"glow_halloween"] = _prop_material(PROP_SHADER, HALLOWEEN_ATLAS, pale, 0.6, 0.8)
	_materials[&"glow_halloween"].set_shader_parameter("glow", 4.0)
	var grass := ShaderMaterial.new()
	grass.shader = GRASS_SHADER
	_materials[&"grass"] = grass


## The sand floor, built here rather than saved in the scene, like everything else the layout
## mask is painted into.
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	plane.subdivide_width = int(GROUND_SIZE / 2.0) - 1
	plane.subdivide_depth = int(GROUND_SIZE / 2.0) - 1
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = _materials[&"sand"]
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


static func _prop_material(shader: Shader, atlas: Texture2D, tint: Vector3, saturation: float,
		brightness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", atlas)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("saturation", saturation)
	material.set_shader_parameter("brightness", brightness)
	return material


## Mesh parts of a KayKit model, loaded once.
func _parts(model: String) -> Array:
	if not _parts_cache.has(model):
		var path := DUNGEON_PATH % model if model in DUNGEON_MODELS else HALLOWEEN_PATH % model
		var root := (load(path) as PackedScene).instantiate() as Node3D
		var parts := []
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var relative := (node as Node3D).transform
			var parent := node.get_parent()
			while parent != root:
				relative = (parent as Node3D).transform * relative
				parent = parent.get_parent()
			parts.append([(node as MeshInstance3D).mesh, relative])
		root.free()
		_parts_cache[model] = parts
	return _parts_cache[model]


## Adds one instance of a KayKit model (all its parts) to the batches.
func _place(model: String, xform: Transform3D, material: StringName, shadows := false,
		custom := Color(0, 0, 0, 0), group := "") -> void:
	for part: Array in _parts(model):
		_add_instance(part[0], xform * (part[1] as Transform3D), material, shadows, custom, group)


## group splits a mesh's instances into their own MultiMesh (the walls of each side), so they
## are culled separately.
func _add_instance(mesh: Mesh, xform: Transform3D, material: StringName, shadows: bool,
		custom: Color, group: String) -> void:
	var key := "%d|%s|%s|%s" % [mesh.get_instance_id(), material, shadows, group]
	if not _batches.has(key):
		var batch := Batch.new()
		batch.mesh = mesh
		batch.material = _materials[material]
		batch.shadows = shadows
		_batches[key] = batch
	_batches[key].transforms.append(xform)
	_batches[key].customs.append(custom)


func _flush_batches() -> void:
	var holder := Node3D.new()
	holder.name = "Dressing"
	add_child(holder)
	for key in _batches:
		var batch := _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multimesh.set_instance_transform(i, batch.transforms[i])
			multimesh.set_instance_custom_data(i, batch.customs[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.material_override = batch.material
		node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch.shadows
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		holder.add_child(node)


## Procedural meshes, built once: grass tuft, rocks, barrel stave, sand drifts.
func _mesh(kind: StringName) -> Mesh:
	if not _procedural.has(kind):
		match kind:
			&"grass":
				_procedural[kind] = _grass_mesh()
			&"rock_a":
				_procedural[kind] = _rock_mesh(1)
			&"rock_b":
				_procedural[kind] = _rock_mesh(2)
			&"stave":
				_procedural[kind] = _stave_mesh()
			&"drift":
				_procedural[kind] = _drift_mesh(0.72, 0.09)
			&"drift_long":
				_procedural[kind] = _drift_mesh(0.42, 0.075)
	return _procedural[kind]


## Tuft of nine tapered blades leaning outward; UV.y runs from root to tip.
static func _grass_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	var blades := 9
	for blade in blades:
		var angle := TAU * blade / blades + rng.randf_range(-0.3, 0.3)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-outward.z, 0.0, outward.x) * rng.randf_range(0.035, 0.055)
		var height := rng.randf_range(0.55, 1.0)
		var lean := rng.randf_range(0.2, 0.5) * height
		var root := outward * rng.randf_range(0.02, 0.1)
		var middle := root + outward * lean * 0.4 + Vector3.UP * height * 0.55
		var tip := root + outward * lean + Vector3.UP * height
		var points: Array[Vector3] = [root - side, root + side, middle - side * 0.6, middle + side * 0.6, tip]
		var heights: Array[float] = [0.0, 0.0, 0.55, 0.55, 1.0]
		for index: int in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			surface.set_uv(Vector2(0.0, heights[index]))
			surface.add_vertex(points[index])
	surface.index()
	return surface.commit()


## Flat-shaded rock: a squashed, jittered icosahedron, colored from the dungeon atlas' rock swatch.
static func _rock_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + variant
	var t := (1.0 + sqrt(5.0)) / 2.0
	var corners: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in corners.size():
		corners[i] = corners[i].normalized() * rng.randf_range(0.7, 1.15) * Vector3(0.5, 0.32, 0.45)
		corners[i].y -= 0.08
	var faces: Array[int] = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2,
			10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in range(0, faces.size(), 3):
		var a := corners[faces[f]]
		var b := corners[faces[f + 1]]
		var c := corners[faces[f + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
			var swap := b
			b = c
			c = swap
		surface.set_normal(normal)
		surface.set_uv(Vector2(0.92, lerpf(0.2, 0.05, normal.y * 0.5 + 0.5)))
		# Godot's front faces wind clockwise, the opposite of the right-hand normal.
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(b)
	return surface.commit()


## Loose barrel stave: a thin, slightly bent plank in the atlas' wood color.
static func _stave_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_uv(Vector2(0.56, 0.1))
	var half := Vector3(0.07, 0.02, 0.42)
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var u := Vector3(normal.y, normal.z, normal.x)
		var v := normal.cross(u)
		var center := normal * half
		var corners: Array[Vector3] = []
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner := center + (u * s.x + v * s.y) * half
			corner.y += 0.05 * (1.0 - pow(corner.z / half.z, 2.0))
			corners.append(corner)
		surface.set_normal(normal)
		for index: int in [0, 2, 1, 0, 3, 2]:
			surface.add_vertex(corners[index])
	return surface.commit()


## Low sand drift with a flat rim that melts into the ground: 1 m long (x), depth wide (z) and
## height tall. Its proportions are baked in because a multimesh instance's normals don't follow
## a non-uniform scale; instances are only scaled uniformly.
static func _drift_mesh(depth: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 5
	var segments := 14
	for ring in rings:
		for segment in segments:
			var quad: Array[Vector2] = [Vector2(ring, segment), Vector2(ring + 1, segment),
					Vector2(ring + 1, segment + 1), Vector2(ring, segment + 1)]
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner in quad:
				var r := corner.x / rings
				var angle := TAU * corner.y / segments
				var rise := height * pow(1.0 - r * r, 2.0)
				points.append(Vector3(cos(angle), 0.0, sin(angle) * depth) * r + Vector3.UP * rise)
				var slope := 4.0 * height * r * (1.0 - r * r)
				normals.append(Vector3(slope * cos(angle), 1.0, slope * sin(angle) / depth).normalized())
			for index: int in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(normals[index])
				surface.add_vertex(points[index])
	surface.index()
	return surface.commit()


# --- Layout mask -------------------------------------------------------------------------------


## Raises one channel of the layout mask around a point: full strength inside inner, fading to 0
## at radius. Overlapping paint keeps the stronger value.
func _paint(channel: int, center: Vector2, radius: float, strength: float, inner := 0.0) -> void:
	var texel := MASK_EXTENT / MASK_SIZE
	var origin := (center + Vector2.ONE * MASK_EXTENT * 0.5) / texel
	var reach := radius / texel
	for z in range(maxi(int(origin.y - reach), 0), mini(int(origin.y + reach) + 1, MASK_SIZE)):
		for x in range(maxi(int(origin.x - reach), 0), mini(int(origin.x + reach) + 1, MASK_SIZE)):
			var distance := Vector2(x + 0.5 - origin.x, z + 0.5 - origin.y).length() * texel
			if distance >= radius:
				continue
			var value := int(255.0 * strength * (1.0 - smoothstep(inner, radius, distance)))
			var index := (z * MASK_SIZE + x) * 4 + channel
			if value > _mask[index]:
				_mask[index] = value


## How clear of sand one patch of old floor is at a point: 1 swept clean, 0 buried. The edge
## wobbles, and tongues of sand reach in across the floor.
func _exposure(patch: Array, point: Vector2) -> float:
	var offset: Vector2 = (point - (patch[0] as Vector2)).abs() - (patch[1] as Vector2)
	var outside := Vector2(maxf(offset.x, 0.0), maxf(offset.y, 0.0)).length() + minf(maxf(offset.x, offset.y), 0.0)
	var wobble := (sin(point.x * 0.23 + sin(point.y * 0.17) * 1.3) * 1.6
			+ sin(point.y * 0.29 + sin(point.x * 0.11 + 1.7) * 1.1) * 1.4)
	var tongue := smoothstep(0.2, 0.5, _noise.get_noise_2dv(point))
	return (1.0 - smoothstep(-2.5, 2.0, outside + wobble)) * (1.0 - 0.9 * tongue)


func _mask_value(channel: int, point: Vector2) -> float:
	var texel := MASK_EXTENT / MASK_SIZE
	var x := clampi(int((point.x + MASK_EXTENT * 0.5) / texel), 0, MASK_SIZE - 1)
	var z := clampi(int((point.y + MASK_EXTENT * 0.5) / texel), 0, MASK_SIZE - 1)
	return _mask[(z * MASK_SIZE + x) * 4 + channel] / 255.0


func _apply_mask() -> void:
	var image := Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8, _mask)
	var texture := ImageTexture.create_from_image(image)
	var rect := Vector4(-MASK_EXTENT * 0.5, -MASK_EXTENT * 0.5, MASK_EXTENT, MASK_EXTENT)
	for material: ShaderMaterial in _materials.values():
		if material.shader != GRASS_SHADER:
			material.set_shader_parameter("layout_mask", texture)
			material.set_shader_parameter("mask_rect", rect)


# --- Floor -------------------------------------------------------------------------------------


## Paints where the old floor shows and lays tiles there: whole 4 m tiles where it is swept clean,
## 2 m tiles (more of them broken or weedy, some missing) toward the drifts.
func _build_floor() -> void:
	var texel := MASK_EXTENT / MASK_SIZE
	var half_extent := MASK_EXTENT * 0.5
	# 2 m cells already tiled, so patches that reach into each other don't stack tiles.
	var tiled: Dictionary[Vector2i, bool] = {}
	for patch: Array in FLOOR_PATCHES:
		var center: Vector2 = patch[0]
		var reach: Vector2 = (patch[1] as Vector2) + Vector2(5.0, 5.0)
		for z in range(maxi(int((center.y - reach.y + half_extent) / texel), 0),
				mini(int((center.y + reach.y + half_extent) / texel) + 1, MASK_SIZE)):
			for x in range(maxi(int((center.x - reach.x + half_extent) / texel), 0),
					mini(int((center.x + reach.x + half_extent) / texel) + 1, MASK_SIZE)):
				var point := Vector2(x + 0.5, z + 0.5) * texel - Vector2.ONE * half_extent
				var value := int(255.0 * _exposure(patch, point))
				var index := (z * MASK_SIZE + x) * 4 + EXPOSURE
				if value > _mask[index]:
					_mask[index] = value
		# Cells of 2 m; a whole tile covers 2 x 2 cells on the 4 m grid.
		var cells: Dictionary[Vector2i, float] = {}
		var first := Vector2i(floori((center.x - reach.x) / 2.0), floori((center.y - reach.y) / 2.0))
		var last := Vector2i(ceili((center.x + reach.x) / 2.0), ceili((center.y + reach.y) / 2.0))
		for cz in range(first.y, last.y):
			for cx in range(first.x, last.x):
				var exposure := _exposure(patch, Vector2(cx * 2.0 + 1.0, cz * 2.0 + 1.0))
				if exposure > 0.12 and not tiled.has(Vector2i(cx, cz)):
					cells[Vector2i(cx, cz)] = exposure
					tiled[Vector2i(cx, cz)] = true
		for cell: Vector2i in cells.keys():
			if cell.x % 2 != 0 or cell.y % 2 != 0 or not cells.has(cell):
				continue
			var block: Array[Vector2i] = [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]
			var clear := true
			for part in block:
				clear = clear and cells.has(part) and cells[part] > 0.6
			if not clear or _rng.randf() < 0.45:
				continue
			for part in block:
				cells.erase(part)
			var at := Vector2(cell.x * 2.0 + 2.0, cell.y * 2.0 + 2.0)
			var model := "floor_tile_large_rocks" if _rng.randf() < 0.1 and at.length() > 8.0 else "floor_tile_large"
			_place(model, Transform3D(Basis(Vector3.UP, _rng.randi_range(0, 3) * PI / 2.0),
					Vector3(at.x, FLOOR_TOP - 0.05, at.y)), &"floor")
		for cell: Vector2i in cells:
			var exposure: float = cells[cell]
			if _rng.randf() < (0.0 if exposure > 0.55 else 0.08 if exposure > 0.3 else 0.25):
				continue
			var model := "floor_tile_small"
			var weathered := _rng.randf()
			var worn := 0.25 if exposure > 0.55 else 0.6 if exposure > 0.3 else 0.85
			if weathered < worn * 0.15:
				model = "floor_tile_small_broken_A"
			elif weathered < worn * 0.65:
				model = "floor_tile_small_broken_B"
			elif weathered < worn:
				model = "floor_tile_small_weeds_A" if _rng.randf() < 0.5 else "floor_tile_small_weeds_B"
			var tilt := Vector3.ZERO
			if exposure < 0.55:
				tilt = Vector3(_rng.randf_range(-0.01, 0.01), 0.0, _rng.randf_range(-0.01, 0.01))
			var orient := Basis.from_euler(tilt) * Basis(Vector3.UP, _rng.randi_range(0, 3) * PI / 2.0)
			var middle := Vector3(cell.x * 2.0 + 1.0, FLOOR_TOP - 0.05, cell.y * 2.0 + 1.0)
			_place(model, Transform3D(orient, middle), &"floor")


# --- Obstacles ---------------------------------------------------------------------------------


func _build_obstacle(entry: Array) -> void:
	var kind: String = entry[0]
	var at: Vector2 = entry[1]
	var yaw := deg_to_rad(entry[2])
	var size: float = entry[3]
	match kind:
		"pillar":
			_broken_pillar(at, yaw, size)
		"pillar_decorated":
			_place("pillar_decorated", _ground_transform(at, yaw, -0.1), &"stone", true)
			_solid_box(at, Vector3(1.6, 4.0, 1.6), yaw)
			_settle(at, 1.0, 2.8)
		"fallen_pillar":
			_fallen_pillar(at, yaw, size)
		"rubble_large", "rubble_half":
			_rubble(kind, at, yaw, size)
		"grave":
			_place("grave_A_destroyed", _ground_transform(at, yaw, -0.1), &"halloween", true)
			_solid_box(at + Vector2(0.04, -0.07).rotated(-yaw), Vector3(2.0, 2.0, 1.1), yaw)
			_settle(at, 1.2, 2.4)
		"tree_large", "tree_medium":
			_place("tree_dead_large" if kind == "tree_large" else "tree_dead_medium",
					_ground_transform(at, yaw, 0.0), &"halloween", true)
			_solid_cylinder(at, 0.45, 3.0)
			_settle(at, 0.5, 2.0)
			_grass_patch(at, 2.5)
		"crates":
			_crates(at, yaw)
		"barrels":
			_barrels(at, yaw)
		"barrel_pile":
			_barrel_pile(at, yaw)
		"arch":
			_place("arch", _ground_transform(at, yaw, -0.2), &"halloween", true)
			for leg: float in [-1.72, 1.72]:
				var foot := at + Vector2(leg, 0.0).rotated(-yaw)
				_solid_box(foot, Vector3(0.8, 3.5, 0.85), yaw)
				_settle(foot, 0.5, 1.6)
			_rocks_around(at, 1.5, 4.0, 6)
		"shrine":
			_place("shrine_candles", _ground_transform(at, yaw, -0.05), &"glow_halloween", true)
			_place("candle_triple", _ground_transform(at + Vector2(1.1, 0.6).rotated(-yaw), yaw + 0.6, 0.0),
					&"glow_halloween")
			_solid_box(at, Vector3(1.1, 1.8, 1.1), yaw)
			_settle(at, 0.7, 1.8)
			_add_light(Vector3(at.x + 0.6, 1.3, at.y + 0.8), 1.3, 6.0)
		"ribcage":
			_giant_ribcage(at, yaw)
		"wall_ruin":
			_wall_ruin(at, yaw, size)


## Transform for a prop standing on the sand at a point, raised by height (negative sinks it).
static func _ground_transform(at: Vector2, yaw: float, height: float, factor := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * factor), Vector3(at.x, height, at.y))


## Solid box standing on the ground, at least 2 m tall so the spawner's check at 1 m finds it.
## On layer 1, the StaticBody3D default.
func _solid_box(at: Vector2, size: Vector3, yaw: float) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, maxf(size.y, 2.0), size.z)
	_add_body(box, Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, box.size.y * 0.5, at.y)))


func _solid_cylinder(at: Vector2, radius: float, height: float) -> void:
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	_add_body(cylinder, Transform3D(Basis.IDENTITY, Vector3(at.x, height * 0.5, at.y)))


func _add_body(shape: Shape3D, placement: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.transform = placement
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_obstacles.add_child(body)


## Beds a prop into the sand: keeps the scatter out, darkens a hollow around it and piles a drift
## against it.
func _settle(at: Vector2, radius: float, hollow: float) -> void:
	_footprints.append(Vector3(at.x, at.y, radius + 0.4))
	_paint(HOLLOW, at, hollow, 0.5, radius * 0.6)
	var angle := _rng.randf() * TAU
	_drift(at + Vector2.from_angle(angle) * radius * 0.8, radius + 1.0, -angle)


func _broken_pillar(at: Vector2, yaw: float, height: float) -> void:
	_place("pillar", _ground_transform(at, yaw, -0.15), &"stone_broken", true,
			Color(height + 0.15, 0.35, _rng.randf() * 10.0, 1.0))
	_solid_box(at, Vector3(1.5, height, 1.5), yaw)
	_settle(at, 1.0, 2.8)
	_rocks_around(at, 1.1, 3.0, 7)
	if height < 3.0:
		# The top that broke off lies next to it.
		_drum(at + Vector2(2.4, 1.5).rotated(-yaw), yaw + 0.9)


## Pillar lying on its side, broken off at length (m), centered on at.
func _fallen_pillar(at: Vector2, yaw: float, length: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var origin := Vector3(at.x, 0.45, at.y) + turn * Vector3(-length * 0.5, 0.0, 0.0)
	_place("pillar", Transform3D(turn * Basis(Vector3.BACK, -PI / 2.0), origin), &"stone_broken", true,
			Color(length, 0.4, _rng.randf() * 10.0, 1.0))
	_solid_box(at, Vector3(length, 1.2, 1.5), yaw)
	_footprints.append(Vector3(at.x, at.y, length * 0.5 + 0.4))
	for end: float in [-0.3, 0.3]:
		_paint(HOLLOW, at + Vector2(length * end, 0.0).rotated(-yaw), 2.4, 0.45, 0.8)
	_drift(at + Vector2(0.0, 0.8).rotated(-yaw), length * 0.6, yaw, true)
	_rocks_around(at, 1.2, 3.2, 6)
	_drum(at + Vector2(length * 0.5 + 1.6, -0.8).rotated(-yaw), yaw - 0.5)


## Drum of a fallen column lying in the sand.
func _drum(at: Vector2, yaw: float) -> void:
	var orient := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI / 2.0)
	_place("column", Transform3D(orient, Vector3(at.x, 0.22, at.y)), &"stone", true)
	_footprints.append(Vector3(at.x, at.y, 1.0))


func _rubble(model: String, at: Vector2, yaw: float, factor: float) -> void:
	var bounds := (_parts(model)[0][0] as Mesh).get_aabb()
	var turn := Basis(Vector3.UP, yaw)
	var middle := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z) * factor
	_place(model, Transform3D(turn * Basis.from_scale(Vector3.ONE * factor), Vector3(at.x, -0.2, at.y) - turn * middle),
			&"stone", true)
	var size := Vector3(bounds.size.x * 0.82, bounds.size.y * 0.85, bounds.size.z * 0.75) * factor
	_solid_box(at, size, yaw)
	_footprints.append(Vector3(at.x, at.y, size.x * 0.5 + 0.3))
	_paint(HOLLOW, at, size.x * 0.5 + 2.0, 0.5, size.z * 0.4)
	_rocks_around(at, size.x * 0.4, size.x * 0.5 + 2.5, 9)


func _wall_ruin(at: Vector2, yaw: float, sink: float) -> void:
	_place("wall_broken", _ground_transform(at, yaw, -sink), &"stone", true)
	_solid_box(at, Vector3(4.0, 4.0 - sink, 1.0), yaw)
	_footprints.append(Vector3(at.x, at.y, 2.3))
	_paint(HOLLOW, at, 3.4, 0.45, 1.0)
	for side: float in [-1.0, 1.0]:
		_drift(at + Vector2(0.0, side * 0.9).rotated(-yaw), 2.4, yaw, true)
	_rocks_around(at, 1.2, 3.5, 8)
	_place("barrel_small", _ground_transform(at + Vector2(2.9, 1.3).rotated(-yaw), yaw, 0.0), &"stone")
	_broken_barrel(at + Vector2(-2.6, 1.5).rotated(-yaw), yaw + 1.2)


func _crates(at: Vector2, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	_place("crates_stacked", _ground_transform(at, yaw, -0.05), &"stone", true)
	_place("box_large", _ground_transform(at + Vector2(1.9, 0.3).rotated(-yaw), yaw + 0.2, -0.05), &"stone", true)
	_place("keg", _ground_transform(at + Vector2(-2.0, 0.1).rotated(-yaw), yaw + PI / 2.0, -0.05), &"stone", true)
	_solid_box(at, Vector3(5.6, 2.2, 2.1), yaw)
	_footprints.append(Vector3(at.x, at.y, 3.2))
	_paint(HOLLOW, at, 4.2, 0.45, 1.5)
	_drift(at + Vector2(0.0, 1.3).rotated(-yaw), 2.8, yaw, true)
	_place("barrel_small", Transform3D(turn * Basis(Vector3.RIGHT, PI / 2.0),
			Vector3(at.x, 0.45, at.y) + turn * Vector3(0.8, 0.0, 2.1)), &"stone")
	_staves(at + Vector2(0.0, 2.4).rotated(-yaw), 4)


## Storeroom barrels with a lantern on the big one.
func _barrels(at: Vector2, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	_place("barrel_large", _ground_transform(at, yaw, -0.05), &"stone", true)
	_place("barrel_small_stack", _ground_transform(at + Vector2(1.9, -0.2).rotated(-yaw), yaw, -0.05), &"stone", true)
	_place("barrel_small", _ground_transform(at + Vector2(-1.4, 0.3).rotated(-yaw), yaw + 0.7, -0.05), &"stone", true)
	_solid_box(at + Vector2(0.45, 0.0).rotated(-yaw), Vector3(4.8, 2.0, 2.0), yaw)
	_footprints.append(Vector3(at.x, at.y, 2.8))
	_paint(HOLLOW, at, 3.8, 0.45, 1.2)
	_place("lantern_standing", _ground_transform(at + Vector2(0.15, 0.1).rotated(-yaw), yaw, 1.95), &"glow_halloween")
	_add_light(Vector3(at.x, 2.7, at.y) + turn * Vector3(0.15, 0.0, 0.6), 1.7, 8.0)
	_place("barrel_small", Transform3D(turn * Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, PI / 2.0),
			Vector3(at.x, 0.45, at.y) + turn * Vector3(0.4, 0.0, 1.9)), &"stone")
	_broken_barrel(at + Vector2(-1.8, 1.7).rotated(-yaw), yaw)
	_staves(at + Vector2(-1.2, 2.3).rotated(-yaw), 5)
	_drift(at + Vector2(0.4, -1.1).rotated(-yaw), 2.6, yaw, true)


## A big barrel with a tipped and a broken small one beside it.
func _barrel_pile(at: Vector2, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	_place("barrel_large", _ground_transform(at, yaw, -0.05), &"stone", true)
	_solid_cylinder(at, 0.95, 2.0)
	_settle(at, 0.95, 2.4)
	_place("barrel_small", Transform3D(turn * Basis(Vector3.UP, 1.1) * Basis(Vector3.RIGHT, PI / 2.0),
			Vector3(at.x, 0.45, at.y) + turn * Vector3(1.6, 0.0, 0.9)), &"stone")
	_broken_barrel(at + Vector2(-1.5, 1.0).rotated(-yaw), yaw + 2.0)
	_staves(at + Vector2(-0.6, 2.0).rotated(-yaw), 4)


func _broken_barrel(at: Vector2, yaw: float) -> void:
	_place("barrel_small", _ground_transform(at, yaw, -0.05), &"stone_broken", false,
			Color(_rng.randf_range(0.42, 0.6), 0.22, _rng.randf() * 10.0, 0.0))
	_footprints.append(Vector3(at.x, at.y, 0.7))


func _staves(at: Vector2, count: int) -> void:
	for i in count:
		var spot := at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.7, 0.7))
		var orient := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.15, 0.15))
		_add_instance(_mesh(&"stave"), Transform3D(orient, Vector3(spot.x, 0.0, spot.y)), &"stone", false, Color(), "")


## Ribs of something huge sticking out of the sand, its skull nearby.
func _giant_ribcage(at: Vector2, yaw: float) -> void:
	var orient := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.25) * Basis.from_scale(Vector3.ONE * 3.0)
	_place("ribcage", Transform3D(orient, Vector3(at.x, 0.55, at.y)), &"bone", true)
	_solid_cylinder(at, 1.25, 2.2)
	_settle(at, 1.3, 3.2)
	var skull_at := at + Vector2(3.4, 1.6).rotated(-yaw)
	_place("skull", Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.4) * Basis.from_scale(Vector3.ONE * 1.25),
			Vector3(skull_at.x, -0.3, skull_at.y)), &"bone", true)
	_footprints.append(Vector3(skull_at.x, skull_at.y, 1.0))
	for i in 5:
		_bone(at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, 4.0), _rng.randf_range(1.0, 1.4))


# --- Walls -------------------------------------------------------------------------------------


## Half-buried walls along the edge (each side its own batches, so unseen sides are culled), a
## pillar every few segments, collapsed stretches and a torch on the north wall.
func _build_walls() -> void:
	for side: Array in WALL_SIDES:
		var group: String = side[0]
		var yaw := deg_to_rad(side[1])
		var turn := Basis(Vector3.UP, yaw)
		var north := group == "north"
		for i in WALL_SEGMENTS:
			var along := -58.0 + 4.0 * i
			var sink := _rng.randf_range(side[2], side[3])
			var special := north and i == 19
			if special:
				sink = 0.7
			var roll := _rng.randf()
			if roll < 0.1 and not special:
				_place("rubble_half", Transform3D(turn, turn * Vector3(along - 2.0, -sink * 0.8, -WALL_LINE)),
						&"stone", true, Color(), group)
			else:
				var model := "wall_broken" if roll < 0.42 and not special else "wall_cracked"
				_place(model, Transform3D(turn, turn * Vector3(along, -sink, -WALL_LINE)), &"stone", true, Color(), group)
			if i % 3 == 0:
				var joint := Vector3(along - 2.0, -sink + _rng.randf_range(0.0, 0.4), -WALL_LINE + 0.15)
				var pillar := Transform3D(turn, turn * joint)
				if _rng.randf() < 0.4:
					_place("pillar", pillar, &"stone_broken", true,
							Color(_rng.randf_range(2.2, 3.6), 0.35, _rng.randf() * 10.0, 1.0), group)
				else:
					_place("pillar", pillar, &"stone", true, Color(), group)
			var inner := WALL_LINE - 1.2
			if _rng.randf() < 0.75:
				var spot := turn * Vector3(along + _rng.randf_range(-1.0, 1.0), 0.0, -inner)
				_drift(Vector2(spot.x, spot.z), _rng.randf_range(1.8, 2.6), -yaw, true)
			for r in _rng.randi_range(0, 2):
				var spot := turn * Vector3(along + _rng.randf_range(-1.8, 1.8), 0.0, -inner + _rng.randf_range(-0.2, 1.0))
				_rock(Vector2(spot.x, spot.z), _rng.randf_range(0.5, 1.1))
			if north and i == 19:
				_place("torch_mounted", Transform3D(turn, Vector3(along, 2.0, -WALL_LINE + 0.63)), &"glow")
				_add_light(Vector3(along, 2.6, -WALL_LINE + 1.4), 2.0, 9.0)


# --- Dressing ----------------------------------------------------------------------------------


func _build_dressing() -> void:
	# Plaza: a lantern by the north-west pillar.
	_place("lantern_standing", _ground_transform(Vector2(-13.2, -10.6), 0.4, 0.0), &"glow_halloween")
	_footprints.append(Vector3(-13.2, -10.6, 0.6))
	_add_light(Vector3(-13.2, 0.9, -10.3), 1.6, 7.0)
	# Colonnade: a torch stuck on the broken pillar.
	_place("torch_lit", _ground_transform(Vector2(0.1, -35.9), 0.3, 2.15), &"glow")
	_add_light(Vector3(0.1, 2.9, -35.3), 2.0, 9.0)
	_graveyard()
	_storeroom()
	_grove()
	for entry: Array in DRUMS:
		_drum(entry[0], deg_to_rad(entry[1]))
		_rocks_around(entry[0], 1.0, 2.5, 3)
	for at: Vector2 in STONE_HEAPS:
		_rocks_around(at, 0.0, 2.2, 9)
	for entry: Array in REMAINS:
		_remains(entry[0], deg_to_rad(entry[1]), entry[2])
	for entry: Array in GRASS:
		_grass_patch(entry[0], entry[1])
	# Loose bones and stones over the open sand.
	for i in 230:
		var spot := Vector2(_rng.randf_range(-57.0, 57.0), _rng.randf_range(-57.0, 57.0))
		if _is_blocked(spot, 0.6) or _mask_value(EXPOSURE, spot) > 0.5:
			continue
		if i % 3 == 0:
			_bone(spot, _rng.randf_range(0.5, 0.75))
		else:
			_rock(spot, _rng.randf_range(0.4, 1.0))


func _graveyard() -> void:
	# A flagstone path leading in from the plaza side.
	for i in 5:
		var spot := Vector2(29.0 + i * 1.9, 7.5 + sin(i * 1.3) * 0.5)
		_place("path_A" if i % 2 == 0 else "path_B", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU),
				Vector3(spot.x, -0.08, spot.y)), &"halloween")
	_place("lantern_standing", _ground_transform(Vector2(37.5, 6.6), 0.2, 0.0), &"glow_halloween")
	_footprints.append(Vector3(37.5, 6.6, 0.6))
	_add_light(Vector3(37.5, 0.9, 6.9), 1.6, 7.5)
	_place("candle_triple", _ground_transform(Vector2(40.7, 5.0), 0.3, 0.0), &"glow_halloween")
	for entry: Array in [[Vector2(35.5, 13), 0.15], [Vector2(41, 15.5), -0.3], [Vector2(48, 7), 0.5]]:
		var at: Vector2 = entry[0]
		var yaw: float = entry[1]
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.15, 0.1)) * Basis(Vector3.BACK, _rng.randf_range(-0.12, 0.12))
		_place("gravestone", Transform3D(Basis(Vector3.UP, yaw) * tilt, Vector3(at.x, -0.15, at.y)), &"halloween", true)
		_settle(at, 0.7, 1.6)
	for at: Vector2 in [Vector2(34, 2.5), Vector2(46.5, 4), Vector2(38.5, 16.5), Vector2(43, 0.5)]:
		var tilt := Basis(Vector3.BACK, _rng.randf_range(-0.3, 0.3))
		_place("gravemarker_A", Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)) * tilt,
				Vector3(at.x, -0.1, at.y)), &"halloween")
	for entry: Array in [[Vector2(37, -1.5), 0.05], [Vector2(42.5, -2.2), -0.12]]:
		var at: Vector2 = entry[0]
		var yaw: float = entry[1]
		_place("fence_broken", _ground_transform(at, yaw, -0.25, 0.85), &"halloween", true)
	_place("fence_pillar_broken", _ground_transform(Vector2(34.4, -1.3), 0.0, -0.1), &"halloween")
	_place("fence_pillar_broken", _ground_transform(Vector2(45.3, -2.6), 0.4, -0.1), &"halloween")
	# An open coffin half in the sand, its lid slid off.
	var coffin := Transform3D(Basis(Vector3.UP, 1.4) * Basis(Vector3.RIGHT, 0.08) * Basis.from_scale(Vector3.ONE * 0.75),
			Vector3(45.5, -0.3, 16.5))
	for part: Array in _parts("coffin"):
		var lid := (part[0] as Mesh).get_aabb().position.y > 0.5
		var slide := (Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.25), Vector3(1.6, -0.55, 0.4))
				if lid else Transform3D.IDENTITY)
		_add_instance(part[0], coffin * slide * (part[1] as Transform3D), &"halloween", false, Color(), "")
	_footprints.append(Vector3(45.5, 16.5, 1.6))
	_place("post_skull", _ground_transform(Vector2(31, 13), 2.6, -0.2), &"halloween", true)
	_footprints.append(Vector3(31, 13, 0.6))


func _storeroom() -> void:
	_place("sword_shield_broken", _ground_transform(Vector2(-33.4, -9.5), 0.8, -0.05), &"stone")
	_place("box_large", _ground_transform(Vector2(-44.5, -4.5), 0.5, -0.4, 0.8), &"stone")
	_footprints.append(Vector3(-44.5, -4.5, 1.0))
	_rocks_around(Vector2(-39, -7), 4.0, 7.5, 6)


func _grove() -> void:
	_place("tree_dead_small", _ground_transform(Vector2(-43, 37), 2.2, 0.0), &"halloween", true)
	_footprints.append(Vector3(-43, 37, 0.5))
	_place("tree_dead_small", _ground_transform(Vector2(-27, 26), 4.0, 0.0, 0.8), &"halloween", true)
	_footprints.append(Vector3(-27, 26, 0.5))
	_place("skull", Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, -0.45) * Basis.from_scale(Vector3.ONE * 0.9),
			Vector3(-40.8, -0.2, 35.5)), &"bone", true)
	_footprints.append(Vector3(-40.8, 35.5, 0.6))
	_rocks_around(Vector2(-36, 34), 3.0, 8.0, 8)


## Bones of an adventurer: ribcage, skull and a few loose bones, maybe a broken sword and shield.
func _remains(at: Vector2, yaw: float, armed: bool) -> void:
	var turn := Basis(Vector3.UP, yaw)
	_place("ribcage", Transform3D(turn * Basis(Vector3.RIGHT, -1.35) * Basis.from_scale(Vector3.ONE * 0.6),
			Vector3(at.x, 0.06, at.y)), &"bone")
	var skull := at + Vector2(0.9, -0.4).rotated(-yaw)
	_place("skull", Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.9, 0.9)) * Basis(Vector3.RIGHT, -0.45)
			* Basis.from_scale(Vector3.ONE * 0.5), Vector3(skull.x, -0.06, skull.y)), &"bone")
	for i in 3:
		_bone(at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.6, 1.5), _rng.randf_range(0.5, 0.7))
	if armed:
		var sword := at + Vector2(-0.9, 0.7).rotated(-yaw)
		_place("sword_shield_broken", Transform3D(Basis(Vector3.UP, yaw + 0.5) * Basis(Vector3.BACK, 0.2),
				Vector3(sword.x, -0.1, sword.y)), &"stone")
	_footprints.append(Vector3(at.x, at.y, 1.2))


func _bone(at: Vector2, size: float) -> void:
	var model: String = ["bone_A", "bone_B", "bone_C"][_rng.randi_range(0, 2)]
	var orient := (Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
			* Basis.from_scale(Vector3.ONE * size))
	_place(model, Transform3D(orient, Vector3(at.x, 0.03 * size, at.y)), &"bone")


func _rock(at: Vector2, size: float) -> void:
	var kind := &"rock_a" if _rng.randf() < 0.5 else &"rock_b"
	var squash := Vector3(1.0, _rng.randf_range(0.8, 1.2), 1.0)
	var orient := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(squash * size)
	_add_instance(_mesh(kind), Transform3D(orient, Vector3(at.x, 0.0, at.y)), &"stone", false, Color(), "")


func _rocks_around(at: Vector2, inner: float, outer: float, count: int) -> void:
	for i in count:
		var distance := _rng.randf_range(inner, outer)
		var spot := at + Vector2.from_angle(_rng.randf() * TAU) * distance
		_rock(spot, _rng.randf_range(0.5, 1.3) * (1.0 - 0.4 * (distance - inner) / maxf(outer - inner, 0.1)))


## Sand piled against a prop: length is the drift's half length (m); long ones lie along walls.
func _drift(at: Vector2, length: float, yaw: float, long := false) -> void:
	var orient := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * length)
	_add_instance(_mesh(&"drift_long" if long else &"drift"), Transform3D(orient, Vector3(at.x, -0.02, at.y)),
			&"sand", false, Color(), "")


## Tufts of dry grass, denser toward the middle, on damp, darker sand; none on swept stone.
func _grass_patch(center: Vector2, radius: float) -> void:
	_paint(DAMP, center, radius * 1.15, 0.55, radius * 0.35)
	for i in int(radius * radius * 3.5):
		var distance := radius * pow(_rng.randf(), 0.8)
		var spot := center + Vector2.from_angle(_rng.randf() * TAU) * distance
		if _is_blocked(spot, 0.0) or _mask_value(EXPOSURE, spot) > 0.6:
			continue
		var size := _rng.randf_range(0.5, 0.95) * (1.0 - 0.45 * distance / radius)
		var stretch := Vector3(1.0, _rng.randf_range(0.8, 1.2), 1.0)
		var orient := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(stretch * size)
		_add_instance(_mesh(&"grass"), Transform3D(orient, Vector3(spot.x, 0.0, spot.y)), &"grass", false,
				Color(pow(_rng.randf(), 1.6), 0.0, 0.0, 0.0), "")


func _is_blocked(point: Vector2, margin: float) -> bool:
	for footprint in _footprints:
		if Vector2(footprint.x, footprint.y).distance_to(point) < footprint.z + margin:
			return true
	return false


func _add_light(at: Vector3, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = LIGHT_COLOR
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	add_child(light)
	_lights.append(light)
	_light_energy.append(energy)
