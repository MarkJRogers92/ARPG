class_name ReapingScythe
extends Node3D
## The Reaping Scythe: thrown out toward the nearest enemy (or where you aim),
## it spins out to its range and then flies back to the hero wherever they've
## moved, so where you walk shapes its second cut. It cuts each enemy once
## on the way out and once on the way back, and the return cut hits harder.
##
## Unlocked and improved by the "scythe" upgrade (see Upgrades.DEFS).

const SPEED := 16.0
const RETURN_SPEED := 19.0
const HIT_RADIUS := 1.0
const RETURN_BONUS := 1.5
const COLOR := Color(0.65, 0.95, 0.85)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 1.0
## In flight: {"node", "pos": Vector2, "dir", "out": float (distance left), "back": bool, "hits": {}}
var _blades: Array[Dictionary] = []
var _mesh: Mesh


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true
	var kit := MeshKit.new()
	var steel := Color(0.78, 0.85, 0.88)
	# A crescent blade (segments around an arc) on a short haft.
	for i in 7:
		var a := deg_to_rad(-70.0 + i * 22.0)
		var p := Vector3(cos(a), 0, sin(a)) * 0.7
		kit.box(Vector3(0.3, 0.05, 0.14 - i * 0.012), Transform3D(Basis(Vector3.UP, -a), p), steel if i < 6 else COLOR, 0.25 + i * 0.12)
	kit.cylinder(0.04, 0.04, 0.9, MeshKit.at(Vector3(-0.2, 0, 0.1), Vector3(0, 0, 90)), Color(0.3, 0.2, 0.14), 0.0, 5)
	_mesh = kit.commit(Models.kit_material())


func update(delta: float) -> void:
	_fly(delta)
	var stats := _player.stats
	if stats.scythe_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0 or _blades.size() >= stats.scythe_count:
		return
	_timer = stats.scythe_cooldown
	var dir := _aim()
	var node := MeshInstance3D.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var spread := 0.0 if _blades.is_empty() else (0.35 * (1 if _blades.size() % 2 == 1 else -1))
	_blades.append({"node": node, "pos": _player.pos2, "dir": dir.rotated(spread), "out": stats.scythe_range,
			"back": false, "hits": {}})
	Sound.play("blade", 0.6, 4.0)


func _aim() -> Vector2:
	if _player.aim_mode != Player.Aim.AUTO:
		return _player.aim_dir
	var best := Vector2.ZERO
	var best_d2 := 14.0 * 14.0
	var from := _player.pos2
	for swarm in _swarms:
		var n := swarm.grid.query(from, 14.0)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0:
				continue
			var d2 := from.distance_squared_to(swarm.pos[i])
			if d2 < best_d2:
				best_d2 = d2
				best = swarm.pos[i] - from
	return best.normalized() if best != Vector2.ZERO else _player._facing()


func _fly(delta: float) -> void:
	var stats := _player.stats
	var i := _blades.size() - 1
	while i >= 0:
		var b := _blades[i]
		var node: MeshInstance3D = b["node"]
		var p: Vector2 = b["pos"]
		if not b["back"]:
			var step := SPEED * delta
			p += b["dir"] * step
			b["out"] -= step
			if b["out"] <= 0.0:
				b["back"] = true
				b["hits"] = {}
		else:
			var to := _player.pos2 - p
			var d := to.length()
			if d < 0.8:
				node.queue_free()
				_blades.remove_at(i)
				i -= 1
				continue
			p += to / d * minf(RETURN_SPEED * delta, d)
		b["pos"] = p
		node.position = Vector3(p.x, 1.0, p.y)
		node.rotation.y += delta * 18.0
		_cut(b, stats.scythe_damage * (RETURN_BONUS if b["back"] else 1.0))
		i -= 1


func _cut(b: Dictionary, damage: float) -> void:
	Elements.source = "Reaping Scythe"
	var p: Vector2 = b["pos"]
	var stats := _player.stats
	for swarm in _swarms:
		var n := swarm.grid.query(p, HIT_RADIUS + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0 or b["hits"].has(swarm.ids[i]):
				continue
			b["hits"][swarm.ids[i]] = true
			var crit := randf() < stats.crit_chance
			Elements.hit(swarm, i, damage * (stats.crit_mult if crit else 1.0), Elements.NONE, crit)
			Juice.burst(swarm.pos[i], 0.9, COLOR, 2, 3.0, 0.3, 0.25, 1.5)
