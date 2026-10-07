class_name Obstacles
extends RefCounted
## Solid scenery (walls, gates, big set pieces) as circles on the ground.
## WorldDecor rebuilds the set whenever the scenery around the hero changes;
## the hero and every enemy swarm are pushed out of them each frame, and slide
## around them because only the overlapping part of a step is undone.
##
## Bolts, enemy shots, gems, loot and the spectral army pass through: they're
## magic (and it keeps the horde game readable).
##
## Fast path for the swarms: a coarse grid flags the cells near any obstacle,
## so most enemies cost one array read. Only flagged cells check circles.

const CELL := 1.0
## At least the radius of any non-boss body (a brute elite is about 1.16), so a
## flagged cell covers every possible overlap. Bosses always check (see EnemySwarm).
const MAX_BODY := 1.2

## [Vector2 center, float radius] per obstacle.
static var circles: Array = []
## Grid origin, width (cells per side) and per-cell obstacle lists.
static var origin := Vector2.ZERO
static var width := 0
## 1 where a cell is near an obstacle, else 0. Read directly by hot loops.
static var flags := PackedByteArray()
static var _cells: Array = []
static var _all := PackedInt32Array()
## The circles again as packed arrays, for hot loops (EnemySwarm).
static var centers := PackedVector2Array()
static var radii := PackedFloat32Array()
## Per cell, the circles that might touch a body in it (or null). For hot loops.
static var cells: Array:
	get:
		return _cells


## Replaces every obstacle. `area` is the ground the grid covers.
static func set_circles(list: Array, area: Rect2) -> void:
	circles = list
	origin = area.position
	width = int(ceil(maxf(area.size.x, area.size.y) / CELL))
	flags = PackedByteArray()
	_cells = []
	_all = PackedInt32Array()
	centers = PackedVector2Array()
	radii = PackedFloat32Array()
	for c: Array in list:
		centers.append(c[0])
		radii.append(c[1])
	if list.is_empty():
		width = 0
		return
	flags.resize(width * width)
	_cells.resize(width * width)
	_all = PackedInt32Array(range(list.size()))
	for i in list.size():
		var c: Vector2 = list[i][0]
		var reach: float = list[i][1] + MAX_BODY
		var x0 := maxi(int(floor((c.x - reach - origin.x) / CELL)), 0)
		var x1 := mini(int(floor((c.x + reach - origin.x) / CELL)), width - 1)
		var y0 := maxi(int(floor((c.y - reach - origin.y) / CELL)), 0)
		var y1 := mini(int(floor((c.y + reach - origin.y) / CELL)), width - 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var k := gy * width + gx
				flags[k] = 1
				if _cells[k] == null:
					_cells[k] = PackedInt32Array()
				_cells[k].append(i)


static func clear() -> void:
	set_circles([], Rect2())


## True if a body of `radius` at `p` might touch an obstacle (cheap test).
static func near(p: Vector2) -> bool:
	if width == 0:
		return false
	var gx := int(floor((p.x - origin.x) / CELL))
	var gy := int(floor((p.y - origin.y) / CELL))
	return gx >= 0 and gy >= 0 and gx < width and gy < width and flags[gy * width + gx] == 1


## `p` moved out of every obstacle a body of `radius` overlaps.
static func resolve(p: Vector2, radius: float) -> Vector2:
	if width == 0:
		return p
	var gx := int(floor((p.x - origin.x) / CELL))
	var gy := int(floor((p.y - origin.y) / CELL))
	if gx < 0 or gy < 0 or gx >= width or gy >= width:
		return p
	var list = _cells[gy * width + gx]
	if radius > MAX_BODY:
		list = _all
	if list == null:
		return p
	# A few passes settle bodies touching neighbouring circles.
	for pass_i in 3:
		var moved := false
		for i: int in list:
			var c: Vector2 = circles[i][0]
			var min_d: float = circles[i][1] + radius
			var off := p - c
			var d2 := off.length_squared()
			# A hair of tolerance, so a body left exactly on the edge counts as out.
			if d2 < (min_d - 0.001) * (min_d - 0.001):
				if d2 < 0.000001:
					off = Vector2(0.0, 1.0)
					d2 = 1.0
				p = c + off / sqrt(d2) * min_d
				moved = true
		if not moved:
			return p
	# Still wedged (a seam too narrow to fit through): step out to the nearest free spot.
	return _escape(p, radius, list)


## Like resolve(), but a body pushed back while moving by `move` also slides
## along the obstacle's edge, the way toward its goal, so a horde flows
## around a wall instead of piling up behind it.
static func resolve_slide(p: Vector2, radius: float, move: Vector2) -> Vector2:
	var q := resolve(p, radius)
	if q == p or move == Vector2.ZERO:
		return q
	var n := (q - p).normalized()
	var t := Vector2(-n.y, n.x)
	# Which way round: toward the goal, and away from the rest of the set piece
	# (so a wall is passed at its end, not pushed into its corner).
	var away := Vector2.ZERO
	var list = _cells[floori((q.y - origin.y) / CELL) * width + floori((q.x - origin.x) / CELL)] \
			if near(q) else null
	if list != null and list.size() > 1:
		var centroid := Vector2.ZERO
		for i: int in list:
			centroid += circles[i][0]
		away = (q - centroid / list.size()).normalized()
	if t.dot(move.normalized()) + 0.6 * t.dot(away) < 0.0:
		t = -t
	return resolve(q + t * move.length() * 0.9, radius)


static func _escape(p: Vector2, radius: float, list: PackedInt32Array) -> Vector2:
	for dist in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]:
		for k in 12:
			var q: Vector2 = p + Vector2.from_angle(k * TAU / 12.0) * dist
			var free := true
			for i: int in list:
				if q.distance_squared_to(circles[i][0]) < (circles[i][1] + radius - 0.001) * (circles[i][1] + radius - 0.001):
					free = false
					break
			if free:
				return q
	return p


## True if `p` is inside an obstacle (for spawns and tests).
static func blocked(p: Vector2, radius := 0.0) -> bool:
	for c: Array in circles:
		if p.distance_to(c[0]) < c[1] + radius:
			return true
	return false
