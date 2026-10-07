class_name AssetProps
extends RefCounted
## Scenery made in Blender (GLBs under res://assets/environment/arpg_pack/),
## adapted to the same MultiMesh path as the code-built props in Models.
##
## Each GLB is loaded once: its single MeshInstance3D is found, any node
## transform is baked in (all are identity today), and the surfaces are copied
## into a new ArrayMesh that uses the kit shader, so the art gets the same
## lighting, rim light and fog response as the rest of the world. The imported
## resources are left untouched.
##
## Glow comes from each surface's imported material, NOT from UV.x: in these
## exports most opaque vertices also have a non-zero UV.x, so reading UV.x as
## a glow weight (as Models' own meshes do) would make stone glow. Opaque
## surfaces get no glow; emissive surfaces glow evenly at EMISSIVE_GLOW.
##
## Placement data per kind (see WorldDecor):
##   path        pack/Asset, without .glb
##   realm       the realm it was chosen for (documentation and tests)
##   scale       [min, max] uniform scale; 1 authored unit = 1 m
##   yaw         how far (radians) it may turn from facing the camera (+Z);
##               TAU means any direction
##   landmark    true: at most one landmark per chunk, kept apart (see WorldDecor)
##   footprint   ground radius in meters, used for spacing and clearance
##   shadow      casts shadows

const ROOT := "res://assets/environment/arpg_pack/%s.glb"
## Matches the brightest code-built accents (UV.x 0.72 in the source packs).
const EMISSIVE_GLOW := 0.72

## Stage 1: three per realm (an opaque prop, a glowing one, a big silhouette).
const KINDS := {
	"rune_gravestone": {"path": "01_soul_ruins/Rune_Gravestone", "realm": "graveyard",
		"scale": [0.9, 1.1], "yaw": 0.5, "landmark": false, "footprint": 0.8, "shadow": true},
	"soul_brazier": {"path": "01_soul_ruins/Soul_Lantern_Brazier", "realm": "graveyard",
		"scale": [0.95, 1.05], "yaw": TAU, "landmark": false, "footprint": 0.5, "shadow": true},
	"mausoleum": {"path": "04_landmarks/Graveyard_Mausoleum", "realm": "graveyard",
		"scale": [1.0, 1.0], "yaw": 0.35, "landmark": true, "footprint": 2.6, "shadow": true},
	"snow_boulder": {"path": "03_three_realms/Snowbound_Boulder", "realm": "frozen",
		"scale": [0.8, 1.15], "yaw": TAU, "landmark": false, "footprint": 0.9, "shadow": true},
	"frosted_pine": {"path": "03_three_realms/Frosted_Pine", "realm": "frozen",
		"scale": [0.9, 1.25], "yaw": TAU, "landmark": false, "footprint": 0.8, "shadow": true},
	"ice_arch": {"path": "03_three_realms/Glacial_Ice_Arch", "realm": "frozen",
		"scale": [1.0, 1.0], "yaw": 0.35, "landmark": true, "footprint": 1.8, "shadow": true},
	"obsidian_outcrop": {"path": "03_three_realms/Obsidian_Outcrop", "realm": "ember",
		"scale": [0.8, 1.15], "yaw": TAU, "landmark": false, "footprint": 1.0, "shadow": true},
	"brimstone_vent": {"path": "03_three_realms/Brimstone_Vent", "realm": "ember",
		"scale": [0.9, 1.1], "yaw": TAU, "landmark": false, "footprint": 1.1, "shadow": false},
	"skull_gateway": {"path": "04_landmarks/Demon_Skull_Gateway", "realm": "ember",
		"scale": [1.0, 1.0], "yaw": 0.3, "landmark": true, "footprint": 2.3, "shadow": true},
}

## Densities proposed for the realms' scatter, for review only: the realms
## don't use them yet (tools/asset_showcase.gd "scatter" previews them).
## Small kinds are per chunk like Realm props; landmark kinds are the chance a
## chunk holds that landmark.
const PROPOSED := {
	"graveyard": {"rune_gravestone": 0.25, "soul_brazier": 0.08, "mausoleum": 0.05},
	"frozen": {"snow_boulder": 0.4, "frosted_pine": 0.35, "ice_arch": 0.06},
	"ember": {"obsidian_outcrop": 0.45, "brimstone_vent": 0.15, "skull_gateway": 0.05},
}

static var _meshes := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func data(kind: String) -> Dictionary:
	return KINDS[kind]


## The kind's mesh, built on first use and cached. Null if the GLB is missing
## or has no mesh.
static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var built := _build(ROOT % KINDS[kind]["path"], KINDS[kind]["landmark"])
	_meshes[kind] = built
	return built


static func _build(path: String, landmark: bool) -> ArrayMesh:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("AssetProps: can't load %s" % path)
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.push_front(root)
	if found.is_empty():
		root.free()
		push_error("AssetProps: no mesh in %s" % path)
		return null
	var mi := found[0] as MeshInstance3D
	# The mesh's transform relative to the scene root, baked into the vertices.
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if root is Node3D and root != mi:
		xf = (root as Node3D).transform * xf
	var source := mi.mesh
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		if not xf.is_equal_approx(Transform3D.IDENTITY):
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var nb := xf.basis.inverse().transposed()
				for i in normals.size():
					normals[i] = (nb * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays)
		var imported := source.surface_get_material(s)
		var glowing := imported is BaseMaterial3D and (imported as BaseMaterial3D).emission_enabled
		out.surface_set_material(s, landmark_material(glowing) if landmark \
				else (emissive_material() if glowing else opaque_material()))
	root.free()
	return out


## Landmarks: the kit look, with a see-through window where they'd hide the
## hero (shaders/kit_landmark.gdshader).
static func landmark_material(glowing: bool) -> ShaderMaterial:
	return Models.material("kit_landmark", {"flat_glow": EMISSIVE_GLOW if glowing else 0.0},
			"glow" if glowing else "opaque")


## Where the hero is, for the landmarks' see-through window. Every frame.
static func set_hero(at: Vector3) -> void:
	for glowing in [false, true]:
		landmark_material(glowing).set_shader_parameter("hero_position", at + Vector3(0.0, 0.9, 0.0))


## The kit shader with UV.x ignored: no glow, rim light as usual.
static func opaque_material() -> ShaderMaterial:
	return Models.material("kit", {"uv_glow": 0.0, "flat_glow": 0.0}, "asset_opaque")


## The kit shader glowing evenly, like the code-built glowing parts.
static func emissive_material() -> ShaderMaterial:
	return Models.material("kit", {"uv_glow": 0.0, "flat_glow": EMISSIVE_GLOW}, "asset_glow")
