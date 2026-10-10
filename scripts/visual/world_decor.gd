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
## tuning it never rerolls existing props. One primary landmark slot per
## chunk now anchors an authored burial plot, snow camp or forge yard. Auxiliary
## scenery belongs to that place, rather than being independent landmark rolls.
## Footprints stay within chunks; the yard and its approach remain free of scatter.

@export var chunk_size := 12.0
## Chunks drawn in each direction from the hero's chunk.
@export var view_chunks := 3
## False retains the old scatter for comparison captures and regression tests.
@export var compositions := true
## Average number of each prop per chunk.
## The realm sets this (see Realm); kinds not listed don't appear.
@export var density := {
	"grass": 10.0, "rock": 0.9, "bush": 1.0, "mushroom": 0.5, "bones": 0.5,
	"tree": 0.35, "grave": 0.35, "pillar": 0.12, "crystal": 0.14,
}
## Kinds big enough to cast real shadows.
const SHADOWED := ["rock", "tree", "grave", "pillar", "crystal", "bush", "pine", "ice", "snowrock", "obsidian", "ashtree"]
## Explicit dependency also works before a newly added global class is scanned.
const COMPOSITION_LAYOUTS := preload("res://scripts/visual/decor_compositions.gd")

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
## Authored places and ground stamps currently in view (replaced on each rebuild).
var groups: Array = []
var ground_marks: Array = []
var _emit_timer := 0.0

var _layers := {}
var _ground_layers := {}
var _center := Vector2i(1 << 30, 0)
## Runtime-only reuse: compute() remains an uncached placement oracle. Keep just
## the current view, so an endless walk cannot accumulate an endless cache.
var cache_chunks := true
var _chunk_cache := {}
var _chunk_settings: Array = []


func _exit_tree() -> void:
	_chunk_cache.clear()
	_chunk_settings.clear()


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
	for style: String in ["graveyard", "frozen", "ember"]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		plane.material = Models.material("decor_ground", {"biome": ["graveyard", "frozen", "ember"].find(style)}, style)
		mm.mesh = plane
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_ground_layers[style] = mmi


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
	if not cache_chunks:
		_chunk_cache.clear()
		_chunk_settings.clear()
	var result := _compute(_center, cache_chunks)
	var xforms: Dictionary = result[0]
	var colors: Dictionary = result[1]
	Obstacles.set_circles(result[2], Rect2(Vector2(_center - Vector2i.ONE * view_chunks) * chunk_size,
			Vector2.ONE * (2 * view_chunks + 1) * chunk_size))
	emitters = result[3]
	groups = result[4]
	ground_marks = result[5]
	placed = xforms
	for kind: String in Models.PROPS:
		var mm: MultiMesh = _layers[kind].multimesh
		var list: Array = xforms[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, colors[kind][i])
	for style: String in _ground_layers:
		var marks: Array = ground_marks.filter(func(m: Dictionary) -> bool: return m["style"] == style)
		var mm: MultiMesh = _ground_layers[style].multimesh
		mm.instance_count = marks.size()
		for i in marks.size():
			var m: Dictionary = marks[i]
			var size: Vector2 = m["size"]
			var at: Vector2 = m["at"]
			var basis := Basis(Vector3.UP, m["yaw"]).scaled_local(Vector3(size.x, 1.0, size.y))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(at.x, 0.018 if m["path"] else 0.012, at.y)))
			mm.set_instance_custom_data(i, Color(size.x, size.y, 1.0 if m["path"] else 0.0, 0.0))


## Every prop around chunk `center`: [{kind: [Transform3D]}, {kind: [Color]},
## obstacle circles [[Vector2, radius]], glow emitters [[Vector3, Color]],
## composed groups, ground marks]. The original first four indices are unchanged.
## Pure (no nodes or rendering), so tests can check placement.
func compute(center: Vector2i) -> Array:
	return _compute(center, false)


