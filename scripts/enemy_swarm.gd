class_name EnemySwarm
extends MultiMeshInstance3D
## A horde of one enemy type.
##
## Enemies are not nodes: they are rows in flat arrays, simulated by step() and
## drawn by a single MultiMesh. There is no physics body per enemy. Collisions
## (bullets, aura, touching the player) go through a SpatialHash instead.
## Add another enemy type by adding another EnemySwarm node with different
## exports and registering it in main.gd.
##
## Positions are on the XZ plane, stored as Vector2(x, z).

## Emitted the moment an enemy's HP hits zero. The row is removed at the start
## of the next step(), so don't hold indices across frames.
signal enemy_died(position: Vector2, xp: int)

## Every swarm joins this group, which is how main.gd finds them.
const GROUP := "enemy_swarms"

## Unique across all swarms so projectiles can remember what they already hit.
static var _next_id := 1

@export_group("Stats")
@export var max_hp := 10.0
@export var move_speed := 3.0
## Damage per second dealt to the player per enemy in contact.
@export var contact_dps := 5.0
@export var radius := 0.45
@export var xp_value := 1

@export_group("Spawning")
## Game time (seconds) when the wave director starts spawning this type.
@export var spawn_start_time := 0.0
## Seconds over which its spawn weight ramps from 0 to full after the start time.
@export var spawn_ramp_seconds := 0.0
## Relative weight against the other enemy types once fully ramped in.
@export var spawn_share := 1.0

@export_group("Loot")
## Chance that a kill drops an item.
@export_range(0.0, 1.0, 0.001) var loot_chance := 0.01
## Pushes that item's rarity roll toward better results (see ItemGenerator).
@export var loot_quality := 0.0

@export_group("Look")
## Which model to draw (see Models.enemy).
@export_enum("grunt", "brute", "runner") var model := "grunt"
@export var body_height := 1.4
## Main skin color of the model; also tints its death burst.
@export var color := Color(0.5, 0.62, 0.42)

@export_group("Horde")
@export var capacity := 4000
## How hard crowded enemies push apart. Higher spreads the horde out more.
@export var separation_strength := 0.25
## Enemies per cell (a cell is one enemy wide) beyond which an enemy stops
## advancing, so the horde queues up instead of compressing into a pile.
@export var crowd_limit := 3
## Enemies farther than this from the player are recycled to the spawn ring.
@export var recycle_distance := 40.0
@export var ring_min := 20.0
@export var ring_max := 24.0

## Longest push, in units of an enemy's own chase speed.
const _MAX_PUSH := 1.5

var count := 0
var pos := PackedVector2Array()
var hp := PackedFloat32Array()
var ids := PackedInt32Array()
## Spatial index over `pos`, rebuilt at the start of every step().
var grid: SpatialHash

var _push := PackedVector2Array()
## 1.0 = free to advance, 0.0 = boxed in by a full cell.
var _advance := PackedFloat32Array()
var _dead := PackedInt32Array()
## Hit flash per enemy, 1 on a hit and fading to 0 (drawn by enemy.gdshader).
var _flash := PackedFloat32Array()
var _buffer := PackedFloat32Array()
var _shadow: MultiMeshInstance3D
var _frame := 0


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false) # main.gd drives step() so update order is explicit
	pos.resize(capacity)
	hp.resize(capacity)
	ids.resize(capacity)
	_push.resize(capacity)
	_advance.resize(capacity)
	_flash.resize(capacity)
	grid = SpatialHash.new(radius * 2.0, 4096, capacity)

	# Look: a model per type, animated in the shader (see enemy.gdshader), plus
	# a blob shadow drawn from the same buffer.
	var quadruped := model == "runner"
	var mat := Models.material("enemy", {
		"height": body_height,
		"stride_speed": minf(move_speed / body_height * 4.2, 16.0),
		"quadruped": quadruped,
		"leg_height": 0.36 if quadruped else 0.3,
		"stride": 0.12 if quadruped else 0.16,
		"sway": 0.04 if model == "brute" else 0.08,
	}, name)
	MultiMeshUtil.setup(self, Models.enemy(model, color, body_height), capacity, mat)
	var blob := PlaneMesh.new()
	blob.size = Vector2.ONE * radius * 2.8
	_shadow = MultiMeshUtil.add_layer(self, blob, Models.material("blob_shadow"))
	_buffer = MultiMeshUtil.make_buffer(capacity, 0.0)
	# Keep the horde out of the hero's light (it would cost a lighting pass).
	layers = 2
	_shadow.layers = 2


static func random_ring_point(center: Vector2, ring_min: float, ring_max: float) -> Vector2:
	return center + Vector2.from_angle(randf() * TAU) * randf_range(ring_min, ring_max)


## The wave director's relative weight for this type at `game_time` seconds.
func spawn_weight(game_time: float) -> float:
	if game_time < spawn_start_time:
		return 0.0
	if spawn_ramp_seconds <= 0.0:
		return spawn_share
	return spawn_share * clampf((game_time - spawn_start_time) / spawn_ramp_seconds, 0.0, 1.0)


