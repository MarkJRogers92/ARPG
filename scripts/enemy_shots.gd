class_name EnemyShots
extends MultiMeshInstance3D
## Projectiles fired by ranged enemies (and anything else hostile), simulated
## as flat arrays like the hero's bolts. They only test against the hero, so
## they're cheap; dashing passes through them unharmed.

signal hit_player(at: Vector2)

@export var capacity := 600
@export var height := 1.2
@export var color := Color(1.0, 0.3, 0.55)
@export var hit_radius := 0.55
@export var lifetime := 3.5

var count := 0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _buffer := PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_damage.resize(capacity)
	var mesh := Models.enemy_orb()
	MultiMeshUtil.setup(self, mesh, capacity, mesh.surface_get_material(0))
	_buffer = MultiMeshUtil.make_buffer(capacity, height)


func spawn(at: Vector2, dir: Vector2, speed: float, damage: float) -> void:
	if count >= capacity:
		return
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	MultiMeshUtil.set_facing(_buffer, o, dir)
	var tint := color.srgb_to_linear()
	for c in 4:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + c] = tint[c]
	_buffer[o + MultiMeshUtil.OFFSET_X] = at.x
	_buffer[o + MultiMeshUtil.OFFSET_Z] = at.y
	_pos[count] = at
	_vel[count] = dir * speed
	_life[count] = lifetime
	_damage[count] = damage
	count += 1


## Moves the shots and damages `player` with any that reach it.
func step(delta: float, player: Player) -> void:
	var target := player.pos2
	var hit_sq := hit_radius * hit_radius + Player.RADIUS * Player.RADIUS
	var i := count - 1
	while i >= 0:
		var p := _pos[i] + _vel[i] * delta
		_pos[i] = p
		_life[i] -= delta
		if p.distance_squared_to(target) < hit_sq and not player.is_dashing():
			player.take_damage(_damage[i])
			hit_player.emit(p)
			_remove_at(i)
		elif _life[i] <= 0.0:
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


func clear() -> void:
	count = 0
	multimesh.visible_instance_count = 0


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_damage[i] = _damage[last]
		MultiMeshUtil.copy_instance(_buffer, i, last)
	count = last