func _compute(center: Vector2i, reuse_chunks: bool) -> Array:
	if reuse_chunks:
		_sync_chunk_cache(center)
	var xforms := {}
	var colors := {}
	var solids := []
	var glows := []
	var composed := []
	var marks := []
	for kind: String in Models.PROPS:
		xforms[kind] = []
		colors[kind] = []
	var fixed_landmarks := []
	for f: Dictionary in fixed:
		if AssetProps.has(f["kind"]) and AssetProps.data(f["kind"])["landmark"]:
			fixed_landmarks.append([f["at"], AssetProps.data(f["kind"])["footprint"] * f.get("scale", 1.0), true])
	for cy in range(center.y - view_chunks, center.y + view_chunks + 1):
		for cx in range(center.x - view_chunks, center.x + view_chunks + 1):
			var chunk := Vector2i(cx, cy)
			var data: Array
			if reuse_chunks and _chunk_cache.has(chunk):
				data = _chunk_cache[chunk]
			else:
				data = _compute_chunk(chunk, fixed_landmarks)
				if reuse_chunks:
					_chunk_cache[chunk] = data
			for kind: String in data[0]:
				xforms[kind].append_array(data[0][kind])
				colors[kind].append_array(data[1][kind])
			# These contain nested mutable arrays/dictionaries; frame consumers must
			# never alias the retained chunk. Transforms/colours above are value types.
			solids.append_array(data[2].duplicate(true) if reuse_chunks else data[2])
			glows.append_array(data[3].duplicate(true) if reuse_chunks else data[3])
			composed.append_array(data[4].duplicate(true) if reuse_chunks else data[4])
			marks.append_array(data[5].duplicate(true) if reuse_chunks else data[5])
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
	return [xforms, colors, solids, glows, composed, marks]


func _sync_chunk_cache(center: Vector2i) -> void:
	var settings: Array = [chunk_size, compositions, density, fixed]
	if settings != _chunk_settings:
		_chunk_cache.clear()
		# Detect in-place edits to realm densities and nested showcase entries too.
		_chunk_settings = settings.duplicate(true)
	for chunk: Vector2i in _chunk_cache.keys():
		if absi(chunk.x - center.x) > view_chunks or absi(chunk.y - center.y) > view_chunks:
			_chunk_cache.erase(chunk)


## Independent seeded chunk, without fixed props (those append last, as before).
func _compute_chunk(chunk: Vector2i, fixed_landmarks: Array) -> Array:
	var xforms := {}
	var colors := {}
	var solids := []
	var glows := []
	var chunk_groups := []
	var marks := []
	for kind: String in Models.PROPS:
		# Only positive-density kinds can be placed; fixed props append outside
		# the chunk. Avoid storing/merging dozens of empty off-biome arrays.
		if density.get(kind, 0.0) > 0.0:
			xforms[kind] = []
			colors[kind] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk * 92821 + Vector2i(17, 3))
	var origin := Vector2(chunk) * chunk_size
	var imported := _place_assets(chunk, xforms, colors, solids, glows, chunk_groups, marks)
	for kind: String in Models.PROPS:
		if AssetProps.has(kind):
			continue
		var n := _poisson(rng, density.get(kind, 0.0))
		for k in n:
			var p := origin + Vector2(rng.randf(), rng.randf()) * chunk_size
			if p.length_squared() < 36.0 and kind != "grass":
				continue
			var s := rng.randf_range(0.7, 1.3)
			if kind == "tree" or kind == "pillar":
				s = rng.randf_range(0.9, 1.4)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var shade := rng.randf_range(0.8, 1.15)
			# Keep every original draw and suppression decision in the original order.
			if _inside_landmark(p, imported) or _inside_landmark(p, fixed_landmarks) or _inside_group(p, chunk_groups):
				continue
			xforms[kind].append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
			colors[kind].append(Color(shade, shade, shade))
	return [xforms, colors, solids, glows, chunk_groups, marks]


## Imported props for one chunk; returns what it placed as [[at, footprint, landmark]].
func _place_assets(chunk: Vector2i, xforms: Dictionary, colors: Dictionary, solids: Array, glows: Array,
		composed: Array = [], marks: Array = []) -> Array:
	if not compositions:
		return _scatter_assets(chunk, xforms, colors, solids, glows)
	# Generate the old plan first: usable pieces retain their exact seeded transforms,
	# counts and colours, even when cosmetic scenery is thinned or grouped.
	var old_xf := {}
	var old_colors := {}
	for kind: String in AssetProps.KINDS:
		old_xf[kind] = []
		old_colors[kind] = []
	_scatter_assets(chunk, old_xf, old_colors, [], [])
	var placed := []
	var anchor := ""
	for kind: String in AssetProps.KINDS:
		if AssetProps.data(kind)["landmark"] and not old_xf[kind].is_empty():
			anchor = kind
		if Landmarks.USES.has(kind):
			_copy_assets(kind, old_xf, old_colors, xforms, colors, solids, glows, placed)
	var grouped := false
	if anchor != "" and not Landmarks.USES.has(anchor):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([chunk.x, chunk.y, "composition"])
		var layout := COMPOSITION_LAYOUTS.layout(anchor, rng.randi_range(0, 1))
		if not layout.is_empty() and chunk_size >= 12.0:
			var at := (Vector2(chunk) + Vector2.ONE * 0.5) * chunk_size
			var radius: float = layout["radius"]
			var slack := minf(0.15, chunk_size * 0.5 - radius - 0.3)
			at += Vector2(rng.randf_range(-slack, slack), rng.randf_range(-slack, slack))
			# Keep the entire place beyond the original landmark start exclusion.
			# An existing usable piece wins over cosmetic composition, not vice versa.
			if at.length() >= 2.0 * ASSET_CLEAR + radius and not _overlaps(at, radius, placed):
				_add_group(anchor, layout, at, xforms, colors, solids, glows, placed, composed, marks)
				grouped = true
		if not grouped:
			_copy_assets(anchor, old_xf, old_colors, xforms, colors, solids, glows, placed)
	for kind: String in AssetProps.KINDS:
		var d := AssetProps.data(kind)
		if d["landmark"] or Landmarks.USES.has(kind):
			continue
		# Approved small props are cluster members, never unrelated isolated rolls.
		if str(d["path"]).begins_with("06_approved_collection/"):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([chunk.x, chunk.y, kind, "quiet_scatter"])
		for i in old_xf[kind].size():
			var keep := rng.randf() < 0.45
			var xf: Transform3D = old_xf[kind][i]
			var p := Vector2(xf.origin.x, xf.origin.z)
			var fp: float = d["footprint"] * xf.basis.get_scale().x
			if not keep or _overlaps(p, fp, placed) or _inside_group(p, composed, fp):
				continue
			_append_asset(kind, xf, old_colors[kind][i], xforms, colors, solids, glows, placed)
	return placed


