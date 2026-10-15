class_name RealmProps
extends RefCounted
## Textured scenery models (GLBs under res://assets/environment/realm_props/) that
## stand in for the old code-built combat props of the same kind name (the pines,
## rocks, dead trees, graves...). Models.prop(kind) returns these meshes, so
## WorldDecor keeps its one-MultiMesh-per-kind path and its placement rules.
##
## Each GLB is loaded once and baked into an ArrayMesh: centered on its footprint,
## base at y = 0, scaled so its `size` (height, or widest ground extent for squat
## props) matches the kind it replaced. Surfaces use shaders/realm_prop.gdshader:
## the albedo atlas, the moon's light and shadows, a see-through window where the
## prop would cover the hero (set_hero), and an emission mask read from the albedo.
##
## Per kind:
##   file     GLB name under realm_props/
##   fit      "height" or "width": which measure `size` (meters) fixes
##   tint     multiplies the albedo; brightness scales it
##   rough, spec, rim, rim_strength: the surface response
##   glow     {mode, color, strength, lo, hi, pulse, speed}: emission read from the albedo
##   shadow   casts shadows (WorldDecor reads this)
##   native   Blender filler props (filler/): vertex colored, already in meters with their feet
##            on the ground, so they are not re-fitted; `glow` (color optional) lights the
##            model's "glow" surface evenly instead of reading the albedo

const ROOT := "res://assets/environment/realm_props/%s.glb"
const WARM := Color(1.0, 0.5, 0.16)

