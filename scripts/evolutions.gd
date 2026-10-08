class_name Evolutions
extends RefCounted
## Weapon evolutions: max out a weapon, own its catalyst (another level-up
## card, any rank), and the next level-up offers its evolved form as a golden
## card. Each evolves once a night. A weapon's card names its catalyst once
## it's close to max, so the pairs can be found by playing.
##
##   weapon     the upgrade id that must be at its max rank
##   catalyst   the upgrade id that must have been taken at least once
##   mods       added under "evolution" when taken (see PlayerStats)

const SOURCE := "evolution"
const PREFIX := "evo:"
const _MORE := PlayerStats.Op.MORE
const _ADD := PlayerStats.Op.ADD

const DEFS := {
	"soul_lance": {
		"name": "Soul Lance", "weapon": "bolt_damage", "catalyst": "bolt_pierce", "icon": "bolt_damage",
		"color": Color(0.55, 0.85, 1.0),
		"desc": "Magic Bolt evolves: bolts pierce everything, fly faster and farther, +50% damage",
		"mods": [
			{"stat": "bolt_pierce", "op": _ADD, "value": 50.0},
			{"stat": "bolt_damage", "op": _MORE, "value": 0.5},
			{"stat": "bolt_speed", "op": _MORE, "value": 0.4},
			{"stat": "bolt_range", "op": _MORE, "value": 0.3},
		],
	},
	"absolute_zero": {
		"name": "Absolute Zero", "weapon": "aura", "catalyst": "frostbite", "icon": "aura",
		"color": Color(0.7, 0.92, 1.0),
		"desc": "Frost Aura evolves: +50% radius, double damage, pulses 30% faster",
		"mods": [
			{"stat": "aura_radius", "op": _MORE, "value": 0.5},
			{"stat": "aura_damage", "op": _MORE, "value": 1.0},
			{"stat": "aura_interval", "op": _MORE, "value": -0.3},
		],
	},
	"storm_lord": {
		"name": "Storm Lord", "weapon": "lightning", "catalyst": "ignite", "icon": "lightning",
		"color": Color(0.8, 0.65, 1.0),
		"desc": "Chain Lightning evolves: +6 jumps, strikes 50% faster, +60% damage",
		"mods": [
			{"stat": "lightning_chains", "op": _ADD, "value": 6.0},
			{"stat": "lightning_rate", "op": _MORE, "value": 0.5},
			{"stat": "lightning_damage", "op": _MORE, "value": 0.6},
		],
	},
	"blade_cyclone": {
		"name": "Blade Cyclone", "weapon": "orbit", "catalyst": "move_speed", "icon": "orbit",
		"color": Color(0.5, 1.0, 0.85),
		"desc": "Spirit Blades evolve: +3 blades, +80% damage, a wider orbit",
		"mods": [
			{"stat": "orbit_count", "op": _ADD, "value": 3.0},
			{"stat": "orbit_damage", "op": _MORE, "value": 0.8},
			{"stat": "orbit_radius", "op": _MORE, "value": 0.35},
		],
	},
	"charons_hoard": {
		"name": "Charon's Hoard", "weapon": "obol", "catalyst": "magnet", "icon": "obol",
		"color": Color(1.0, 0.85, 0.35),
		"desc": "The Obol evolves: +5 ricochets, +25% luck, coins fly 50% more often",
		"mods": [
			{"stat": "obol_bounces", "op": _ADD, "value": 5.0},
			{"stat": "obol_luck", "op": _ADD, "value": 0.25},
			{"stat": "obol_rate", "op": _MORE, "value": 0.5},
		],
	},
	"deaths_harvest": {
		"name": "Death's Harvest", "weapon": "scythe", "catalyst": "harvest", "icon": "scythe",
		"color": Color(0.7, 1.0, 0.85),
		"desc": "The Scythe evolves: +2 scythes, +80% damage, +4 m reach, +30% souls",
		"mods": [
			{"stat": "scythe_count", "op": _ADD, "value": 2.0},
			{"stat": "scythe_damage", "op": _MORE, "value": 0.8},
			{"stat": "scythe_range", "op": _ADD, "value": 4.0},
			{"stat": "soul_chance", "op": _MORE, "value": 0.3},
		],
	},
	"requiem": {
		"name": "Requiem", "weapon": "bell", "catalyst": "legion", "icon": "bell",
		"color": Color(0.88, 0.82, 1.0),
		"desc": "The Bell evolves: tolls after 10 fewer kills, double damage, +4 m radius",
		"mods": [
			{"stat": "bell_cost", "op": _ADD, "value": -10.0},
			{"stat": "bell_damage", "op": _MORE, "value": 1.0},
			{"stat": "bell_radius", "op": _ADD, "value": 4.0},
		],
	},
	"ossuary": {
		"name": "Ossuary", "weapon": "spikes", "catalyst": "regen", "icon": "spikes",
		"color": Color(0.95, 0.9, 0.75),
		"desc": "Grave Spikes evolve: +3 spikes, +60% damage, 40% wider, 30% more often",
		"mods": [
			{"stat": "spikes_count", "op": _ADD, "value": 3.0},
			{"stat": "spikes_damage", "op": _MORE, "value": 0.6},
			{"stat": "spikes_radius", "op": _MORE, "value": 0.4},
			{"stat": "spikes_rate", "op": _MORE, "value": 0.3},
		],
	},
	"will_o_wisp": {
		"name": "Will-o'-the-Wisp", "weapon": "wisps", "catalyst": "frostbite", "icon": "wisps",
		"color": Color(0.65, 0.95, 1.0),
		"desc": "The Lantern evolves: +4 wisps, +60% damage, released 40% more often",
		"mods": [
			{"stat": "wisp_count", "op": _ADD, "value": 4.0},
			{"stat": "wisp_damage", "op": _MORE, "value": 0.6},
			{"stat": "wisp_rate", "op": _MORE, "value": 0.4},
		],
	},
	"path_of_cinders": {
		"name": "Path of Cinders", "weapon": "trail", "catalyst": "ignite", "icon": "trail",
		"color": Color(1.0, 0.55, 0.2),
		"desc": "The Trail evolves: double burn, 50% wider, burns 2 s longer",
		"mods": [
			{"stat": "trail_dps", "op": _MORE, "value": 1.0},
			{"stat": "trail_radius", "op": _MORE, "value": 0.5},
			{"stat": "trail_life", "op": _ADD, "value": 2.0},
		],
	},
	"supernova": {
		"name": "Supernova", "weapon": "nova", "catalyst": "max_hp", "icon": "nova",
		"color": Color(1.0, 0.55, 0.9),
		"desc": "Arcane Nova evolves: +60% radius, double damage, 30% more often",
		"mods": [
			{"stat": "nova_radius", "op": _MORE, "value": 0.6},
			{"stat": "nova_damage", "op": _MORE, "value": 1.0},
			{"stat": "nova_rate", "op": _MORE, "value": 0.3},
		],
	},
}


