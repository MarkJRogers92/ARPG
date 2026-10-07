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
## Emitted alongside enemy_died when the one that died was an elite.
signal elite_died(position: Vector2)
## A charger's charge ran into the hero (see `charger`).
signal charged_hero(damage: float)
## A raiser calls up the dead around `position` (see `raise_interval`).
signal raise_called(position: Vector2)

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
## 1 = shoved around fully by knockback, 0 = immovable.
@export_range(0.0, 1.0) var knockback_taken := 1.0
## Bosses get a health bar, their own spawn schedule (BossDirector) and big
## rewards instead of a spot in the wave director's mix.
@export var boss := false

@export_group("Ranged")
## 0 = melee. Otherwise the enemy stops at this distance and shoots.
@export var attack_range := 0.0
## Seconds between shots, per enemy (with some randomness).
@export var fire_interval := 3.0
@export var shot_speed := 7.0
@export var shot_damage := 10.0
## The shots' element (see Elements): frost chills the hero, fire burns.
@export var shot_element := 0
## Where shots go. main.gd sets it.
var shots: EnemyShots

@export_group("Specialists")
## Lancers: stop, show a line on the ground along their path, then charge
## straight down it, then recover. Sidestep the line, punish the recovery.
@export var charger := false
@export var charge_range := 9.0
@export var charge_windup := 0.8
@export var charge_speed := 15.0
@export var charge_time := 0.55
@export var charge_recover := 1.1
@export var charge_damage := 14.0
## Gravediggers: every `raise_interval` seconds (0 = never) call up the dead.
@export var raise_interval := 0.0
## Hang back this far from the hero (0 = close in).
@export var hold_range := 0.0

@export_group("Elites")
## Elites are rare, bigger, glowing versions with more HP, more XP and a
## guaranteed item. The wave director decides how often they appear.
@export var elite_hp_mult := 7.0
@export var elite_xp_mult := 8
@export var elite_scale := 1.45
@export var elite_tint := Color(1.12, 1.04, 0.88)

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
@export_enum("grunt", "brute", "runner", "cultist", "boss", "wraith", "imp", "lich", "colossus", "tyrant", "goblin", "lancer", "gravedigger") var model := "grunt"
## Runs away from the hero instead of chasing (treasure goblins).
@export var flee := false
## What the game calls one of these (the realm sets it; see Realm).
@export var display_name := ""
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
var _elite := PackedByteArray()
## Elemental statuses (seconds left) and burn damage per second; see Elements.
var chill := PackedFloat32Array()
var shock := PackedFloat32Array()
var burn := PackedFloat32Array()
var burn_dps := PackedFloat32Array()
## 1 while an enemy has (or just lost) a status, so step() only does status
## work for those.
var _afflicted := PackedByteArray()
var _scale := PackedFloat32Array()
var _fire := PackedFloat32Array()
var _buffer := PackedFloat32Array()
var _shadow: MultiMeshInstance3D
var _frame := 0
## Chargers: state (0 stalk, 1 wind up, 2 charge, 3 recover), its timer, the
## locked direction, and whether this charge already hit the hero.
var _cstate := PackedByteArray()
var _ctime := PackedFloat32Array()
var _cdir := PackedVector2Array()
var _chit := PackedByteArray()
## At most this many chargers wind up at once (each shows a ground line).
const MAX_WINDUPS := 6
var _telegraph: MultiMeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false) # main.gd drives step() so update order is explicit
	pos.resize(capacity)
	hp.resize(capacity)
	ids.resize(capacity)
	_push.resize(capacity)
	_advance.resize(capacity)
	_flash.resize(capacity)
	_elite.resize(capacity)
	chill.resize(capacity)
	shock.resize(capacity)
	burn.resize(capacity)
	burn_dps.resize(capacity)
	_afflicted.resize(capacity)
	_scale.resize(capacity)
	_fire.resize(capacity)
	if charger:
		_cstate.resize(capacity)
		_ctime.resize(capacity)
		_cdir.resize(capacity)
		_chit.resize(capacity)
		_make_telegraph()
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
		"sway": 0.04 if model in ["brute", "boss"] else 0.08,
	}, name)
	MultiMeshUtil.setup(self, Models.enemy(model, color, body_height), capacity, mat)
	var blob := PlaneMesh.new()
	blob.size = Vector2.ONE * radius * (2.8 if not boss else 2.2)
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


