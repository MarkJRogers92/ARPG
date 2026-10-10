class_name CreatureModels
extends RefCounted
## Cosmetic alternate creatures: shared rigid-joint GPU animation, never one
## Skeleton3D/AnimationPlayer per horde member. UV2.x stores the authored joint.
const MAX_LIVE_PER_SWARM := 16 # Keep detailed joint animation bounded in late hordes.
const ROOT := "res://assets/enemies/creatures/"
const REALMS := {
	"graveyard": {"grunt": "coffin_crawler", "runner": "gallows_raven"},
	"frozen": {"runner": "rime_widow", "lancer": "antler_revenant"},
	"ember": {"runner": "slag_scorpion", "brute": "furnace_tortoise"},
}
static var enabled := true # explicit visual-only fallback / matched benchmark
static var _meshes := {}
static var _rigs: Dictionary = {}

static func kind_for(realm: String, model: String) -> String:
	return REALMS.get(realm, {}).get(model, "") if enabled else ""

static func rig(kind: String) -> Dictionary:
	if _rigs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "creature_rigs.json"))
		if parsed is Dictionary: _rigs = parsed
	return _rigs.get(kind, {})

static func mesh(kind: String) -> ArrayMesh:
	if not enabled or rig(kind).is_empty(): return null
	if not _meshes.has(kind): _meshes[kind] = _build(kind)
	var source: ArrayMesh = _meshes[kind]
	return source.duplicate() as ArrayMesh if source != null else null

static func _build(kind: String) -> ArrayMesh:
	var path := ROOT + kind + ".glb"
	if not ResourceLoader.exists(path): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: found.push_front(root)
	if found.size() != 1:
		root.free()
		return null
	var mi := found[0] as MeshInstance3D
	if mi.mesh == null or not mi.transform.is_equal_approx(Transform3D.IDENTITY) or not (root as Node3D).transform.is_equal_approx(Transform3D.IDENTITY):
		root.free()
		return null
	var out := ArrayMesh.new()
	var joints: int = rig(kind).bones.size()
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		for required in [Mesh.ARRAY_COLOR, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arrays[required] == null or arrays[required].size() != arrays[Mesh.ARRAY_VERTEX].size():
				root.free()
				return null
		for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
			if uv.x < 0 or uv.x >= joints or absf(uv.x - roundf(uv.x)) > 0.001:
				root.free()
				return null
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	root.free()
	return out

static func material(kind: String, spectral: bool, spectral_color: Color) -> ShaderMaterial:
	var data := rig(kind)
	var pivots := PackedVector3Array()
	var axes := PackedVector3Array()
	var params := PackedVector4Array()
	var bends := PackedVector2Array()
	var parents := PackedInt32Array()
	for i in 32:
		if i < data.bones.size():
			var b: Dictionary = data.bones[i]
			pivots.append(Vector3(b.pivot[0], b.pivot[1], b.pivot[2]))
			axes.append(Vector3(b.axis[0], b.axis[1], b.axis[2]))
			params.append(Vector4(b.idle, b.walk, b.attack, b.phase))
			bends.append(Vector2(b.bend, b.death))
			parents.append(int(b.parent))
		else:
			pivots.append(Vector3.ZERO)
			axes.append(Vector3.RIGHT)
			params.append(Vector4.ZERO)
			bends.append(Vector2.ZERO)
			parents.append(-1)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/creature.gdshader")
	for pair in [["joint_pivots",pivots],["joint_axes",axes],["joint_params",params],["joint_bends",bends],["joint_parents",parents],["hover_height",data.hover],["cycle_speed",data.speed],["spectral",spectral],["spectral_color",spectral_color]]:
		mat.set_shader_parameter(pair[0],pair[1])
	if kind in ["slag_scorpion", "furnace_tortoise"]:
		mat.set_shader_parameter("rim_color",Color(0.55,0.68,0.82))
		mat.set_shader_parameter("rim_strength",0.70)
	return mat
