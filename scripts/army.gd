class_name Army
extends Node3D
## The Soul Army: spectral copies of slain enemies that fight for the hero.
##
## Kills sometimes leave a soul (a pale crystal on the ground, in the Souls
## GemSwarm). Each soul remembers what kind of enemy it came from. Once the
## hero has gathered `soul_cost` of them and the army has room
## (`minion_max`), the kind most of those souls came from rises as a minion.
## An elite's soul raises an elite champion straight away, and a boss's soul
## binds the boss itself; when the army is full, the newest common minion
## makes way for them.
##
## Minions are few (a dozen or two), so they're simple arrays and per-type
## MultiMeshes rebuilt every frame. They hunt the enemy nearest to them (within
## reach of the hero), cleave what's around their target, take contact damage
## from the horde, and drift back to the hero when there's nothing to fight.

signal raised(kind: String)

const CAPACITY := 40
const SIGHT := 11.0 # how far a minion looks for prey
const LEASH := 15.0 # targets must be this close to the hero
const ATTACK_INTERVAL := 0.4
const RETARGET := 0.35

## How the hero's stats scale for each enemy type: tougher types make tougher
## minions. Built in setup() from each EnemySwarm's own stats.
var _types: Array[Dictionary] = []
var _type_of := {} # EnemySwarm -> index in _types

## Souls gathered toward the next minion, and which kinds they came from.
var souls := 0
var _votes := {}

var count := 0
var _type := PackedInt32Array()
var _pos := PackedVector2Array()
var _hp := PackedFloat32Array()
var _max_hp := PackedFloat32Array()
var _elite := PackedByteArray()
var _attack := PackedFloat32Array()
var _retarget := PackedFloat32Array()
var _hurt := PackedFloat32Array()
var _facing := PackedVector2Array()
var _phase := PackedFloat32Array()
## Current target per minion: swarm index and enemy id (-1 = none).
var _target_swarm := PackedInt32Array()
var _target_id := PackedInt32Array()
var _target_index := PackedInt32Array()

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _soulfire: Array[Vector2] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms
	_type.resize(CAPACITY)
	_target_swarm.resize(CAPACITY)
	_target_id.resize(CAPACITY)
	_target_index.resize(CAPACITY)
	_hp.resize(CAPACITY)
	_max_hp.resize(CAPACITY)
	_attack.resize(CAPACITY)
	_retarget.resize(CAPACITY)
	_hurt.resize(CAPACITY)
	_phase.resize(CAPACITY)
	_pos.resize(CAPACITY)
	_facing.resize(CAPACITY)
	_elite.resize(CAPACITY)
	for s in swarms:
		var t := {
			"swarm": s, "name": String(s.name),
			"hp": 10.0 if s.boss else clampf(s.max_hp / 10.0, 1.0, 4.0),
			"damage": 5.0 if s.boss else clampf(s.contact_dps / 5.0, 0.6, 2.5),
			"speed": maxf(s.move_speed * 1.3, 4.5),
			"radius": s.radius,
		}
		var mmi := MultiMeshInstance3D.new()
		var mat := Models.material("enemy", {
			"height": s.body_height, "spectral": true,
			"stride_speed": minf(t["speed"] / s.body_height * 4.2, 16.0),
			"quadruped": s.model == "runner", "leg_height": 0.36 if s.model == "runner" else 0.3,
		}, "spectral_" + t["name"])
		MultiMeshUtil.setup(mmi, Models.enemy(s.model, s.color, s.body_height), 8 if s.boss else CAPACITY, mat)
		mmi.layers = 2
		add_child(mmi)
		t["mmi"] = mmi
		_type_of[s] = _types.size()
		_types.append(t)


func type_index(swarm: EnemySwarm) -> int:
	return _type_of.get(swarm, 0)


## Souls are encoded as gem values: type + 1, +100 for an elite, +200 for a boss.
static func soul_value(type: int, elite: bool, boss: bool) -> int:
	return type + 1 + (200 if boss else (100 if elite else 0))


func collect_soul(value: int) -> void:
	var type := (value % 100) - 1
	if value >= 200:
		_raise(type, true, true)
	elif value >= 100:
		_raise(type, true, false)
	else:
		souls += 1
		_votes[type] = _votes.get(type, 0) + 1
		_try_raise()


