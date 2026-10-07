class_name WorldDecor
extends Node3D
## Scatters scenery (grass, rocks, trees, graves, ruins, glowing mushrooms...)
## over an endless world. The world is cut into square chunks; what grows in a
## chunk comes from a seed made of its coordinates, so walking away and back
## shows the same scenery. Only the chunks around the hero exist, and every
## prop kind is one MultiMesh, rebuilt when the hero crosses a chunk border.
##
## Most props are decoration that enemies and the hero walk through; imported
## set pieces with collision circles (AssetProps "solid") block them (Obstacles).
##
## Imported scenery (AssetProps kinds) is placed separately from the
## code-built props, with its own seed per chunk and kind, so adding or
## tuning it never moves the existing props. Landmarks (big set pieces) take
## at most one slot per chunk, near its middle; every imported prop stays
## inside its chunk by its footprint and keeps clear of the others, so none
## overlap, and code-built props inside a landmark's footprint are left out.

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

## Extra props at fixed places, drawn whenever their chunk is in view. For
## developer showcases only (tools/asset_showcase.gd), never set by the game:
## [{"kind": String, "at": Vector2, "yaw": float, "scale": float}].
var fixed: Array = []
## No imported prop closer than this to the start (plus its footprint); landmarks
## keep twice as far away.
const ASSET_CLEAR := 6.0
## Every prop in view, as built: {kind: [Transform3D]} (Landmarks reads it).
var placed := {}
## Glowing imported props in view: [[Vector3 top, Color]] (see emit()).
var emitters: Array = []
var _emit_timer := 0.0

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
		var shadowed: bool = AssetProps.data(kind)["shadow"] if AssetProps.has(kind) else kind in SHADOWED
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadowed \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_layers[kind] = mmi


## Call every frame with the hero's ground position; rebuilds when needed.
func follow(hero: Vector2) -> void:
	AssetProps.set_hero(Vector3(hero.x, 0.0, hero.y))
	var c := Vector2i(floori(hero.x / chunk_size), floori(hero.y / chunk_size))
	if c != _center:
		_center = c
		_rebuild()


## Ambient motes drifting up from glowing props near the hero (soul wisps in the
## graveyard, embers in the rift). Call every frame.
func emit(delta: float, hero: Vector2, motes: FxSwarm) -> void:
	if emitters.is_empty():
		return
	_emit_timer -= delta
	while _emit_timer <= 0.0:
		_emit_timer += 0.06
		var e: Array = emitters[randi() % emitters.size()]
		var at: Vector3 = e[0]
		if Vector2(at.x, at.z).distance_squared_to(hero) < 22.0 * 22.0:
			var jitter := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			motes.burst(Vector2(at.x, at.z) + jitter, at.y, e[1], 1, 0.3, 0.1, 2.2, 0.9)


## Rebuilds the scenery now (after changing `density`).
func rebuild_now() -> void:
	if not _layers.is_empty():
		_rebuild()


func _rebuild() -> void:
	var result := compute(_center)
	var xforms: Dictionary = result[0]
	var colors: Dictionary = result[1]
	Obstacles.set_circles(result[2], Rect2(Vector2(_center - Vector2i.ONE * view_chunks) * chunk_size,
			Vector2.ONE * (2 * view_chunks + 1) * chunk_size))
	emitters = result[3]
	placed = xforms
	for kind: String in Models.PROPS:
		var mm: MultiMesh = _layers[kind].multimesh
		var list: Array = xforms[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, colors[kind][i])


## Every prop around chunk `center`: [{kind: [Transform3D]}, {kind: [Color]},
## obstacle circles [[Vector2, radius]], glow emitters [[Vector3, Color]]].
## Pure (no nodes or rendering), so tests can check placement.
func compute(center: Vector2i) -> Array:
	var xforms := {}
	var colors := {}
	var solids := []
	var glows := []
	for kind: String in Models.PROPS:
		xforms[kind] = []
		colors[kind] = []
	var rng := RandomNumberGenerator.new()
	var fixed_landmarks := []
	for f: Dictionary in fixed:
		if AssetProps.has(f["kind"]) and AssetProps.data(f["kind"])["landmark"]:
			fixed_landmarks.append([f["at"], AssetProps.data(f["kind"])["footprint"] * f.get("scale", 1.0), true])
	for cy in range(center.y - view_chunks, center.y + view_chunks + 1):
		for cx in range(center.x - view_chunks, center.x + view_chunks + 1):
			rng.seed = hash(Vector2i(cx, cy) * 92821 + Vector2i(17, 3))
			var origin := Vector2(cx, cy) * chunk_size
			var placed := _place_assets(Vector2i(cx, cy), xforms, colors, solids, glows)
			for kind: String in Models.PROPS:
				if AssetProps.has(kind):
					continue
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
					var shade := rng.randf_range(0.8, 1.15)
					# Decided after every draw, so landmarks never move the other props.
					if _inside_landmark(p, placed) or _inside_landmark(p, fixed_landmarks):
						continue
					xforms[kind].append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
					colors[kind].append(Color(shade, shade, shade))
	for f: Dictionary in fixed:
		var at: Vector2 = f["at"]
		var c := Vector2i(floori(at.x / chunk_size), floori(at.y / chunk_size))
		if xforms.has(f["kind"]) and absi(c.x - center.x) <= view_chunks and absi(c.y - center.y) <= view_chunks:
			var basis := Basis(Vector3.UP, f.get("yaw", 0.0)).scaled(Vector3.ONE * f.get("scale", 1.0))
			var xf := Transform3D(basis, Vector3(at.x, 0.0, at.y))
			xforms[f["kind"]].append(xf)
			colors[f["kind"]].append(Color.WHITE)
			if AssetProps.has(f["kind"]):
				_extras(f["kind"], xf, solids, glows)
	return [xforms, colors, solids, glows]


