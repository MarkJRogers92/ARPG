class_name BuildSynergies
extends RefCounted
## Pure-data API for the three rank-one synergy cards. Primary code feeds this
## on_hit() calls before Elements.hit() and on_dash() on a successful dash,
## then drains the queued pulses after the weapons step via Elements.hit_area().
## Cooldowns run on combat delta; the synergy only fires when the card is owned
## AND the affected systems are actually live.

const RELAY_COOLDOWN := 0.75
const ESCORT_COOLDOWN := 1.0
const RELAY_RADIUS := 1.6
const ESCORT_RADIUS := 1.6
const WAKE_RADIUS := 0.7
const MAX_QUEUE := 5

var _queue: Array[Dictionary] = []
var _relay_cd: float = 0.0
var _escort_cd: float = 0.0

static func live(id: String, stats: PlayerStats) -> bool:
	if stats == null or Upgrades.level_of(id, stats) <= 0: return false
	match id:
		"synergy_relay": return stats.lightning_level > 0 and Upgrades._has_chill_source(stats)
		"synergy_escort": return stats.minion_max > 0 and Upgrades._has_burn_source(stats)
		"synergy_wake": return stats.orbit_level > 0
	return false


## Called before a weapon/ability damages enemy `index` in `swarm`. `who` is the
## source name used by the weapon (e.g. "Chain Lightning", "Soul Army"),
## `element` is the Elements enum for the hit, and `amount` is the damage value
## that will be passed to Elements.hit().
func on_hit(player: Player, swarm: EnemySwarm, index: int, who: String, element: int, amount: float) -> void:
	if player == null or player.dead or swarm == null or index < 0 or index >= swarm.count or swarm.hp[index] <= 0.0 or amount <= 0.0:
		return
	var stats := player.stats
	if stats == null:
		return

	if live("synergy_relay", stats) and _relay_cd <= 0.0 \
			and who == "Chain Lightning" and element == Elements.LIGHTNING and swarm.chill[index] > 0.0:
		var dir := (swarm.pos[index] - player.pos2).normalized()
		if dir.is_zero_approx():
			dir = Vector2(0, -1)
		_enqueue({
			"at": swarm.pos[index] + dir * 2.0,
			"radius": RELAY_RADIUS,
			"damage": amount * 0.5,
			"element": Elements.FROST,
			"source": "Frost Relay",
		})
		_relay_cd = RELAY_COOLDOWN

	if live("synergy_escort", stats) and _escort_cd <= 0.0 \
			and who == "Soul Army" and swarm.burn[index] > 0.0:
		_enqueue({
			"at": swarm.pos[index],
			"radius": ESCORT_RADIUS,
			"damage": stats.minion_damage * 0.35,
			"element": Elements.FIRE,
			"source": "Ashen Escort",
		})
		_escort_cd = ESCORT_COOLDOWN


## Called once on a successful dash. `direction` is the ground-plane dash
## direction; if zero a default forward vector is used.
func on_dash(player: Player, direction: Vector2) -> void:
	if player == null or player.dead:
		return
	var stats := player.stats
	if not live("synergy_wake", stats):
		return
	var dir := direction.normalized()
	if dir.is_zero_approx():
		dir = Vector2(0, -1)
	var origin := player.pos2
	for offset in [1.0, 2.0, 3.0]:
		_enqueue({
			"at": origin + dir * offset,
			"radius": WAKE_RADIUS,
			"damage": stats.orbit_damage * 0.4,
			"element": Elements.NONE,
			"source": "Blade Wake",
		})
		if _queue.size() >= MAX_QUEUE:
			break


## Advance cooldowns by `delta` seconds of combat time.
func tick(delta: float) -> void:
	_relay_cd = maxf(_relay_cd - delta, 0.0)
	_escort_cd = maxf(_escort_cd - delta, 0.0)


## Return and clear all queued pulses. Each pulse is a dictionary with the keys
## at, radius, damage, element, source expected by Elements.hit_area().
func drain() -> Array[Dictionary]:
	var out := _queue.duplicate()
	_queue.clear()
	return out


## Clear queued pulses and cooldowns (e.g. on run start).
func reset() -> void:
	_queue.clear()
	_relay_cd = 0.0
	_escort_cd = 0.0


func _enqueue(pulse: Dictionary) -> void:
	if _queue.size() < MAX_QUEUE:
		_queue.append(pulse)
