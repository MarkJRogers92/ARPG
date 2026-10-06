class_name BossDirector
extends Node3D
## Brings in a boss every few minutes and runs its signature attack: a ground
## slam. The boss marks the ground where the hero stands with a red circle
## that fills up; when it's full, everything inside takes a heavy hit. Walk
## out of it or dash through it.
##
## The boss itself is an ordinary EnemySwarm (the "Bosses" node, with `boss`
## set and a spawn share of 0 so the wave director never picks it).

signal boss_spawned(boss_name: String)

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

## How many bosses have arrived this run.
var spawned := 0

var _swarm: EnemySwarm
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


func tick(delta: float) -> void:
	if _swarm == null:
		return
	if _director.elapsed >= _next_at:
		_next_at += interval
		_spawn()

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
func boss_health() -> float:
	if _swarm == null:
		return -1.0
	var best := -1.0
	for i in _swarm.count:
		var id := _swarm.ids[i]
		if _swarm.hp[i] > 0.0 and _bosses.has(id):
			best = maxf(best, _swarm.hp[i] / _bosses[id]["max_hp"])
	return best


func _spawn() -> void:
	var at := EnemySwarm.random_ring_point(_player.pos2, 16.0, 18.0)
	var hp_mult := _director.hp_multiplier() * (1.0 + growth * spawned)
	if _swarm.spawn(at, hp_mult):
		spawned += 1
		boss_spawned.emit(boss_name)
		Juice.shake(0.4)


func _start_slam(at: Vector2) -> void:
	var ring := _decal(at, Color(1.0, 0.15, 0.1, 0.8), 1.0, slam_radius * 2.0)
	var fill := _decal(at, Color(1.0, 0.25, 0.1, 0.35), 0.0, slam_radius * 2.0)
	fill.scale = Vector3.ONE * 0.05
	_slams.append({"at": at, "t": 0.0, "ring": ring, "fill": fill,
			"damage": slam_damage * (1.0 + growth * (spawned - 1))})


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


func _decal(at: Vector2, color: Color, ring: float, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground_glow.gdshader")
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("ring", ring)
	mat.set_shader_parameter("pulse_speed", 14.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, 0.08, at.y)
	add_child(mi)
	return mi
