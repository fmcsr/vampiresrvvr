class_name ParticleBursts
extends Node3D
## Pooled one-shot GPU particle bursts: hit sparks, bone shards, dust, embers and so on. Main adds
## one to every run and effects call Fx.burst(). Each kind keeps a small ring of emitters, so a new
## burst reuses the oldest one instead of creating nodes mid-fight.

const POOL_SIZE := 12
## kind: {"amount": particles, "lifetime": s, "speed": (min, max), "spread": degrees,
## "flat": 0..1 (1 = spreads in a flat ring), "direction", "gravity", "drag",
## "size": (min, max) in m, "grow": end size ratio, "shape": "dot" | "chunk" | "puff",
## "glow": brightness multiplier (> 1 blooms), "radius": emission sphere radius, "pool": emitters}
const KINDS := {
	&"sparks": {"amount": 12, "lifetime": 0.35, "speed": Vector2(4.0, 9.0), "spread": 75.0,
			"gravity": -14.0, "drag": 6.0, "size": Vector2(0.15, 0.28), "shape": "dot", "glow": 1.8, "pool": 24},
	&"bones": {"amount": 10, "lifetime": 0.75, "speed": Vector2(3.0, 6.5), "spread": 55.0,
			"gravity": -20.0, "drag": 1.0, "size": Vector2(0.16, 0.3), "shape": "chunk", "glow": 1.0, "pool": 24},
	&"gore": {"amount": 12, "lifetime": 0.6, "speed": Vector2(2.5, 5.5), "spread": 60.0,
			"gravity": -18.0, "drag": 1.5, "size": Vector2(0.18, 0.32), "shape": "puff", "glow": 1.0, "pool": 16},
	&"dust": {"amount": 12, "lifetime": 0.9, "speed": Vector2(1.5, 3.5), "spread": 180.0, "flat": 1.0,
			"direction": Vector3.RIGHT, "gravity": 0.8, "drag": 3.0, "size": Vector2(0.45, 0.8), "grow": 2.2,
			"shape": "puff", "glow": 1.0, "radius": 0.5},
	&"embers": {"amount": 18, "lifetime": 0.8, "speed": Vector2(0.8, 3.0), "spread": 50.0,
			"gravity": 2.5, "drag": 1.0, "size": Vector2(0.14, 0.26), "shape": "dot", "glow": 2.2, "radius": 0.9},
	&"shards": {"amount": 18, "lifetime": 0.55, "speed": Vector2(5.0, 10.0), "spread": 180.0, "flat": 0.85,
			"direction": Vector3.RIGHT, "gravity": -8.0, "drag": 3.0, "size": Vector2(0.16, 0.32),
			"shape": "chunk", "glow": 1.6},
	&"wisps": {"amount": 10, "lifetime": 1.0, "speed": Vector2(0.4, 1.4), "spread": 35.0,
			"gravity": 1.8, "drag": 0.5, "size": Vector2(0.22, 0.4), "shape": "dot", "glow": 1.8, "radius": 0.5},
	&"glints": {"amount": 16, "lifetime": 0.9, "speed": Vector2(1.5, 4.5), "spread": 35.0,
			"gravity": -3.0, "drag": 0.8, "size": Vector2(0.14, 0.26), "shape": "dot", "glow": 2.2, "radius": 0.4},
	&"ring": {"amount": 28, "lifetime": 0.6, "speed": Vector2(6.0, 8.0), "spread": 180.0, "flat": 1.0,
			"direction": Vector3.RIGHT, "gravity": 0.5, "drag": 5.0, "size": Vector2(0.18, 0.3),
			"shape": "dot", "glow": 2.0},
}

var _pools: Dictionary[StringName, Array] = {}
var _next: Dictionary[StringName, int] = {}
var _dot_texture: GradientTexture2D


func _ready() -> void:
	_dot_texture = GradientTexture2D.new()
	_dot_texture.fill = GradientTexture2D.FILL_RADIAL
	_dot_texture.fill_from = Vector2(0.5, 0.5)
	_dot_texture.fill_to = Vector2(0.5, 0.0)
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_dot_texture.gradient = soft
	# Everything is built up front so the first kill doesn't stall on creating emitters.
	for kind: StringName in KINDS:
		_build_pool(kind)


## Fires a burst of `kind` at `at`, tinted with color. amount scales the particle count (0..1).
func burst(kind: StringName, at: Vector3, color: Color, amount := 1.0) -> void:
	var pool: Array = _pools.get(kind, [])
	if pool.is_empty():
		push_warning("Unknown particle kind: %s" % kind)
		return
	var index: int = _next[kind]
	_next[kind] = (index + 1) % pool.size()
	var emitter: GPUParticles3D = pool[index]
	emitter.global_position = at
	var glow: float = KINDS[kind].get("glow", 1.0)
	(emitter.process_material as ParticleProcessMaterial).color = Color(color.r * glow, color.g * glow, color.b * glow, color.a)
	emitter.amount_ratio = clampf(amount, 0.05, 1.0)
	emitter.restart()


func _build_pool(kind: StringName) -> void:
	var info: Dictionary = KINDS[kind]
	var mesh := _mesh(info)
	var pool: Array[GPUParticles3D] = []
	for i in int(info.get("pool", POOL_SIZE)):
		var emitter := GPUParticles3D.new()
		emitter.amount = info["amount"]
		emitter.lifetime = info["lifetime"]
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.emitting = false
		emitter.local_coords = false
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		emitter.visibility_aabb = AABB(Vector3(-8.0, -2.0, -8.0), Vector3(16.0, 10.0, 16.0))
		emitter.process_material = _process_material(info)
		emitter.draw_pass_1 = mesh
		add_child(emitter)
		pool.append(emitter)
	_pools[kind] = pool
	_next[kind] = 0


func _process_material(info: Dictionary) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = info.get("direction", Vector3.UP)
	material.spread = info.get("spread", 45.0)
	material.flatness = info.get("flat", 0.0)
	var speed: Vector2 = info["speed"]
	material.initial_velocity_min = speed.x
	material.initial_velocity_max = speed.y
	material.gravity = Vector3(0.0, info.get("gravity", -9.8), 0.0)
	material.damping_min = info.get("drag", 0.0)
	material.damping_max = info.get("drag", 0.0)
	var size: Vector2 = info["size"]
	material.scale_min = size.x
	material.scale_max = size.y
	var radius: float = info.get("radius", 0.0)
	if radius > 0.0:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = radius
	# Fade out over the lifetime; some kinds also grow.
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.6, Color(1.0, 1.0, 1.0, 0.8))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	material.color_ramp = ramp
	var grow: float = info.get("grow", 0.0)
	var curve := Curve.new()
	if grow > 0.0:
		curve.max_value = grow
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, grow))
	else:
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.35))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = curve
	material.scale_curve = scale_texture
	return material


func _mesh(info: Dictionary) -> Mesh:
	var draw := StandardMaterial3D.new()
	draw.vertex_color_use_as_albedo = true
	match info["shape"]:
		"chunk":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			draw.roughness = 0.8
			if info.get("glow", 1.0) > 1.0:
				draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			box.material = draw
			return box
		"puff":
			draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			# Without this, particle billboards drop the particle's size.
			draw.billboard_keep_scale = true
			draw.albedo_texture = _dot_texture
		_:
			# Glowing dot, added on top of what's behind it.
			draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			draw.billboard_keep_scale = true
			draw.albedo_texture = _dot_texture
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = draw
	return quad