func alive_count() -> int:
	return count - _dead.size()


## Adds an enemy. Returns false when the swarm is full.
func spawn(at: Vector2, hp_mult := 1.0) -> bool:
	if count >= capacity:
		return false
	pos[count] = at
	hp[count] = max_hp * hp_mult
	ids[count] = _next_id
	_next_id += 1
	_push[count] = Vector2.ZERO
	_advance[count] = 1.0
	_flash[count] = 0.0
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM] = 0.0
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 1] = randf() # walk cycle phase
	count += 1
	return true


## Advances the horde one frame and uploads it to the GPU.
func step(delta: float, target: Vector2) -> void:
	_flush_dead()
	grid.rebuild(pos, count)
	_frame += 1

	# Crowd spreading is the expensive part, so each enemy only recomputes its
	# push every `stride` frames and reuses it in between. The stride grows with
	# the horde, which keeps the lookups per frame roughly constant.
	var stride := clampi(ceili(count / 3000.0), 1, 4)
	for i in range(_frame % stride, count, stride):
		var jitter := Vector2.from_angle(float(i) * 2.399963 + float(_frame) * 0.7) * 0.35
		var push := grid.repulsion(pos[i], jitter) * separation_strength
		if push.length_squared() > _MAX_PUSH * _MAX_PUSH:
			push = push.normalized() * _MAX_PUSH
		_push[i] = push
		_advance[i] = clampf(1.0 - float(grid.last_own_count - 1) / crowd_limit, 0.0, 1.0)

	var step_len := move_speed * delta
	var recycle_sq := recycle_distance * recycle_distance
	# Stop just inside touching range so the horde rings the player instead of
	# piling onto one point.
	var stop_sq := (radius + 0.35) * (radius + 0.35)
	var buf := _buffer
	var fade := delta * 7.0
	for i in count:
		var p := pos[i]
		var to := target - p
		var d2 := to.length_squared()
		if d2 > recycle_sq:
			p = random_ring_point(target, ring_min, ring_max)
			to = target - p
			d2 = to.length_squared()
		var chase := Vector2.ZERO
		if d2 > stop_sq:
			chase = to / sqrt(d2)
		p += (chase * _advance[i] + _push[i]) * step_len
		pos[i] = p
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		buf[o + MultiMeshUtil.OFFSET_X] = p.x
		buf[o + MultiMeshUtil.OFFSET_Z] = p.y
		# Facing turns slowly, so each enemy refreshes it every 4th frame
		# (inlined MultiMeshUtil.set_facing: this loop is the hot path).
		if (i + _frame) & 3 == 0 and chase != Vector2.ZERO:
			buf[o] = -chase.y
			buf[o + 2] = -chase.x
			buf[o + 8] = chase.x
			buf[o + 10] = -chase.y
		var f := _flash[i]
		if f > 0.0:
			f = maxf(f - fade, 0.0)
			_flash[i] = f
			buf[o + MultiMeshUtil.OFFSET_CUSTOM] = f

	var mm := multimesh
	mm.visible_instance_count = count
	_shadow.multimesh.visible_instance_count = count
	if count > 0:
		mm.buffer = buf
		_shadow.multimesh.buffer = buf


## Applies damage to enemy `i`. Safe to call while iterating query results.
func damage(i: int, amount: float) -> void:
	if hp[i] <= 0.0:
		return
	hp[i] -= amount
	_flash[i] = 1.0
	if hp[i] <= 0.0:
		_dead.append(i)
		enemy_died.emit(pos[i], xp_value)


## Damages every enemy within `r` of `center`.
func damage_in_radius(center: Vector2, r: float, amount: float) -> void:
	var n := grid.query(center, r + radius)
	var res := grid.results
	for k in n:
		damage(res[k], amount)


## Total contact DPS from enemies touching a circle (capped so a huge pile
## doesn't delete the player instantly).
func contact_load(center: Vector2, r: float) -> float:
	var n := grid.query(center, r + radius)
	var res := grid.results
	var touching := 0
	for k in n:
		if hp[res[k]] > 0.0:
			touching += 1
	return minf(touching, 8.0) * contact_dps


## Index of the closest living enemy within `max_dist`, or -1.
func nearest(from: Vector2, max_dist: float) -> int:
	var best := -1
	var best_d2 := max_dist * max_dist
	for i in count:
		if hp[i] <= 0.0:
			continue
		var d2 := from.distance_squared_to(pos[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


func _flush_dead() -> void:
	if _dead.is_empty():
		return
	# Remove highest index first. Each swap-remove then pulls in the current
	# last row, which is never a pending-dead one (those all have lower indices).
	_dead.sort()
	for k in range(_dead.size() - 1, -1, -1):
		var i := _dead[k]
		var last := count - 1
		if i != last:
			pos[i] = pos[last]
			hp[i] = hp[last]
			ids[i] = ids[last]
			_push[i] = _push[last]
			_advance[i] = _advance[last]
			_flash[i] = _flash[last]
			MultiMeshUtil.copy_instance(_buffer, i, last)
		count = last
	_dead.clear()
