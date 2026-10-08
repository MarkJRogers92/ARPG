class_name HazardDirector
extends Node3D
## Each realm's environmental hazard. They're all telegraphed: a circle marks
## the spot and fills up, then the hazard lands. Hazards hit the horde too, so
## leading enemies into them is a tactic.
##
##   graves   a grave bursts open and ghouls climb out around it
##   ice      ice shards fall, hurting and chilling everything they hit
##   meteors  meteors fall, hurting and burning everything they hit

## "" turns hazards off. The realm sets this (see Realm).
@export var kind := ""
## No hazards before this game time.
@export var start_time := 60.0

var _director: WaveDirector
var _player: Player
var _spawn_swarm: EnemySwarm
var _timer := 0.0
## Each: {"at", "t", "windup", "radius", "ring", "fill", "falling"}
var _pending: Array[Dictionary] = []


func setup(director: WaveDirector, player: Player, spawn_swarm: EnemySwarm) -> void:
	_director = director
	_player = player
	_spawn_swarm = spawn_swarm


func tick(delta: float) -> void:
	if _director == null:
		return
	_update(delta)
	if kind == "" or _director.elapsed < start_time:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var t := _director.elapsed
	match kind:
		"graves":
			_timer = maxf(22.0 - t / 60.0, 10.0)
			_start(_player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 11.0), 1.6, 1.6, Color(0.6, 0.4, 1.0))
		"ice", "meteors":
			# Falls faster as the night goes on. Half of them aim where the
			# hero is heading.
			_timer = maxf(4.0 - t / 360.0, 1.8)
			var at := _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(1.0, 8.0)
			if randf() < 0.3:
				at = _player.pos2 + Vector2(_player.velocity.x, _player.velocity.z) * 0.7
			var color := Color(0.55, 0.85, 1.0) if kind == "ice" else Color(1.0, 0.45, 0.15)
			_start(at, 1.1 if kind == "ice" else 1.3, 1.9 if kind == "ice" else 2.3, color)


func _start(at: Vector2, windup: float, radius: float, color: Color) -> void:
	var ring := make_warning(self, at, Color(color, 0.85), 1.0, radius * 2.0)
	var fill := make_warning(self, at, Color(color, 0.3), 0.0, radius * 2.0)
	fill.scale = Vector3.ONE * 0.05
	var falling: MeshInstance3D = null
	if kind == "ice" or kind == "meteors":
		falling = MeshInstance3D.new()
		falling.mesh = Models.prop("ice") if kind == "ice" else Models.enemy_orb()
		falling.scale = Vector3.ONE * (0.6 if kind == "ice" else 3.0)
		falling.rotation_degrees = Vector3(180 if kind == "ice" else 90, 0, 0)
		falling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		falling.position = Vector3(at.x, 16.0, at.y)
		add_child(falling)
	_pending.append({"at": at, "t": 0.0, "windup": windup, "radius": radius,
			"ring": ring, "fill": fill, "falling": falling})


func _update(delta: float) -> void:
	var i := _pending.size() - 1
	while i >= 0:
		var h := _pending[i]
		h["t"] += delta
		var t: float = h["t"] / h["windup"]
		(h["fill"] as MeshInstance3D).scale = Vector3.ONE * clampf(t, 0.05, 1.0)
		var falling: MeshInstance3D = h["falling"]
		if falling:
			falling.position.y = lerpf(16.0, 0.6, t * t)
		if t >= 1.0:
			_land(h["at"], h["radius"])
			h["ring"].queue_free()
			h["fill"].queue_free()
			if falling:
				falling.queue_free()
			_pending.remove_at(i)
		i -= 1


func _land(at: Vector2, r: float) -> void:
	var t := _director.elapsed
	var hero_hit := _player.pos2.distance_to(at) <= r + Player.RADIUS and not _player.is_dashing()
	var near := _player.pos2.distance_to(at) < 10.0
	# Far-off impacts are quieter.
	var vol := -clampf((_player.pos2.distance_to(at) - 4.0) * 0.8, 0.0, 14.0)
	Sound.play({"graves": "grave", "ice": "ice_impact", "meteors": "meteor"}.get(kind, "grave"), 1.0, vol)
	match kind:
		"graves":
			var n := 4 + int(t / 180.0)
			for k in n:
				_spawn_swarm.spawn(at + Vector2.from_angle(TAU * k / n) * 1.2, _director.hp_multiplier())
			Juice.burst(at, 0.4, Color(0.45, 0.38, 0.3), 24, 5.0, 0.5, 0.6, 5.0)
			Juice.ring(at, Color(0.6, 0.4, 1.0), 20, 5.0, 0.45, 0.4)
			Juice.flash(at, Color(0.6, 0.4, 1.0), 3.0, 6.0, 0.3)
		"ice":
			Elements.source = "Hazards"
			Elements.hit_area(at, r, 20.0 * _director.hp_multiplier(), Elements.FROST)
			if hero_hit:
				_player.take_damage(7.0 + t / 90.0, CAUSES.get(kind, "Hazards"))
				_player.afflict(Elements.FROST)
			Juice.burst(at, 0.6, Color(0.8, 0.95, 1.0), 22, 6.0, 0.4, 0.5, 4.0)
			Juice.ring(at, Color(0.55, 0.85, 1.0), 24, r / 0.35, 0.45, 0.35)
			Juice.flash(at, Color(0.55, 0.85, 1.0), 3.0, 7.0, 0.25)
			if near:
				Juice.shake(0.12)
		"meteors":
			Elements.source = "Hazards"
			Elements.hit_area(at, r, 40.0 * _director.hp_multiplier(), Elements.FIRE)
			if hero_hit:
				_player.take_damage(7.0 + t / 90.0, CAUSES.get(kind, "Hazards"))
				_player.afflict(Elements.FIRE)
			Juice.burst(at, 0.6, Color(1.0, 0.5, 0.15), 30, 8.0, 0.55, 0.6, 6.0)
			Juice.burst(at, 0.4, Color(0.25, 0.2, 0.2), 14, 4.0, 0.6, 1.0, 3.0)
			Juice.ring(at, Color(1.0, 0.45, 0.15), 28, r / 0.35, 0.55, 0.4)
			Juice.flash(at, Color(1.0, 0.5, 0.2), 6.0, 10.0, 0.35)
			if near:
				Juice.shake(0.25)


## A circle painted on the ground (telegraphs). `ring` 1 = an outline, 0 = a
## filled disc. Shared with BossDirector.
## A decal that warns of damage to come: drawn bolder with the Bold warnings
## setting (Juice.warning_color()).
## What the death recap calls each hazard.
const CAUSES := {"graves": "Bursting graves", "ice": "Falling ice", "meteors": "Meteors"}


static func make_warning(parent: Node, at: Vector2, color: Color, ring: float, size: float) -> MeshInstance3D:
	return make_decal(parent, at, Juice.warning_color(color), ring, size)


static func make_decal(parent: Node, at: Vector2, color: Color, ring: float, size: float) -> MeshInstance3D:
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
	parent.add_child(mi)
	return mi
