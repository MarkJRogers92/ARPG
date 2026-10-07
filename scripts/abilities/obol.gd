class_name Obol
extends Node3D
## The Ferryman's Obol: every so often the hero flicks a heavy coin at the
## nearest enemy. It ricochets to the next one, `obol_bounces` times. Each hit
## has an `obol_luck` chance to land heads: a gold flash, double damage and
## one extra bounce. A coin never hits the same enemy twice.
##
## Unlocked and improved by the "obol" upgrade (see Upgrades.DEFS).

const TARGET_RANGE := 12.0
const BOUNCE_RANGE := 7.0
const SPEED := 20.0
const COLOR := Color(1.0, 0.82, 0.35)
const MAX_COINS := 6

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 0.5
## In flight: {"node", "pos": Vector3, "swarm", "id", "bounces", "hit": {}, "damage"}
var _coins: Array[Dictionary] = []
var _mesh: Mesh


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true
	var kit := MeshKit.new()
	kit.cylinder(0.22, 0.22, 0.05, MeshKit.at(Vector3.ZERO, Vector3(90, 0, 0)), COLOR, 1.2, 10)
	kit.cylinder(0.12, 0.12, 0.06, MeshKit.at(Vector3.ZERO, Vector3(90, 0, 0)), Color(0.85, 0.6, 0.2), 0.6, 8)
	_mesh = kit.commit(Models.kit_material())


func update(delta: float) -> void:
	_fly(delta)
	var stats := _player.stats
	if stats.obol_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0 or _coins.size() >= MAX_COINS:
		return
	var target := _nearest(_player.pos2, TARGET_RANGE, {})
	if target.is_empty():
		_timer = 0.2
		return
	_timer = stats.obol_cooldown
	var node := MeshInstance3D.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var start := Vector3(_player.pos2.x, 1.3, _player.pos2.y)
	node.position = start
	_coins.append({"node": node, "pos": start, "swarm": target["swarm"], "id": target["swarm"].ids[target["index"]],
			"bounces": stats.obol_bounces, "hit": {}, "damage": stats.obol_damage})
	Sound.play("pickup", 1.6, -6.0)


func _fly(delta: float) -> void:
	var i := _coins.size() - 1
	while i >= 0:
		var c := _coins[i]
		var swarm: EnemySwarm = c["swarm"]
		var k := _index_of(swarm, c["id"])
		if k < 0:
			# The target died on the way: find another or drop out of the air.
			var next := _nearest(Vector2(c["pos"].x, c["pos"].z), BOUNCE_RANGE, c["hit"])
			if next.is_empty():
				_end(i)
				i -= 1
				continue
			c["swarm"] = next["swarm"]
			c["id"] = next["swarm"].ids[next["index"]]
			swarm = c["swarm"]
			k = next["index"]
		var goal := Vector3(swarm.pos[k].x, swarm.body_height * 0.55, swarm.pos[k].y)
		var to: Vector3 = goal - c["pos"]
		var step := SPEED * delta
		var node: MeshInstance3D = c["node"]
		node.rotation.y += delta * 25.0
		if to.length() > step:
			c["pos"] += to.normalized() * step
			node.position = c["pos"]
			i -= 1
			continue
		# Hit.
		c["pos"] = goal
		node.position = goal
		var stats := _player.stats
		var lucky := randf() < stats.obol_luck
		var crit := randf() < stats.crit_chance
		var dmg: float = c["damage"] * (2.0 if lucky else 1.0) * (stats.crit_mult if crit else 1.0)
		Elements.hit(swarm, k, dmg, Elements.NONE, crit or lucky)
		c["hit"][c["id"]] = true
		Juice.burst(swarm.pos[k], goal.y, COLOR, 6 if lucky else 3, 4.0, 0.3, 0.3, 2.0)
		if lucky:
			c["bounces"] += 1
			Juice.flash(swarm.pos[k], COLOR, 2.5, 5.0, 0.15)
			Sound.play("gem", 1.8, -2.0)
		else:
			Sound.play("bolt_hit", 0.7)
		c["bounces"] -= 1
		c["damage"] *= 0.9
		var next := _nearest(swarm.pos[k], BOUNCE_RANGE, c["hit"]) if c["bounces"] >= 0 else {}
		if next.is_empty():
			_end(i)
		else:
			c["swarm"] = next["swarm"]
			c["id"] = next["swarm"].ids[next["index"]]
		i -= 1


func _end(i: int) -> void:
	var node: MeshInstance3D = _coins[i]["node"]
	Juice.burst(Vector2(node.position.x, node.position.z), node.position.y, COLOR, 4, 2.0, 0.25, 0.4, 1.0)
	node.queue_free()
	_coins.remove_at(i)


static func _index_of(swarm: EnemySwarm, id: int) -> int:
	for k in swarm.count:
		if swarm.ids[k] == id:
			return k if swarm.hp[k] > 0.0 else -1
	return -1


func _nearest(from: Vector2, max_dist: float, skip: Dictionary) -> Dictionary:
	var best := {}
	var best_d2 := max_dist * max_dist
	for swarm in _swarms:
		var n := swarm.grid.query(from, max_dist)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0 or skip.has(swarm.ids[i]):
				continue
			var d2 := from.distance_squared_to(swarm.pos[i])
			if d2 < best_d2:
				best_d2 = d2
				best = {"swarm": swarm, "index": i}
	return best
