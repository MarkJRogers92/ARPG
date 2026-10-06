class_name ArcaneNova
extends MeshInstance3D
## Arcane Nova: every few seconds the hero releases a ring of force that
## damages everything within `nova_radius` and throws it back, buying room to
## breathe. Drawn as a glowing ring expanding over the ground.
##
## Unlocked and improved by the "nova" upgrade (see Upgrades.DEFS).

const KNOCKBACK := 4.5
const EXPAND_TIME := 0.35
const COLOR := Color(1.0, 0.45, 0.9)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 1.0
var _anim := 1.0
var _material: ShaderMaterial


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	top_level = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(2, 2)
	mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ground_glow.gdshader")
	_material.set_shader_parameter("ring", 1.0)
	_material.set_shader_parameter("pulse_speed", 0.0)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func update(delta: float) -> void:
	var stats := _player.stats
	_animate(delta)
	if stats.nova_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = stats.nova_cooldown

	var center := _player.pos2
	var r := stats.nova_radius
	for swarm in _swarms:
		var n := swarm.grid.query(center, r + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0:
				continue
			var crit := randf() < stats.crit_chance
			var amount := stats.nova_damage * (stats.crit_mult if crit else 1.0)
			swarm.damage(i, amount)
			Juice.number(swarm.pos[i], amount, crit, COLOR.lightened(0.4))
		swarm.knockback(center, r + swarm.radius, KNOCKBACK)
	_anim = 0.0
	Juice.ring(center, COLOR, 40, r / 0.45, 0.55, 0.45)
	Juice.flash(center, COLOR, 5.0, r * 1.8, 0.35)
	Juice.shake(0.25)


func _animate(delta: float) -> void:
	if _anim >= 1.0:
		visible = false
		return
	_anim = minf(_anim + delta / EXPAND_TIME, 1.0)
	visible = true
	var r := _player.stats.nova_radius * (0.25 + 0.75 * (1.0 - pow(1.0 - _anim, 3.0)))
	global_position = Vector3(_player.global_position.x, 0.07, _player.global_position.z)
	scale = Vector3(r, 1.0, r)
	_material.set_shader_parameter("color", Color(COLOR, 0.9 * (1.0 - _anim)))
