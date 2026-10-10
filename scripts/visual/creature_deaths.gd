class_name CreatureDeaths
extends MultiMeshInstance3D
## Bounded cosmetic aftermath, no physics, XP, targeting, or per-enemy nodes.
const LIMIT := 24
const DURATION := 0.55
var _buffer := PackedFloat32Array()
var _ages := PackedFloat32Array()
var _count := 0

func setup(mesh: Mesh, mat: Material) -> void:
	MultiMeshUtil.setup(self,mesh,LIMIT,mat)
	_buffer = MultiMeshUtil.make_buffer(LIMIT,0.0)
	_ages.resize(LIMIT)
	layers = 2
	extra_cull_margin = 3.0
	set_process(false)

func capture(source: PackedFloat32Array, row: int, at: Vector2) -> void:
	# At capacity replace the oldest, rather than accumulating death actors.
	var slot := _count if _count < LIMIT else 0
	if _count >= LIMIT:
		for i in LIMIT:
			if _ages[i] > _ages[slot]: slot = i
	else: _count += 1
	var dest := slot * MultiMeshUtil.FLOATS_PER_INSTANCE
	var src := row * MultiMeshUtil.FLOATS_PER_INSTANCE
	for k in MultiMeshUtil.FLOATS_PER_INSTANCE: _buffer[dest+k] = source[src+k]
	_buffer[dest+MultiMeshUtil.OFFSET_X] = at.x
	_buffer[dest+MultiMeshUtil.OFFSET_Z] = at.y
	_buffer[dest+MultiMeshUtil.OFFSET_COLOR+3] = 8.0
	_buffer[dest+MultiMeshUtil.OFFSET_CUSTOM] = 0.0
	_ages[slot] = 0.0
	multimesh.visible_instance_count = _count
	multimesh.buffer = _buffer
	set_process(true)

func _process(delta: float) -> void:
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] >= DURATION:
			_count -= 1
			if i != _count:
				_ages[i] = _ages[_count]
				MultiMeshUtil.copy_instance(_buffer,i,_count)
			continue
		_buffer[i*MultiMeshUtil.FLOATS_PER_INSTANCE+MultiMeshUtil.OFFSET_COLOR+3] = 8.0+_ages[i]/DURATION
		i += 1
	multimesh.visible_instance_count = _count
	if _count > 0: multimesh.buffer = _buffer
	else: set_process(false)

func clear() -> void:
	_count = 0
	multimesh.visible_instance_count = 0
	set_process(false)
