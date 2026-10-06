class_name SkillData
extends RefCounted
## The skill tree, as data. Four branches grow out of the central Awakening
## node: Offense (up), Aura (right), Defense (down) and Utility (left). Each
## node adds stat modifiers (see PlayerStats), so a node needs no code: add an
## entry to NODES and it works, in the tree screen and in the stats.
##
##   name     shown in the tooltip
##   branch   a key of BRANCHES (colors the node)
##   tier     SMALL, NOTABLE or KEYSTONE; sets the point cost
##   pos      grid position in the screen layout (x right, y down, origin at 0,0)
##   links    nodes it connects to. Links go both ways, so list each once.
##   mods     [{stat, op, value}], same as upgrades and gear
##   note     optional extra tooltip line for effects the stats can't show
##
## You can allocate a node when you have the points and it's linked to one you
## already own (see SkillTree).

enum Tier { SMALL, NOTABLE, KEYSTONE }

const COSTS := {Tier.SMALL: 1, Tier.NOTABLE: 2, Tier.KEYSTONE: 3}
const TIER_NAMES := {Tier.SMALL: "Small", Tier.NOTABLE: "Notable", Tier.KEYSTONE: "Keystone"}
const ROOT := "origin"

const BRANCHES := {
	"core": Color(0.78, 0.84, 1.0),
	"offense": Color(1.0, 0.55, 0.3),
	"aura": Color(0.45, 0.8, 1.0),
	"defense": Color(0.45, 0.9, 0.5),
	"utility": Color(0.95, 0.85, 0.35),
}

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED
const _MORE := PlayerStats.Op.MORE
const _SMALL := Tier.SMALL
const _NOTABLE := Tier.NOTABLE
const _KEYSTONE := Tier.KEYSTONE

