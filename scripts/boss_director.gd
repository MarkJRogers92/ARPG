class_name BossDirector
extends Node3D
## Brings in a boss every few minutes and runs its signature attack: a ground
## slam. The boss marks the ground where the hero stands with a red circle
## that fills up; when it's full, everything inside takes a heavy hit. Walk
## out of it or dash through it.
##
## The boss itself is an ordinary EnemySwarm (the "Bosses" node, with `boss`
## set and a spawn share of 0 so the wave director never picks it).
##
## At `run_length` (dawn) the realm's final boss arrives instead ("FinalBoss"
## node): it slams more often, fires rings of shots in the realm's element,
## calls in waves of the realm's foot soldiers, and gets faster below half
## health. Killing it wins the night (main.gd listens for its death). After a
## win, Endless mode brings mid-bosses back.

signal boss_spawned(boss_name: String)
signal final_spawned(boss_name: String)

@export var boss_name := "Ogre Warlord"
## Game time of the first boss, then one more every `interval` seconds.
@export var first_at := 180.0
@export var interval := 180.0
## Each later boss has this much more HP and slam damage than the one before.
@export var growth := 0.5
@export var slam_interval := 5.0
@export var slam_windup := 1.1
@export var slam_radius := 3.6
@export var slam_damage := 30.0
## The boss only slams when the hero is this close.
@export var slam_reach := 14.0

@export_group("Final boss")
@export var final_name := "The Lich King"
## Game time when the final boss arrives: the length of the night.
@export var run_length := 900.0
## The final boss's shots use this element (see Elements).
@export var final_shot := 0
@export var ring_interval := 6.0
@export var ring_shots := 18
@export var summon_interval := 14.0
@export var summon_count := 14

## How many bosses have arrived this run.
var spawned := 0
var final_arrived := false
## Set after a win: mid-bosses keep coming, no more final boss.
var endless := false

var _swarm: EnemySwarm
var _final: EnemySwarm
var _shots: EnemyShots
var _summon_swarm: EnemySwarm
var _ring_timer := 4.0
var _summon_timer := 8.0
var _director: WaveDirector
var _player: Player
var _next_at := 0.0
## Boss id -> {"max_hp": float, "timer": float}
var _bosses := {}
## Each: {"at": Vector2, "t": float, "damage": float, "ring": MeshInstance3D, "fill": MeshInstance3D}
var _slams: Array[Dictionary] = []


func setup(swarm: EnemySwarm, director: WaveDirector, player: Player) -> void:
	_swarm = swarm
	_director = director
	_player = player
	_next_at = first_at


func setup_final(final: EnemySwarm, shots: EnemyShots, summon_swarm: EnemySwarm) -> void:
	_final = final
	_shots = shots
	_summon_swarm = summon_swarm


## Seconds until the final boss comes (0 once it has).
func time_to_final() -> float:
	return maxf(run_length - _director.elapsed, 0.0) if _director else run_length


func final_alive() -> bool:
	return _final != null and _final.alive_count() > 0


func tick(delta: float) -> void:
	if _swarm == null:
		return
	# Mid-bosses until dawn (and again in Endless), then the final boss.
	if _director.elapsed >= _next_at and (_director.elapsed < run_length - 30.0 or endless):
		_next_at += interval
		_spawn()
	if _final and not final_arrived and not endless and _director.elapsed >= run_length:
		_spawn_final()
	if final_alive():
		_final_attacks(delta)

	var hero := _player.pos2
	for i in _swarm.count:
		if _swarm.hp[i] <= 0.0:
			continue
		var id := _swarm.ids[i]
		if not _bosses.has(id):
			_bosses[id] = {"max_hp": _swarm.hp[i], "timer": slam_interval}
		var b: Dictionary = _bosses[id]
		b["timer"] -= delta
		if b["timer"] <= 0.0 and hero.distance_to(_swarm.pos[i]) < slam_reach:
			b["timer"] = slam_interval
			_start_slam(hero)
	_update_slams(delta)


func boss_alive() -> bool:
	return _swarm != null and _swarm.alive_count() > 0


## Health of the strongest living boss as 0..1, or -1 when there is none.
## The final boss comes first.
func boss_health() -> float:
	if final_alive():
		for i in _final.count:
			var id := _final.ids[i]
			if _final.hp[i] > 0.0 and _bosses.has(id):
				return _final.hp[i] / _bosses[id]["max_hp"]
	if _swarm == null:
		return -1.0
	var best := -1.0
	for i in _swarm.count:
		var id := _swarm.ids[i]
		if _swarm.hp[i] > 0.0 and _bosses.has(id):
			best = maxf(best, _swarm.hp[i] / _bosses[id]["max_hp"])
	return best


