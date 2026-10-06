class_name GemSwarm
extends MultiMeshInstance3D
## XP gems dropped by dead enemies. Array-simulated and MultiMesh-drawn like
## the other swarms. Gems inside the player's pickup radius get pulled in.

@export var capacity := 3000
@export var height := 0.4
@export var color := Color(0.3, 1.0, 0.6)
@export var magnet_accel := 40.0
@export var collect_radius := 0.7

var count := 0

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

	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 6
	mesh.rings = 3
	MultiMeshUtil.setup(self, mesh, capacity, color, 0.5)
	_buffer = MultiMeshUtil.make_buffer(capacity, height)


## Drops a gem worth `value` XP. If the swarm is full the XP is returned
## so the caller can award it directly instead of losing it.
func drop(at: Vector2, value: int) -> int:
	if count >= capacity:
		return value
	_pos[count] = at
	_value[count] = value
	_pull[count] = 0.0
	count += 1
	return 0


## Moves gems and returns the XP collected this frame.
func step(delta: float, target: Vector2, pickup_radius: float) -> int:
	var gained := 0
	var pickup_sq := pickup_radius * pickup_radius
	var collect_sq := collect_radius * collect_radius
	var i := count - 1
	while i >= 0:
		var p := _pos[i]
		var to := target - p
		var d2 := to.length_squared()
		if d2 <= collect_sq:
			gained += _value[i]
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


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_value[i] = _value[last]
		_pull[i] = _pull[last]
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		var q := last * MultiMeshUtil.FLOATS_PER_INSTANCE
		_buffer[o + MultiMeshUtil.OFFSET_X] = _buffer[q + MultiMeshUtil.OFFSET_X]
		_buffer[o + MultiMeshUtil.OFFSET_Z] = _buffer[q + MultiMeshUtil.OFFSET_Z]
	count = last