const NODES := {
	"origin": {"name": "Awakening", "branch": "core", "tier": _SMALL, "pos": Vector2i(0, 0),
		"links": ["o1", "a1", "d1", "u1"], "mods": [],
		"note": "Where every path begins."},

	# --- Offense (up): bolts and crits ---
	"o1": {"name": "Quickened", "branch": "offense", "tier": _SMALL, "pos": Vector2i(0, -1),
		"links": ["o2"], "mods": [{"stat": "bolt_rate", "op": _INC, "value": 0.05}]},
	"o2": {"name": "Sharpened", "branch": "offense", "tier": _SMALL, "pos": Vector2i(0, -2),
		"links": ["o3", "o4", "o5"], "mods": [{"stat": "damage", "op": _INC, "value": 0.05}]},
	"o3": {"name": "Keen Eye", "branch": "offense", "tier": _SMALL, "pos": Vector2i(-1, -2),
		"links": ["o6"], "mods": [{"stat": "crit_chance", "op": _ADD, "value": 0.03}]},
	"o4": {"name": "Heavy Bolts", "branch": "offense", "tier": _SMALL, "pos": Vector2i(1, -2),
		"links": ["o7"], "mods": [{"stat": "bolt_damage", "op": _INC, "value": 0.08}]},
	"o5": {"name": "Arcane Barrage", "branch": "offense", "tier": _KEYSTONE, "pos": Vector2i(0, -3),
		"links": [], "mods": [
			{"stat": "bolt_count", "op": _ADD, "value": 2.0},
			{"stat": "bolt_damage", "op": _MORE, "value": -0.30}]},
	"o6": {"name": "Lethal Focus", "branch": "offense", "tier": _NOTABLE, "pos": Vector2i(-2, -2),
		"links": [], "mods": [
			{"stat": "crit_mult", "op": _ADD, "value": 0.35},
			{"stat": "crit_chance", "op": _ADD, "value": 0.02}]},
	"o7": {"name": "Needlepoint", "branch": "offense", "tier": _NOTABLE, "pos": Vector2i(2, -2),
		"links": [], "mods": [
			{"stat": "bolt_pierce", "op": _ADD, "value": 1.0},
			{"stat": "bolt_damage", "op": _INC, "value": 0.06}]},

	# --- Aura (right): the Frost Aura ---
	"a1": {"name": "Frostbound", "branch": "aura", "tier": _NOTABLE, "pos": Vector2i(1, 0),
		"links": ["a2"], "mods": [{"stat": "aura_level", "op": _ADD, "value": 1.0}],
		"note": "Unlocks the Frost Aura."},
	"a2": {"name": "Biting Cold", "branch": "aura", "tier": _SMALL, "pos": Vector2i(2, 0),
		"links": ["a3", "a4", "a5"], "mods": [{"stat": "aura_damage", "op": _INC, "value": 0.12}]},
	"a3": {"name": "Widening Frost", "branch": "aura", "tier": _SMALL, "pos": Vector2i(3, 0),
		"links": ["a6"], "mods": [{"stat": "aura_radius", "op": _INC, "value": 0.10}]},
	"a4": {"name": "Rimed", "branch": "aura", "tier": _SMALL, "pos": Vector2i(2, -1),
		"links": [], "mods": [{"stat": "aura_damage", "op": _INC, "value": 0.08}]},
	"a5": {"name": "Glacial Reach", "branch": "aura", "tier": _SMALL, "pos": Vector2i(2, 1),
		"links": [], "mods": [{"stat": "aura_radius", "op": _INC, "value": 0.08}]},
	"a6": {"name": "Absolute Zero", "branch": "aura", "tier": _KEYSTONE, "pos": Vector2i(4, 0),
		"links": [], "mods": [
			{"stat": "aura_radius", "op": _MORE, "value": 0.50},
			{"stat": "aura_damage", "op": _MORE, "value": 0.50},
			{"stat": "move_speed", "op": _MORE, "value": -0.12}]},

	# --- Defense (down): HP, armor, regen ---
	"d1": {"name": "Toughness", "branch": "defense", "tier": _SMALL, "pos": Vector2i(0, 1),
		"links": ["d2"], "mods": [{"stat": "max_hp", "op": _INC, "value": 0.06}]},
	"d2": {"name": "Thick Skin", "branch": "defense", "tier": _SMALL, "pos": Vector2i(0, 2),
		"links": ["d3", "d4", "d5"], "mods": [{"stat": "armor", "op": _ADD, "value": 8.0}]},
	"d3": {"name": "Mending", "branch": "defense", "tier": _SMALL, "pos": Vector2i(-1, 2),
		"links": ["d6"], "mods": [{"stat": "regen", "op": _ADD, "value": 0.5}]},
	"d4": {"name": "Fortitude", "branch": "defense", "tier": _SMALL, "pos": Vector2i(1, 2),
		"links": ["d7"], "mods": [{"stat": "max_hp", "op": _ADD, "value": 20.0}]},
	"d5": {"name": "Juggernaut", "branch": "defense", "tier": _KEYSTONE, "pos": Vector2i(0, 3),
		"links": [], "mods": [
			{"stat": "max_hp", "op": _MORE, "value": 0.50},
			{"stat": "armor", "op": _ADD, "value": 30.0},
			{"stat": "move_speed", "op": _MORE, "value": -0.10}]},
	"d6": {"name": "Second Wind", "branch": "defense", "tier": _NOTABLE, "pos": Vector2i(-2, 2),
		"links": [], "mods": [
			{"stat": "regen", "op": _ADD, "value": 1.5},
			{"stat": "max_hp", "op": _INC, "value": 0.05}]},
	"d7": {"name": "Bulwark", "branch": "defense", "tier": _NOTABLE, "pos": Vector2i(2, 2),
		"links": [], "mods": [
			{"stat": "armor", "op": _ADD, "value": 25.0},
			{"stat": "max_hp", "op": _INC, "value": 0.08}]},

	# --- Utility (left): speed, pickup, XP and luck ---
	"u1": {"name": "Fleet", "branch": "utility", "tier": _SMALL, "pos": Vector2i(-1, 0),
		"links": ["u2"], "mods": [{"stat": "move_speed", "op": _INC, "value": 0.05}]},
	"u2": {"name": "Magnetic", "branch": "utility", "tier": _SMALL, "pos": Vector2i(-2, 0),
		"links": ["u3", "u4", "u5"], "mods": [{"stat": "pickup_radius", "op": _INC, "value": 0.15}]},
	"u3": {"name": "Studious", "branch": "utility", "tier": _SMALL, "pos": Vector2i(-3, 0),
		"links": ["u7"], "mods": [{"stat": "xp_gain", "op": _INC, "value": 0.06}]},
	"u4": {"name": "Lucky", "branch": "utility", "tier": _SMALL, "pos": Vector2i(-2, -1),
		"links": ["u6"], "mods": [{"stat": "magic_find", "op": _ADD, "value": 0.06}]},
	"u5": {"name": "Swift", "branch": "utility", "tier": _SMALL, "pos": Vector2i(-2, 1),
		"links": [], "mods": [{"stat": "move_speed", "op": _INC, "value": 0.04}]},
	"u6": {"name": "Prospector", "branch": "utility", "tier": _NOTABLE, "pos": Vector2i(-3, -1),
		"links": [], "mods": [
			{"stat": "magic_find", "op": _ADD, "value": 0.15},
			{"stat": "xp_gain", "op": _INC, "value": 0.08}]},
	"u7": {"name": "Gambler's Edge", "branch": "utility", "tier": _KEYSTONE, "pos": Vector2i(-4, 0),
		"links": [], "mods": [
			{"stat": "xp_gain", "op": _MORE, "value": 0.25},
			{"stat": "magic_find", "op": _ADD, "value": 0.30},
			{"stat": "max_hp", "op": _MORE, "value": -0.20}]},
}

## id -> [neighbor ids], built from `links` (which only list each link once).
static var _adjacency := {}


static func ids() -> Array:
	return NODES.keys()


static func cost(id: String) -> int:
	return COSTS[NODES[id]["tier"]]


static func color(id: String) -> Color:
	return BRANCHES[NODES[id]["branch"]]


static func neighbors(id: String) -> Array:
	if _adjacency.is_empty():
		for a: String in NODES:
			_adjacency[a] = []
		for a: String in NODES:
			for b: String in NODES[a]["links"]:
				if not _adjacency[a].has(b):
					_adjacency[a].append(b)
				if not _adjacency[b].has(a):
					_adjacency[b].append(a)
	return _adjacency[id]


## Tooltip lines: each modifier, then the note if there is one.
static func description_lines(id: String) -> Array[String]:
	var lines: Array[String] = []
	var def: Dictionary = NODES[id]
	for mod: Dictionary in def["mods"]:
		if mod["stat"] == "aura_level":
			continue # the note says it better
		lines.append(ItemData.mod_text(mod))
	if def.has("note"):
		lines.append(def["note"])
	return lines