func is_elite(i: int) -> bool:
	return _elite[i] == 1


## Adds an enemy (an elite if `elite`). Returns false when the swarm is full.
func spawn(at: Vector2, hp_mult := 1.0, elite := false) -> bool:
	if count >= capacity:
		return false
	pos[count] = at
	hp[count] = max_hp * hp_mult * (elite_hp_mult if elite else 1.0)
	_elite[count] = 1 if elite else 0
	_scale[count] = elite_scale if elite else 1.0
	_fire[count] = randf_range(0.5, 1.0) * (raise_interval if raise_interval > 0.0 else fire_interval)
	if charger:
		_cstate[count] = 0
		_ctime[count] = randf_range(0.5, 1.5)
		_chit[count] = 0
	chill[count] = 0.0
	shock[count] = 0.0
	burn[count] = 0.0
	burn_dps[count] = 0.0
	_afflicted[count] = 0
	ids[count] = _next_id
	_next_id += 1
	_push[count] = Vector2.ZERO
	_advance[count] = 1.0
	_flash[count] = 0.0
	var o := count * MultiMeshUtil.FLOATS_PER_INSTANCE
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM] = 0.0
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 1] = randf() # walk cycle phase
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 2] = 1.0 if elite else 0.0 # glow
	var sc := _scale[count]
	_buffer[o] = sc
	_buffer[o + 2] = 0.0
	_buffer[o + 5] = sc
	_buffer[o + 8] = 0.0
	_buffer[o + 10] = sc
	var tint := elite_tint if elite else Color.WHITE
	for c in 3:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + c] = tint[c]
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
	# piling onto one point. Ranged enemies stop at their attack range.
	var stop := maxf(maxf(radius + 0.35, attack_range), hold_range)
	var stop_sq := stop * stop
	var ranged := attack_range > 0.0 and shots != null
	var fire_sq := (attack_range + 2.0) * (attack_range + 2.0)
	var buf := _buffer
	var fade := delta * 9.0
	# Solid scenery (Obstacles): a flag grid read inline, circles only when flagged.
	var ob_w := Obstacles.width
	var ob_flags := Obstacles.flags
	var ob_origin := Obstacles.origin
	var ob_cells := Obstacles.cells
	var ob_centers := Obstacles.centers
	var ob_radii := Obstacles.radii
	# Huge hordes check every other frame per enemy (a step is a few cm).
	var ob_stride := 1 if count < 3000 else 2
	var windups := 0
	if charger:
		for i in count:
			if _cstate[i] == 1:
				windups += 1
	for i in count:
		var p := pos[i]
		var to := target - p
		var d2 := to.length_squared()
		if d2 > recycle_sq:
			p = random_ring_point(target, ring_min, ring_max)
			to = target - p
			d2 = to.length_squared()
		var chase := Vector2.ZERO
		if flee:
			# Run from the hero, weaving a little.
			chase = (-to / sqrt(maxf(d2, 0.0001))).rotated(sin(float(_frame) * 0.03 + i) * 0.6)
		elif d2 > stop_sq:
			chase = to / sqrt(d2)
		# Chilled enemies move at half speed (bosses at three quarters).
		var sl := step_len if chill[i] <= 0.0 else step_len * (0.75 if boss else 0.5)
		var push := _push[i]
		if charger:
			var st := _cstate[i]
			_ctime[i] -= delta
			if st == 0:
				if _ctime[i] <= 0.0 and d2 < charge_range * charge_range and d2 > 4.0 and windups < MAX_WINDUPS:
					_cstate[i] = 1
					_ctime[i] = charge_windup
					_cdir[i] = to / sqrt(d2)
					_chit[i] = 0
					windups += 1
			elif st == 1:
				chase = Vector2.ZERO
				push = Vector2.ZERO
				_flash[i] = maxf(_flash[i], 0.35 + 0.35 * sin(_ctime[i] * 30.0))
				if _ctime[i] <= 0.0:
					_cstate[i] = 2
					_ctime[i] = charge_time
					windups -= 1
			elif st == 2:
				chase = _cdir[i]
				push = Vector2.ZERO
				sl = charge_speed * delta * (1.0 if chill[i] <= 0.0 else 0.5)
				if _chit[i] == 0 and d2 < (radius + 0.6) * (radius + 0.6):
					_chit[i] = 1
					charged_hero.emit(charge_damage)
				if _ctime[i] <= 0.0:
					_cstate[i] = 3
					_ctime[i] = charge_recover
			else:
				chase = Vector2.ZERO
				if _ctime[i] <= 0.0:
					_cstate[i] = 0
					_ctime[i] = randf_range(0.8, 2.0)
		if raise_interval > 0.0:
			_fire[i] -= delta
			if _fire[i] <= 0.0:
				_fire[i] = raise_interval * randf_range(0.8, 1.2)
				if d2 < 22.0 * 22.0:
					raise_called.emit(p)
		var move := (chase * _advance[i] + push) * sl
		p += move
		if ob_w > 0 and (boss or ob_stride == 1 or (i + _frame) & 1 == 0):
			var gx := floori(p.x - ob_origin.x) # Obstacles.CELL is 1 m
			var gy := floori(p.y - ob_origin.y)
			if boss:
				p = Obstacles.resolve_slide(p, radius * _scale[i], move)
			elif gx >= 0 and gy >= 0 and gx < ob_w and gy < ob_w and ob_flags[gy * ob_w + gx] == 1:
				# Only a real overlap pays for the full resolve.
				var body := radius * _scale[i]
				for j: int in ob_cells[gy * ob_w + gx]:
					var reach := ob_radii[j] + body
					if p.distance_squared_to(ob_centers[j]) < reach * reach:
						p = Obstacles.resolve_slide(p, body, move)
						if charger and _cstate[i] == 2:
							# Slammed into a wall: stunned for a moment.
							_cstate[i] = 3
							_ctime[i] = charge_recover * 1.5
						break
		pos[i] = p
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		buf[o + MultiMeshUtil.OFFSET_X] = p.x
		buf[o + MultiMeshUtil.OFFSET_Z] = p.y
		# Facing turns slowly, so each enemy refreshes it every 4th frame
		# (inlined MultiMeshUtil.set_facing: this loop is the hot path).
		if (i + _frame) & 3 == 0:
			var face := chase
			if charger and _cstate[i] == 1:
				face = _cdir[i]
			if face == Vector2.ZERO and ranged and d2 > 0.0:
				face = to / sqrt(d2) # ranged: keep facing the hero while shooting
			if face != Vector2.ZERO:
				var sc := _scale[i]
				buf[o] = -face.y * sc
				buf[o + 2] = -face.x * sc
				buf[o + 8] = face.x * sc
				buf[o + 10] = -face.y * sc
		if ranged:
			_fire[i] -= delta
			if _fire[i] <= 0.0:
				_fire[i] = fire_interval * randf_range(0.8, 1.2)
				if d2 < fire_sq:
					var dir := (target - p).normalized()
					shots.spawn(p + dir * radius, dir, shot_speed, shot_damage, shot_element)
		if _afflicted[i] == 1:
			_update_status(i, o, delta)
		var f := _flash[i]
		if f > 0.0:
			f = maxf(f - fade, 0.0)
			_flash[i] = f
			buf[o + MultiMeshUtil.OFFSET_CUSTOM] = f

	if charger:
		_draw_telegraphs()
	var mm := multimesh
	mm.visible_instance_count = count
	_shadow.multimesh.visible_instance_count = count
	if count > 0:
		mm.buffer = buf
		_shadow.multimesh.buffer = buf