func _copy_assets(kind: String, source: Dictionary, shades: Dictionary, xforms: Dictionary, colors: Dictionary,
		solids: Array, glows: Array, placed: Array) -> void:
	for i in source[kind].size():
		_append_asset(kind, source[kind][i], shades[kind][i], xforms, colors, solids, glows, placed)


func _append_asset(kind: String, xf: Transform3D, shade: Color, xforms: Dictionary, colors: Dictionary,
		solids: Array, glows: Array, placed: Array) -> void:
	xforms[kind].append(xf)
	colors[kind].append(shade)
	_extras(kind, xf, solids, glows)
	var d := AssetProps.data(kind)
	placed.append([Vector2(xf.origin.x, xf.origin.z), d["footprint"] * xf.basis.get_scale().x, d["landmark"]])


func _add_group(anchor: String, layout: Dictionary, at: Vector2, xforms: Dictionary, colors: Dictionary,
		solids: Array, glows: Array, placed: Array, composed: Array, marks: Array) -> void:
	var entries: Array = [{"kind": anchor, "at": layout["anchor_at"], "yaw": layout["anchor_yaw"], "scale": 1.0}]
	entries.append_array(layout["members"])
	for entry: Dictionary in entries:
		var kind: String = entry["kind"]
		if density.get(kind, 0.0) <= 0.0:
			continue
		var p: Vector2 = at + entry["at"]
		var xf := Transform3D(Basis(Vector3.UP, entry["yaw"]).scaled(Vector3.ONE * entry["scale"]), Vector3(p.x, 0.0, p.y))
		_append_asset(kind, xf, Color.WHITE, xforms, colors, solids, glows, placed)
	var lanes := []
	var style: String = AssetProps.data(anchor)["realm"]
	for local_lane: Dictionary in layout["lanes"]:
		var a: Vector2 = at + local_lane["a"]
		var b: Vector2 = at + local_lane["b"]
		lanes.append({"a": a, "b": b, "width": local_lane["width"]})
		var delta := b - a
		marks.append({"at": (a + b) * 0.5, "size": Vector2(local_lane["width"], delta.length()),
			"yaw": atan2(delta.x, delta.y), "style": style, "path": true})
	for pad: Dictionary in layout["pads"]:
		marks.append({"at": at + pad["at"], "size": pad["size"], "yaw": pad["yaw"], "style": pad["style"], "path": false})
	composed.append({"id": layout["id"], "kind": anchor, "at": at, "radius": layout["radius"], "lanes": lanes,
		"anchor_at": at + layout["anchor_at"], "anchor_yaw": layout["anchor_yaw"]})


static func _inside_group(p: Vector2, composed: Array, margin: float = 0.0) -> bool:
	for group: Dictionary in composed:
		if p.distance_to(group["at"]) < float(group["radius"]) + margin:
			return true
		for lane: Dictionary in group["lanes"]:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, lane["a"], lane["b"])) < float(lane["width"]) * 0.5 + margin:
				return true
	return false


## Original seeded placement plan, also used to preserve gameplay scenery.
func _scatter_assets(chunk: Vector2i, xforms: Dictionary, colors: Dictionary, solids: Array, glows: Array) -> Array:
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
