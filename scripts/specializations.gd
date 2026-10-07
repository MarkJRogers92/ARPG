class_name Specializations
extends RefCounted
## At level 10 every hero picks one path for the rest of the night: three per
## class, each a real trade-off (shown as cards like a level-up). Applied as
## modifiers under the source "spec", plus an ability unlock where noted.

const SOURCE := "spec"
const LEVEL := 10

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED
const _MORE := PlayerStats.Op.MORE

const PATHS := {
	"battlemage": [
		{"id": "sniper", "name": "Arcane Sniper", "icon": "bolt_pierce", "color": Color(0.5, 0.85, 1.0),
			"desc": "Bolts pierce 3 more, hit 40% harder and fly 40% farther. One bolt fewer per volley.",
			"mods": [{"stat": "bolt_pierce", "op": _ADD, "value": 3.0}, {"stat": "bolt_damage", "op": _MORE, "value": 0.4},
				{"stat": "bolt_range", "op": _INC, "value": 0.4}, {"stat": "bolt_count", "op": _ADD, "value": -1.0}]},
		{"id": "artillery", "name": "Artillery", "icon": "bolt_count", "color": Color(1.0, 0.75, 0.4),
			"desc": "+2 bolts per volley and 20% faster volleys. Bolts deal 20% less.",
			"mods": [{"stat": "bolt_count", "op": _ADD, "value": 2.0}, {"stat": "bolt_rate", "op": _INC, "value": 0.2},
				{"stat": "bolt_damage", "op": _MORE, "value": -0.2}]},
		{"id": "spellblade", "name": "Spellblade", "icon": "aura", "color": Color(0.55, 0.85, 1.0),
			"desc": "Frost Aura (or +2 ranks of it), +60% aura damage, +15% move speed. Bolts deal 25% less.",
			"mods": [{"stat": "aura_level", "op": _ADD, "value": 2.0}, {"stat": "aura_damage", "op": _MORE, "value": 0.6},
				{"stat": "move_speed", "op": _INC, "value": 0.15}, {"stat": "bolt_damage", "op": _MORE, "value": -0.25}]},
	],
	"necromancer": [
		{"id": "champions", "name": "Lord of Champions", "icon": "legion", "color": Color(0.45, 1.0, 0.6),
			"desc": "Minions get +80% health and +60% damage. One fewer minion.",
			"mods": [{"stat": "minion_hp", "op": _MORE, "value": 0.8}, {"stat": "minion_damage", "op": _MORE, "value": 0.6},
				{"stat": "minion_max", "op": _ADD, "value": -1.0}]},
		{"id": "legion", "name": "Endless Legion", "icon": "harvest", "color": Color(0.45, 0.8, 1.0),
			"desc": "+4 army size and souls cost 3 less. Minions have 30% less health.",
			"mods": [{"stat": "minion_max", "op": _ADD, "value": 4.0}, {"stat": "soul_cost", "op": _ADD, "value": -3.0},
				{"stat": "minion_hp", "op": _MORE, "value": -0.3}]},
		{"id": "reaper", "name": "Grim Reaper", "icon": "scythe", "color": Color(0.65, 0.95, 0.85),
			"desc": "The Reaping Scythe (or +2 ranks of it), +50% scythe damage. Army 1 smaller.",
			"mods": [{"stat": "scythe_level", "op": _ADD, "value": 2.0}, {"stat": "scythe_count", "op": _ADD, "value": 1.0},
				{"stat": "scythe_damage", "op": _MORE, "value": 0.5}, {"stat": "minion_max", "op": _ADD, "value": -1.0}]},
	],
	"pyromancer": [
		{"id": "wildfire", "name": "Wildfire", "icon": "ignite", "color": Color(1.0, 0.5, 0.15),
			"desc": "+25% ignite chance, +70% burn damage. Bolts deal 15% less on impact.",
			"mods": [{"stat": "ignite_chance", "op": _ADD, "value": 0.25}, {"stat": "burn_dps", "op": _MORE, "value": 0.7},
				{"stat": "bolt_damage", "op": _MORE, "value": -0.15}]},
		{"id": "detonator", "name": "Detonator", "icon": "nova", "color": Color(1.0, 0.5, 0.9),
			"desc": "Arcane Nova (or +2 ranks), +80% reaction damage. 15% less max health.",
			"mods": [{"stat": "nova_level", "op": _ADD, "value": 2.0}, {"stat": "reaction_damage", "op": _MORE, "value": 0.8},
				{"stat": "max_hp", "op": _MORE, "value": -0.15}]},
		{"id": "frostfire", "name": "Frostfire", "icon": "frostbite", "color": Color(0.55, 0.85, 1.0),
			"desc": "+30% chill chance and +50% reaction damage: freeze them, then melt them.",
			"mods": [{"stat": "chill_chance", "op": _ADD, "value": 0.3}, {"stat": "reaction_damage", "op": _MORE, "value": 0.5}]},
	],
	"stormcaller": [
		{"id": "arcmaster", "name": "Arc Master", "icon": "lightning", "color": Color(0.72, 0.6, 1.0),
			"desc": "Lightning jumps 4 more times and strikes 20% faster. Each jump loses more damage.",
			"mods": [{"stat": "lightning_chains", "op": _ADD, "value": 4.0}, {"stat": "lightning_rate", "op": _INC, "value": 0.2},
				{"stat": "lightning_damage", "op": _MORE, "value": -0.15}]},
		{"id": "thunderstrike", "name": "Thunderstrike", "icon": "nova", "color": Color(0.85, 0.8, 1.0),
			"desc": "Lightning hits 90% harder and the Funeral Bell joins you (or +2 ranks). 2 fewer jumps.",
			"mods": [{"stat": "lightning_damage", "op": _MORE, "value": 0.9}, {"stat": "lightning_chains", "op": _ADD, "value": -2.0},
				{"stat": "bell_level", "op": _ADD, "value": 2.0}, {"stat": "bell_cost", "op": _ADD, "value": -6.0}]},
		{"id": "tempest", "name": "Tempest", "icon": "move_speed", "color": Color(0.6, 1.0, 0.8),
			"desc": "Dash 40% more often, +20% move speed, +25% lightning damage. 10% less max health.",
			"mods": [{"stat": "dash_cooldown", "op": _INC, "value": -0.4}, {"stat": "move_speed", "op": _INC, "value": 0.2},
				{"stat": "lightning_damage", "op": _MORE, "value": 0.25}, {"stat": "max_hp", "op": _MORE, "value": -0.1}]},
	],
}


static func paths(hero_class: String) -> Array:
	return PATHS.get(hero_class, PATHS["battlemage"])


## Cards for the HUD: [{id "spec:<id>", name, desc, icon, color}].
static func cards(hero_class: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in paths(hero_class):
		out.append({"id": "spec:" + p["id"], "name": p["name"], "desc": p["desc"], "icon": p["icon"], "color": p["color"],
				"level": 0, "max": 0})
	return out


static func find(hero_class: String, id: String) -> Dictionary:
	for p: Dictionary in paths(hero_class):
		if p["id"] == id:
			return p
	return {}


static func apply(stats: PlayerStats, hero_class: String, id: String) -> bool:
	var p := find(hero_class, id)
	if p.is_empty():
		return false
	stats.remove_source(SOURCE)
	stats.add_mods(SOURCE, p["mods"])
	stats.recalculate()
	return true