func current_boss_name() -> String:
	return final_name if final_alive() else boss_name


func _spawn_final() -> void:
	final_arrived = true
	var at := EnemySwarm.random_ring_point(_player.pos2, 13.0, 15.0)
	if _final.spawn(at, _director.hp_multiplier()):
		_bosses[_final.ids[_final.count - 1]] = {"max_hp": _final.hp[_final.count - 1], "timer": 3.0}
		final_spawned.emit(final_name)
		Juice.shake(0.7)
		Juice.flash(at, Color(1.0, 0.3, 0.2), 8.0, 20.0, 1.0)


func _final_attacks(delta: float) -> void:
	var i := 0
	while i < _final.count - 1 and _final.hp[i] <= 0.0:
		i += 1
	var id := _final.ids[i]
	var b: Dictionary = _bosses.get(id, {})
	if b.is_empty():
		_bosses[id] = {"max_hp": _final.hp[i], "timer": 3.0}
		b = _bosses[id]
	var enraged: bool = _final.hp[i] < b["max_hp"] * 0.5
	var speed := 1.6 if enraged else 1.0
	var at := _final.pos[i]
	var hero := _player.pos2
	b["timer"] -= delta * speed
	if b["timer"] <= 0.0 and hero.distance_to(at) < slam_reach * 1.5:
		b["timer"] = slam_interval * 0.7
		_start_slam(hero)
	_ring_timer -= delta * speed
	if _ring_timer <= 0.0:
		_ring_timer = ring_interval
		var n := ring_shots + (10 if enraged else 0)
		var offset := randf() * TAU
		for k in n:
			var dir := Vector2.from_angle(offset + TAU * k / n)
			_shots.spawn(at + dir * 1.5, dir, 6.0, 10.0 + 6.0 * _director.hp_scale, final_shot)
		Juice.flash(at, Elements.COLORS.get(final_shot, Color(0.8, 0.5, 1.0)), 4.0, 10.0, 0.3)
	_summon_timer -= delta
	if _summon_timer <= 0.0 and _summon_swarm:
		_summon_timer = summon_interval
		for k in summon_count:
			_summon_swarm.spawn(hero + Vector2.from_angle(TAU * k / summon_count) * 9.0, _director.hp_multiplier())
		Juice.ring(hero, Color(0.8, 0.4, 1.0), 30, 9.0 / 0.5, 0.5, 0.5)


func _spawn() -> void:
	var at := EnemySwarm.random_ring_point(_player.pos2, 16.0, 18.0)
	var hp_mult := _director.hp_multiplier() * (1.0 + growth * spawned)
	if _swarm.spawn(at, hp_mult):
		spawned += 1
		boss_spawned.emit(boss_name)
		Juice.shake(0.4)


func _start_slam(at: Vector2) -> void:
	var ring := HazardDirector.make_decal(self, at, Color(1.0, 0.15, 0.1, 0.8), 1.0, slam_radius * 2.0)
	var fill := HazardDirector.make_decal(self, at, Color(1.0, 0.25, 0.1, 0.35), 0.0, slam_radius * 2.0)
	fill.scale = Vector3.ONE * 0.05
	_slams.append({"at": at, "t": 0.0, "ring": ring, "fill": fill,
			"damage": slam_damage * (1.0 + growth * maxi(spawned - 1, 0)) * (1.5 if final_alive() else 1.0)})


func _update_slams(delta: float) -> void:
	var i := _slams.size() - 1
	while i >= 0:
		var slam := _slams[i]
		slam["t"] += delta
		var t: float = slam["t"] / slam_windup
		(slam["fill"] as MeshInstance3D).scale = Vector3.ONE * clampf(t, 0.05, 1.0)
		if t >= 1.0:
			var at: Vector2 = slam["at"]
			if _player.pos2.distance_to(at) <= slam_radius + Player.RADIUS and not _player.is_dashing():
				_player.take_damage(slam["damage"])
			Juice.shake(0.55)
			Juice.flash(at, Color(1.0, 0.45, 0.2), 6.0, slam_radius * 3.0, 0.4)
			Juice.ring(at, Color(1.0, 0.5, 0.2), 36, slam_radius / 0.4, 0.6, 0.4)
			Juice.burst(at, 0.3, Color(0.55, 0.45, 0.35), 24, 6.0, 0.5, 0.7, 5.0)
			slam["ring"].queue_free()
			slam["fill"].queue_free()
			_slams.remove_at(i)
		i -= 1
