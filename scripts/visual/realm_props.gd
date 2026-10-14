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
	var extent := box.size.y if d["fit"] == "height" else maxf(box.size.x, box.size.z)
	var k: float = d["size"] / maxf(extent, 0.001)
	# Footprint center, feet on the ground.
	var shift := Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
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
		out.surface_set_material(s, _material(kind, imported.albedo_texture if imported else null))
	root.free()
	return out


static func _material(kind: String, tex: Texture2D) -> ShaderMaterial:
	var d: Dictionary = KINDS[kind]
	var glow: Dictionary = d.get("glow", {})
	return Models.material("realm_prop", {
		"albedo_tex": tex,
		"tint": d.get("tint", Color.WHITE),
		"brightness": d.get("brightness", 1.0),
		"roughness": d["rough"],
		"specular": d.get("spec", 0.35),
		"emit_mode": glow.get("mode", 0),
		"emit_color": glow.get("color", WARM),
		"emit_strength": glow.get("strength", 0.0),
		"emit_lo": glow.get("lo", 0.1),
		"emit_hi": glow.get("hi", 0.4),
		"crack_scale": glow.get("scale", 3.5),
		"crack_width": glow.get("width", 0.06),
		"pulse": glow.get("pulse", 0.0),
		"pulse_speed": glow.get("speed", 1.2),
		"rim_color": d.get("rim", Color(0.55, 0.65, 1.0)),
		"rim_strength": d.get("rim_strength", 0.15),
	}, kind)


## Where the hero is, for the see-through window. Every frame.
static func set_hero(at: Vector3) -> void:
	for kind: String in _meshes:
		var built := _meshes[kind] as ArrayMesh
		if built != null:
			(built.surface_get_material(0) as ShaderMaterial).set_shader_parameter("hero_position", at + Vector3(0.0, 0.9, 0.0))
