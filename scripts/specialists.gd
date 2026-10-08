class_name Specialists
extends Node3D
## What the hero sees and feels of the specialist enemies (see the
## "Specialists" exports on EnemySwarm):
##
##   Shieldbearers  direct hits glance off their shields; burn, freeze or
##                  blast them instead (or let the army do it).
##   Menders        every few seconds heal the horde inside their ring.
##   Bloaters       stop next to the hero, light up, and burst a moment later,
##                  hurting the hero and the horde alike. Killed with the fuse
##                  lit, they burst at once, so they chain.
##
## Each one is explained with a toast the first time it does its thing.
## Blasts can't run inside a swarm's step (they query every swarm and can set
## off more bloaters), so they are queued and go off in tick().

signal announced(text: String, color: Color)

## A mend restores this share of an enemy's full health.
const MEND_SHARE := 0.3
## A blast hurts the horde this many times the hero's damage, scaled with the
## night's enemy health like everything else.
const BLAST_HORDE_MULT := 2.5
const SHIELD_COLOR := Color(0.8, 0.85, 0.95)
const FUSE_COLOR := Color(1.0, 0.6, 0.2)

var _swarms: Array[EnemySwarm] = []
var _player: Player
var _director: WaveDirector
var _told := {}
## Blasts waiting for tick(): {"at", "swarm"}
var _blasts: Array[Dictionary] = []
## Fuse circles on the ground, by exploder id: {"ring", "fill", "t", "life"}
var _fuses := {}


func setup(swarms: Array[EnemySwarm], player: Player, director: WaveDirector) -> void:
	_swarms = swarms
	_player = player
	_director = director
	for s in swarms:
		if s.direct_taken < 1.0:
			s.shield_blocked.connect(_on_blocked.bind(s))
		if s.mend_interval > 0.0:
			s.mend_called.connect(_on_mend.bind(s))
		if s.fuse_range > 0.0:
			s.fuse_lit.connect(_on_fuse_lit.bind(s))
			s.detonated.connect(_on_detonated.bind(s))


func tick(delta: float) -> void:
	var work := _blasts
	_blasts = []
	for b in work:
		_blast(b["at"], b["swarm"])
	for id: int in _fuses.keys():
		var f: Dictionary = _fuses[id]
		f["t"] += delta
		var fill: MeshInstance3D = f["fill"]
		fill.scale = Vector3.ONE * clampf(f["t"] / f["life"], 0.05, 1.0)
		if f["t"] > f["life"] + 0.2:
			_clear_fuse(id)


## How many fuse circles are on the ground (for tests).
func fuse_count() -> int:
	return _fuses.size()


func _tell(s: EnemySwarm, text: String, color: Color) -> void:
	if _told.has(s):
		return
	_told[s] = true
	announced.emit(text, color)


func _on_blocked(at: Vector2, s: EnemySwarm) -> void:
	Juice.burst(at, 0.9, SHIELD_COLOR, 4, 4.0, 0.25, 0.25, 1.5)
	Sound.play("bolt_hit", 1.6, -6.0)
	_tell(s, "%ss shrug off bolts and blades. Burn, freeze or blast them." % s.display_name, SHIELD_COLOR)


## Heals every living non-boss enemy in the ring, up to its full health.
func _on_mend(at: Vector2, s: EnemySwarm) -> void:
	var mult := _director.hp_multiplier() if _director else 1.0
	var healed := 0
	for swarm in _swarms:
		if swarm.boss or swarm.count == 0:
			continue
		var n := swarm.grid.query(at, s.mend_radius + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			var hp := swarm.hp[i]
			if hp <= 0.0:
				continue
			var full := swarm.max_hp * mult * (swarm.elite_hp_mult if swarm.is_elite(i) else 1.0)
			if hp < full:
				swarm.hp[i] = minf(hp + full * MEND_SHARE, full)
				healed += 1
				if healed <= 8:
					Juice.burst(swarm.pos[i], 1.0, EnemySwarm.MEND_COLOR, 2, 1.5, 0.3, 0.5, 2.5)
	Juice.ring(at, EnemySwarm.MEND_COLOR, 24, s.mend_radius * 1.6, 0.35, 0.6)
	if healed > 0:
		Sound.play("heal", 0.8, -10.0)
		_tell(s, "A %s heals the horde in its ring. Kill it first." % s.display_name, EnemySwarm.MEND_COLOR)


func _on_fuse_lit(id: int, at: Vector2, s: EnemySwarm) -> void:
	_clear_fuse(id)
	var size := s.blast_radius * 2.0 / 0.82
	var ring := HazardDirector.make_decal(self, at, Color(FUSE_COLOR, 0.85), 1.0, size)
	var fill := HazardDirector.make_decal(self, at, Color(1.0, 0.4, 0.1, 0.35), 0.0, size)
	fill.scale = Vector3.ONE * 0.05
	_fuses[id] = {"ring": ring, "fill": fill, "t": 0.0, "life": s.fuse_time}
	Sound.play("telegraph", 1.4, -4.0)
	_tell(s, "A %s is about to burst! Get clear or dash." % s.display_name, FUSE_COLOR)


func _on_detonated(id: int, at: Vector2, s: EnemySwarm) -> void:
	_clear_fuse(id)
	_blasts.append({"at": at, "swarm": s})


func _clear_fuse(id: int) -> void:
	var f: Dictionary = _fuses.get(id, {})
	if f.is_empty():
		return
	(f["ring"] as MeshInstance3D).queue_free()
	(f["fill"] as MeshInstance3D).queue_free()
	_fuses.erase(id)


func _blast(at: Vector2, s: EnemySwarm) -> void:
	var r := s.blast_radius
	var element := s.shot_element
	if _player and not _player.dead and _player.pos2.distance_to(at) < r + Player.RADIUS:
		if not _player.is_dashing():
			_player.take_damage(s.blast_damage)
			_player.afflict(element)
			Sound.play("hurt")
			Juice.shake(0.3)
	var was := Elements.source
	Elements.source = "Blasts"
	var mult := _director.hp_multiplier() if _director else 1.0
	Elements.hit_area(at, r, s.blast_damage * BLAST_HORDE_MULT * mult, element)
	Elements.source = was
	var color: Color = Elements.COLORS.get(element, FUSE_COLOR)
	Juice.ring(at, color, 26, r * 2.6, 0.5, 0.45)
	Juice.burst(at, 0.8, color, 16, 6.0, 0.5, 0.5, 4.0)
	Juice.burst(at, 0.6, s.color, 8, 4.0, 0.4, 0.6, 3.0)
	Juice.flash(at, color, 4.0, r * 2.5, 0.25)
	Sound.play("overload", 0.8, -2.0)
