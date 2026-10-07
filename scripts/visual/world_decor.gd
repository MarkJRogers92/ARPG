class_name WorldDecor
extends Node3D
## Scatters scenery (grass, rocks, trees, graves, ruins, glowing mushrooms...)
## over an endless world. The world is cut into square chunks; what grows in a
## chunk comes from a seed made of its coordinates, so walking away and back
## shows the same scenery. Only the chunks around the hero exist, and every
## prop kind is one MultiMesh, rebuilt when the hero crosses a chunk border.
##
## Props are decoration only: enemies and the hero walk through them.

@export var chunk_size := 12.0
## Chunks drawn in each direction from the hero's chunk.
@export var view_chunks := 3
## Average number of each prop per chunk.
## The realm sets this (see Realm); kinds not listed don't appear.
@export var density := {
	"grass": 10.0, "rock": 0.9, "bush": 1.0, "mushroom": 0.5, "bones": 0.5,
	"tree": 0.35, "grave": 0.35, "pillar": 0.12, "crystal": 0.14,
}
## Kinds big enough to cast real shadows.
const SHADOWED := ["rock", "tree", "grave", "pillar", "crystal", "bush", "pine", "ice", "snowrock", "obsidian", "ashtree"]

var _layers := {}
var _center := Vector2i(1 << 30, 0)


func _ready() -> void:
	for kind: String in Models.PROPS:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Models.prop(kind)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in SHADOWED \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_layers[kind] = mmi


## Call every frame with the hero's ground position; rebuilds when needed.
func follow(hero: Vector2) -> void:
	var c := Vector2i(floori(hero.x / chunk_size), floori(hero.y / chunk_size))
	if c != _center:
		_center = c
		_rebuild()


## Rebuilds the scenery now (after changing `density`).
func rebuild_now() -> void:
	if not _layers.is_empty():
		_rebuild()


func _rebuild() -> void:
	var xforms := {}
	var colors := {}
	for kind: String in Models.PROPS:
		xforms[kind] = []
		colors[kind] = []
	var rng := RandomNumberGenerator.new()
	for cy in range(_center.y - view_chunks, _center.y + view_chunks + 1):
		for cx in range(_center.x - view_chunks, _center.x + view_chunks + 1):
			rng.seed = hash(Vector2i(cx, cy) * 92821 + Vector2i(17, 3))
			var origin := Vector2(cx, cy) * chunk_size
			for kind: String in Models.PROPS:
				var n := _poisson(rng, density.get(kind, 0.0))
				for k in n:
					var p := origin + Vector2(rng.randf(), rng.randf()) * chunk_size
					# Leave the area right around the start clear.
					if p.length_squared() < 36.0 and kind != "grass":
						continue
					var s := rng.randf_range(0.7, 1.3)
					if kind == "tree" or kind == "pillar":
						s = rng.randf_range(0.9, 1.4)
					var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
					xforms[kind].append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
					var shade := rng.randf_range(0.8, 1.15)
					colors[kind].append(Color(shade, shade, shade))
	for kind: String in Models.PROPS:
		var mm: MultiMesh = _layers[kind].multimesh
		var list: Array = xforms[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, colors[kind][i])


## A small random count with the given average.
static func _poisson(rng: RandomNumberGenerator, mean: float) -> int:
	var l := exp(-mean)
	var k := 0
	var p := rng.randf()
	while p > l and k < 40:
		k += 1
		p *= rng.randf()
	return k
