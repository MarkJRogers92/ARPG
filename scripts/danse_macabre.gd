class_name DanseMacabre
extends RefCounted
## The army's ultimate, fed by overflow souls.
##
## A soul gathered while the army can't use it (it's at capacity) fills the
## Requiem meter instead of going to waste. At MAX, with at least MIN_MINIONS
## raised, the hero can call the Danse Macabre: for DURATION seconds every
## minion leaves its AI and circles the hero in an evenly spaced ring that
## widens and speeds up. The dancers can't be hurt, and every enemy they pass
## through takes damage (credited to "Danse Macabre" in the combat ledger) and
## is thrown outward. Then the army goes back to hunting and the meter is empty.
##
## This class is only the state and the maths. Army owns an instance, moves the
## minions (Army.step) and applies the damage (Army._dance_strike).

const SOURCE := "Danse Macabre"
const MAX := 40
const MIN_MINIONS := 3
const DURATION := 8.0
const RADIUS_START := 4.5
const RADIUS_END := 7.0
const SPEED_START := 1.5 # rad/s
const SPEED_END := 4.0
## A dancer hurts enemies this close to it, every TICK seconds.
const REACH := 1.4
const TICK := 0.25
## Per tick, a dancer's damage is its usual hit times this.
const DAMAGE_MULT := 1.5
## How far a tick throws an enemy outward (before its knockback resistance).
const KNOCKBACK := 1.6

## Requiem meter, 0..MAX.
var meter := 0
var active := false
var time := 0.0
var angle := 0.0
var _tick := 0.0


## One soul that the army couldn't use. Ignored while dancing.
func add_overflow(n := 1) -> void:
	if not active:
		meter = clampi(meter + n, 0, MAX)


func is_full() -> bool:
	return meter >= MAX


func can_start(minions: int) -> bool:
	return not active and is_full() and minions >= MIN_MINIONS


## Begins the dance (false if it can't).
func start(minions: int) -> bool:
	if not can_start(minions):
		return false
	active = true
	time = 0.0
	angle = 0.0
	_tick = 0.0
	return true


## 0..1 through the dance.
func progress() -> float:
	return clampf(time / DURATION, 0.0, 1.0)


func radius() -> float:
	return lerpf(RADIUS_START, RADIUS_END, progress())


func angular_speed() -> float:
	return lerpf(SPEED_START, SPEED_END, progress())


## Advances the dance. Returns true on the frame it ends (the meter is spent).
func advance(delta: float) -> bool:
	if not active:
		return false
	angle += angular_speed() * delta
	time += delta
	_tick += delta
	if time >= DURATION:
		finish()
		return true
	return false


## True (once per TICK) when the dancers should strike.
func strike_due() -> bool:
	if active and _tick >= TICK:
		_tick -= TICK
		return true
	return false


func finish() -> void:
	active = false
	time = 0.0
	angle = 0.0
	_tick = 0.0
	meter = 0


## Where dancer `i` of `n` stands: evenly spaced around `hero`.
static func slot(i: int, n: int, hero: Vector2, ring_angle: float, ring_radius: float) -> Vector2:
	return hero + Vector2.from_angle(ring_angle + TAU * i / maxf(n, 1.0)) * ring_radius


## The HUD line, e.g. "REQUIEM 23/40" (with the key hint once it's ready).
static func label(value: int, hint: String) -> String:
	if value >= MAX:
		return "REQUIEM READY  %s" % hint
	return "REQUIEM %d/%d" % [value, MAX]