const KINDS := {
	# The Hollow Graveyard
	"tree": {"file": "dead_tree", "fit": "height", "size": 2.7, "rough": 0.9, "shadow": true},
	"grave": {"file": "grave_cluster", "fit": "width", "size": 1.6, "rough": 0.9, "shadow": true},
	"celtic_cross": {"file": "celtic_cross", "fit": "height", "size": 1.2, "rough": 0.85, "shadow": true},
	"rock": {"file": "mossy_boulder", "fit": "width", "size": 1.5, "rough": 0.95, "shadow": true, "tint": Color(0.72, 0.82, 0.74)},
	"pillar": {"file": "ruined_pillar", "fit": "height", "size": 2.2, "rough": 0.9, "shadow": true},
	"crystal": {"file": "soul_crystal", "fit": "height", "size": 1.3, "rough": 0.3, "spec": 0.6, "shadow": true,
		"glow": {"mode": 2, "color": Color(0.62, 0.42, 1.0), "strength": 1.6, "lo": 0.1, "hi": 0.45, "pulse": 0.18, "speed": 1.4},
		"rim": Color(0.6, 0.5, 1.0), "rim_strength": 0.5},
	"mushroom": {"file": "ghost_mushrooms", "fit": "height", "size": 0.9, "rough": 0.7, "shadow": false,
		"glow": {"mode": 2, "color": Color(0.3, 0.95, 0.85), "strength": 0.9, "lo": 0.05, "hi": 0.35, "pulse": 0.25, "speed": 1.8},
		"rim": Color(0.3, 0.9, 0.8), "rim_strength": 0.25},
	# The Frozen Wastes
	"pine": {"file": "snow_pine", "fit": "height", "size": 2.6, "rough": 0.9, "shadow": true, "tint": Color(0.72, 0.78, 0.88)},
	"frozen_deadtree": {"file": "frozen_deadtree", "fit": "height", "size": 2.4, "rough": 0.9, "shadow": true},
	"ice": {"file": "ice_spikes", "fit": "height", "size": 1.6, "rough": 0.2, "spec": 0.8, "shadow": true,
		"glow": {"mode": 3, "color": Color(0.5, 0.85, 1.0), "strength": 0.22, "lo": 0.5, "hi": 0.95, "pulse": 0.0, "speed": 1.0},
		"rim": Color(0.65, 0.9, 1.0), "rim_strength": 0.55},
	"snowrock": {"file": "snow_boulder", "fit": "height", "size": 1.0, "rough": 0.9, "shadow": true, "tint": Color(0.82, 0.85, 0.92)},
	# The Ember Rift
	"ashtree": {"file": "ash_tree", "fit": "height", "size": 2.4, "rough": 0.95, "shadow": true, "tint": Color(0.6, 0.48, 0.42),
		"glow": {"mode": 4, "color": WARM, "strength": 1.6, "lo": 0.15, "hi": 0.7, "scale": 3.2, "width": 0.05, "pulse": 0.25, "speed": 1.1}},
	"obsidian": {"file": "obsidian_spire", "fit": "height", "size": 1.7, "rough": 0.18, "spec": 0.9, "shadow": true, "brightness": 2.2,
		"rim": Color(1.0, 0.5, 0.25), "rim_strength": 0.35},
	"brimstone": {"file": "brimstone_vent", "fit": "width", "size": 1.5, "rough": 0.8, "shadow": false, "brightness": 1.8, "tint": Color(1.0, 0.7, 0.55),
		"glow": {"mode": 1, "color": WARM, "strength": 2.4, "lo": 0.12, "hi": 0.4, "pulse": 0.22, "speed": 1.6}},
	"magma_rock": {"file": "magma_rock", "fit": "height", "size": 0.95, "rough": 0.85, "shadow": true, "brightness": 2.0, "tint": Color(1.0, 0.72, 0.58),
		"glow": {"mode": 4, "color": WARM, "strength": 2.2, "lo": 0.15, "hi": 0.7, "scale": 4.0, "width": 0.07, "pulse": 0.2, "speed": 1.2}},
	# Blender filler props (vertex colors; the "glow" surface becomes emission).
	"grass_graveyard_a": {"file": "filler/grass_graveyard_a", "native": true, "rough": 0.95, "shadow": false},
	"grass_graveyard_b": {"file": "filler/grass_graveyard_b", "native": true, "rough": 0.95, "shadow": false},
	"grass_graveyard_c": {"file": "filler/grass_graveyard_c", "native": true, "rough": 0.95, "shadow": false},
	"grass_frozen_a": {"file": "filler/grass_frozen_a", "native": true, "rough": 0.95, "shadow": false},
	"grass_frozen_b": {"file": "filler/grass_frozen_b", "native": true, "rough": 0.95, "shadow": false},
	"grass_ember_a": {"file": "filler/grass_ember_a", "native": true, "rough": 0.95, "shadow": false,
		"glow": {"strength": 1.6, "pulse": 0.25, "speed": 1.7}},
	"grass_ember_b": {"file": "filler/grass_ember_b", "native": true, "rough": 0.95, "shadow": false,
		"glow": {"strength": 1.6, "pulse": 0.25, "speed": 1.4}},
	"bush_graveyard": {"file": "filler/bush_graveyard", "native": true, "rough": 0.95, "shadow": false},
	"bush_frozen": {"file": "filler/bush_frozen", "native": true, "rough": 0.95, "shadow": false},
	"bush_ember": {"file": "filler/bush_ember", "native": true, "rough": 0.95, "shadow": false,
		"glow": {"strength": 1.5, "pulse": 0.2, "speed": 1.2}},
	"bone_pile_a": {"file": "filler/bone_pile_a", "native": true, "rough": 0.85, "shadow": false},
	"bone_pile_b": {"file": "filler/bone_pile_b", "native": true, "rough": 0.85, "shadow": false},
	"candle_cluster_a": {"file": "filler/candle_cluster_a", "native": true, "rough": 0.8, "shadow": false,
		"glow": {"strength": 2.6, "pulse": 0.18, "speed": 7.0}},
	"candle_cluster_b": {"file": "filler/candle_cluster_b", "native": true, "rough": 0.8, "shadow": false,
		"glow": {"strength": 2.6, "pulse": 0.18, "speed": 6.0}},
	"grave_markers": {"file": "filler/grave_markers", "native": true, "rough": 0.9, "shadow": true},
	"rune_menhir_graveyard": {"file": "filler/rune_menhir", "native": true, "rough": 0.9, "shadow": true,
		"glow": {"color": Color(0.45, 0.9, 1.0), "strength": 1.8, "pulse": 0.2, "speed": 1.3}},
	"rune_menhir_frozen": {"file": "filler/rune_menhir", "native": true, "rough": 0.9, "shadow": true,
		"glow": {"color": Color(0.7, 0.88, 1.0), "strength": 1.6, "pulse": 0.2, "speed": 1.3}},
	"rune_menhir_ember": {"file": "filler/rune_menhir", "native": true, "rough": 0.9, "shadow": true,
		"glow": {"color": Color(1.0, 0.45, 0.12), "strength": 2.0, "pulse": 0.22, "speed": 1.5}},
	"cairn_frozen": {"file": "filler/cairn_frozen", "native": true, "rough": 0.9, "shadow": true},
	"iron_stakes_ember": {"file": "filler/iron_stakes_ember", "native": true, "rough": 0.5, "spec": 0.6, "shadow": true,
		"glow": {"strength": 1.6, "pulse": 0.2, "speed": 1.2}},
}

