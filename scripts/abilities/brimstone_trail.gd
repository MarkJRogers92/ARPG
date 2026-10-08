class_name BrimstoneTrail
extends Node3D
## Brimstone Trail: the hero leaves patches of burning ground behind as it
## walks (one every STEP of distance). Each patch burns for trail_life
## seconds, setting what stands in it alight and searing it a few times a
## second, then cools and fades. Kiting a horde through your own trail is
## the point; standing still lays nothing.
##
## Unlocked and improved by the "trail" upgrade (see Upgrades.DEFS).

## Distance walked between patches.
const STEP := 1.1
## Patches sear what's in them this often.
const TICK := 0.25
const MAX_PATCHES := 40
const COLOR := Color(1.0, 0.45, 0.12)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _last := Vector2.INF
var _tick := 0.0
## {"at", "t", "glow", "life"}
var _patches: Array[Dictionary] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true


func update(delta: float) -> void:
	var stats := _player.stats
	if stats.trail_level > 0:
		var hero := _player.pos2
		if _last == Vector2.INF or hero.distance_to(_last) >= STEP:
			_last = hero
			_lay(hero)
	_burn(delta)


func _lay(at: Vector2) -> void:
	if _patches.size() >= MAX_PATCHES:
		var oldest: Dictionary = _patches.pop_front()
		(oldest["glow"] as MeshInstance3D).queue_free()
	var stats := _player.stats
	var glow := HazardDirector.make_decal(self, at, Color(COLOR, 0.9), 0.0, stats.trail_radius * 2.6)
	glow.rotation.y = randf() * TAU
	_patches.append({"at": at, "t": 0.0, "glow": glow, "life": stats.trail_life})


func _burn(delta: float) -> void:
	_tick -= delta
	var sear := _tick <= 0.0
	if sear:
		_tick = TICK
	var stats := _player.stats
	var i := _patches.size() - 1
	while i >= 0:
		var p := _patches[i]
		p["t"] += delta
		var left: float = 1.0 - p["t"] / p["life"]
		var glow: MeshInstance3D = p["glow"]
		if left <= 0.0:
			glow.queue_free()
			_patches.remove_at(i)
			i -= 1
			continue
		# Fades out over its last third, flickering.
		var a := clampf(left * 3.0, 0.0, 1.0) * (0.85 + 0.15 * sin(p["t"] * 17.0 + i))
		(glow.material_override as ShaderMaterial).set_shader_parameter("color", Color(COLOR, a))
		if sear:
			Elements.source = "Brimstone Trail"
			Elements.hit_area(p["at"], stats.trail_radius, stats.trail_dps * TICK, Elements.FIRE)
			if randf() < 0.8:
				Juice.burst(p["at"] + Vector2.from_angle(randf() * TAU) * randf() * stats.trail_radius, 0.1,
						Color(1.0, 0.55, 0.15), 1, 0.6, 0.3, 0.6, 2.2)
		i -= 1
