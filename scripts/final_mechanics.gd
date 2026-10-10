class_name FinalMechanics
extends Node3D
## Each realm's final boss has one signature problem to solve, on top of the
## shared slams, shot rings and summons (BossDirector):
##
##   The Lich King       at 66% and 33% health he wraps himself in a soul ward
##                       and raises three phylacteries around the hero. While
##                       any stand he takes no damage; shatter them.
##   The Frost Colossus  every 12 s he cracks the ground: four lines of ice
##                       spikes race out from him (telegraphed, step off
##                       them). Then he's exposed for 3 s: double damage.
##   The Ashen Tyrant    four cinder seals around him take 75% of his damage.
##                       He calls meteors down on the hero; lure each one onto
##                       a seal (stand by it) to break it.

const WARD_THRESHOLDS := [0.66, 0.33]
const FRACTURE_INTERVAL := 12.0
const FRACTURE_WINDUP := 1.2
const FRACTURE_LENGTH := 14.0
const FRACTURE_WIDTH := 1.4
const EXPOSED_TIME := 3.0
const METEOR_INTERVAL := 2.6
const METEOR_WINDUP := 1.5
const METEOR_RADIUS := 2.4
const SEAL_RADIUS := 1.6

## What the HUD shows under the boss bar ("" for nothing).
var hint := ""

var _final: EnemySwarm
var _wards: EnemySwarm
var _player: Player
var _director: WaveDirector
var _kind := ""
var _max_hp := 0.0
var _ward_step := 0
var _warded := false
var _timer := 5.0
var _exposed := 0.0
## Fracture lines winding up: {"from", "dir", "t", "nodes": [MeshInstance3D]}
var _lines: Array[Dictionary] = []
## Seals: {"at", "node"}; meteors: {"at", "t", "ring", "fill"}
var _seals: Array[Dictionary] = []
var _meteors: Array[Dictionary] = []
var _line_mat: ShaderMaterial
var _cleaned := false


func setup(final: EnemySwarm, wards: EnemySwarm, player: Player, director: WaveDirector) -> void:
	_final = final
	_wards = wards
	_player = player
	_director = director
	_kind = {"graveyard": "lich", "frozen": "colossus", "ember": "tyrant"}.get(Realm.current, "lich")
	_line_mat = preload("res://scripts/visual/combat_visuals.gd").warning_material(Color(0.55, 0.85, 1.0, 0.45), 1.0, true)
	refresh_warnings()


## The fracture lines in the current warning style.
func refresh_warnings() -> void:
	if _line_mat:
		_line_mat.set_shader_parameter("color", Juice.warning_color(Color(0.55, 0.85, 1.0, 0.45)))


func kind() -> String:
	return _kind


## main.gd calls this every frame while the final boss lives.
func tick(delta: float) -> void:
	var i := _boss_index()
	if i < 0:
		if not _cleaned and _max_hp > 0.0:
			_cleaned = true
			_cleanup()
		return
	if _max_hp <= 0.0:
		_max_hp = _final.hp[i]
		if _kind == "tyrant":
			_place_seals(_final.pos[i])
	match _kind:
		"lich": _lich(i)
		"colossus": _colossus(i, delta)
		"tyrant": _tyrant(i, delta)


func _boss_index() -> int:
	for i in _final.count:
		if _final.hp[i] > 0.0:
			return i
	return -1


# --- the Lich King: phylacteries -----------------------------------------------------

func _lich(i: int) -> void:
	var frac := _final.hp[i] / _max_hp
	if not _warded and _ward_step < WARD_THRESHOLDS.size() and frac <= WARD_THRESHOLDS[_ward_step]:
		_ward_step += 1
		_warded = true
		_final.damage_taken = 0.0
		var hero := _player.pos2
		for k in 3:
			var at := hero + Vector2.from_angle(TAU * k / 3.0 + randf()) * 8.0
			if Obstacles.blocked(at, 1.0):
				at = hero + Vector2.from_angle(TAU * k / 3.0) * 6.0
			_wards.spawn(at, _director.hp_multiplier() * 1.5)
		Sound.play("boss_roar", 0.7)
		Juice.ring(_final.pos[i], Color(0.6, 0.9, 1.0), 40, 10.0, 0.6, 0.6)
	if _warded:
		hint = "Soul ward!  Shatter the phylacteries (%d left)" % _wards.alive_count()
		if Engine.get_process_frames() % 20 == 0:
			Juice.ring(_final.pos[i], Color(0.6, 0.9, 1.0, 0.6), 16, 4.0, 0.4, 0.4)
		if _wards.alive_count() == 0:
			_warded = false
			_final.damage_taken = 1.0
			Sound.play("shatter", 0.6)
			Juice.flash(_final.pos[i], Color(0.6, 0.9, 1.0), 6.0, 12.0, 0.5)
	else:
		hint = ""


# --- the Frost Colossus: fracture, then exposed ------------------------------------------

func _colossus(i: int, delta: float) -> void:
	var at := _final.pos[i]
	if _exposed > 0.0:
		_exposed -= delta
		_final.damage_taken = 2.0
		hint = "EXPOSED!  Double damage"
		if _exposed <= 0.0:
			_final.damage_taken = 1.0
			hint = ""
	_timer -= delta
	if _timer <= 0.0 and _lines.is_empty():
		_timer = FRACTURE_INTERVAL
		var aim := (_player.pos2 - at).normalized()
		for k in 4:
			_add_line(at, aim.rotated(k * TAU / 4.0 + 0.0))
		Sound.play("telegraph", 0.7)
		Sound.play("boss_roar", 1.2, -4.0)
	var j := _lines.size() - 1
	while j >= 0:
		var line := _lines[j]
		line["t"] += delta
		var mesh: MeshInstance3D = line["node"]
		var grow := clampf(line["t"] / FRACTURE_WINDUP, 0.0, 1.0)
		mesh.scale = Vector3(1.0, 1.0, maxf(grow, 0.05))
		if line["t"] >= FRACTURE_WINDUP:
			_strike_line(line)
			mesh.queue_free()
			_lines.remove_at(j)
			if _lines.is_empty():
				_exposed = EXPOSED_TIME
				Juice.shake(0.5)
		j -= 1


