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
## typed field for it below. The game treats this as constant; it's a static
## var only so tools/balance_bot.gd can try other starting values.
static var BASE := {
	"max_hp": 100.0,
	"regen": 1.5, # HP per second
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
	"bolt_count": 2.0,
	"bolt_pierce": 1.0,
	"bolt_speed": 22.0,
	"bolt_range": 16.0,
	"aura_level": 0.0, # 0 = locked
	"aura_damage": 5.0,
	"aura_radius": 3.5,
	"aura_interval": 0.5,
	"lightning_level": 0.0, # 0 = locked
	"lightning_damage": 16.0,
	"lightning_chains": 3.0, # extra enemies each strike jumps to
	"lightning_rate": 0.6, # strikes per second
	"orbit_level": 0.0, # 0 = locked
	"orbit_count": 2.0,
	"orbit_damage": 7.0, # per hit; each blade hits an enemy at most ~4x a second
	"orbit_radius": 2.8,
	"nova_level": 0.0, # 0 = locked
	"nova_damage": 24.0,
	"nova_radius": 5.5,
	"nova_rate": 0.25, # novas per second
	"obol_level": 0.0, # 0 = locked
	"obol_damage": 20.0,
	"obol_bounces": 3.0, # ricochets after the first hit
	"obol_rate": 0.5, # coins per second
	"obol_luck": 0.2, # chance a hit lands heads: double damage, +1 bounce
	"scythe_level": 0.0, # 0 = locked
	"scythe_damage": 16.0, # per cut; the return cut does 1.5x
	"scythe_count": 1.0, # scythes in the air at once
	"scythe_rate": 0.6, # throws per second
	"scythe_range": 8.0,
	"bell_level": 0.0, # 0 = locked
	"bell_damage": 70.0,
	"bell_radius": 7.0,
	"bell_cost": 30.0, # kills near the hero per ring
	"dash_cooldown": 3.0, # seconds
	"minion_max": 2.0, # Soul Army size
	"minion_damage": 12.0, # per second, per minion (scaled by the enemy type)
	"minion_hp": 90.0,
	"soul_chance": 0.06, # chance that a kill leaves a soul
	"soul_cost": 12.0, # souls per raised minion
	"ignite_chance": 0.0, # chance a bolt sets what it hits on fire
	"burn_dps": 6.0,
	"chill_chance": 0.0, # chance a bolt chills (slows) what it hits
	"reaction_damage": 1.0, # multiplier for Shatter / Melt / Overload
}

# Effective values, refreshed by recalculate(). Read these; don't write them.
var max_hp := 100.0
var regen := 1.5
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
var bolt_count := 2
var bolt_pierce := 1
var bolt_speed := 22.0
var bolt_range := 16.0
var aura_level := 0
var aura_damage := 5.0
var aura_radius := 3.5
var aura_interval := 0.5
var lightning_level := 0
var lightning_damage := 16.0
var lightning_chains := 3
var lightning_cooldown := 1.6
var orbit_level := 0
var orbit_count := 2
var orbit_damage := 7.0
var orbit_radius := 2.8
var nova_level := 0
var nova_damage := 24.0
var nova_radius := 5.5
var nova_cooldown := 4.0
var obol_level := 0
var obol_damage := 20.0
var obol_bounces := 3
var obol_cooldown := 2.0
var obol_luck := 0.2
var scythe_level := 0
var scythe_damage := 16.0
var scythe_count := 1
var scythe_cooldown := 1.7
var scythe_range := 8.0
var bell_level := 0
var bell_damage := 70.0
var bell_radius := 7.0
var bell_cost := 30
var dash_cooldown := 3.0
var minion_max := 2
var minion_damage := 12.0
var minion_hp := 90.0
var soul_chance := 0.06
var soul_cost := 12
var ignite_chance := 0.0
var burn_dps := 6.0
var chill_chance := 0.0
var reaction_damage := 1.0

## Legendary powers in effect: power id -> how many sources grant it (worn
## items plus `innate_powers`). Inventory keeps this up to date.
var powers := {}
## Powers the hero has without gear (its class, see HeroClass).
var innate_powers := {}

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


func add_mod(source: String, stat: String, op: Op, value: float) -> void:
	assert(BASE.has(stat), "Unknown stat '%s'" % stat)
	_mods.append({"source": source, "stat": stat, "op": op, "value": value})


## Adds several {stat, op, value} modifiers under one source.
func add_mods(source: String, mods: Array) -> void:
	for m: Dictionary in mods:
		add_mod(source, m["stat"], m["op"], m["value"])


## The modifiers added under `source` (copies).
func mods_from(source: String) -> Array[Dictionary]:
	return _mods.filter(func(m: Dictionary) -> bool: return m["source"] == source)


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
	lightning_level = maxi(0, roundi(values["lightning_level"]))
	lightning_damage = values["lightning_damage"] * damage_mult
	lightning_chains = maxi(0, roundi(values["lightning_chains"]))
	lightning_cooldown = 1.0 / maxf(0.05, values["lightning_rate"])
	orbit_level = maxi(0, roundi(values["orbit_level"]))
	orbit_count = clampi(roundi(values["orbit_count"]), 1, 12)
	orbit_damage = values["orbit_damage"] * damage_mult
	orbit_radius = values["orbit_radius"]
	nova_level = maxi(0, roundi(values["nova_level"]))
	nova_damage = values["nova_damage"] * damage_mult
	nova_radius = values["nova_radius"]
	nova_cooldown = 1.0 / maxf(0.05, values["nova_rate"])
	obol_level = maxi(0, roundi(values["obol_level"]))
	obol_damage = values["obol_damage"] * damage_mult
	obol_bounces = maxi(0, roundi(values["obol_bounces"]))
	obol_cooldown = 1.0 / maxf(0.05, values["obol_rate"])
	obol_luck = clampf(values["obol_luck"], 0.0, 0.9)
	scythe_level = maxi(0, roundi(values["scythe_level"]))
	scythe_damage = values["scythe_damage"] * damage_mult
	scythe_count = clampi(roundi(values["scythe_count"]), 1, 6)
	scythe_cooldown = 1.0 / maxf(0.05, values["scythe_rate"])
	scythe_range = values["scythe_range"]
	bell_level = maxi(0, roundi(values["bell_level"]))
	bell_damage = values["bell_damage"] * damage_mult
	bell_radius = values["bell_radius"]
	bell_cost = maxi(6, roundi(values["bell_cost"]))
	dash_cooldown = maxf(0.3, values["dash_cooldown"])
	minion_max = maxi(0, roundi(values["minion_max"]))
	minion_damage = values["minion_damage"] * damage_mult
	minion_hp = maxf(1.0, values["minion_hp"])
	soul_chance = clampf(values["soul_chance"], 0.0, 1.0)
	soul_cost = maxi(3, roundi(values["soul_cost"]))
	ignite_chance = clampf(values["ignite_chance"], 0.0, 1.0)
	burn_dps = values["burn_dps"] * damage_mult
	chill_chance = clampf(values["chill_chance"], 0.0, 1.0)
	reaction_damage = values["reaction_damage"] * damage_mult
	hp = minf(hp, max_hp)


## Fraction of incoming damage that gets through.
func damage_taken_factor() -> float:
	return 100.0 / (100.0 + armor)
