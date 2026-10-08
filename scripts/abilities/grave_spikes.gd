class_name GraveSpikes
extends Node3D
## Grave Spikes: every few seconds the ground cracks under a few enemies near
## the hero, and a moment later a cluster of bone spikes bursts up through
## it, hurting everything standing there. The crack is short (WINDUP), so it
## mostly reads as a warning to the player of where the spikes will rise.
##
## Unlocked and improved by the "spikes" upgrade (see Upgrades.DEFS).

## How far from the hero it looks for targets.
const REACH := 10.0
const WINDUP := 0.3
## The spikes stand this long, then sink back into the ground.
const STAND := 0.35
const SINK := 0.45
const MAX_ERUPTIONS := 24
const COLOR := Color(0.92, 0.88, 0.75)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 1.0
## {"at", "t", "crack", "spikes", "hit"}
var _eruptions: Array[Dictionary] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true


func update(delta: float) -> void:
	_rise(delta)
	var stats := _player.stats
	if stats.spikes_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = stats.spikes_cooldown
	for at in _targets(stats.spikes_count):
		_erupt(at)


## Up to `n` spots under living enemies near the hero, nearest first among a
## random sample, so the spikes favor what's closing in.
func _targets(n: int) -> Array[Vector2]:
	var hero := _player.pos2
	var found: Array[Vector2] = []
	for swarm in _swarms:
		var count := swarm.grid.query(hero, REACH)
		var res := swarm.grid.results
		for k in count:
			var i := res[k]
			if swarm.hp[i] > 0.0:
				found.append(swarm.pos[i])
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(hero) < b.distance_squared_to(hero))
	var out: Array[Vector2] = []
	for p in found:
		if out.size() >= n:
			break
		# Spread out: no two eruptions on top of each other.
		var crowded := false
		for q in out:
			if q.distance_squared_to(p) < 1.6 * 1.6:
				crowded = true
				break
		if not crowded:
			out.append(p)
	return out


func _erupt(at: Vector2) -> void:
	if _eruptions.size() >= MAX_ERUPTIONS:
		return
	var crack := HazardDirector.make_decal(self, at, Color(0.85, 0.75, 0.55, 0.6), 0.6, _player.stats.spikes_radius * 2.0)
	var spikes := MeshInstance3D.new()
	spikes.mesh = Models.bone_spikes()
	spikes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spikes.position = Vector3(at.x, -1.2, at.y)
	spikes.rotation.y = randf() * TAU
	spikes.scale = Vector3.ONE * (_player.stats.spikes_radius / 1.5)
	add_child(spikes)
	_eruptions.append({"at": at, "t": 0.0, "crack": crack, "spikes": spikes, "hit": false})


func _rise(delta: float) -> void:
	var i := _eruptions.size() - 1
	while i >= 0:
		var e := _eruptions[i]
		e["t"] += delta
		var t: float = e["t"]
		var spikes: MeshInstance3D = e["spikes"]
		if t >= WINDUP and not e["hit"]:
			e["hit"] = true
			var stats := _player.stats
			Elements.source = "Grave Spikes"
			Elements.hit_area(e["at"], stats.spikes_radius, stats.spikes_damage, Elements.NONE, stats.crit_chance, stats.crit_mult)
			Juice.burst(e["at"], 0.3, COLOR, 10, 4.0, 0.35, 0.45, 5.0)
			Juice.burst(e["at"], 0.1, Color(0.35, 0.28, 0.2), 8, 3.0, 0.4, 0.6, 2.0)
			Sound.play("grave", 1.6, -9.0)
		# Up fast, stand, sink slowly.
		var y := -1.2
		if t >= WINDUP:
			var up := clampf((t - WINDUP) / 0.08, 0.0, 1.0)
			var down := clampf((t - WINDUP - STAND) / SINK, 0.0, 1.0)
			y = lerpf(-1.2, 0.0, up) - down * 1.3
		spikes.position.y = y
		if t > WINDUP + STAND + SINK:
			(e["crack"] as MeshInstance3D).queue_free()
			spikes.queue_free()
			_eruptions.remove_at(i)
		i -= 1
