class_name WaveDirector
extends Node
## Decides how fast enemies spawn and which type. The overall rate and enemy HP
## ramp up with time, and each enemy type declares when it appears and how
## common it is (the "Spawning" exports on its EnemySwarm), so a new type needs
## no changes here. Tune the exports to change the difficulty curve.

## Enemies per second at t=0.
@export var base_rate := 1.5
## Extra enemies per second, gained every second.
@export var rate_growth := 0.08
@export var max_spawn_per_frame := 60
## Enemy HP multiplier grows by 1.0 every this many seconds.
@export var hp_growth_seconds := 120.0

## Game time in seconds, counted from the first tick.
var elapsed := 0.0

var _swarms: Array[EnemySwarm] = []
var _weights: Array[float] = []
var _accum := 0.0


func setup(swarms: Array[EnemySwarm]) -> void:
	_swarms = swarms
	_weights.resize(swarms.size())


func tick(delta: float, center: Vector2) -> void:
	elapsed += delta
	_accum = minf(_accum + spawn_rate() * delta, max_spawn_per_frame + 1.0)
	var n := mini(int(_accum), max_spawn_per_frame)
	_accum -= n
	if n == 0:
		return

	var total := 0.0
	for i in _swarms.size():
		_weights[i] = _swarms[i].spawn_weight(elapsed)
		total += _weights[i]
	if total <= 0.0:
		return

	var hp_mult := hp_multiplier()
	for k in n:
		var swarm := _pick(randf() * total)
		swarm.spawn(EnemySwarm.random_ring_point(center, swarm.ring_min, swarm.ring_max), hp_mult)


## Enemies per second right now.
func spawn_rate() -> float:
	return base_rate + rate_growth * elapsed


func hp_multiplier() -> float:
	return 1.0 + elapsed / hp_growth_seconds


func _pick(roll: float) -> EnemySwarm:
	for i in _swarms.size():
		roll -= _weights[i]
		if roll < 0.0:
			return _swarms[i]
	return _swarms[-1]