func _try_raise() -> void:
	var stats := _player.stats
	if souls < stats.soul_cost or count >= stats.minion_max:
		return
	var best := 0
	for t: int in _votes:
		if _votes[t] > _votes.get(best, -1):
			best = t
	souls = 0
	_votes.clear()
	_raise(best, false, false)


func _raise(type: int, elite: bool, boss: bool) -> void:
	if type < 0 or type >= _types.size():
		return
	var stats := _player.stats
	if boss and _count_type(type) > 0:
		boss = false
		elite = true
		type = 0
	if count >= maxi(stats.minion_max, 1) or count >= CAPACITY:
		if not (elite or boss):
			return
		# Champions push out the newest common minion.
		var victim := -1
		for k in range(count - 1, -1, -1):
			if _elite[k] == 0:
				victim = k
				break
		if victim < 0:
			return
		_remove(victim, false, false)
	var t: Dictionary = _types[type]
	var k := count
	count += 1
	_type[k] = type
	_pos[k] = _player.pos2 + Vector2.from_angle(randf() * TAU) * 1.5
	_elite[k] = 1 if elite and not boss else 0
	_max_hp[k] = stats.minion_hp * t["hp"] * (2.0 if elite else 1.0)
	_hp[k] = _max_hp[k]
	_attack[k] = 0.0
	_retarget[k] = 0.0
	_hurt[k] = 0.0
	_facing[k] = Vector2(0, -1)
	_phase[k] = randf()
	_target_id[k] = -1
	Juice.ring(_pos[k], Color(0.45, 0.8, 1.0), 24, 5.0, 0.45, 0.5)
	Juice.burst(_pos[k], 0.3, Color(0.6, 0.9, 1.0), 18, 1.5, 0.45, 0.9, 6.0)
	Juice.flash(_pos[k], Color(0.45, 0.8, 1.0), 3.0, 6.0, 0.4)
	raised.emit(t["name"])


func _count_type(type: int) -> int:
	var n := 0
	for k in count:
		if _type[k] == type:
			n += 1
	return n


func step(delta: float) -> void:
	var hero := _player.pos2
	var stats := _player.stats
	var k := count - 1
	while k >= 0:
		var t: Dictionary = _types[_type[k]]
		var p := _pos[k]
		# Too far behind (the hero ran off): reappear at the hero's side.
		if p.distance_squared_to(hero) > 30.0 * 30.0:
			p = hero + Vector2.from_angle(randf() * TAU) * 2.0
		_retarget[k] -= delta
		if _retarget[k] <= 0.0 or not _target_alive(k):
			_retarget[k] = RETARGET
			_find_target(k, p, hero)

		var goal := p
		var reach: float = t["radius"] + 0.6
		var fighting := false
		if _target_alive(k):
			var swarm := _swarms[_target_swarm[k]]
			var enemy := swarm.pos[_target_index[k]]
			goal = enemy
			reach += swarm.radius
			fighting = p.distance_to(enemy) <= reach
		else:
			# Nothing to fight: fall in around the hero.
			var slot := Vector2.from_angle(TAU * k / maxf(count, 1.0) + 0.5) * (2.2 + 0.4 * (k % 3))
			goal = hero + slot
			reach = 0.4

		var to := goal - p
		var d := to.length()
		if d > reach:
			var speed: float = t["speed"]
			if not fighting and p.distance_to(hero) > 8.0:
				speed = maxf(speed, stats.move_speed * 1.2)
			p += to / d * minf(speed * delta, d - reach * 0.9)
			_facing[k] = to / d
		elif d > 0.01:
			_facing[k] = to / d
		# Keep minions from stacking on each other.
		for j in count:
			if j != k:
				var away := p - _pos[j]
				var dd := away.length_squared()
				if dd < 0.8 and dd > 0.0001:
					p += away / sqrt(dd) * delta * 2.0
		_pos[k] = p

		_attack[k] -= delta
		if fighting and _attack[k] <= 0.0:
			_attack[k] = ATTACK_INTERVAL
			var dmg: float = stats.minion_damage * t["damage"] * ATTACK_INTERVAL * (2.0 if _elite[k] == 1 else 1.0)
			_cleave(_swarms[_target_swarm[k]].pos[_target_index[k]], dmg)

		_hurt[k] -= delta
		if _hurt[k] <= 0.0:
			_hurt[k] = 0.25
			_hp[k] -= _contact_damage(p, t["radius"]) * 0.25
			if _hp[k] <= 0.0:
				_remove(k, true)
		k -= 1
	_draw()


