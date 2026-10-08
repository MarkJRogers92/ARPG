class_name SpecialistModels
extends RefCounted
## Approved optional cosmetic meshes. Scenes are extracted once, never per enemy.
## Each caller receives its own mesh so assigning swarm materials cannot
## change another swarm's spectral/status/gait parameters.

const ROOT := "res://assets/enemies/specialists/%s.glb"
const SIGNATURE_ROOT := "res://assets/enemies/signatures/%s.glb"
const KINDS := {
	"ferryman": 2.86, # preserve approved raft/oar-inclusive native proportion
	"debt_collector": 2.2, # existing body parameter; native hat-inclusive height 2.655
	"bone_shieldbearer": 1.8,
	"grave_mender": 1.8,
	"hoarfrost_shaman": 1.8,
	"frost_bloater": 1.35,
	"obsidian_guard": 1.8,
	"magma_bloater": 1.35,
}
const REALMS := {
	"graveyard": {"shieldbearer": "bone_shieldbearer", "mender": "grave_mender"},
	"frozen": {"mender": "hoarfrost_shaman", "bloater": "frost_bloater"},
	"ember": {"shieldbearer": "obsidian_guard", "bloater": "magma_bloater"},
}
static var _meshes := {}


static func kind_for(realm: String, model: String) -> String:
	if model == "collector" and REALMS.has(realm):
		return "debt_collector"
	return REALMS.get(realm, {}).get(model, "")


static func mesh(kind: String, body_height: float) -> ArrayMesh:
	if not KINDS.has(kind) or body_height <= 0.0:
		return null
	var key := "%s/%s" % [kind, body_height]
	if not _meshes.has(key):
		_meshes[key] = _build(kind, body_height / float(KINDS[kind]))
	var cached := _meshes[key] as ArrayMesh
	return cached.duplicate() as ArrayMesh if cached != null else null


static func _build(kind: String, scale_factor: float) -> ArrayMesh:
	var path := (SIGNATURE_ROOT if kind in ["ferryman", "debt_collector"] else ROOT) % kind
	if not ResourceLoader.exists(path):
		push_warning("Specialist model unavailable; keeping procedural appearance: " + kind)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.push_front(root)
	if found.size() != 1 or (found[0] as MeshInstance3D).mesh == null:
		root.free()
		return null
	var mi := found[0] as MeshInstance3D
	var xf := Transform3D.IDENTITY
	var node: Node = mi
	while node is Node3D:
		xf = (node as Node3D).transform * xf
		if node == root:
			break
		node = node.get_parent()
	xf = Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3.ZERO) * xf
	var normal_basis := xf.basis.inverse().transposed()
	var source := mi.mesh
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		# COLOR_0 is already linear; UV0.x is exactly 0 or 0.72. Preserve both
		# instead of adding the older scenery adapter's per-material emission.
		if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
			root.free()
			return null
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			verts[i] = xf * verts[i]
			if i < normals.size():
				normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays)
	root.free()
	return out if out.get_surface_count() > 0 else null