## Imported props for one chunk; returns what it placed as [[at, footprint, landmark]].
func _place_assets(chunk: Vector2i, xforms: Dictionary, colors: Dictionary, solids: Array, glows: Array) -> Array:
	var placed := []
	var origin := Vector2(chunk) * chunk_size
	var rng := RandomNumberGenerator.new()
	# The landmark slot: one roll picks which landmark (if any) this chunk holds.
	rng.seed = hash([chunk.x, chunk.y, "landmark"])
	var roll := rng.randf()
	for kind: String in AssetProps.KINDS:
		var d := AssetProps.data(kind)
		if not d["landmark"]:
			continue
		roll -= density.get(kind, 0.0)
		if roll < 0.0:
			var fp: float = d["footprint"]
			var slack := maxf(chunk_size * 0.5 - fp, 0.0)
			var p := origin + Vector2.ONE * chunk_size * 0.5 + Vector2(rng.randf_range(-slack, slack), rng.randf_range(-slack, slack))
			if p.length() >= 2.0 * ASSET_CLEAR + fp:
				_add_asset(kind, p, rng, xforms, colors, solids, glows)
				placed.append([p, fp, true])
			break
	for kind: String in AssetProps.KINDS:
		var d := AssetProps.data(kind)
		var mean: float = density.get(kind, 0.0)
		if d["landmark"] or mean <= 0.0:
			continue
		rng.seed = hash([chunk.x, chunk.y, kind])
		var fp: float = d["footprint"]
		for k in _poisson(rng, mean):
			# Inset by the footprint, so props in neighboring chunks can't overlap.
			var p := origin + Vector2(rng.randf_range(fp, chunk_size - fp), rng.randf_range(fp, chunk_size - fp))
			if p.length() < ASSET_CLEAR + fp or _overlaps(p, fp, placed):
				continue
			_add_asset(kind, p, rng, xforms, colors, solids, glows)
			placed.append([p, fp, false])
	return placed


func _add_asset(kind: String, p: Vector2, rng: RandomNumberGenerator, xforms: Dictionary, colors: Dictionary,
		solids: Array, glows: Array) -> void:
	var d := AssetProps.data(kind)
	var yaw: float = d["yaw"]
	# The art's front faces +Z, toward the camera; big pieces only turn a little.
	var angle := rng.randf() * TAU if yaw >= TAU else rng.randf_range(-yaw, yaw)
	var s := rng.randf_range(d["scale"][0], d["scale"][1])
	var xf := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * s), Vector3(p.x, 0.0, p.y))
	xforms[kind].append(xf)
	var shade := rng.randf_range(0.9, 1.1)
	colors[kind].append(Color(shade, shade, shade))
	_extras(kind, xf, solids, glows)


## A placed asset's collision circles and glow emitter, in world space.
static func _extras(kind: String, xf: Transform3D, solids: Array, glows: Array) -> void:
	var d := AssetProps.data(kind)
	var s := xf.basis.get_scale().x
	for c: Array in d["solid"]:
		var w := xf * Vector3(c[0], 0.0, c[1])
		solids.append([Vector2(w.x, w.z), c[2] * s])
	if d["fx"] != null:
		var mesh := AssetProps.mesh(kind)
		var top := mesh.get_aabb().size.y * 0.6 * s if mesh else 1.0
		glows.append([xf.origin + Vector3(0.0, top, 0.0), d["fx"]])


static func _overlaps(p: Vector2, fp: float, placed: Array) -> bool:
	for q: Array in placed:
		if p.distance_to(q[0]) < fp + q[1]:
			return true
	return false


static func _inside_landmark(p: Vector2, placed: Array) -> bool:
	for q: Array in placed:
		if q[2] and p.distance_to(q[0]) < q[1]:
			return true
	return false


## A small random count with the given average.
static func _poisson(rng: RandomNumberGenerator, mean: float) -> int:
	var l := exp(-mean)
	var k := 0
	var p := rng.randf()
	while p > l and k < 40:
		k += 1
		p *= rng.randf()
	return k
