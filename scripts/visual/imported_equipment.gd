class_name ImportedEquipment
extends RefCounted
## Opt-in generated equipment prototypes. No random-drop or stat changes.
## Source GLBs retain their PBR textures; only vertices are uniformly scaled.
## Authored origins are attachment points, not display/icon centers.

const KINDS := {
	"Amber Amulet": {"slot": "amulet", "file": "amber_amulet", "scale": 0.37},
	"Rune Greatsword": {"slot": "weapon", "file": "rune_greatsword", "scale": 1.6},
}
const ROOT := "res://assets/equipment/prototypes/%s.glb"
static var _meshes: Dictionary = {}

static func has_item(slot: String, base_name: String) -> bool:
	return KINDS.has(base_name) and KINDS[base_name].slot == slot

static func mesh(base_name: String) -> ArrayMesh:
	if not _meshes.has(base_name):
		_meshes[base_name] = _build(base_name)
	return _meshes[base_name]

static func _build(base_name: String) -> ArrayMesh:
	var data: Dictionary = KINDS[base_name]
	var scene := load(ROOT % data.file) as PackedScene
	if scene == null:
		push_error("ImportedEquipment: missing asset " + base_name)
		return null
	var instance := scene.instantiate()
	var found := instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		found.push_front(instance)
	if found.size() != 1:
		instance.free()
		push_error("ImportedEquipment: expected one baked mesh for " + base_name)
		return null
	var node := found[0] as MeshInstance3D
	var cursor: Node = node
	while cursor is Node3D:
		if not (cursor as Node3D).transform.is_equal_approx(Transform3D.IDENTITY):
			instance.free()
			push_error("ImportedEquipment: bake source transforms before registering " + base_name)
			return null
		cursor = cursor.get_parent()
	var source := node.mesh
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			vertices[i] *= float(data.scale)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		# A uniform positive scale preserves normals, tangents, and winding.
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, source.surface_get_material(surface))
	instance.free()
	return out
