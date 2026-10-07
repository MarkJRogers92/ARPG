class_name ProjectileSwarm
extends MultiMeshInstance3D
## Player projectiles, simulated as flat arrays like EnemySwarm and tested
## against the enemy spatial hashes (no physics bodies). A bolt can carry an
## element (see Elements), which colors it and what it does on a hit.

## How many recently hit enemies a piercing bolt remembers, so it doesn't hit
## the same one again on every frame it overlaps it.
const HIT_MEMORY := 8

@export var capacity := 1024
@export var projectile_radius := 0.25
@export var height := 1.0
@export var color := Color(0.55, 0.65, 1.0)
@export var crit_color := Color(1.0, 0.55, 0.2)

## Emitted where a bolt hits something, for impact sparks.
signal hit(at: Vector2, crit: bool, damage: float)

var count := 0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
## Enemies a bolt can still pass through. Hitting one with 0 left destroys it.
var _pierce := PackedInt32Array()
var _crit := PackedByteArray()
var _element := PackedByteArray()
## 1 for the small bolts a Hydra weapon splits off; they don't split again.
var _split := PackedByteArray()
var _hit_ids := PackedInt32Array()
var _hit_cursor := PackedInt32Array()
var _buffer := PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_damage.resize(capacity)
	_pierce.resize(capacity)
	_crit.resize(capacity)
	_element.resize(capacity)
	_split.resize(capacity)
	_hit_ids.resize(capacity * HIT_MEMORY)
	_hit_cursor.resize(capacity)

	var mesh := Models.bolt()
	MultiMeshUtil.setup(self, mesh, capacity, mesh.surface_get_material(0))
	_buffer = MultiMeshUtil.make_buffer(capacity, height)


## `dir` must be normalized. Critical hits are drawn bigger and hotter;
## elemental bolts take their element's color.
func spawn(at: Vector2, dir: Vector2, speed: float, dmg: float, pierce: int, lifetime: float,
		crit := false, element := Elements.NONE, split := false) -> void:
	if count >= capacity:
		return
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	MultiMeshUtil.set_facing(_buffer, o, dir, (1.4 if crit else 1.0) * (0.65 if split else 1.0))
	var base_color: Color = Elements.COLORS.get(element, color)
	var tint := (crit_color if crit else base_color).srgb_to_linear()
	_element[count] = element
	_split[count] = 1 if split else 0
	for c in 4:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + c] = tint[c]
	_buffer[o + MultiMeshUtil.OFFSET_X] = at.x
	_buffer[o + MultiMeshUtil.OFFSET_Z] = at.y
	_crit[count] = 1 if crit else 0
	_pos[count] = at
	_vel[count] = dir * speed
	_life[count] = lifetime
	_damage[count] = dmg
	_pierce[count] = pierce
	_hit_cursor[count] = 0
	var base := count * HIT_MEMORY
	for k in HIT_MEMORY:
		_hit_ids[base + k] = 0
	count += 1


## Moves every projectile and applies hits against `swarms`.
## Call after the swarms' step() so their spatial hashes are current.
func step(delta: float, swarms: Array[EnemySwarm]) -> void:
	var i := count - 1
	while i >= 0:
		var from := _pos[i]
		var p := from + _vel[i] * delta
		_pos[i] = p
		_life[i] -= delta
		if _life[i] <= 0.0 or _hit_something(i, from, p, swarms):
			_remove_at(i)
		else:
			var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
			_buffer[o + MultiMeshUtil.OFFSET_X] = p.x
			_buffer[o + MultiMeshUtil.OFFSET_Z] = p.y
		i -= 1

	var mm := multimesh
	mm.visible_instance_count = count
	if count > 0:
		mm.buffer = _buffer


## Applies this projectile's hits for the frame. Returns true if it is spent.
## Swept: everything the bolt passed over between `from` and `to` counts, in
## order along the path (across every enemy type), so a fast bolt or a long
## frame can't skip an enemy and pierce is spent on the nearest first.
func _hit_something(i: int, from: Vector2, to: Vector2, swarms: Array[EnemySwarm]) -> bool:
	Elements.source = "Magic Bolt"
	var base := i * HIT_MEMORY
	var seg := to - from
	var seg_len2 := maxf(seg.length_squared(), 0.000001)
	var mid := (from + to) * 0.5
	var half := sqrt(seg_len2) * 0.5
	# [t along the path, swarm, index]
	var hits: Array = []
	for swarm in swarms:
		var reach := projectile_radius + swarm.radius
		var n := swarm.grid.query(mid, reach + half)
		if n == 0:
			continue
		var res := swarm.grid.results
		for k in n:
			var j := res[k]
			if swarm.hp[j] <= 0.0 or _already_hit(base, swarm.ids[j]):
				continue
			var t := clampf((swarm.pos[j] - from).dot(seg) / seg_len2, 0.0, 1.0)
			if (from + seg * t).distance_squared_to(swarm.pos[j]) <= reach * reach:
				hits.append([t, swarm, j])
	if hits.is_empty():
		return false
	if hits.size() > 1:
		hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for h: Array in hits:
		var swarm: EnemySwarm = h[1]
		var j: int = h[2]
		if swarm.hp[j] <= 0.0:
			continue
		var id := swarm.ids[j]
		var at: Vector2 = from + seg * h[0]
		var killed := Elements.hit(swarm, j, _damage[i], _element[i], _crit[i] == 1)
		hit.emit(at, _crit[i] == 1, _damage[i])
		if killed and _split[i] == 0 and Elements.has_power("splitting"):
			# Hydra: the kill spits out three smaller bolts.
			var v := _vel[i]
			for a: float in [-0.6, 0.0, 0.6]:
				spawn(swarm.pos[j], v.normalized().rotated(a), v.length(), _damage[i] * 0.6, 0,
						0.7, false, _element[i], true)
		_hit_ids[base + _hit_cursor[i]] = id
		_hit_cursor[i] = (_hit_cursor[i] + 1) % HIT_MEMORY
		if _pierce[i] <= 0:
			return true
		_pierce[i] -= 1
	return false


func _already_hit(base: int, id: int) -> bool:
	for k in HIT_MEMORY:
		if _hit_ids[base + k] == id:
			return true
	return false


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_damage[i] = _damage[last]
		_pierce[i] = _pierce[last]
		_crit[i] = _crit[last]
		_element[i] = _element[last]
		_split[i] = _split[last]
		_hit_cursor[i] = _hit_cursor[last]
		var dst := i * HIT_MEMORY
		var src := last * HIT_MEMORY
		for k in HIT_MEMORY:
			_hit_ids[dst + k] = _hit_ids[src + k]
		# Keep the moved bolt's slice of the render buffer in sync, since the
		# loop has already passed it (iterating downward) and won't rewrite it.
		MultiMeshUtil.copy_instance(_buffer, i, last)
	count = last
