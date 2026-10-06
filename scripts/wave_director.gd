class_name WaveDirector
extends Node
## Decides what spawns and how fast. Spawn rate and enemy HP ramp up with
## time; tougher enemy types phase in later. Tune the exports to change the
## difficulty curve.

## Enemies per second at t=0.
@export var base_rate := 1.5
## Extra enemies per second, gained every second.
@export var rate_growth := 0.08
@export var max_spawn_per_frame := 60
## Enemy HP multiplier grows by 1.0 every this many seconds.
@export var hp_growth_seconds := 120.0
@export var brute_start_time := 45.0
## Fraction of spawns that are brutes once fully ramped.
@export var brute_max_share := 0.12

var _grunts: EnemySwarm
var _brutes: EnemySwarm
var _time := 0.0
var _accum := 0.0


func setup(grunts: EnemySwarm, brutes: EnemySwarm) -> void:
	_grunts = grunts
	_brutes = brutes


func tick(delta: float, center: Vector2) -> void:
	_time += delta
	_accum = minf(_accum + (base_rate + rate_growth * _time) * delta, max_spawn_per_frame + 1.0)
	var n := mini(int(_accum), max_spawn_per_frame)
	_accum -= n

	var hp_mult := 1.0 + _time / hp_growth_seconds
	var brute_share := clampf((_time - brute_start_time) / 300.0, 0.0, 1.0) * brute_max_share
	for k in n:
		var swarm := _brutes if randf() < brute_share else _grunts
		swarm.spawn(EnemySwarm.random_ring_point(center, swarm.ring_min, swarm.ring_max), hp_mult)
