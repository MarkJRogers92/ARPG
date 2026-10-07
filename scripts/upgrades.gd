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
	"lightning": {
		"name": "Chain Lightning", "desc": "Lightning strikes and jumps between 4 enemies",
		"desc_next": "+1 jump, +25% damage, strikes 10% faster", "max": 6,
		"first_mods": [{"stat": "lightning_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "lightning_level", "op": _ADD, "value": 1.0},
			{"stat": "lightning_chains", "op": _ADD, "value": 1.0},
			{"stat": "lightning_damage", "op": _MORE, "value": 0.25},
			{"stat": "lightning_rate", "op": _MORE, "value": 0.10},
		],
	},
	"orbit": {
		"name": "Spirit Blades", "desc": "Two blades circle you and cut through enemies",
		"desc_next": "+1 blade, +20% damage, wider orbit", "max": 5,
		"first_mods": [{"stat": "orbit_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "orbit_level", "op": _ADD, "value": 1.0},
			{"stat": "orbit_count", "op": _ADD, "value": 1.0},
			{"stat": "orbit_damage", "op": _MORE, "value": 0.20},
			{"stat": "orbit_radius", "op": _MORE, "value": 0.06},
		],
	},
	"obol": {
		"name": "Ferryman's Obol", "desc": "Flick a heavy coin that ricochets between 4 enemies; heads hits twice as hard",
		"desc_next": "+1 ricochet, +25% damage, +5% luck", "max": 5,
		"first_mods": [{"stat": "obol_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "obol_level", "op": _ADD, "value": 1.0},
			{"stat": "obol_bounces", "op": _ADD, "value": 1.0},
			{"stat": "obol_damage", "op": _MORE, "value": 0.25},
			{"stat": "obol_luck", "op": _ADD, "value": 0.05},
		],
	},
	"scythe": {
		"name": "Reaping Scythe", "desc": "Throw a scythe that cuts out and back; the return cut hits 50% harder",
		"desc_next": "+1 scythe, +20% damage, +1 m range", "max": 5,
		"first_mods": [{"stat": "scythe_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "scythe_level", "op": _ADD, "value": 1.0},
			{"stat": "scythe_count", "op": _ADD, "value": 1.0},
			{"stat": "scythe_damage", "op": _MORE, "value": 0.2},
			{"stat": "scythe_range", "op": _ADD, "value": 1.0},
		],
	},
	"bell": {
		"name": "Funeral Bell", "desc": "Every 30 kills near you, a bell tolls: a shockwave that hurls the horde back",
		"desc_next": "-4 kills per toll, +35% damage, +1 m radius", "max": 5,
		"first_mods": [{"stat": "bell_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "bell_level", "op": _ADD, "value": 1.0},
			{"stat": "bell_cost", "op": _ADD, "value": -4.0},
			{"stat": "bell_damage", "op": _MORE, "value": 0.35},
			{"stat": "bell_radius", "op": _ADD, "value": 1.0},
		],
	},
	"nova": {
		"name": "Arcane Nova", "desc": "A blast every 4 s damages and throws back nearby enemies",
		"desc_next": "+30% damage, +12% radius, 12% more often", "max": 5,
		"first_mods": [{"stat": "nova_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "nova_level", "op": _ADD, "value": 1.0},
			{"stat": "nova_damage", "op": _MORE, "value": 0.30},
			{"stat": "nova_radius", "op": _MORE, "value": 0.12},
			{"stat": "nova_rate", "op": _MORE, "value": 0.12},
		],
	},
	"legion": {
		"name": "Soul Legion", "desc": "+1 minion in your army, minions +25% damage and life", "max": 6,
		"mods": [
			{"stat": "minion_max", "op": _ADD, "value": 1.0},
			{"stat": "minion_damage", "op": _MORE, "value": 0.25},
			{"stat": "minion_hp", "op": _MORE, "value": 0.25},
		],
	},
	"harvest": {
		"name": "Soul Harvest", "desc": "+40% souls from kills, minions rise 1 soul sooner", "max": 4,
		"mods": [
			{"stat": "soul_chance", "op": _MORE, "value": 0.4},
			{"stat": "soul_cost", "op": _ADD, "value": -1.0},
		],
	},
	"ignite": {
		"name": "Kindling", "desc": "Bolts have a 20% chance to set enemies on fire",
		"desc_next": "+10% ignite chance, +35% burn damage", "max": 5,
		"first_mods": [{"stat": "ignite_chance", "op": _ADD, "value": 0.2}],
		"mods": [
			{"stat": "ignite_chance", "op": _ADD, "value": 0.1},
			{"stat": "burn_dps", "op": _MORE, "value": 0.35},
		],
	},
	"frostbite": {
		"name": "Frostbite", "desc": "Bolts have a 20% chance to chill (slow) enemies",
		"desc_next": "+10% chill chance, reactions +20% damage", "max": 4,
		"first_mods": [{"stat": "chill_chance", "op": _ADD, "value": 0.2}],
		"mods": [
			{"stat": "chill_chance", "op": _ADD, "value": 0.1},
			{"stat": "reaction_damage", "op": _MORE, "value": 0.2},
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

const HEAL := {"id": "heal", "name": "Second Wind", "level": 0, "max": 0,
		"title": "Second Wind", "desc": "Restore 40% of max HP"}


static func level_of(id: String, stats: PlayerStats) -> int:
	return stats.upgrade_levels.get(id, 0)


## Up to `n` random upgrades that aren't maxed out, as
## [{id, name, level, max, title, desc}], where level is the one you'd reach.
## Falls back to a heal if the pool runs dry. A weapon ready to evolve (see
## Evolutions) always takes the first place.
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
			"name": def["name"],
			"level": lvl + 1,
			"max": def["max"],
			"title": "%s  (Lv %d)" % [def["name"], lvl + 1],
			"desc": _desc(id, lvl, stats),
		})
	var evolving := Evolutions.ready(stats)
	if not evolving.is_empty():
		var card := Evolutions.card(evolving.pick_random())
		if out.size() >= n:
			out[0] = card
		else:
			out.push_front(card)
	if out.is_empty():
		out.append(HEAL)
	return out


static func _desc(id: String, lvl: int, stats: PlayerStats) -> String:
	var def: Dictionary = DEFS[id]
	var text: String = def["desc_next"] if (lvl > 0 or already_active(id, stats)) and def.has("desc_next") else def["desc"]
	# The last rank or two: say what it evolves with.
	var evo := Evolutions.for_weapon(id)
	if not evo.is_empty() and lvl + 2 >= def["max"]:
		text += "\nAt max rank, with %s: evolves into %s" % [DEFS[evo["catalyst"]]["name"], evo["name"]]
	return text


## True if an ability card's ability is already on from another source (a
## class, an item or the skill tree) before the first card is taken.
static func already_active(id: String, stats: PlayerStats) -> bool:
	var def: Dictionary = DEFS.get(id, {})
	if not def.has("first_mods") or level_of(id, stats) > 0:
		return false
	var stat: String = def["first_mods"][0]["stat"]
	return stat.ends_with("_level") and float(stats.get(stat)) >= 1.0


## True when roll() had nothing left to offer but the heal fallback.
static func is_exhausted(choices: Array[Dictionary]) -> bool:
	return choices.size() == 1 and choices[0]["id"] == "heal"


static func apply(id: String, stats: PlayerStats) -> void:
	if id.begins_with(Evolutions.PREFIX):
		Evolutions.apply(id.substr(Evolutions.PREFIX.length()), stats)
		return
	if id == "heal":
		stats.hp = minf(stats.max_hp, stats.hp + stats.max_hp * 0.4)
		return
	var def: Dictionary = DEFS[id]
	var lvl := level_of(id, stats)
	var active := already_active(id, stats)
	stats.upgrade_levels[id] = lvl + 1
	var mods: Array = def["first_mods"] if lvl == 0 and def.has("first_mods") else def["mods"]
	if lvl == 0 and active:
		# Granted by a class or an item already: the card still unlocks it for
		# the run (so it stays if the item goes), and improves it right away.
		mods = def["first_mods"] + def["mods"].filter(func(m: Dictionary) -> bool:
			return m["stat"] != def["first_mods"][0]["stat"])
	stats.add_mods(SOURCE, mods)
	stats.recalculate()
	if def.has("heal"):
		stats.hp = minf(stats.max_hp, stats.hp + def["heal"])
