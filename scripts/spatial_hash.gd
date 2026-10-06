class_name SpatialHash
extends RefCounted
## Uniform-grid spatial hash over 2D points, rebuilt every frame.
##
## Buckets are linked lists stored in flat arrays, so a rebuild is a single
## pass over the points with no per-cell allocations. Cells are hashed into a
## fixed number of buckets: collisions only add extra candidates, and query()
## always does an exact distance check.
##
## Queries see the point positions as of the last rebuild() (the array is
## shared copy-on-write, so later writes by the owner don't leak in). Indices
## are only valid until the owner reorders its arrays, so rebuild after any
## swap-remove and don't query across one.

const _PRIME_X := 73856093
const _PRIME_Y := 19349663

## Filled by query(); only the first `query()` return value entries are valid.
var results := PackedInt32Array()
## How many points share the cell of the last point passed to repulsion().
var last_own_count := 0

var _inv_cell: float
var _mask: int
var _head := PackedInt32Array()
var _count := PackedInt32Array()
var _next := PackedInt32Array()
var _stamp := PackedInt32Array()
var _stamp_counter := 0
var _points := PackedVector2Array()


func _init(cell_size := 2.0, bucket_count := 4096, capacity := 1024) -> void:
	assert(nearest_po2(bucket_count) == bucket_count, "bucket_count must be a power of two")
	_inv_cell = 1.0 / cell_size
	_mask = bucket_count - 1
	_head.resize(bucket_count)
	_count.resize(bucket_count)
	_stamp.resize(bucket_count)
	_next.resize(capacity)
	results.resize(256)


func rebuild(points: PackedVector2Array, count: int) -> void:
	_points = points
	if _next.size() < count:
		_next.resize(maxi(count, _next.size() * 2))
	_head.fill(-1)
	_count.fill(0)
	for i in count:
		var p := points[i]
		var b := ((floori(p.x * _inv_cell) * _PRIME_X) ^ (floori(p.y * _inv_cell) * _PRIME_Y)) & _mask
		_next[i] = _head[b]
		_head[b] = i
		_count[b] += 1


## A push vector away from crowded cells, for spreading a horde out.
##
## Reads the occupancy of the cell holding `p` and its four neighbors (a
## constant cost however packed the crowd is) and returns roughly "enemies per
## cell" worth of push toward emptier space. Unlike neighbor sampling this is
## symmetric, so a dense pile builds real outward pressure and spreads instead
## of compressing. `jitter` is a unit-ish vector that breaks ties for points
## sitting exactly on top of each other.
func repulsion(p: Vector2, jitter: Vector2) -> Vector2:
	var fx := p.x * _inv_cell
	var fy := p.y * _inv_cell
	var cx := floori(fx)
	var cy := floori(fy)
	var own := _count[((cx * _PRIME_X) ^ (cy * _PRIME_Y)) & _mask]
	last_own_count = own

	var push := Vector2(
		_count[(((cx - 1) * _PRIME_X) ^ (cy * _PRIME_Y)) & _mask]
				- _count[(((cx + 1) * _PRIME_X) ^ (cy * _PRIME_Y)) & _mask],
		_count[((cx * _PRIME_X) ^ ((cy - 1) * _PRIME_Y)) & _mask]
				- _count[((cx * _PRIME_X) ^ ((cy + 1) * _PRIME_Y)) & _mask])

	if own > 1:
		# Several points share this cell: nudge each toward its own edge.
		var offset := Vector2(fx - cx - 0.5, fy - cy - 0.5)
		push += (offset * 2.0 + jitter) * (own - 1)
	return push


## Collects the indices of points within `radius` of `center` into `results`
## and returns how many were found (stops early at `max_results`).
func query(center: Vector2, radius: float, max_results := 0x7fffffff) -> int:
	var found := 0
	var r2 := radius * radius
	var cx0 := floori((center.x - radius) * _inv_cell)
	var cx1 := floori((center.x + radius) * _inv_cell)
	var cy0 := floori((center.y - radius) * _inv_cell)
	var cy1 := floori((center.y + radius) * _inv_cell)

	# Several cells in the queried window can hash to one bucket; the stamp
	# makes sure each bucket is walked once so no point is reported twice.
	_stamp_counter += 1
	if _stamp_counter >= 0x3fffffff:
		_stamp.fill(0)
		_stamp_counter = 1

	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var b := ((cx * _PRIME_X) ^ (cy * _PRIME_Y)) & _mask
			if _stamp[b] == _stamp_counter:
				continue
			_stamp[b] = _stamp_counter
			var j := _head[b]
			while j != -1:
				if center.distance_squared_to(_points[j]) <= r2:
					if found == results.size():
						results.resize(found * 2)
					results[found] = j
					found += 1
					if found >= max_results:
						return found
				j = _next[j]
	return found
