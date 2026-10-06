class_name SpiritBlades
extends Node3D
## Spirit Blades: glowing blades that circle the hero and cut whatever they
## pass through. Each blade hits a given enemy at most every HIT_INTERVAL
## seconds (tracked per blade by enemy id), so a crowd standing in the ring
## takes steady damage rather than one hit per frame.
##
## Unlocked and improved by the "orbit" upgrade (see Upgrades.DEFS).

const SPIN_SPEED := 2.8 # radians per second
const HIT_RADIUS := 0.75
const HIT_INTERVAL := 0.3
const COLOR := Color(0.45, 1.0, 0.85)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _blades: Array[MeshInstance3D] = []
var _angle := 0.0
## Per blade: enemy id -> time left before that blade can hit it again.
var _cooldowns: Array[Dictionary] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true


func update(delta: float) -> void:
	var stats := _player.stats
	var count := stats.orbit_count if stats.orbit_level > 0 else 0
	while _blades.size() < count:
		var blade := MeshInstance3D.new()
		blade.mesh = Models.spirit_blade()
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blade)
		_blades.append(blade)
		_cooldowns.append({})
	while _blades.size() > count:
		_blades.pop_back().queue_free()
		_cooldowns.pop_back()
	if count == 0:
		return

	global_position = Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	_angle = fmod(_angle + SPIN_SPEED * delta, TAU)
	var center := _player.pos2
	for b in count:
		var a := _angle + TAU * b / count
		var offset := Vector2.from_angle(a) * stats.orbit_radius
		var blade := _blades[b]
		blade.position = Vector3(offset.x, 1.0 + sin(_angle * 2.0 + b) * 0.15, offset.y)
		# Point along the direction of travel, tilted like a thrown blade.
		blade.rotation = Vector3(0.0, PI - a, 0.0)
		blade.rotate_object_local(Vector3.FORWARD, 0.5)
		_cut(b, center + offset, delta)


func _cut(b: int, at: Vector2, delta: float) -> void:
	var stats := _player.stats
	var cd: Dictionary = _cooldowns[b]
	for id in cd.keys():
		cd[id] -= delta
		if cd[id] <= 0.0:
			cd.erase(id)
	for swarm in _swarms:
		var n := swarm.grid.query(at, HIT_RADIUS + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0 or cd.has(swarm.ids[i]):
				continue
			cd[swarm.ids[i]] = HIT_INTERVAL
			var crit := randf() < stats.crit_chance
			var amount := stats.orbit_damage * (stats.crit_mult if crit else 1.0)
			swarm.damage(i, amount)
			Juice.number(swarm.pos[i], amount, crit, COLOR.lightened(0.4))
			Juice.burst(swarm.pos[i], 1.0, COLOR, 2, 3.0, 0.3, 0.25, 1.5)
