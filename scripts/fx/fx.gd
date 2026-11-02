class_name Fx
extends RefCounted
## Temporary visual effects and flat shapes drawn on the ground. Effects fade quickly and free themselves.
## To be replaced with particle and shader effects in v0.4.

const GROUND_HEIGHT := 0.06

static var _ghost_mesh: CapsuleMesh


## Slice on the ground opening in the given direction (Fire Wave). half_angle is in radians.
static func sector(origin: Vector3, direction: Vector3, radius: float, half_angle: float, color: Color) -> void:
	var node := _spawn(flat_mesh(0.0, radius, half_angle, 24), Color(color, 0.75), origin + Vector3.UP * GROUND_HEIGHT)
	node.rotation.y = atan2(-direction.x, -direction.z)
	node.scale = Vector3(0.6, 1.0, 0.6)
	_fade_out(node, 0.3, Vector3(1.05, 1.0, 1.05))


## Ring expanding outward (Frost Nova, boss ground slam, chest).
static func ring(center: Vector3, radius: float, color: Color) -> void:
	var edge := _spawn(flat_mesh(radius * 0.85, radius, PI, 48), Color(color, 0.9), center + Vector3.UP * GROUND_HEIGHT)
	edge.scale = Vector3(0.2, 1.0, 0.2)
	_fade_out(edge, 0.45, Vector3.ONE)
	var fill := _spawn(flat_mesh(0.0, radius, PI, 48), Color(color, 0.3), center + Vector3.UP * GROUND_HEIGHT)
	fill.scale = Vector3(0.2, 1.0, 0.2)
	_fade_out(fill, 0.6, Vector3.ONE)


## Warning circle that appears on the ground and fills up before something lands.
static func telegraph(center: Vector3, radius: float, color: Color, duration: float) -> void:
	var fill := _spawn(flat_mesh(0.0, radius, PI, 48), Color(color, 0.22), center + Vector3.UP * GROUND_HEIGHT)
	fill.scale = Vector3(0.05, 1.0, 0.05)
	var grow := fill.create_tween()
	grow.tween_property(fill, "scale", Vector3.ONE, duration)
	grow.tween_callback(fill.queue_free)
	var edge := _spawn(flat_mesh(radius * 0.95, radius, PI, 48), Color(color, 0.8), center + Vector3.UP * (GROUND_HEIGHT + 0.01))
	edge.create_tween().tween_callback(edge.queue_free).set_delay(duration)


## Warning lane on the ground running from start along direction, growing more opaque (boss charge).
static func lane(start: Vector3, direction: Vector3, length: float, width: float, color: Color, duration: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	var node := _spawn(plane, Color(color, 0.12), start + flat * (length * 0.5) + Vector3.UP * GROUND_HEIGHT)
	node.rotation.y = atan2(-flat.x, -flat.z)
	var material := node.material_override as StandardMaterial3D
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.45, duration)
	tween.tween_callback(node.queue_free)


## Pillar of light from the sky plus a ground blast (Heaven's Wrath).
static func pillar(center: Vector3, radius: float, color: Color) -> void:
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = radius * 0.45
	beam_mesh.bottom_radius = radius * 0.45
	beam_mesh.height = 30.0
	# Color values above 1 trigger the glow effect.
	var bright := Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 0.85)
	var beam := _spawn(beam_mesh, bright, center + Vector3.UP * 15.0)
	_fade_out(beam, 0.45, Vector3(0.1, 1.0, 0.1))
	var blast := _spawn(flat_mesh(0.0, radius, PI, 48), Color(color, 0.7), center + Vector3.UP * GROUND_HEIGHT)
	blast.scale = Vector3(0.6, 1.0, 0.6)
	_fade_out(blast, 0.5, Vector3(1.1, 1.0, 1.1))


## Afterimage left behind during a dash.
static func ghost(at: Vector3, yaw: float, color: Color) -> void:
	if _ghost_mesh == null:
		_ghost_mesh = CapsuleMesh.new()
		_ghost_mesh.radius = 0.45
		_ghost_mesh.height = 1.8
	var node := _spawn(_ghost_mesh, Color(color, 0.45), at + Vector3.UP * 0.9)
	node.rotation.y = yaw
	_fade_out(node, 0.25, Vector3(0.8, 1.0, 0.8))


## Text that rises and fades (e.g. "+25 gold").
static func floating_text(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Game.world.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)


## Sword Swing: a quarter ring facing its direction that fades quickly.
static func slash(origin: Vector3, direction: Vector3, reach: float, half_angle: float, color: Color) -> void:
	var node := _spawn(flat_mesh(reach * 0.45, reach, half_angle, 20), Color(color, 0.85), origin + Vector3.UP * (GROUND_HEIGHT + 0.6))
	node.rotation.y = atan2(-direction.x, -direction.z)
	node.scale = Vector3(0.75, 1.0, 0.75)
	_fade_out(node, 0.16, Vector3(1.05, 1.0, 1.05))


## Whirlwind spin: a short-lived thin ring around the character.
static func spin(center: Vector3, radius: float, color: Color) -> void:
	var node := _spawn(flat_mesh(radius * 0.8, radius, PI, 32), Color(color, 0.55), center + Vector3.UP * 0.7)
	node.rotation.y = randf() * TAU
	_fade_out(node, 0.22, Vector3(1.08, 1.0, 1.08))


## Ring that shrinks inward (Soul Chain).
static func implode(center: Vector3, radius: float, color: Color) -> void:
	var node := _spawn(flat_mesh(radius * 0.9, radius, PI, 48), Color(color, 0.8), center + Vector3.UP * GROUND_HEIGHT)
	_fade_out(node, 0.35, Vector3(0.15, 1.0, 0.15))


## Area that stays on the ground for a while, then fades (Aftershock fissure).
static func zone(center: Vector3, radius: float, color: Color, duration: float) -> void:
	var node := _spawn(flat_mesh(0.0, radius, PI, 40), Color(color, 0.25), center + Vector3.UP * GROUND_HEIGHT)
	var material := node.material_override as StandardMaterial3D
	var tween := node.create_tween()
	tween.tween_interval(maxf(duration - 0.4, 0.0))
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(node.queue_free)


## Sword falling from the sky (Sword Rain).
static func sword_drop(at: Vector3, color: Color) -> void:
	var blade := BoxMesh.new()
	blade.size = Vector3(0.14, 1.8, 0.14)
	var bright := Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 0.95)
	var node := _spawn(blade, bright, at + Vector3.UP * 7.0)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y - 6.1, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: ring(at, 1.0, color))
	tween.tween_property(node.material_override, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(node.queue_free)


## Unshaded, transparent, double-sided material.
static func unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


## Ring slice on the XZ plane facing -Z. inner = 0 gives a solid slice, half_angle = PI a full circle.
static func flat_mesh(inner: float, outer: float, half_angle: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in segments:
		var a0 := lerpf(-half_angle, half_angle, float(i) / segments)
		var a1 := lerpf(-half_angle, half_angle, float(i + 1) / segments)
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		vertices.append(d0 * inner)
		vertices.append(d0 * outer)
		vertices.append(d1 * outer)
		if inner > 0.0:
			vertices.append(d0 * inner)
			vertices.append(d1 * outer)
			vertices.append(d1 * inner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _spawn(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = unshaded_material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Game.world.add_child(node)
	node.global_position = at
	return node


static func _fade_out(node: MeshInstance3D, duration: float, end_scale: Vector3) -> void:
	var material := node.material_override as StandardMaterial3D
	var tween := node.create_tween().set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", end_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(node.queue_free)
