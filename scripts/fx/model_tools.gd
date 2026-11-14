class_name ModelTools
extends RefCounted
## Helpers for the KayKit models.

## Weapon and prop meshes that come attached to the KayKit adventurers; a character shows only
## the ones it uses (see keep_props).
const PROPS: Array[String] = ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield",
		"Round_Shield", "Spike_Shield", "Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable", "1H_Axe",
		"1H_Axe_Offhand", "2H_Axe", "Barbarian_Round_Shield", "Mug", "Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]
## How a weapon sits in a hand slot, the way the adventurers' own props are attached: turned
## around in the right hand, as is in the left. Shields stand a little off the hand.
const GRIPS := {
	"handslot.r": Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.033, 0.0)),
	"handslot.l": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.017, 0.0)),
}
const SHIELD_OFFSET := Vector3(0.0, 0.0, 0.156)


## Hides every prop mesh except the ones listed in keep.
static func keep_props(model: Node, keep: Array) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name in PROPS and not mesh.name in keep:
			mesh.visible = false


## Merges skinned mesh parts that share one skeleton and skin (KayKit characters come in nine to
## fifteen parts) into a single mesh with one surface per material, so a character is drawn with
## one or two draw calls instead of one per part. Bone indices stay valid because every part
## uses the same skin.
## weapons maps a hand slot bone ("handslot.r", "handslot.l") to a KayKit weapon scene (null
## for an empty hand). A weapon is skinned rigidly to its slot and drawn with the character's
## main material, since KayKit characters and their weapons share one texture atlas, so it adds
## no draw call.
static func merge_skinned_parts(parts: Array[MeshInstance3D], weapons: Dictionary = {}) -> ArrayMesh:
	# material -> merged surface arrays
	var groups: Dictionary = {}
	var bones_per_vertex := 4
	var main_material: Material
	for part in parts:
		for surface in part.mesh.get_surface_count():
			var material: Material = part.get_active_material(surface)
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			bones_per_vertex = (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(vertex_count, 1)
			if not groups.has(material):
				groups[material] = _empty_arrays()
			_append(groups[material], arrays)
			# The textured body material, not the eyes' glow.
			if main_material == null and material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture:
				main_material = material
	for slot: String in weapons:
		var weapon: PackedScene = weapons[slot]
		if weapon:
			for arrays in _weapon_surfaces(weapon, slot, parts[0], bones_per_vertex):
				_append(groups[main_material], arrays)
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if bones_per_vertex == 8 else 0
	var mesh := ArrayMesh.new()
	for material: Material in groups:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, groups[material], [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## The weapon's surfaces moved into the character's mesh space at its hand slot, every vertex
## bound fully to the slot bone: skinning applies pose × bind pose, so a vertex placed at
## inverse(bind pose) × grip follows the hand exactly.
static func _weapon_surfaces(weapon: PackedScene, slot: String, part: MeshInstance3D, bones_per_vertex: int) -> Array[Array]:
	var skin := part.skin
	var skeleton := part.get_node_or_null(part.skeleton) as Skeleton3D
	var bind := -1
	for i in skin.get_bind_count():
		var by_name := String(skin.get_bind_name(i)) == slot
		var by_bone := skeleton != null and skin.get_bind_bone(i) >= 0 and skin.get_bind_bone(i) == skeleton.find_bone(slot)
		if by_name or by_bone:
			bind = i
			break
	if bind < 0:
		push_error("No %s bone in the skin to hold %s" % [slot, weapon.resource_path])
		return []
	var grip: Transform3D = GRIPS[slot]
	if weapon.resource_path.get_file().contains("Shield"):
		grip = grip.translated_local(SHIELD_OFFSET)
	var to_mesh := skin.get_bind_pose(bind).affine_inverse() * grip
	var surfaces: Array[Array] = []
	var root := weapon.instantiate() as Node3D
	for node in [root] + root.find_children("*", "MeshInstance3D", true, false):
		if not node is MeshInstance3D:
			continue
		var place := to_mesh * _transform_in(root, node)
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_arrays(surface)
			var arrays := _empty_arrays()
			var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				vertices[i] = place * vertices[i]
				normals[i] = (place.basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TEX_UV] = source[Mesh.ARRAY_TEX_UV]
			arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var bones := PackedInt32Array()
			bones.resize(vertices.size() * bones_per_vertex)
			var weights := PackedFloat32Array()
			weights.resize(vertices.size() * bones_per_vertex)
			for i in vertices.size():
				bones[i * bones_per_vertex] = bind
				weights[i * bones_per_vertex] = 1.0
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			surfaces.append(arrays)
	root.free()
	return surfaces


## A node's transform relative to an ancestor (the scene isn't in the tree, so no global transforms).
static func _transform_in(ancestor: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	while node != ancestor:
		transform = node.transform * transform
		node = node.get_parent() as Node3D
	return transform


static func _empty_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return arrays


## Packed arrays are copied when read out of an Array, so each one is extended and stored back.
static func _append(target: Array, source: Array) -> void:
	var vertices: PackedVector3Array = target[Mesh.ARRAY_VERTEX]
	var offset := vertices.size()
	var added: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	vertices.append_array(added)
	target[Mesh.ARRAY_VERTEX] = vertices
	var normals: PackedVector3Array = target[Mesh.ARRAY_NORMAL]
	normals.append_array(source[Mesh.ARRAY_NORMAL])
	target[Mesh.ARRAY_NORMAL] = normals
	var uvs: PackedVector2Array = target[Mesh.ARRAY_TEX_UV]
	uvs.append_array(source[Mesh.ARRAY_TEX_UV])
	target[Mesh.ARRAY_TEX_UV] = uvs
	var bones: PackedInt32Array = target[Mesh.ARRAY_BONES]
	bones.append_array(source[Mesh.ARRAY_BONES])
	target[Mesh.ARRAY_BONES] = bones
	var weights: PackedFloat32Array = target[Mesh.ARRAY_WEIGHTS]
	weights.append_array(source[Mesh.ARRAY_WEIGHTS])
	target[Mesh.ARRAY_WEIGHTS] = weights
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = target[Mesh.ARRAY_INDEX]
	if source_indices.is_empty():
		for i in added.size():
			indices.append(offset + i)
	else:
		for index in source_indices:
			indices.append(offset + index)
	target[Mesh.ARRAY_INDEX] = indices
