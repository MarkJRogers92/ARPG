class_name FxSwarm
extends MultiMeshInstance3D
## Short-lived glowing particles for hits, deaths and level-ups. Simulated as
## flat arrays and drawn by one MultiMesh like the other swarms, so a big kill
## streak costs a few array writes, not nodes. When full, new bursts are
## dropped (they're decoration).
##
## Instance data for particle.gdshader: custom x = life left (1 -> 0),
## custom y = size, color = the particle color.

@export var capacity := 3000
@export var gravity := 9.0

var count := 0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _buffer := PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_max_life.resize(capacity)
	_size.resize(capacity)
	var quad := QuadMesh.new()
	MultiMeshUtil.setup(self, quad, capacity, Models.material("particle"))
	_buffer = MultiMeshUtil.make_buffer(capacity, 0.0)


## `n` particles flying out from `at` (height `y`), in `color`.
func burst(at: Vector2, y: float, color: Color, n: int, speed := 4.0, size := 0.35, life := 0.5, upward := 3.0) -> void:
	var c := color.srgb_to_linear()
	for k in n:
		if count >= capacity:
			return
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * speed
		_pos[count] = Vector3(at.x, y, at.y)
		_vel[count] = Vector3(dir.x, randf_range(0.5, 1.0) * upward, dir.y)
		var l := life * randf_range(0.6, 1.0)
		_life[count] = l
		_max_life[count] = l
		_size[count] = size * randf_range(0.6, 1.2)
		var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
		for ch in 4:
			_buffer[o + MultiMeshUtil.OFFSET_COLOR + ch] = c[ch]
		count += 1


## A ring of particles expanding flat along the ground (level-ups, novas).
func ring(at: Vector2, color: Color, n: int, speed := 8.0, size := 0.5, life := 0.6) -> void:
	var c := color.srgb_to_linear()
	for k in n:
		if count >= capacity:
			return
		var dir := Vector2.from_angle(TAU * k / n)
		_pos[count] = Vector3(at.x, 0.3, at.y)
		_vel[count] = Vector3(dir.x * speed, gravity * life * 0.5, dir.y * speed)
		_life[count] = life
		_max_life[count] = life
		_size[count] = size
		var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
		for ch in 4:
			_buffer[o + MultiMeshUtil.OFFSET_COLOR + ch] = c[ch]
		count += 1


func step(delta: float) -> void:
	var drag := exp(-3.0 * delta)
	var i := count - 1
	while i >= 0:
		var l := _life[i] - delta
		if l <= 0.0:
			_remove_at(i)
			i -= 1
			continue
		_life[i] = l
		var v := _vel[i]
		v.x *= drag
		v.z *= drag
		v.y -= gravity * delta
		_vel[i] = v
		var p := _pos[i] + v * delta
		if p.y < 0.05:
			p.y = 0.05
		_pos[i] = p
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		_buffer[o + MultiMeshUtil.OFFSET_X] = p.x
		_buffer[o + MultiMeshUtil.OFFSET_Y] = p.y
		_buffer[o + MultiMeshUtil.OFFSET_Z] = p.z
		_buffer[o + MultiMeshUtil.OFFSET_CUSTOM] = l / _max_life[i]
		_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 1] = _size[i]
		i -= 1

	var mm := multimesh
	mm.visible_instance_count = count
	if count > 0:
		mm.buffer = _buffer


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_max_life[i] = _max_life[last]
		_size[i] = _size[last]
		MultiMeshUtil.copy_instance(_buffer, i, last)
	count = last
