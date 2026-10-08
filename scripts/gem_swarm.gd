class_name GemSwarm
extends MultiMeshInstance3D
## XP gems dropped by dead enemies. Array-simulated and MultiMesh-drawn like
## the other swarms. Gems inside the player's pickup radius get pulled in.

@export var capacity := 3000
@export var height := 0.4
## Gem color by XP value: the first entry whose value is at least the gem's.
@export var tiers: Array[Color] = [Color(0.3, 1.0, 0.55), Color(0.35, 0.7, 1.0), Color(0.85, 0.4, 1.0), Color(1.0, 0.8, 0.3)]
## ...where tier k holds values up to tier_values[k].
@export var tier_values: Array[int] = [2, 8, 30, 1000000]
@export var magnet_accel := 40.0
@export var collect_radius := 0.7

var count := 0
## Values of the gems picked up in the last step() (the Soul Army reads which
## souls came in).
var collected := PackedInt32Array()

var _pos := PackedVector2Array()
var _value := PackedInt32Array()
## 0 = idle on the ground, otherwise the current pull speed toward the player.
var _pull := PackedFloat32Array()
var _buffer := PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_pos.resize(capacity)
	_value.resize(capacity)
	_pull.resize(capacity)

	var mesh := Models.gem()
	MultiMeshUtil.setup(self, mesh, capacity, mesh.surface_get_material(0))
	_buffer = MultiMeshUtil.make_buffer(capacity, height)


## Drops a gem worth `value` XP. If the swarm is full the XP is returned
## so the caller can award it directly instead of losing it.
func drop(at: Vector2, value: int) -> int:
	if count >= capacity:
		return value
	var tier := 0
	while tier < tier_values.size() - 1 and value > tier_values[tier]:
		tier += 1
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	var c := tiers[mini(tier, tiers.size() - 1)].srgb_to_linear()
	for k in 4:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + k] = c[k]
	MultiMeshUtil.set_facing(_buffer, o, Vector2.UP, 1.5 + 0.3 * tier)
	_buffer[o + MultiMeshUtil.OFFSET_X] = at.x
	_buffer[o + MultiMeshUtil.OFFSET_Z] = at.y
	_pos[count] = at
	_value[count] = value
	_pull[count] = 0.0
	count += 1
	return 0


## Moves gems and returns the XP collected this frame.
func step(delta: float, target: Vector2, pickup_radius: float) -> int:
	var gained := 0
	collected.clear()
	var pickup_sq := pickup_radius * pickup_radius
	var collect_sq := collect_radius * collect_radius
	var i := count - 1
	while i >= 0:
		var p := _pos[i]
		var to := target - p
		var d2 := to.length_squared()
		if d2 <= collect_sq:
			gained += _value[i]
			collected.append(_value[i])
			_remove_at(i)
			i -= 1
			continue
		if _pull[i] > 0.0 or d2 <= pickup_sq:
			_pull[i] += magnet_accel * delta
			p += to / sqrt(d2) * _pull[i] * delta
			_pos[i] = p
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		_buffer[o + MultiMeshUtil.OFFSET_X] = p.x
		_buffer[o + MultiMeshUtil.OFFSET_Z] = p.y
		i -= 1

	var mm := multimesh
	mm.visible_instance_count = count
	if count > 0:
		mm.buffer = _buffer
	return gained


## Pulls every gem on the ground toward the player (the Vortex power-up).
func pull_all() -> void:
	for i in count:
		_pull[i] = maxf(_pull[i], 6.0)


## Removes every gem within `r` of `at` (a Gravedigger eating souls). Returns how many.
func take_near(at: Vector2, r: float) -> int:
	var n := 0
	var i := count - 1
	while i >= 0:
		if _pos[i].distance_squared_to(at) <= r * r:
			_remove_at(i)
			n += 1
		i -= 1
	if n > 0:
		multimesh.visible_instance_count = count
	return n


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_value[i] = _value[last]
		_pull[i] = _pull[last]
		MultiMeshUtil.copy_instance(_buffer, i, last)
	count = last
