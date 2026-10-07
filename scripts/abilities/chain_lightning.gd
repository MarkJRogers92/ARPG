class_name ChainLightning
extends MeshInstance3D
## Chain Lightning: every so often, a bolt of lightning strikes the nearest
## enemy and jumps from it to the next closest one, `lightning_chains` times,
## losing a little damage on each jump. It shocks what it hits, and shatters
## chilled enemies (see Elements). The arcs are drawn as flickering,
## camera-facing ribbons in an ImmediateMesh, so they cost no nodes.
##
## Unlocked and improved by the "lightning" upgrade (see Upgrades.DEFS).

const TARGET_RANGE := 13.0
const JUMP_RANGE := 5.5
const FALLOFF := 0.85
const ARC_LIFE := 0.2
const COLOR := Color(0.7, 0.6, 1.0)

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _timer := 0.0
var _mesh := ImmediateMesh.new()
## Each arc: {"points": PackedVector3Array, "life": float}
var _arcs: Array[Dictionary] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


func _ready() -> void:
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = mat
	custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 40, 20000))


func update(delta: float) -> void:
	_draw_arcs(delta)
	var stats := _player.stats
	if stats.lightning_level <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return

	var origin := _player.pos2
	var first := _nearest(origin, TARGET_RANGE, {})
	if first.is_empty():
		_timer = 0.15
		return
	_timer = stats.lightning_cooldown

	var points := PackedVector3Array([Vector3(origin.x, 2.3, origin.y)])
	var hit := {}
	var damage := stats.lightning_damage
	var target := first
	for k in stats.lightning_chains + 1:
		var swarm: EnemySwarm = target["swarm"]
		var i: int = target["index"]
		var at := swarm.pos[i]
		hit[swarm.ids[i]] = true
		var crit := randf() < stats.crit_chance
		Elements.hit(swarm, i, damage * (stats.crit_mult if crit else 1.0), Elements.LIGHTNING, crit)
		Juice.burst(at, swarm.body_height * 0.6, COLOR, 4, 4.0, 0.35, 0.3, 2.0)
		points.append(Vector3(at.x, swarm.body_height * 0.6, at.y))
		damage *= FALLOFF
		target = _nearest(at, JUMP_RANGE, hit)
		if target.is_empty():
			break
	_arcs.append({"points": points, "life": ARC_LIFE})
	Juice.flash(first["swarm"].pos[first["index"]], COLOR, 3.0, 7.0, 0.15)


## The closest living enemy within `max_dist` of `from` whose id isn't in
## `skip`, as {swarm, index}, or {} if there is none.
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


func _draw_arcs(delta: float) -> void:
	_mesh.clear_surfaces()
	if _arcs.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3(0, 30, 20)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in _arcs:
		arc["life"] -= delta
		var fade: float = clampf(arc["life"] / ARC_LIFE, 0.0, 1.0)
		var pts: PackedVector3Array = arc["points"]
		for s in pts.size() - 1:
			var jagged := _jag(pts[s], pts[s + 1])
			_ribbon(jagged, eye, 0.45, Color(COLOR, 0.35 * fade))
			_ribbon(jagged, eye, 0.1, Color(1, 1, 1, fade))
	_mesh.surface_end()
	_arcs = _arcs.filter(func(a: Dictionary) -> bool: return a["life"] > 0.0)


## A zig-zag between two points, new every frame so the arc flickers.
func _jag(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array([a])
	var steps := 6
	var side := (b - a).cross(Vector3.UP).normalized()
	for k in range(1, steps):
		var t := float(k) / steps
		var p := a.lerp(b, t)
		p += side * randf_range(-0.45, 0.45) + Vector3.UP * randf_range(-0.3, 0.3)
		out.append(p)
	out.append(b)
	return out


func _ribbon(pts: PackedVector3Array, eye: Vector3, width: float, color: Color) -> void:
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var side := (b - a).cross(eye - a).normalized() * width * 0.5
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(a - side)
		_mesh.surface_add_vertex(a + side)
		_mesh.surface_add_vertex(b + side)
		_mesh.surface_add_vertex(a - side)
		_mesh.surface_add_vertex(b + side)
		_mesh.surface_add_vertex(b - side)