func _add_line(from: Vector2, dir: Vector2) -> void:
	var strip := PlaneMesh.new()
	strip.size = Vector2(FRACTURE_WIDTH, FRACTURE_LENGTH)
	strip.center_offset = Vector3(0, 0, -FRACTURE_LENGTH * 0.5)
	strip.material = _line_mat
	var node := MeshInstance3D.new()
	node.mesh = strip
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(from.x, 0.05, from.y)
	node.rotation.y = atan2(-dir.x, -dir.y)
	add_child(node)
	_lines.append({"from": from, "dir": dir, "t": 0.0, "node": node})


func _strike_line(line: Dictionary) -> void:
	var from: Vector2 = line["from"]
	var dir: Vector2 = line["dir"]
	var rel := _player.pos2 - from
	var along := rel.dot(dir)
	var off := absf(rel.dot(dir.orthogonal()))
	if along > 0.0 and along < FRACTURE_LENGTH and off < FRACTURE_WIDTH * 0.5 + Player.RADIUS and not _player.is_dashing():
		_player.take_damage(25.0 + 10.0 * _director.hp_scale, "%s's fracture" % _final.display_name)
		Sound.play("hurt")
	for k in 7:
		var p := from + dir * (k + 1) * FRACTURE_LENGTH / 7.0
		Juice.burst(p, 0.4, Color(0.7, 0.9, 1.0), 6, 4.0, 0.45, 0.5, 5.0)
	Sound.play("ice_impact")


# --- the Ashen Tyrant: cinder seals and meteors ------------------------------------------

func _place_seals(center: Vector2) -> void:
	for k in 4:
		var at := center + Vector2.from_angle(TAU * k / 4.0 + PI / 4.0) * 7.0
		var root := Node3D.new()
		root.position = Vector3(at.x, 0.0, at.y)
		add_child(root)
		var mi := MeshInstance3D.new()
		mi.mesh = AssetProps.mesh("brimstone_vent")
		mi.scale = Vector3.ONE * 0.8
		root.add_child(mi)
		HazardDirector.make_decal(root, Vector2.ZERO, Color(1.0, 0.5, 0.15, 0.7), 0.85, SEAL_RADIUS * 2.0)
		_seals.append({"at": at, "node": root})


func _tyrant(i: int, delta: float) -> void:
	_final.damage_taken = 0.25 if not _seals.is_empty() else 1.0
	hint = "Cinder seals shield him (%d)  ·  lure his meteors onto them" % _seals.size() if not _seals.is_empty() else ""
	_timer -= delta
	if _timer <= 0.0:
		_timer = METEOR_INTERVAL
		var at := _player.pos2
		var ring := HazardDirector.make_warning(self, at, Color(1.0, 0.35, 0.1, 0.8), 1.0, METEOR_RADIUS * 2.0)
		var fill := HazardDirector.make_warning(self, at, Color(1.0, 0.45, 0.1, 0.35), 0.0, METEOR_RADIUS * 2.0)
		fill.scale = Vector3.ONE * 0.05
		_meteors.append({"at": at, "t": 0.0, "ring": ring, "fill": fill})
		Sound.play("telegraph", 1.2)
	var j := _meteors.size() - 1
	while j >= 0:
		var m := _meteors[j]
		m["t"] += delta
		(m["fill"] as MeshInstance3D).scale = Vector3.ONE * clampf(m["t"] / METEOR_WINDUP, 0.05, 1.0)
		if m["t"] >= METEOR_WINDUP:
			var at: Vector2 = m["at"]
			if _player.pos2.distance_to(at) <= METEOR_RADIUS + Player.RADIUS and not _player.is_dashing():
				_player.take_damage(18.0 + 8.0 * _director.hp_scale, "%s's meteors" % _final.display_name)
			Sound.play("meteor")
			Juice.flash(at, Color(1.0, 0.5, 0.2), 6.0, 10.0, 0.4)
			Juice.burst(at, 0.4, Color(1.0, 0.5, 0.15), 24, 6.0, 0.5, 0.6, 5.0)
			_break_seals_near(at)
			m["ring"].queue_free()
			m["fill"].queue_free()
			_meteors.remove_at(j)
		j -= 1


func _break_seals_near(at: Vector2) -> void:
	var k := _seals.size() - 1
	while k >= 0:
		if (_seals[k]["at"] as Vector2).distance_to(at) <= METEOR_RADIUS + SEAL_RADIUS:
			Juice.ring(_seals[k]["at"], Color(1.0, 0.6, 0.2), 30, 8.0, 0.5, 0.5)
			Sound.play("shatter", 0.5)
			(_seals[k]["node"] as Node3D).queue_free()
			_seals.remove_at(k)
		k -= 1


## The seals still standing (for tests and the HUD).
func seals_left() -> int:
	return _seals.size()


func _cleanup() -> void:
	hint = ""
	for s in _seals:
		(s["node"] as Node3D).queue_free()
	_seals.clear()
	for m in _meteors:
		m["ring"].queue_free()
		m["fill"].queue_free()
	_meteors.clear()
	for l in _lines:
		(l["node"] as Node3D).queue_free()
	_lines.clear()
	if _wards:
		_wards.despawn_all()