## Off shows the old code-built props instead (before/after captures, tests).
static var enabled := true
static var _meshes := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func casts_shadow(kind: String) -> bool:
	return KINDS[kind]["shadow"]


## The kind's mesh, built on first use and cached; null if the GLB can't be read.
static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	return _meshes[kind]


static func _build(kind: String) -> ArrayMesh:
	var d: Dictionary = KINDS[kind]
	var path: String = ROOT % d["file"]
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("RealmProps: can't load %s" % path)
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.push_front(root)
	if found.is_empty():
		root.free()
		push_error("RealmProps: no mesh in %s" % path)
		return null
	var source := (found[0] as MeshInstance3D).mesh
	var box := source.get_aabb()
	var native: bool = d.get("native", false)
	var k := 1.0
	var shift := Vector3.ZERO
	if not native:
		var extent := box.size.y if d["fit"] == "height" else maxf(box.size.x, box.size.z)
		k = d["size"] / maxf(extent, 0.001)
		# Footprint center, feet on the ground.
		shift = Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = (verts[i] - shift) * k
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays)
		var imported := source.surface_get_material(s) as BaseMaterial3D
		out.surface_set_material(s, _material(kind, s, imported))
	root.free()
	return out


static func _material(kind: String, surface: int, imported: BaseMaterial3D) -> ShaderMaterial:
	var d: Dictionary = KINDS[kind]
	var glow: Dictionary = d.get("glow", {})
	var tex: Texture2D = imported.albedo_texture if imported else null
	var native: bool = d.get("native", false)
	var mode: int = glow.get("mode", 0)
	var color: Color = glow.get("color", WARM)
	var strength: float = glow.get("strength", 0.0)
	if native:
		# Only the model's emissive surface glows, in its own color unless the kind overrides it.
		var lit := imported != null and imported.emission_enabled
		mode = 5 if lit else 0
		if lit and not glow.has("color"):
			color = imported.emission if imported.emission != Color.BLACK else imported.albedo_color
		if not lit:
			strength = 0.0
	return Models.material("realm_prop", {
		"albedo_tex": tex,
		"use_vcol": native,
		"tint": d.get("tint", Color.WHITE),
		"brightness": d.get("brightness", 1.0),
		"roughness": d["rough"],
		"specular": d.get("spec", 0.35),
		"emit_mode": mode,
		"emit_color": color,
		"emit_strength": strength,
		"emit_lo": glow.get("lo", 0.1),
		"emit_hi": glow.get("hi", 0.4),
		"crack_scale": glow.get("scale", 3.5),
		"crack_width": glow.get("width", 0.06),
		"pulse": glow.get("pulse", 0.0),
		"pulse_speed": glow.get("speed", 1.2),
		"rim_color": d.get("rim", Color(0.55, 0.65, 1.0)),
		"rim_strength": d.get("rim_strength", 0.15),
	}, "%s|%d" % [kind, surface])


## Where the hero is, for the see-through window. Every frame.
static func set_hero(at: Vector3) -> void:
	for kind: String in _meshes:
		var built := _meshes[kind] as ArrayMesh
		if built != null:
			for s in built.get_surface_count():
				(built.surface_get_material(s) as ShaderMaterial).set_shader_parameter("hero_position", at + Vector3(0.0, 0.9, 0.0))