## Applies damage to enemy `i`. Safe to call while iterating query results.
## Weapons should go through Elements.hit(), which adds statuses, reactions and
## damage numbers on top of this. Returns true if this killed the enemy.
func damage(i: int, amount: float) -> bool:
	if hp[i] <= 0.0:
		return false
	hp[i] -= amount
	_flash[i] = 1.0
	if hp[i] <= 0.0:
		_die(i)
		return true
	return false


## Removes every enemy without a death (no XP, no loot): an escaped goblin.
func despawn_all() -> void:
	for i in count:
		if hp[i] > 0.0:
			hp[i] = 0.0
			_dead.append(i)


## The ground lines for chargers winding up: one flat strip per charger along
## its charge, its own small MultiMesh (the swarm's buffer is per enemy).
func _make_telegraph() -> void:
	var strip := PlaneMesh.new()
	strip.size = Vector2(1.0, 1.0)
	strip.center_offset = Vector3(0, 0, -0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.25, 0.12, 0.42)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	strip.material = mat
	_telegraph = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = strip
	mm.instance_count = MAX_WINDUPS
	mm.visible_instance_count = 0
	_telegraph.multimesh = mm
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.top_level = true
	add_child(_telegraph)


func _draw_telegraphs() -> void:
	var mm := _telegraph.multimesh
	var n := 0
	var length := charge_speed * charge_time + 1.0
	for i in count:
		if _cstate[i] != 1 or n >= MAX_WINDUPS:
			continue
		var d := _cdir[i]
		# The strip grows as the wind-up runs out, so the timing reads too.
		var grow := 1.0 - clampf(_ctime[i] / charge_windup, 0.0, 1.0)
		var basis := Basis(Vector3(-d.y, 0, d.x) * radius * 2.2, Vector3.UP, Vector3(-d.x, 0, -d.y) * length * (0.35 + 0.65 * grow))
		mm.set_instance_transform(n, Transform3D(basis, Vector3(pos[i].x, 0.04, pos[i].y)))
		n += 1
	mm.visible_instance_count = n


