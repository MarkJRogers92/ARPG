class_name Upgrades
extends RefCounted
## The level-up pool, as data. Each level taken adds the entry's `mods` to the
## player's stats under the source "upgrade" (see PlayerStats). To add an
## upgrade, add an entry here: no code needed unless it does something new.
##
##   name / desc   shown on the card
##   max           how many times it can be taken
##   mods          [{stat, op, value}] applied every level taken
##   first_mods    optional: applied instead of `mods` on the first level
##   desc_next     optional: card text for levels after the first
##   heal          optional: flat HP restored when taken

const SOURCE := "upgrade"
const _MORE := PlayerStats.Op.MORE
const _ADD := PlayerStats.Op.ADD

const DEFS := {
	"bolt_damage": {
		"name": "Sharper Bolts", "desc": "+25% bolt damage", "max": 8,
		"mods": [{"stat": "bolt_damage", "op": _MORE, "value": 0.25}],
	},
	"bolt_rate": {
		"name": "Quick Cast", "desc": "Bolts fire 18% faster", "max": 6,
		"mods": [{"stat": "bolt_rate", "op": _MORE, "value": 0.18}],
	},
	"bolt_count": {
		"name": "Multishot", "desc": "+1 bolt per volley", "max": 5,
		"mods": [{"stat": "bolt_count", "op": _ADD, "value": 1.0}],
	},
	"bolt_pierce": {
		"name": "Piercing Bolts", "desc": "Bolts pass through +1 enemy", "max": 4,
		"mods": [{"stat": "bolt_pierce", "op": _ADD, "value": 1.0}],
	},
	"aura": {
		"name": "Frost Aura", "desc": "Damages enemies close to you",
		"desc_next": "+15% radius, +30% damage", "max": 6,
		"first_mods": [{"stat": "aura_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "aura_level", "op": _ADD, "value": 1.0},
			{"stat": "aura_radius", "op": _MORE, "value": 0.15},
			{"stat": "aura_damage", "op": _MORE, "value": 0.30},
		],
	},
	"move_speed": {
		"name": "Swift Boots", "desc": "+10% move speed", "max": 5,
		"mods": [{"stat": "move_speed", "op": _MORE, "value": 0.10}],
	},
	"max_hp": {
		"name": "Vitality", "desc": "+25 max HP, heal 25", "max": 8, "heal": 25.0,
		"mods": [{"stat": "max_hp", "op": _ADD, "value": 25.0}],
	},
	"regen": {
		"name": "Regeneration", "desc": "+0.5 HP per second", "max": 5,
		"mods": [{"stat": "regen", "op": _ADD, "value": 0.5}],
	},
	"magnet": {
		"name": "Magnetism", "desc": "+30% pickup range", "max": 5,
		"mods": [{"stat": "pickup_radius", "op": _MORE, "value": 0.30}],
	},
}

const HEAL := {"id": "heal", "title": "Second Wind", "desc": "Restore 40% of max HP"}


static func level_of(id: String, stats: PlayerStats) -> int:
	return stats.upgrade_levels.get(id, 0)


## Up to `n` random upgrades that aren't maxed out, as
## [{id, title, desc}]. Falls back to a heal if the pool runs dry.
static func roll(stats: PlayerStats, n := 3) -> Array[Dictionary]:
	var pool: Array[String] = []
	for id: String in DEFS:
		if level_of(id, stats) < DEFS[id]["max"]:
			pool.append(id)
	pool.shuffle()

	var out: Array[Dictionary] = []
	for id in pool.slice(0, n):
		var lvl := level_of(id, stats)
		var def: Dictionary = DEFS[id]
		out.append({
			"id": id,
			"title": "%s  (Lv %d)" % [def["name"], lvl + 1],
			"desc": def["desc_next"] if lvl > 0 and def.has("desc_next") else def["desc"],
		})
	if out.is_empty():
		out.append(HEAL)
	return out


## True when roll() had nothing left to offer but the heal fallback.
static func is_exhausted(choices: Array[Dictionary]) -> bool:
	return choices.size() == 1 and choices[0]["id"] == "heal"


static func apply(id: String, stats: PlayerStats) -> void:
	if id == "heal":
		stats.hp = minf(stats.max_hp, stats.hp + stats.max_hp * 0.4)
		return
	var def: Dictionary = DEFS[id]
	var lvl := level_of(id, stats)
	stats.upgrade_levels[id] = lvl + 1
	var mods: Array = def["first_mods"] if lvl == 0 and def.has("first_mods") else def["mods"]
	stats.add_mods(SOURCE, mods)
	stats.recalculate()
	if def.has("heal"):
		stats.hp = minf(stats.max_hp, stats.hp + def["heal"])
