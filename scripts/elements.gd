class_name Elements
extends RefCounted
## Elemental damage, statuses and reactions. Every weapon hits enemies through
## hit(), which knows about three statuses:
##
##   Chill (frost)      slows the enemy to half speed
##   Shock (lightning)  the enemy takes 25% more damage from everything else
##   Burn (fire)        damage over time; may spread to neighbors on death
##
## and three reactions between them:
##
##   Shatter   lightning hits a chilled enemy: an ice burst hurts and chills
##             everything around it
##   Melt      fire hits a chilled enemy: that hit deals 2.5x
##   Overload  fire hits a shocked enemy, or lightning a burning one: an
##             explosion
##
## Area effects (Shatter, Overload, fire spreading) can't run in the middle of
## a hit, because the caller is usually iterating a spatial hash query and a
## new query would overwrite its results. They are queued and run in flush(),
## which main.gd calls once a frame after all the weapons.

enum { NONE, FIRE, FROST, LIGHTNING }

const CHILL_TIME := 2.5
const SHOCK_TIME := 3.0
const BURN_TIME := 3.0
const SHOCK_BONUS := 1.25
const MELT_MULT := 2.5
const SPREAD_CHANCE := 0.35
## At most this many queued area effects run per frame; the rest are dropped.
const MAX_PER_FLUSH := 24

const COLORS := {
	FIRE: Color(1.0, 0.5, 0.15),
	FROST: Color(0.55, 0.85, 1.0),
	LIGHTNING: Color(0.75, 0.6, 1.0),
}

static var player: Player
## Multiplies how long chill lasts (the Frozen Wastes double it).
static var chill_scale := 1.0
static var swarms: Array[EnemySwarm] = []
static var _queue: Array[Dictionary] = []
static var _text_ready := {}
## Who is hitting right now (each weapon sets it before its hits), and the
## damage really dealt by each this run, for the run report.
static var source := "Other"
static var damage_by := {}


## Credits `amount` of real damage to `who` (or the current source).
static func record(amount: float, who := "") -> void:
	if amount > 0.0:
		var k := who if who != "" else source
		damage_by[k] = damage_by.get(k, 0.0) + amount


static func reset() -> void:
	player = null
	chill_scale = 1.0
	swarms = []
	_queue.clear()
	_text_ready.clear()
	source = "Other"
	damage_by.clear()


static func has_power(id: String) -> bool:
	return player != null and player.stats.powers.has(id)


## Damages enemy `i` of `swarm` with `element`, applying statuses and
## reactions, and shows the damage number. Returns true if it died.
static func hit(swarm: EnemySwarm, i: int, amount: float, element := NONE, crit := false) -> bool:
	if swarm.hp[i] <= 0.0:
		return false
	if element == NONE and has_power("ember_ring") and randf() < 0.15:
		element = FIRE
	var at := swarm.pos[i]
	var react := player.stats.reaction_damage if player else 1.0
	match element:
		LIGHTNING:
			if swarm.chill[i] > 0.0:
				swarm.chill[i] = 0.0
				_queue.append({"kind": "shatter", "at": at, "damage": maxf(amount, 10.0) * 1.5 * react})
			elif swarm.burn[i] > 0.0:
				swarm.burn[i] = 0.0
				_queue.append({"kind": "overload", "at": at, "damage": maxf(amount, 10.0) * 2.0 * react})
		FIRE:
			if swarm.chill[i] > 0.0:
				swarm.chill[i] = 0.0
				amount *= MELT_MULT * react
				_text(at, "MELT", COLORS[FIRE])
				Sound.play("melt")
			elif swarm.shock[i] > 0.0:
				swarm.shock[i] = 0.0
				_queue.append({"kind": "overload", "at": at, "damage": maxf(amount, 10.0) * 2.0 * react})
	if swarm.shock[i] > 0.0 and element != LIGHTNING:
		amount *= SHOCK_BONUS

	var before := swarm.hp[i]
	var killed := swarm.damage(i, amount)
	record(before - maxf(swarm.hp[i], 0.0))
	Juice.number(at, amount, crit, COLORS.get(element, Color.WHITE).lightened(0.35))
	if not killed:
		apply_status(swarm, i, element)
	if crit and has_power("blood_seal"):
		player.heal(1.0)
	return killed