func _target_alive(k: int) -> bool:
	if _target_id[k] < 0:
		return false
	var swarm := _swarms[_target_swarm[k]]
	var i := _target_index[k]
	if i >= swarm.count or swarm.ids[i] != _target_id[k] or swarm.hp[i] <= 0.0:
		_target_id[k] = -1
		return false
	return true


func _find_target(k: int, p: Vector2, hero: Vector2) -> void:
	_target_id[k] = -1
	var best := SIGHT * SIGHT
	for s in _swarms.size():
		var swarm := _swarms[s]
		var n := swarm.grid.query(p, SIGHT)
		var res := swarm.grid.results
		for j in n:
			var i := res[j]
			if swarm.hp[i] <= 0.0 or swarm.pos[i].distance_squared_to(hero) > LEASH * LEASH:
				continue
			var d2 := p.distance_squared_to(swarm.pos[i])
			if d2 < best:
				best = d2
				_target_swarm[k] = s
				_target_index[k] = i
				_target_id[k] = swarm.ids[i]


## A minion's swing hits everything right around its target.
func _cleave(at: Vector2, dmg: float) -> void:
	Elements.hit_area(at, 1.0, dmg, Elements.NONE, _player.stats.crit_chance, _player.stats.crit_mult)
	Juice.burst(at, 0.9, Color(0.5, 0.85, 1.0), 2, 2.5, 0.3, 0.25, 1.5)


## Contact damage per second from enemies touching a minion (capped, like the
## hero's), at a third of full strength: the horde is after the hero, not them.
func _contact_damage(p: Vector2, r: float) -> float:
	var total := 0.0
	for swarm in _swarms:
		total += swarm.contact_load(p, r) * 0.35
	return total


## `refill`: let banked souls raise a replacement right away.
func _remove(k: int, died: bool, refill := true) -> void:
	var p := _pos[k]
	Juice.burst(p, 1.0, Color(0.5, 0.85, 1.0), 14, 4.0, 0.4, 0.6, 3.0)
	if died and Elements.has_power("lich_shroud"):
		# Soulfire: the fallen minion bursts, hurting everything around it.
		_queue_soulfire(p)
	var last := count - 1
	if k != last:
		_type[k] = _type[last]
		_pos[k] = _pos[last]
		_hp[k] = _hp[last]
		_max_hp[k] = _max_hp[last]
		_elite[k] = _elite[last]
		_attack[k] = _attack[last]
		_retarget[k] = _retarget[last]
		_hurt[k] = _hurt[last]
		_facing[k] = _facing[last]
		_phase[k] = _phase[last]
		_target_swarm[k] = _target_swarm[last]
		_target_id[k] = _target_id[last]
		_target_index[k] = _target_index[last]
	count = last
	if refill:
		_try_raise()


func _queue_soulfire(at: Vector2) -> void:
	_soulfire.append(at)


## Soulfire bursts run after all minions have stepped (they query the hash).
func flush() -> void:
	for at in _soulfire:
		Elements.hit_area(at, 3.0, _player.stats.minion_damage * 4.0)
		Juice.ring(at, Color(0.45, 0.8, 1.0), 24, 8.0, 0.5, 0.4)
		Juice.flash(at, Color(0.45, 0.8, 1.0), 4.0, 8.0, 0.3)
	_soulfire.clear()


func _draw() -> void:
	var per_type := {}
	for k in count:
		var list: Array = per_type.get(_type[k], [])
		list.append(k)
		per_type[_type[k]] = list
	for t in _types.size():
		var mm: MultiMesh = _types[t]["mmi"].multimesh
		var list: Array = per_type.get(t, [])
		var n := mini(list.size(), mm.instance_count)
		mm.visible_instance_count = n
		for j in n:
			var k: int = list[j]
			var f := _facing[k]
			var sc := 1.35 if _elite[k] == 1 else 1.0
			var basis := Basis(Vector3.UP, atan2(-f.x, -f.y)).scaled(Vector3.ONE * sc)
			mm.set_instance_transform(j, Transform3D(basis, Vector3(_pos[k].x, 0.0, _pos[k].y)))
			mm.set_instance_custom_data(j, Color(0.0, _phase[k], 0.0, 0.0))
			mm.set_instance_color(j, Color(1.2, 1.2, 1.2) if _elite[k] == 1 else Color.WHITE)
