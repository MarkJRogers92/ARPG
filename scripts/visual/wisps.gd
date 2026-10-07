class_name Wisps
extends MultiMeshInstance3D
## Soul trails: when enemies die, pale wisps rise from them and stream into
## the hero, each leaving a short fading trail, so a big fight fills the
## screen with ribbons of light. When the hero dies, their souls scatter
## upward instead (scatter()). Pure decoration, drawn like FxSwarm (one
## MultiMesh, particle.gdshader).
##
## Each slot is either a head (homing on the hero, or drifting when scattered)
## or a trail dot left behind by a head, fading where it was dropped.

@export var capacity := 2400
## Heads alive at once; kills past this make no new wisps.
@export var max_heads := 260
## Chance that a kill sends a wisp (lowered by settings or tests).
@export var chance := 0.6
const COLOR := Color(0.62, 0.9, 1.0)
const TRAIL_EVERY := 0.035
const TRAIL_LIFE := 0.32
const ARRIVE := 0.7

var count := 0
var heads := 0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _kind := PackedByteArray() # 0 trail, 1 homing head, 2 scattering head
var _age := PackedFloat32Array()
var _trail := PackedFloat32Array()
var _buffer := PackedFloat32Array()
var _color := Color()


func _ready() -> void:
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_max_life.resize(capacity)
	_size.resize(capacity)
	_kind.resize(capacity)
	_age.resize(capacity)
	_trail.resize(capacity)
	var quad := QuadMesh.new()
	MultiMeshUtil.setup(self, quad, capacity, Models.material("particle"))
	_buffer = MultiMeshUtil.make_buffer(capacity, 0.0)
	_color = COLOR.srgb_to_linear()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A kill at `at`: maybe a wisp rises from it toward the hero.
func from_kill(at: Vector2) -> void:
	if heads >= max_heads or randf() >= chance:
		return
	var up := Vector3(randf_range(-1.5, 1.5), randf_range(3.0, 5.0), randf_range(-1.5, 1.5))
	_add(Vector3(at.x, 0.6, at.y), up, 1, 4.0, 0.3)


## The hero has fallen: `n` souls burst from them and drift up into the dark.
func scatter(at: Vector2, n: int) -> void:
	for k in n:
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(2.0, 7.0)
		_add(Vector3(at.x, 1.0, at.y), Vector3(dir.x, randf_range(3.0, 8.0), dir.y), 2, randf_range(1.6, 2.6), randf_range(0.3, 0.5))


func _add(p: Vector3, v: Vector3, kind: int, life: float, size: float) -> void:
	if count >= capacity:
		return
	_pos[count] = p
	_vel[count] = v
	_life[count] = life
	_max_life[count] = life
	_size[count] = size
	_kind[count] = kind
	_age[count] = 0.0
	_trail[count] = randf() * TRAIL_EVERY
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	for ch in 4:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + ch] = _color[ch]
	_buffer[o + MultiMeshUtil.OFFSET_X] = p.x
	_buffer[o + MultiMeshUtil.OFFSET_Y] = p.y
	_buffer[o + MultiMeshUtil.OFFSET_Z] = p.z
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM] = 1.0
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 1] = size
	if kind > 0:
		heads += 1
	count += 1


## `target`: where the hero is (wisps fly to about chest height).
func step(delta: float, target: Vector2) -> void:
	var goal := Vector3(target.x, 1.1, target.y)
	var i := count - 1
	while i >= 0:
		var kind := _kind[i]
		var l := _life[i] - delta
		var p := _pos[i]
		if kind == 1:
			# Rise, then home in harder and harder.
			var a := _age[i] + delta
			_age[i] = a
			var to := goal - p
			var d := to.length()
			if d < ARRIVE or l <= 0.0:
				_remove_at(i)
				i -= 1
				continue
			var pull := minf(a * 3.0, 1.0) * 26.0
			var v := _vel[i] * exp(-2.2 * delta) + to / d * pull * delta
			_vel[i] = v
			p += v * delta
		elif kind == 2:
			if l <= 0.0:
				_remove_at(i)
				i -= 1
				continue
			var v := _vel[i] * exp(-1.2 * delta)
			v.y += 1.5 * delta # souls float up
			_vel[i] = v
			p += v * delta
		else:
			if l <= 0.0:
				_remove_at(i)
				i -= 1
				continue
		_life[i] = l
		_pos[i] = p
		if kind > 0:
			_trail[i] -= delta
			if _trail[i] <= 0.0:
				_trail[i] = TRAIL_EVERY
				_add(p, Vector3.ZERO, 0, TRAIL_LIFE, _size[i] * 0.7)
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		_buffer[o + MultiMeshUtil.OFFSET_X] = p.x
		_buffer[o + MultiMeshUtil.OFFSET_Y] = p.y
		_buffer[o + MultiMeshUtil.OFFSET_Z] = p.z
		_buffer[o + MultiMeshUtil.OFFSET_CUSTOM] = 1.0 if kind == 1 else l / _max_life[i]
		_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 1] = _size[i]
		i -= 1
	multimesh.visible_instance_count = count
	if count > 0:
		multimesh.buffer = _buffer


func clear() -> void:
	count = 0
	heads = 0
	multimesh.visible_instance_count = 0


func _remove_at(i: int) -> void:
	if _kind[i] > 0:
		heads -= 1
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_max_life[i] = _max_life[last]
		_size[i] = _size[last]
		_kind[i] = _kind[last]
		_age[i] = _age[last]
		_trail[i] = _trail[last]
		MultiMeshUtil.copy_instance(_buffer, i, last)
	count = last