static func apply_status(swarm: EnemySwarm, i: int, element: int) -> void:
	match element:
		FROST:
			swarm.chill[i] = CHILL_TIME * chill_scale
		LIGHTNING:
			swarm.shock[i] = SHOCK_TIME
		FIRE:
			if swarm.burn[i] <= 0.0:
				Sound.play("ignite")
			swarm.burn[i] = BURN_TIME
			swarm.burn_dps[i] = maxf(swarm.burn_dps[i], player.stats.burn_dps if player else 6.0)
		_:
			return
	swarm.mark_afflicted(i)


## hit() on every enemy within `r` of `center`. Use it from regular weapon
## code, not from inside another hit (it runs its own query).
static func hit_area(center: Vector2, r: float, amount: float, element := NONE, crit_chance := 0.0, crit_mult := 1.5) -> void:
	for swarm in swarms:
		var n := swarm.grid.query(center, r + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var crit := randf() < crit_chance
			hit(swarm, res[k], amount * (crit_mult if crit else 1.0), element, crit)


## A burning enemy died: maybe set its neighbors on fire.
static func queue_spread(at: Vector2, dps: float) -> void:
	# The Pyromancer's "pyre": fire always spreads.
	if randf() < SPREAD_CHANCE or has_power("pyre"):
		_queue.append({"kind": "spread", "at": at, "damage": dps})


## Runs the queued area effects. Call once a frame, after the weapons.
static func flush() -> void:
	if _queue.is_empty():
		return
	var work := _queue
	_queue = []
	for k in mini(work.size(), MAX_PER_FLUSH):
		var e: Dictionary = work[k]
		var at: Vector2 = e["at"]
		match e["kind"]:
			"shatter":
				_area(at, 2.6, e["damage"], FROST)
				Juice.ring(at, COLORS[FROST], 18, 6.0, 0.4, 0.35)
				Juice.burst(at, 1.0, Color(0.8, 0.95, 1.0), 10, 5.0, 0.35, 0.4, 3.0)
				Juice.flash(at, COLORS[FROST], 3.0, 6.0, 0.2)
				_text(at, "SHATTER", COLORS[FROST])
				Sound.play("shatter")
			"overload":
				_area(at, 3.0, e["damage"], NONE)
				Juice.ring(at, Color(1.0, 0.6, 0.9), 22, 8.0, 0.5, 0.4)
				Juice.burst(at, 1.0, COLORS[FIRE], 14, 6.0, 0.45, 0.5, 4.0)
				Juice.flash(at, Color(1.0, 0.55, 0.6), 4.0, 8.0, 0.25)
				Juice.shake(0.08)
				_text(at, "OVERLOAD", Color(1.0, 0.55, 0.85))
				Sound.play("overload")
			"spread":
				for swarm in swarms:
					var n := swarm.grid.query(at, 2.2 + swarm.radius)
					var res := swarm.grid.results
					for j in n:
						var i := res[j]
						if swarm.hp[i] > 0.0:
							swarm.burn[i] = BURN_TIME
							swarm.burn_dps[i] = maxf(swarm.burn_dps[i], e["damage"])
							swarm.mark_afflicted(i)
				Juice.burst(at, 0.6, COLORS[FIRE], 6, 3.0, 0.35, 0.4, 2.5)


## Damage (and a status) to everything near `at`, without new reactions, so
## effects can't chain forever.
static func _area(at: Vector2, r: float, amount: float, element: int) -> void:
	for swarm in swarms:
		var n := swarm.grid.query(at, r + swarm.radius)
		var res := swarm.grid.results
		for k in n:
			var i := res[k]
			if swarm.hp[i] <= 0.0:
				continue
			var before := swarm.hp[i]
			var killed := swarm.damage(i, amount)
			record(before - maxf(swarm.hp[i], 0.0), "Reactions")
			if not killed:
				apply_status(swarm, i, element)


## Reaction names float up like damage numbers, at most a few a second each.
static func _text(at: Vector2, text: String, color: Color) -> void:
	var now := Time.get_ticks_msec()
	if now < _text_ready.get(text, 0):
		return
	_text_ready[text] = now + 250
	if Juice.numbers:
		Juice.numbers.show_text(at, text, color)