static func taken(id: String, stats: PlayerStats) -> bool:
	return stats.upgrade_levels.has(PREFIX + id)


## Evolutions that could be taken now.
static func ready(stats: PlayerStats) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		var d: Dictionary = DEFS[id]
		if taken(id, stats):
			continue
		if Upgrades.level_of(d["weapon"], stats) >= Upgrades.DEFS[d["weapon"]]["max"] \
				and Upgrades.level_of(d["catalyst"], stats) >= 1:
			out.append(id)
	return out


## The evolution a weapon card leads to ({} if none).
static func for_weapon(weapon: String) -> Dictionary:
	for id: String in DEFS:
		if DEFS[id]["weapon"] == weapon:
			return DEFS[id]
	return {}


## A level-up card for evolution `id`.
static func card(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	return {"id": PREFIX + id, "name": d["name"], "title": d["name"], "desc": d["desc"], "icon": d["icon"],
			"color": d["color"], "tag": "EVOLUTION", "level": 0, "max": 0}


static func apply(id: String, stats: PlayerStats) -> bool:
	if not DEFS.has(id) or taken(id, stats):
		return false
	stats.upgrade_levels[PREFIX + id] = 1
	stats.add_mods(SOURCE, DEFS[id]["mods"])
	stats.recalculate()
	return true