func mark_afflicted(i: int) -> void:
	_afflicted[i] = 1


func _die(i: int) -> void:
	_dead.append(i)
	var elite := _elite[i] == 1
	enemy_died.emit(pos[i], xp_value * (elite_xp_mult if elite else 1))
	if elite:
		elite_died.emit(pos[i])
	if burn[i] > 0.0:
		Elements.queue_spread(pos[i], burn_dps[i])


## Ticks enemy `i`'s statuses (burn damage too) and tints it to show them:
## icy blue when chilled, flickering violet when shocked, glowing embers
## (custom w, see enemy.gdshader) when burning.
func _update_status(i: int, o: int, delta: float) -> void:
	var c := maxf(chill[i] - delta, 0.0)
	var s := maxf(shock[i] - delta, 0.0)
	var b := maxf(burn[i] - delta, 0.0)
	chill[i] = c
	shock[i] = s
	burn[i] = b
	if b > 0.0 and hp[i] > 0.0:
		hp[i] -= burn_dps[i] * delta
		if hp[i] <= 0.0:
			_die(i)
	var tint := elite_tint if _elite[i] == 1 else Color.WHITE
	if c > 0.0:
		tint = tint.lerp(Color(0.5, 0.78, 1.15), 0.6)
	if s > 0.0:
		tint = tint.lerp(Color(1.3, 0.9, 1.7), 0.35 + 0.25 * sin(float(_frame) * 0.9 + i))
	for k in 3:
		_buffer[o + MultiMeshUtil.OFFSET_COLOR + k] = tint[k]
	_buffer[o + MultiMeshUtil.OFFSET_CUSTOM + 3] = 1.0 if b > 0.0 else 0.0
	if c <= 0.0 and s <= 0.0 and b <= 0.0:
		_afflicted[i] = 0


## Shoves every enemy within `r` of `center` straight away from it, up to
## `strength` units (less toward the edge, scaled by knockback_taken).
func knockback(center: Vector2, r: float, strength: float) -> void:
	if knockback_taken <= 0.0:
		return
	var n := grid.query(center, r)
	var res := grid.results
	for k in n:
		var i := res[k]
		var away := pos[i] - center
		var d := away.length()
		if d < 0.001:
			away = Vector2.from_angle(randf() * TAU)
			d = 1.0
		var falloff := 1.0 - 0.5 * clampf(d / r, 0.0, 1.0)
		pos[i] += away / d * strength * falloff * knockback_taken / _scale[i]


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
			_elite[i] = _elite[last]
			_scale[i] = _scale[last]
			_fire[i] = _fire[last]
			if charger:
				_cstate[i] = _cstate[last]
				_ctime[i] = _ctime[last]
				_cdir[i] = _cdir[last]
				_chit[i] = _chit[last]
			chill[i] = chill[last]
			shock[i] = shock[last]
			burn[i] = burn[last]
			burn_dps[i] = burn_dps[last]
			_afflicted[i] = _afflicted[last]
			MultiMeshUtil.copy_instance(_buffer, i, last)
		count = last
	_dead.clear()
