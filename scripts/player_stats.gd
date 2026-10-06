class_name PlayerStats
extends RefCounted
## Every number about the hero, built from base values plus modifiers.
##
## Run upgrades and equipped gear don't edit stats directly; they add
## modifiers tagged with a `source`, and recalculate() rebuilds the effective
## values below. Removing a source (unequipping an item) is therefore exact.
##
##   effective = (base + sum(ADD)) * (1 + sum(INCREASED)) * product(1 + MORE)
##
## By convention gear uses ADD / INCREASED (small additive bonuses) and run
## upgrades use MORE (multiplicative, so they stay relevant next to gear).

enum Op { ADD, INCREASED, MORE }

## Base value of every stat a modifier can target. Adding a stat here makes it
## targetable by upgrades and affixes; read it back from `values` or add a
## typed field for it below.
const BASE := {
	"max_hp": 100.0,
	"regen": 0.0, # HP per second
	"armor": 0.0, # reduces damage taken by armor / (armor + 100)
	"move_speed": 6.0,
	"pickup_radius": 3.0,
	"xp_gain": 1.0, # multiplier
	"magic_find": 0.0, # fraction: 0.25 = +25% chance of better loot
	"damage": 1.0, # multiplier applied to all weapons
	"crit_chance": 0.05,
	"crit_mult": 1.5,
	"bolt_damage": 10.0,
	"bolt_rate": 2.0, # volleys per second
	"bolt_count": 1.0,
	"bolt_pierce": 1.0,
	"bolt_speed": 22.0,
	"bolt_range": 16.0,
	"aura_level": 0.0, # 0 = locked
	"aura_damage": 5.0,
	"aura_radius": 3.5,
	"aura_interval": 0.5,
}

# Effective values, refreshed by recalculate(). Read these; don't write them.
var max_hp := 100.0
var regen := 0.0
var armor := 0.0
var move_speed := 6.0
var pickup_radius := 3.0
var xp_gain := 1.0
var magic_find := 0.0
var crit_chance := 0.05
var crit_mult := 1.5
## Weapon damage already includes the global `damage` multiplier.
var bolt_damage := 10.0
var bolt_cooldown := 0.5
var bolt_count := 1
var bolt_pierce := 1
var bolt_speed := 22.0
var bolt_range := 16.0
var aura_level := 0
var aura_damage := 5.0
var aura_radius := 3.5
var aura_interval := 0.5

## Every effective stat by id (after recalculate()), for UI and tooltips.
var values := {}

# Current state, not derived from modifiers.
var hp := 100.0
var level := 1
var xp := 0
var xp_to_next := 5

## upgrade id -> times taken
var upgrade_levels := {}

var _mods: Array[Dictionary] = []


func _init() -> void:
	recalculate()
	hp = max_hp


func xp_for_level(lvl: int) -> int:
	return int(4.0 + lvl * 3.5 + pow(lvl, 1.5))


func add_mod(source: String, stat: String, op: Op, value: float) -> void:
	assert(BASE.has(stat), "Unknown stat '%s'" % stat)
	_mods.append({"source": source, "stat": stat, "op": op, "value": value})


## Adds several {stat, op, value} modifiers under one source.
func add_mods(source: String, mods: Array) -> void:
	for m: Dictionary in mods:
		add_mod(source, m["stat"], m["op"], m["value"])


## Removes every modifier added under `source`. Returns how many were removed.
func remove_source(source: String) -> int:
	var before := _mods.size()
	_mods = _mods.filter(func(m: Dictionary) -> bool: return m["source"] != source)
	return before - _mods.size()


func recalculate() -> void:
	var add := {}
	var inc := {}
	var more := {}
	for m in _mods:
		var stat: String = m["stat"]
		match m["op"]:
			Op.ADD:
				add[stat] = add.get(stat, 0.0) + m["value"]
			Op.INCREASED:
				inc[stat] = inc.get(stat, 0.0) + m["value"]
			Op.MORE:
				more[stat] = more.get(stat, 1.0) * (1.0 + m["value"])

	values.clear()
	for stat: String in BASE:
		values[stat] = (BASE[stat] + add.get(stat, 0.0)) * (1.0 + inc.get(stat, 0.0)) * more.get(stat, 1.0)

	var damage_mult: float = values["damage"]
	max_hp = maxf(1.0, values["max_hp"])
	regen = values["regen"]
	armor = maxf(0.0, values["armor"])
	move_speed = values["move_speed"]
	pickup_radius = values["pickup_radius"]
	xp_gain = values["xp_gain"]
	magic_find = values["magic_find"]
	crit_chance = clampf(values["crit_chance"], 0.0, 1.0)
	crit_mult = maxf(1.0, values["crit_mult"])
	bolt_damage = values["bolt_damage"] * damage_mult
	bolt_cooldown = 1.0 / maxf(0.1, values["bolt_rate"])
	bolt_count = maxi(1, roundi(values["bolt_count"]))
	bolt_pierce = maxi(0, roundi(values["bolt_pierce"]))
	bolt_speed = values["bolt_speed"]
	bolt_range = values["bolt_range"]
	aura_level = maxi(0, roundi(values["aura_level"]))
	aura_damage = values["aura_damage"] * damage_mult
	aura_radius = values["aura_radius"]
	aura_interval = values["aura_interval"]
	hp = minf(hp, max_hp)


## Fraction of incoming damage that gets through.
func damage_taken_factor() -> float:
	return 100.0 / (100.0 + armor)
