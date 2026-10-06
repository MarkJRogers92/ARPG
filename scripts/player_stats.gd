class_name PlayerStats
extends RefCounted
## Everything upgrades can change. Plain data, so it's easy to save or display.

var max_hp := 100.0
var hp := 100.0
var regen := 0.0
var move_speed := 6.0
var pickup_radius := 3.0

# Magic Bolt: auto-fires at the nearest enemy.
var bolt_damage := 10.0
var bolt_cooldown := 0.5
var bolt_count := 1
var bolt_pierce := 1
var bolt_speed := 22.0
var bolt_range := 16.0

# Frost Aura: damages everything nearby. Locked until aura_level > 0.
var aura_level := 0
var aura_damage := 5.0
var aura_radius := 3.5
var aura_interval := 0.5

var level := 1
var xp := 0
var xp_to_next := 5

## upgrade id -> times taken
var upgrade_levels := {}


func xp_for_level(lvl: int) -> int:
	return int(4.0 + lvl * 3.5 + pow(lvl, 1.5))
