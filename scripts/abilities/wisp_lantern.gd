class_name WispLantern
extends Node3D
## The Wisp Lantern: every so often a few frost wisps drift out from the hero,
## each in its own direction, then turn and home in on the nearest enemy,
## trailing pale light. A wisp bursts on the first enemy it touches, hurting
## and chilling it (so Chain Lightning shatters what the wisps have chilled).
##
## Unlocked and improved by the "wisps" upgrade (see Upgrades.DEFS).

const SPEED := 10.0
## Radians per second a wisp can turn toward its target.
const TURN := 5.5
const LIFE := 3.2
## Wisps drift straight out for this long before they start to hunt.
const DRIFT := 0.25
const HIT_RADIUS := 0.55
const SEEK_RANGE := 14.0
const MAX_WISPS := 48
const COLOR := Color(0.6, 0.9, 1.0)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 1.0
## {"node", "pos", "dir", "t", "target": Vector2 or null, "seek"}
var _wisps: Array[Dictionary] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true


func update(delta: float) -> void:
	_fly(delta)
	var stats := _player.stats
	if stats.wisp_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = stats.wisp_cooldown
	var offset := randf() * TAU
	for k in stats.wisp_count:
		if _wisps.size() >= MAX_WISPS:
			break
		var node := MeshInstance3D.new()
		node.mesh = Models.wisp()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		var dir := Vector2.from_angle(offset + TAU * k / stats.wisp_count)
		_wisps.append({"node": node, "pos": _player.pos2 + dir * 0.6, "dir": dir, "t": 0.0, "seek": 0.0})
	Sound.play("soul", 1.4, -6.0)


func _nearest(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d2 := SEEK_RANGE * SEEK_RANGE
	for swarm in _swarms:
		var n := swarm.grid.query(from, SEEK_RANGE)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0:
				continue
			var d2 := from.distance_squared_to(swarm.pos[i])
			if d2 < best_d2:
				best_d2 = d2
				best = swarm.pos[i]
	return best


func _fly(delta: float) -> void:
	var i := _wisps.size() - 1
	while i >= 0:
		var w := _wisps[i]
		w["t"] += delta
		var p: Vector2 = w["pos"]
		var dir: Vector2 = w["dir"]
		if w["t"] > DRIFT:
			# Look for a target a few times a second, not every frame.
			w["seek"] -= delta
			if w["seek"] <= 0.0:
				w["seek"] = 0.15
				w["target"] = _nearest(p)
			var target: Vector2 = w.get("target", Vector2.INF)
			if target != Vector2.INF:
				var want := (target - p).normalized()
				var turn := clampf(dir.angle_to(want), -TURN * delta, TURN * delta)
				dir = dir.rotated(turn)
		p += dir * SPEED * delta
		w["pos"] = p
		w["dir"] = dir
		var node: MeshInstance3D = w["node"]
		node.position = Vector3(p.x, 1.0 + sin(w["t"] * 9.0 + i) * 0.12, p.y)
		if Engine.get_process_frames() % 3 == 0:
			Juice.burst(p, 1.0, COLOR, 1, 0.3, 0.22, 0.35, 0.2)
		if (w["t"] > DRIFT and _touch(p)) or w["t"] > LIFE:
			node.queue_free()
			_wisps.remove_at(i)
		i -= 1


## Bursts on the first living enemy at `p`. True if it hit one.
func _touch(p: Vector2) -> bool:
	for swarm in _swarms:
		var n := swarm.grid.query(p, HIT_RADIUS + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0:
				continue
			var stats := _player.stats
			var crit := randf() < stats.crit_chance
			Elements.source = "Wisp Lantern"
			Elements.hit(swarm, i, stats.wisp_damage * (stats.crit_mult if crit else 1.0), Elements.FROST, crit)
			Juice.burst(p, 1.0, COLOR, 6, 3.0, 0.3, 0.35, 2.0)
			return true
	return false
