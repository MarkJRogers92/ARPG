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
##   solid       collision circles [x, z, radius] in the asset's own space (see
##               Obstacles); empty means walk-through decoration
##   fx          color of the motes rising from its glowing parts, or null
##
## The realms choose which kinds appear and how often (Realm "props").

const ROOT := "res://assets/environment/arpg_pack/%s.glb"
## Matches the brightest code-built accents (UV.x 0.72 in the source packs).
const EMISSIVE_GLOW := 0.72

const KINDS := {
	# The Hollow Graveyard
	"rune_gravestone": {"path": "01_soul_ruins/Rune_Gravestone", "realm": "graveyard", "scale": [0.9, 1.1], "yaw": 0.5,
		"landmark": false, "footprint": 0.8, "shadow": true, "solid": [], "fx": null},
	"soul_brazier": {"path": "01_soul_ruins/Soul_Lantern_Brazier", "realm": "graveyard", "scale": [0.95, 1.05], "yaw": TAU,
		"landmark": false, "footprint": 0.5, "shadow": true, "solid": [], "fx": Color(0.55, 0.85, 1.0)},
	"ruined_pillar": {"path": "01_soul_ruins/Ruined_Pillar", "realm": "graveyard", "scale": [0.9, 1.15], "yaw": TAU,
		"landmark": false, "footprint": 0.75, "shadow": true, "solid": [], "fx": null},
	"crystal_cluster": {"path": "01_soul_ruins/Violet_Crystal_Cluster", "realm": "graveyard", "scale": [0.85, 1.1], "yaw": TAU,
		"landmark": false, "footprint": 0.7, "shadow": true, "solid": [], "fx": Color(0.75, 0.45, 1.0)},
	"tome_pedestal": {"path": "02_expansion/Ancient_Tome_Pedestal", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": false, "footprint": 0.6, "shadow": true, "solid": [], "fx": Color(0.55, 0.85, 1.0)},
	"barrel": {"path": "02_expansion/Barrel", "realm": "graveyard", "scale": [0.9, 1.1], "yaw": TAU,
		"landmark": false, "footprint": 0.45, "shadow": false, "solid": [], "fx": null},
	"crate_stack": {"path": "02_expansion/Crate_Stack", "realm": "graveyard", "scale": [0.95, 1.05], "yaw": TAU,
		"landmark": false, "footprint": 0.9, "shadow": true, "solid": [], "fx": null},
	"weapon_rack": {"path": "02_expansion/Weapon_Rack", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": false, "footprint": 0.8, "shadow": true, "solid": [], "fx": null},
	"offering_bowl": {"path": "02_expansion/Offering_Bowl", "realm": "graveyard", "scale": [0.9, 1.05], "yaw": TAU,
		"landmark": false, "footprint": 1.05, "shadow": false, "solid": [], "fx": null},
	"sarcophagus": {"path": "03_three_realms/Sealed_Sarcophagus", "realm": "graveyard", "scale": [0.95, 1.05], "yaw": TAU,
		"landmark": false, "footprint": 1.0, "shadow": true, "solid": [], "fx": null},
	"prison_cage": {"path": "03_three_realms/Iron_Prison_Cage", "realm": "graveyard", "scale": [0.95, 1.05], "yaw": TAU,
		"landmark": false, "footprint": 0.7, "shadow": true, "solid": [], "fx": null},
	"gravedigger_bench": {"path": "05_balanced_biomes/Gravedigger_Bench", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": false, "footprint": 1.5, "shadow": true, "solid": [], "fx": null},
	"lantern_post": {"path": "05_balanced_biomes/Procession_Lantern_Post", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": false, "footprint": 0.9, "shadow": true, "solid": [], "fx": Color(0.55, 0.85, 1.0)},
	"mausoleum": {"path": "04_landmarks/Graveyard_Mausoleum", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 2.6, "shadow": true, "solid": [[-0.85, -1.05, 0.95], [0.85, -1.05, 0.95], [-0.85, 0.95, 0.95], [0.85, 0.95, 0.95], [0.0, 0.0, 0.9]], "fx": null},
	"soul_altar": {"path": "01_soul_ruins/Soul_Altar", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.1, "shadow": true, "solid": [[0.0, 0.0, 1.0]], "fx": Color(0.55, 0.85, 1.0)},
	"broken_archway": {"path": "02_expansion/Broken_Archway", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.8, "shadow": true, "solid": [[-1.125, 0.0, 0.6], [1.25, 0.1, 0.65]], "fx": null},
	"ruined_wall": {"path": "02_expansion/Ruined_Wall", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": true, "footprint": 1.4, "shadow": true, "solid": [[-0.95, 0.0, 0.45], [0.0, 0.0, 0.45], [0.95, 0.0, 0.45]], "fx": null},
	"ruin_corner": {"path": "02_expansion/Ruin_Corner", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.3, "shadow": true, "solid": [[-0.625, -0.8, 0.35], [-0.625, -0.15, 0.35], [-0.625, 0.6, 0.35], [0.1, 0.6, 0.35], [0.8, 0.6, 0.35]], "fx": null},
	"portcullis": {"path": "02_expansion/Portcullis", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.45, "shadow": true, "solid": [[-1.0, 0.0, 0.5], [0.0, 0.0, 0.45], [1.0, 0.0, 0.5]], "fx": null},
	"guardian_statue": {"path": "02_expansion/Broken_Guardian_Statue", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.5,
		"landmark": true, "footprint": 1.0, "shadow": true, "solid": [[0.0, 0.0, 0.75]], "fx": null},
	"soul_obelisk": {"path": "02_expansion/Soul_Obelisk", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 0.65, "shadow": true, "solid": [[0.0, 0.0, 0.55]], "fx": Color(0.55, 0.85, 1.0)},
	"stone_well": {"path": "03_three_realms/Abandoned_Stone_Well", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.0, "shadow": true, "solid": [[0.05, 0.0, 0.95]], "fx": null},
	"ritual_door": {"path": "03_three_realms/Sealed_Ritual_Door", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.05, "shadow": true, "solid": [[-0.7, 0.0, 0.45], [0.0, 0.0, 0.45], [0.7, 0.0, 0.45]], "fx": Color(0.55, 0.85, 1.0)},
	"iron_fence": {"path": "04_landmarks/Crooked_Iron_Fence", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": true, "footprint": 2.0, "shadow": true, "solid": [[-1.5, 0.0, 0.38], [-0.75, 0.0, 0.38], [0.0, 0.0, 0.38], [0.75, 0.0, 0.38], [1.5, 0.0, 0.38]], "fx": null},
	"bell_gibbet": {"path": "04_landmarks/Hanging_Bell_Gibbet", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.4,
		"landmark": true, "footprint": 1.35, "shadow": true, "solid": [[-1.0, 0.0, 0.5], [0.0, 0.0, 0.5], [1.0, 0.0, 0.5]], "fx": null},
	"funeral_wagon": {"path": "04_landmarks/Fallen_Funeral_Wagon", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.8, "shadow": true, "solid": [[0.1, -0.6, 0.9], [0.0, 0.7, 0.9]], "fx": null},
	"ossuary_wall": {"path": "05_balanced_biomes/Ossuary_Niche_Wall", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.75, "shadow": true, "solid": [[-1.1, 0.0, 0.65], [0.1, 0.0, 0.65], [1.3, 0.0, 0.6]], "fx": null},
	"winged_memorial": {"path": "05_balanced_biomes/Winged_Memorial", "realm": "graveyard", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.6, "shadow": true, "solid": [[0.0, 0.0, 0.85]], "fx": null},
	# The Frozen Wastes
	"snow_boulder": {"path": "03_three_realms/Snowbound_Boulder", "realm": "frozen", "scale": [0.8, 1.15], "yaw": TAU,
		"landmark": false, "footprint": 0.9, "shadow": true, "solid": [], "fx": null},
	"frosted_pine": {"path": "03_three_realms/Frosted_Pine", "realm": "frozen", "scale": [0.9, 1.25], "yaw": TAU,
		"landmark": false, "footprint": 0.8, "shadow": true, "solid": [], "fx": null},
	"ice_stalagmites": {"path": "03_three_realms/Ice_Stalagmite_Fan", "realm": "frozen", "scale": [0.85, 1.1], "yaw": TAU,
		"landmark": false, "footprint": 0.85, "shadow": true, "solid": [], "fx": null},
	"supply_tripod": {"path": "05_balanced_biomes/Suspended_Supply_Tripod", "realm": "frozen", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": false, "footprint": 1.2, "shadow": true, "solid": [], "fx": null},
	"wind_chime": {"path": "05_balanced_biomes/Icy_Wind_Chime", "realm": "frozen", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": false, "footprint": 1.3, "shadow": true, "solid": [], "fx": null},
	"ice_arch": {"path": "03_three_realms/Glacial_Ice_Arch", "realm": "frozen", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.8, "shadow": true, "solid": [[-1.125, 0.0, 0.5], [1.125, 0.0, 0.5]], "fx": null},
	"watchtower": {"path": "04_landmarks/Frozen_Watchtower_Ruin", "realm": "frozen", "scale": [1.0, 1.0], "yaw": 0.5,
		"landmark": true, "footprint": 1.9, "shadow": true, "solid": [[0.0, -0.5, 1.1], [0.2, 0.6, 1.1], [-0.9, -0.3, 0.6], [1.1, 0.1, 0.6]], "fx": null},
	"sled": {"path": "04_landmarks/Abandoned_Sled", "realm": "frozen", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.8, "shadow": true, "solid": [[0.0, -0.7, 0.9], [0.0, 0.6, 0.85]], "fx": null},
	"ribcage": {"path": "04_landmarks/Giant_Ribcage_Half_Buried_Snow", "realm": "frozen", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 2.4, "shadow": true, "solid": [], "fx": null},
	"frozen_pond": {"path": "04_landmarks/Frozen_Pond_Rim", "realm": "frozen", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 2.4, "shadow": false, "solid": [], "fx": null},
	"fishing_hut": {"path": "05_balanced_biomes/Ice_Fishing_Hut", "realm": "frozen", "scale": [1.0, 1.0], "yaw": 0.5,
		"landmark": true, "footprint": 1.6, "shadow": true, "solid": [[0.1, -0.5, 0.95], [0.1, 0.6, 0.95]], "fx": null},
	"whale_skull": {"path": "05_balanced_biomes/Whale_Skull", "realm": "frozen", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.65, "shadow": true, "solid": [], "fx": null},
	# The Ember Rift
	"obsidian_outcrop": {"path": "03_three_realms/Obsidian_Outcrop", "realm": "ember", "scale": [0.8, 1.15], "yaw": TAU,
		"landmark": false, "footprint": 1.0, "shadow": true, "solid": [], "fx": null},
	"brimstone_vent": {"path": "03_three_realms/Brimstone_Vent", "realm": "ember", "scale": [0.9, 1.1], "yaw": TAU,
		"landmark": false, "footprint": 1.1, "shadow": false, "solid": [], "fx": Color(1.0, 0.5, 0.15)},
	"ashen_tree": {"path": "03_three_realms/Ashen_Tree", "realm": "ember", "scale": [0.9, 1.2], "yaw": TAU,
		"landmark": false, "footprint": 0.9, "shadow": true, "solid": [], "fx": Color(1.0, 0.5, 0.15)},
	"basalt_columns": {"path": "03_three_realms/Basalt_Organ_Columns", "realm": "ember", "scale": [0.9, 1.15], "yaw": TAU,
		"landmark": false, "footprint": 0.9, "shadow": true, "solid": [], "fx": null},
	"scorched_banner": {"path": "05_balanced_biomes/Scorched_Banner", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": false, "footprint": 0.8, "shadow": true, "solid": [], "fx": null},
	"skull_gateway": {"path": "04_landmarks/Demon_Skull_Gateway", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.3,
		"landmark": true, "footprint": 2.3, "shadow": true, "solid": [[-1.25, 0.0, 0.65], [1.25, 0.0, 0.65]], "fx": Color(1.0, 0.5, 0.15)},
	"forge": {"path": "04_landmarks/Forge_Anvil_Station", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.5,
		"landmark": true, "footprint": 1.9, "shadow": true, "solid": [[0.6, -0.6, 0.8], [-0.7, 0.5, 0.7], [0.6, 0.5, 0.6]], "fx": Color(1.0, 0.5, 0.15)},
	"cauldron": {"path": "04_landmarks/Suspended_Cauldron", "realm": "ember", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.5, "shadow": true, "solid": [[0.1, 0.2, 1.0]], "fx": Color(1.0, 0.5, 0.15)},
	"siege_barricade": {"path": "04_landmarks/Charred_Siege_Barricade", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.6,
		"landmark": true, "footprint": 2.05, "shadow": true, "solid": [[-1.5, 0.0, 0.5], [-0.5, 0.0, 0.5], [0.5, 0.0, 0.5], [1.5, 0.0, 0.5]], "fx": Color(1.0, 0.5, 0.15)},
	"minecart": {"path": "05_balanced_biomes/Ore_Minecart", "realm": "ember", "scale": [1.0, 1.0], "yaw": TAU,
		"landmark": true, "footprint": 1.5, "shadow": true, "solid": [[-0.4, 0.0, 0.8], [0.6, 0.0, 0.8]], "fx": Color(1.0, 0.5, 0.15)},
	"furnace": {"path": "05_balanced_biomes/Cracked_Furnace", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.5,
		"landmark": true, "footprint": 1.1, "shadow": true, "solid": [[0.0, 0.0, 1.0]], "fx": Color(1.0, 0.5, 0.15)},
	"chained_gong": {"path": "05_balanced_biomes/Chained_Gong", "realm": "ember", "scale": [1.0, 1.0], "yaw": 0.35,
		"landmark": true, "footprint": 1.4, "shadow": true, "solid": [[-1.0, 0.0, 0.45], [0.0, 0.0, 0.4], [1.0, 0.0, 0.45]], "fx": Color(1.0, 0.5, 0.15)},
}

## Models that aren't scattered, used by events (EventDirector's cursed chest).
const EVENT_KINDS := {
	"treasure_chest": {"path": "02_expansion/Treasure_Chest", "landmark": false},
}

static var _meshes := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func data(kind: String) -> Dictionary:
	return KINDS[kind] if KINDS.has(kind) else EVENT_KINDS[kind]


## The kind's mesh, built on first use and cached. Null if the GLB is missing
## or has no mesh.
static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var built := _build(ROOT % data(kind)["path"], data(kind)["landmark"])
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
