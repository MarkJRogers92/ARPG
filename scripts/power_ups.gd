class_name PowerUps
extends Node3D
## Power-ups: rare pickups that the dead leave behind. Each floats over a
## colored ring; walk over one to take it.
##
##   Bloodlust   +50% damage, weapons 30% faster, +15% speed, for 10 s
##   Vortex      every XP gem and soul on the ground flies to the hero
##   Frost Bomb  a freezing blast: hurts and chills everything near the hero
##   Aegis       a golden shield: no damage at all for 5 s
##
## Elites drop one now and then; any kill may, rarely, once the last drop is
## a while ago (`DROP_GAP`), so they don't flood a late-game horde.
## Bloodlust's modifiers are under the source SOURCE (never saved; see
## RunSave.REBUILT).

signal announced(text: String, color: Color)

const SOURCE := "powerup"
const KINDS := {
	"bloodlust": {"name": "Bloodlust", "color": Color(1.0, 0.3, 0.25), "desc": "+50% damage, faster weapons", "time": 10.0},
	"vortex": {"name": "Vortex", "color": Color(0.78, 0.5, 1.0), "desc": "every gem and soul comes to you", "time": 0.0},
	"frost_bomb": {"name": "Frost Bomb", "color": Color(0.6, 0.9, 1.0), "desc": "the horde around you freezes", "time": 0.0},
	"aegis": {"name": "Aegis", "color": Color(1.0, 0.82, 0.35), "desc": "nothing can hurt you", "time": 5.0},
}
const ORDER := ["bloodlust", "vortex", "frost_bomb", "aegis"]
const ELITE_CHANCE := 0.15
const KILL_CHANCE := 0.004
## After any drop, plain kills can't drop another for this long.
const DROP_GAP := 25.0
const MAX_ON_GROUND := 4
const LIFETIME := 40.0
const FROST_RADIUS := 16.0
const FROST_DAMAGE := 30.0

var _player: Player
var _director: WaveDirector
var _gems: Array[GemSwarm] = []
var _gap := 10.0
## On the ground: {"kind", "at", "node", "ring", "age"}
var _drops: Array[Dictionary] = []
## Seconds left of Bloodlust (Aegis's are the hero's shield_left).
var bloodlust_left := 0.0
var _bubble: MeshInstance3D


func setup(player: Player, director: WaveDirector, gems: Array[GemSwarm]) -> void:
	_player = player
	_director = director
	_gems = gems
	_bubble = MeshInstance3D.new()
	_bubble.mesh = Models.aegis_bubble()
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = false
	add_child(_bubble)


## A kill at `at`: maybe leave a power-up there.
func on_kill(at: Vector2, elite: bool) -> void:
	if _drops.size() >= MAX_ON_GROUND:
		return
	if elite and randf() < ELITE_CHANCE:
		drop(ORDER.pick_random(), at)
	elif _gap <= 0.0 and randf() < KILL_CHANCE:
		drop(ORDER.pick_random(), at)


func drop(kind: String, at: Vector2) -> void:
	_gap = DROP_GAP
	var color: Color = KINDS[kind]["color"]
	var node := MeshInstance3D.new()
	node.mesh = Models.power_up(kind)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(at.x, 1.0, at.y)
	node.scale = Vector3.ONE * 1.6
	add_child(node)
	var ring := HazardDirector.make_decal(self, at, Color(color, 0.65), 1.0, 1.8)
	_drops.append({"kind": kind, "at": at, "node": node, "ring": ring, "age": 0.0})
	Juice.ring(at, color, 18, 4.0, 0.4, 0.5)


func on_ground() -> int:
	return _drops.size()


func tick(delta: float) -> void:
	_gap -= delta
	var hero := _player.pos2
	var reach := maxf(1.3, _player.stats.pickup_radius * 0.45)
	var i := _drops.size() - 1
	while i >= 0:
		var d := _drops[i]
		d["age"] += delta
		var node: MeshInstance3D = d["node"]
		node.position.y = 1.0 + sin(d["age"] * 3.0) * 0.15
		node.rotation.y += delta * 2.2
		var fading: bool = d["age"] > LIFETIME - 5.0
		node.visible = not fading or fmod(d["age"], 0.4) < 0.25
		if hero.distance_to(d["at"]) <= reach:
			_take(d["kind"])
			_remove(i)
		elif d["age"] > LIFETIME:
			_remove(i)
		i -= 1
	if bloodlust_left > 0.0:
		bloodlust_left -= delta
		if bloodlust_left <= 0.0:
			_end_bloodlust()
	_bubble.visible = _player.shield_left > 0.0
	if _bubble.visible:
		_bubble.global_position = _player.global_position
		_bubble.scale = Vector3.ONE * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.01))


func _remove(i: int) -> void:
	var d := _drops[i]
	(d["node"] as MeshInstance3D).queue_free()
	(d["ring"] as MeshInstance3D).queue_free()
	_drops.remove_at(i)


func _take(kind: String) -> void:
	var k: Dictionary = KINDS[kind]
	var color: Color = k["color"]
	var hero := _player.pos2
	announced.emit("%s!  %s" % [k["name"], k["desc"]], color)
	Sound.play("shrine_done", 1.2, -2.0)
	Juice.ring(hero, color, 36, 8.0, 0.5, 0.6)
	Juice.burst(hero, 1.0, color, 20, 4.0, 0.4, 0.6, 5.0)
	match kind:
		"bloodlust":
			_end_bloodlust()
			bloodlust_left = k["time"]
			_player.stats.add_mods(SOURCE, [
				{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.5},
				{"stat": "bolt_rate", "op": PlayerStats.Op.MORE, "value": 0.3},
				{"stat": "scythe_rate", "op": PlayerStats.Op.MORE, "value": 0.3},
				{"stat": "move_speed", "op": PlayerStats.Op.MORE, "value": 0.15}])
			_player.stats.recalculate()
		"vortex":
			for g in _gems:
				g.pull_all()
			Juice.ring(hero, color, 48, 20.0, 0.6, 0.9)
		"frost_bomb":
			var mult := _director.hp_multiplier() if _director else 1.0
			Elements.source = "Frost Bomb"
			Elements.hit_area(hero, FROST_RADIUS, FROST_DAMAGE * mult, Elements.FROST)
			Juice.ring(hero, color, 64, FROST_RADIUS * 2.2, 0.7, 0.7)
			Juice.ring(hero, Color(1, 1, 1), 40, FROST_RADIUS * 1.4, 0.5, 0.5)
			Juice.flash(hero, color, 6.0, FROST_RADIUS, 0.5)
			Juice.shake(0.25)
			Sound.play("shatter", 0.7, 2.0)
		"aegis":
			_player.shield_left = maxf(_player.shield_left, k["time"])


func _end_bloodlust() -> void:
	bloodlust_left = 0.0
	_player.stats.remove_source(SOURCE)
	_player.stats.recalculate()


## What the HUD shows for the timed power-ups ("" for none), and its color.
func status() -> Array:
	var parts := []
	if bloodlust_left > 0.0:
		parts.append("Bloodlust %d s" % ceili(bloodlust_left))
	if _player.shield_left > 0.0:
		parts.append("Aegis %d s" % ceili(_player.shield_left))
	if parts.is_empty():
		return ["", Color.WHITE]
	return ["◆ " + "   ·   ".join(parts), KINDS["bloodlust" if bloodlust_left > 0.0 else "aegis"]["color"]]
