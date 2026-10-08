class_name HeroClass
extends RefCounted
## The heroes you can play. Each has its own look, starting weapon, stat
## modifiers (added under the source "class") and innate powers (the same
## flags legendary items grant, see ItemData.POWERS, plus a few of its own).
## The Battlemage is free; the others are bought with Soul Shards on the title
## screen (see MetaProgress).

const SOURCE := "class"
const ORDER := ["battlemage", "necromancer", "pyromancer", "stormcaller", "reaper"]

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED
const _MORE := PlayerStats.Op.MORE

const CLASSES := {
	"battlemage": {
		"name": "Battlemage", "cost": 0,
		"desc": "Bolts fire 10% faster and pierce one more enemy.",
		"weapon": "Staff", "accent": Color(0.5, 0.85, 1.0),
		"look": {},
		"mods": [{"stat": "bolt_rate", "op": _INC, "value": 0.1}, {"stat": "bolt_pierce", "op": _ADD, "value": 1.0}],
		"powers": [],
	},
	"necromancer": {
		"name": "Necromancer", "cost": 30,
		"desc": "Commands the dead: +2 army size, +50% souls, minions +30% damage, and they burst in soulfire when they fall. Bolts deal 15% less.",
		"weapon": "Orb", "accent": Color(0.45, 1.0, 0.6),
		"look": {"robe": Color(0.12, 0.16, 0.12), "robe_dark": Color(0.06, 0.08, 0.07), "trim": Color(0.55, 0.85, 0.5),
			"cape": Color(0.18, 0.3, 0.2), "eye": Color(0.45, 1.0, 0.55)},
		"mods": [{"stat": "minion_max", "op": _ADD, "value": 2.0}, {"stat": "soul_chance", "op": _INC, "value": 0.5},
			{"stat": "minion_damage", "op": _INC, "value": 0.3}, {"stat": "bolt_damage", "op": _MORE, "value": -0.15}],
		"powers": ["lich_shroud"],
	},
	"pyromancer": {
		"name": "Pyromancer", "cost": 40,
		"desc": "Everything burns: bolts ignite 35% of the time, +60% burn damage, and fire always spreads from the burning dead.",
		"weapon": "Wand", "accent": Color(1.0, 0.5, 0.15),
		"look": {"robe": Color(0.6, 0.12, 0.08), "robe_dark": Color(0.3, 0.05, 0.04), "trim": Color(1.0, 0.6, 0.2),
			"cape": Color(0.2, 0.08, 0.06), "eye": Color(1.0, 0.6, 0.2)},
		"mods": [{"stat": "ignite_chance", "op": _ADD, "value": 0.35}, {"stat": "burn_dps", "op": _INC, "value": 0.6}],
		"powers": ["pyre"],
	},
	"stormcaller": {
		"name": "Stormcaller", "cost": 50,
		"desc": "Starts with Chain Lightning that strikes 50% faster, hits 30% harder and jumps once more. Dashes 30% more often and leaves lightning in its wake.",
		"weapon": "Staff", "accent": Color(0.75, 0.6, 1.0),
		"look": {"robe": Color(0.42, 0.3, 0.7), "robe_dark": Color(0.2, 0.14, 0.38), "trim": Color(0.85, 0.9, 1.0),
			"cape": Color(0.15, 0.18, 0.35), "eye": Color(0.8, 0.7, 1.0)},
		"mods": [{"stat": "lightning_level", "op": _ADD, "value": 1.0}, {"stat": "lightning_chains", "op": _ADD, "value": 1.0},
			{"stat": "lightning_rate", "op": _INC, "value": 0.5}, {"stat": "lightning_damage", "op": _INC, "value": 0.3},
			{"stat": "dash_cooldown", "op": _INC, "value": -0.3}],
		"powers": ["stormstride"],
	},
	# No bolts at all: the scythe is the main attack (the "reaping" power).
	"reaper": {
		"name": "Reaper", "cost": 60,
		"desc": "Fights with the Reaping Scythe instead of bolts: starts with two, thrown 80% faster and 3 m farther for 25% more damage, and they carry your fire and frost. +10% move speed.",
		"weapon": "Scythe", "accent": Color(0.65, 0.95, 0.85),
		"look": {"robe": Color(0.1, 0.1, 0.11), "robe_dark": Color(0.04, 0.04, 0.05), "trim": Color(0.6, 0.9, 0.8),
			"cape": Color(0.08, 0.1, 0.1), "eye": Color(0.6, 1.0, 0.85)},
		"mods": [{"stat": "scythe_level", "op": _ADD, "value": 1.0}, {"stat": "scythe_count", "op": _ADD, "value": 1.0},
			{"stat": "scythe_rate", "op": _INC, "value": 0.8}, {"stat": "scythe_damage", "op": _INC, "value": 0.25},
			{"stat": "scythe_range", "op": _ADD, "value": 3.0}, {"stat": "move_speed", "op": _INC, "value": 0.1}],
		"powers": ["reaping"],
	},
}


static func data(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["battlemage"])


## Gives `player` the class's stats, powers, look and starting weapon.
static func apply(player: Player, id: String) -> void:
	var d := data(id)
	var stats := player.stats
	stats.remove_source(SOURCE)
	stats.add_mods(SOURCE, d["mods"])
	stats.innate_powers.clear()
	for p: String in d["powers"]:
		stats.innate_powers[p] = 1
	player.inventory.refresh_powers()
	stats.recalculate()
	stats.hp = stats.max_hp
	player.set_class_look(d["look"], d["weapon"], d["accent"])
