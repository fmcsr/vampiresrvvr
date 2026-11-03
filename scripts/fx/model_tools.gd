class_name ModelTools
extends RefCounted
## Helpers for the KayKit models.

## Weapon and prop meshes that come attached to the KayKit adventurers; a character shows only
## the ones it uses (see keep_props).
const PROPS: Array[String] = ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield",
		"Round_Shield", "Spike_Shield", "Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable", "1H_Axe",
		"1H_Axe_Offhand", "2H_Axe", "Barbarian_Round_Shield", "Mug", "Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]


## Hides every prop mesh except the ones listed in keep.
static func keep_props(model: Node, keep: Array) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name in PROPS and not mesh.name in keep:
			mesh.visible = false


## Merges skinned mesh parts that share one skeleton and skin (KayKit characters come in nine to
## fifteen parts) into a single mesh with one surface per material, so a character is drawn with
## one or two draw calls instead of one per part. Bone indices stay valid because every part
## uses the same skin.
static func merge_skinned_parts(parts: Array[MeshInstance3D]) -> ArrayMesh:
	# material -> merged surface arrays
	var groups: Dictionary = {}
	var bones_per_vertex := 4
	for part in parts:
		for surface in part.mesh.get_surface_count():
			var material: Material = part.get_active_material(surface)
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			bones_per_vertex = (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(vertex_count, 1)
			if not groups.has(material):
				groups[material] = _empty_arrays()
			_append(groups[material], arrays)
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if bones_per_vertex == 8 else 0
	var mesh := ArrayMesh.new()
	for material: Material in groups:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, groups[material], [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


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
