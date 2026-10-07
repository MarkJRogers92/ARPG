class_name FuneralBell
extends Node3D
## The Funeral Bell: every enemy that dies near the hero adds a toll (the
## army's kills count too). When the bell is full it rings: a shockwave
## around the hero that hurts everything in reach and hurls the horde back.
## The bell's own kills don't refill it, so it can't ring itself forever.
##
## Unlocked and improved by the "bell" upgrade (see Upgrades.DEFS).

const NEAR := 11.0
const COLOR := Color(0.85, 0.8, 1.0)

var _player: Player
var _swarms: Array[EnemySwarm] = []
## Tolls gathered toward the next ring (see PlayerStats.bell_cost).
var charge := 0.0
var _ringing := false


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms


## 0..1 toward the next ring, for the HUD (-1 when locked).
func fraction() -> float:
	var stats := _player.stats
	return charge / float(stats.bell_cost) if stats.bell_level > 0 else -1.0


## main.gd calls this for every kill.
func on_kill(at: Vector2) -> void:
	var stats := _player.stats
	if stats.bell_level <= 0 or _ringing:
		return
	if at.distance_squared_to(_player.pos2) > NEAR * NEAR:
		return
	charge += 1.0
	if charge >= stats.bell_cost:
		charge = 0.0
		ring()


func ring() -> void:
	var stats := _player.stats
	var at := _player.pos2
	_ringing = true
	Elements.hit_area(at, stats.bell_radius, stats.bell_damage, Elements.NONE, stats.crit_chance, stats.crit_mult)
	# The kills that queued hit causes land in Elements.flush(), later this
	# frame; they mustn't count toward the next ring.
	(func() -> void: _ringing = false).call_deferred()
	for swarm in _swarms:
		if not swarm.boss:
			swarm.knockback(at, stats.bell_radius, 6.0)
	Juice.ring(at, COLOR, 64, stats.bell_radius * 2.3, 0.6, 0.7)
	Juice.ring(at, Color(0.6, 0.55, 1.0), 40, stats.bell_radius * 1.4, 0.5, 0.5)
	Juice.flash(at, COLOR, 6.0, stats.bell_radius * 2.0, 0.4)
	Juice.shake(0.3)
	Juice.hitstop(0.06)
	Sound.play("funeral_bell")


func update(_delta: float) -> void:
	pass
