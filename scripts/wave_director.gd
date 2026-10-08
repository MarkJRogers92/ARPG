class_name WaveDirector
extends Node
## Decides how fast enemies spawn and which type. The overall rate and enemy HP
## ramp up with time, and each enemy type declares when it appears and how
## common it is (the "Spawning" exports on its EnemySwarm), so a new type needs
## no changes here. Tune the exports to change the difficulty curve.

## Enemies per second at t=0.
@export var base_rate := 1.2
## Extra enemies per second, gained every second.
@export var rate_growth := 0.04
## Extra enemies per second, gained every second squared: the late-game ramp.
@export var rate_acceleration := 0.0003
@export var max_spawn_per_frame := 60
## Enemy HP multiplier grows by 1.0 every this many seconds...
@export var hp_growth_seconds := 600.0
## ...plus (time / this) squared, so late enemies keep outscaling a maxed build.
## 0 turns the squared term off.
@export var hp_squared_seconds := 330.0
## The realm's difficulty: multiplies enemy HP and the spawn rate.
@export var hp_scale := 1.0
@export var rate_scale := 1.0
## Elites (see EnemySwarm) start appearing at this game time...
@export var elite_start_time := 50.0
## ...at this many per minute, growing by `elites_per_minute_growth` every
## minute up to `elites_per_minute_max`. A rate, not a share of spawns, so the
## huge late-game spawn rate doesn't flood the field (and the ground) with them.
@export var elites_per_minute := 1.5
@export var elites_per_minute_growth := 0.4
@export var elites_per_minute_max := 5.0

## Game time in seconds, counted from the first tick.
var elapsed := 0.0

## Pressure: the night pushes back against a hero who's walking through it.
## While the horde is being wiped out faster than it can gather and the hero
## is barely scratched, pressure climbs (more enemy health, and somewhat more
## enemies: the spawn rate rises with its square root, at most 1.6x); when
## the hero is hurting it eases off. 1 = the plain curve.
var pressure := 1.0
## How fast pressure builds, and how high it may go: the cap starts at 1 at
## `pressure_start` and grows by `pressure_ramp` a minute (Ascension makes it
## grow faster), up to `pressure_max`. Early on there's none: a hero is
## untouched then just because the horde is thin.
@export var pressure_rate := 0.03
@export var pressure_ramp := 2.0
@export var pressure_max := 20.0
@export var pressure_start := 300.0

var _swarms: Array[EnemySwarm] = []
var _weights: Array[float] = []
var _accum := 0.0
var _elite_accum := 0.0
## Campaign missions keep the real elapsed clock above, while enemy age is a
## separately tuned, capped input to the wave and HP curves.
var expedition_profile := false
var _profile_age_rate := 1.0
var _profile_age_cap := 900.0


func configure_expedition(profile: Dictionary) -> void:
	expedition_profile = true
	_profile_age_rate = maxf(float(profile.get("age_rate", 1.0)), 0.01)
	_profile_age_cap = maxf(float(profile.get("growth_cap", 900.0)), 1.0)
	base_rate = 0.48
	rate_growth = 0.0045
	rate_acceleration = 0.000004
	hp_growth_seconds = 600.0
	hp_squared_seconds = 330.0
	hp_scale = float(profile.get("hp_scale", 1.0))
	rate_scale = float(profile.get("spawn_rate", 1.0))
	pressure = 1.0
	pressure_start = INF
	elite_start_time = 45.0
	elites_per_minute = 1.0
	elites_per_minute_growth = 0.12
	elites_per_minute_max = 2.0


func profile_age() -> float:
	return minf(elapsed * _profile_age_rate, _profile_age_cap) if expedition_profile else elapsed


func setup(swarms: Array[EnemySwarm]) -> void:
	_swarms = swarms
	_weights.resize(swarms.size())


func tick(delta: float, center: Vector2) -> void:
	elapsed += delta
	var age := profile_age()
	_elite_accum = minf(_elite_accum + elite_rate() / 60.0 * delta, 3.0)
	_accum = minf(_accum + spawn_rate() * delta, max_spawn_per_frame + 1.0)
	var n := mini(int(_accum), max_spawn_per_frame)
	_accum -= n
	if n == 0:
		return

	var total := 0.0
	for i in _swarms.size():
		_weights[i] = _swarms[i].spawn_weight(age)
		total += _weights[i]
	if total <= 0.0:
		return

	var hp_mult := hp_multiplier()
	for k in n:
		var swarm := _pick(randf() * total)
		var elite := _elite_accum >= 1.0
		if elite:
			_elite_accum -= 1.0
		swarm.spawn(EnemySwarm.random_ring_point(center, swarm.ring_min, swarm.ring_max), hp_mult, elite)


## Raises `n` enemies of the types this hour would bring, in a ring around
## `center` (a resumed night gets its horde back this way).
func populate(center: Vector2, n: int) -> void:
	var total := 0.0
	for i in _swarms.size():
		_weights[i] = _swarms[i].spawn_weight(profile_age())
		total += _weights[i]
	if total <= 0.0:
		return
	var hp_mult := hp_multiplier()
	for k in n:
		var swarm := _pick(randf() * total)
		swarm.spawn(EnemySwarm.random_ring_point(center, 12.0, swarm.ring_max), hp_mult)


## Enemies per second right now.
func spawn_rate() -> float:
	var age := profile_age()
	return (base_rate + rate_growth * age + rate_acceleration * age * age) * rate_scale * minf(sqrt(pressure), 1.6)


## Elites per minute right now.
func elite_rate() -> float:
	var age := profile_age()
	if age < elite_start_time:
		return 0.0
	return minf(elites_per_minute + elites_per_minute_growth * (age - elite_start_time) / 60.0, elites_per_minute_max)


func hp_multiplier() -> float:
	var age := profile_age()
	var mult := 1.0 + age / hp_growth_seconds
	if hp_squared_seconds > 0.0:
		mult += pow(age / hp_squared_seconds, 2.0)
	return mult * hp_scale * pressure


## How many enemies should be alive around the hero at this point of the
## night, for pressure to stay put.
func crowd_target() -> float:
	return 40.0 + profile_age() * 0.45


## Called every frame by main.gd with the hero's health (0..1) and how many
## enemies are alive.
func update_pressure(delta: float, hero_hp: float, alive: int) -> void:
	if expedition_profile:
		pressure = 1.0
		return
	if elapsed < pressure_start:
		return
	if hero_hp < 0.45:
		pressure -= pressure_rate * 3.0 * delta
	elif hero_hp > 0.9:
		# Barely scratched: build. Faster still if the horde is being wiped out.
		pressure += pressure_rate * delta * (2.0 if alive < crowd_target() * 0.85 else 1.0)
	pressure = clampf(pressure, 1.0, pressure_cap())


## How high pressure may be right now.
func pressure_cap() -> float:
	return clampf(1.0 + (elapsed - pressure_start) / 60.0 * pressure_ramp, 1.0, pressure_max)


func _pick(roll: float) -> EnemySwarm:
	for i in _swarms.size():
		roll -= _weights[i]
		if roll < 0.0:
			return _swarms[i]
	return _swarms[-1]
