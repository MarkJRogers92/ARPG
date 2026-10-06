class_name ItemData
extends RefCounted
## All the static data behind loot: slots, rarities, base types and affixes,
## plus the text and scoring helpers that go with them. Tuning loot is mostly
## editing the tables in this file.

enum Rarity { NORMAL, MAGIC, RARE, LEGENDARY }

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED
const _MORE := PlayerStats.Op.MORE

const SLOTS: Array[String] = ["weapon", "helm", "chest", "boots", "amulet", "ring"]

const SLOT_NAMES := {
	"weapon": "Weapon", "helm": "Helm", "chest": "Chest",
	"boots": "Boots", "amulet": "Amulet", "ring": "Ring",
}

## Item level scaling for implicits and affixes:
##   value * (1 + ILVL_GROWTH * growth * (ilvl - 1))
## Flat stats (HP, armor, flat damage) use the full rate. Percentage stats grow
## at PERCENT_GROWTH of it so they don't snowball. A stat can override this with
## its own "growth" multiplier in STAT_INFO (magic find uses 0: it never scales).
const ILVL_GROWTH := 0.06
## Player levels per item level for dropped gear. Item level is what makes loot
## scale, so this is the main lever on how fast gear power grows during a run.
const PLAYER_LEVELS_PER_ILVL := 2.0
const PERCENT_GROWTH := 0.35

## weight:   base chance of this rarity before magic find
## affixes:  [min, max] random affixes
## mf_scale: how strongly magic find boosts this rarity's weight
## luck:     minimum roll quality (0 = anywhere in the range, 0.5 = top half)
const RARITIES := [
	{"name": "Normal", "color": Color(0.85, 0.85, 0.85), "weight": 60.0, "affixes": [0, 0], "mf_scale": 0.0, "luck": 0.0},
	{"name": "Magic", "color": Color(0.4, 0.6, 1.0), "weight": 30.0, "affixes": [1, 2], "mf_scale": 1.0, "luck": 0.0},
	{"name": "Rare", "color": Color(1.0, 0.85, 0.25), "weight": 9.0, "affixes": [3, 4], "mf_scale": 2.0, "luck": 0.0},
	{"name": "Legendary", "color": Color(1.0, 0.5, 0.1), "weight": 1.0, "affixes": [5, 5], "mf_scale": 3.0, "luck": 0.5},
]

## How each stat is shown and how much it's worth when comparing items.
##   label:  name in tooltips
##   frac:   ADD values are fractions shown as percent (0.05 -> "+5%")
##   w_add:  rough power per 1.0 of an ADD modifier
##   w_inc:  rough power per 1.0 (=100%) of an INCREASED / MORE modifier
##   growth: optional override of the item level growth multiplier
## The weights only drive the "likely upgrade" hint, not gameplay.
const STAT_INFO := {
	"max_hp": {"label": "Max HP", "w_add": 0.005, "w_inc": 0.5},
	"regen": {"label": "HP per second", "w_add": 0.04, "w_inc": 0.1},
	"armor": {"label": "Armor", "w_add": 0.005, "w_inc": 0.3},
	"move_speed": {"label": "Move Speed", "w_add": 0.05, "w_inc": 0.4},
	"pickup_radius": {"label": "Pickup Range", "w_add": 0.02, "w_inc": 0.15},
	"xp_gain": {"label": "XP Gain", "w_add": 0.3, "w_inc": 0.3},
	"magic_find": {"label": "Magic Find", "frac": true, "growth": 0.0, "w_add": 0.3, "w_inc": 0.3},
	"damage": {"label": "Damage", "w_add": 1.0, "w_inc": 1.0},
	"crit_chance": {"label": "Crit Chance", "frac": true, "w_add": 0.5, "w_inc": 0.4},
	"crit_mult": {"label": "Crit Damage", "frac": true, "w_add": 0.15, "w_inc": 0.1},
	"bolt_damage": {"label": "Bolt Damage", "w_add": 0.07, "w_inc": 0.7},
	"bolt_rate": {"label": "Bolt Speed", "w_add": 0.35, "w_inc": 0.7},
	"bolt_count": {"label": "Bolts per Volley", "w_add": 0.8, "w_inc": 0.8},
	"bolt_pierce": {"label": "Bolt Pierce", "w_add": 0.35, "w_inc": 0.3},
	"bolt_speed": {"label": "Bolt Velocity", "w_add": 0.01, "w_inc": 0.1},
	"bolt_range": {"label": "Bolt Range", "w_add": 0.01, "w_inc": 0.1},
	"aura_level": {"label": "Aura Level", "w_add": 0.3, "w_inc": 0.3},
	"aura_damage": {"label": "Aura Damage", "w_add": 0.05, "w_inc": 0.25},
	"aura_radius": {"label": "Aura Radius", "w_add": 0.05, "w_inc": 0.2},
	"aura_interval": {"label": "Aura Interval", "w_add": 0.0, "w_inc": 0.0},
}

## Base item types. `implicit` always comes with the item, scaled by item level.
const BASES := {
	"weapon": [
		{"name": "Wand", "implicit": [{"stat": "bolt_rate", "op": _INC, "value": 0.10}]},
		{"name": "Staff", "implicit": [{"stat": "bolt_damage", "op": _ADD, "value": 3.0}]},
		{"name": "Orb", "implicit": [{"stat": "crit_chance", "op": _ADD, "value": 0.03}]},
	],
	"helm": [
		{"name": "Cap", "implicit": [{"stat": "max_hp", "op": _ADD, "value": 12.0}]},
		{"name": "Circlet", "implicit": [{"stat": "xp_gain", "op": _INC, "value": 0.06}]},
		{"name": "Helm", "implicit": [{"stat": "armor", "op": _ADD, "value": 8.0}]},
	],
	"chest": [
		{"name": "Robe", "implicit": [{"stat": "max_hp", "op": _ADD, "value": 20.0}]},
		{"name": "Vest", "implicit": [{"stat": "armor", "op": _ADD, "value": 14.0}]},
		{"name": "Mantle", "implicit": [{"stat": "regen", "op": _ADD, "value": 0.4}]},
	],
	"boots": [
		{"name": "Sandals", "implicit": [{"stat": "move_speed", "op": _INC, "value": 0.05}]},
		{"name": "Boots", "implicit": [{"stat": "armor", "op": _ADD, "value": 6.0}]},
		{"name": "Greaves", "implicit": [{"stat": "pickup_radius", "op": _INC, "value": 0.12}]},
	],
	"amulet": [
		{"name": "Charm", "implicit": [{"stat": "pickup_radius", "op": _INC, "value": 0.15}]},
		{"name": "Pendant", "implicit": [{"stat": "regen", "op": _ADD, "value": 0.4}]},
		{"name": "Talisman", "implicit": [{"stat": "magic_find", "op": _ADD, "value": 0.05}]},
	],
	"ring": [
		{"name": "Band", "implicit": [{"stat": "crit_chance", "op": _ADD, "value": 0.02}]},
		{"name": "Signet", "implicit": [{"stat": "damage", "op": _INC, "value": 0.04}]},
		{"name": "Loop", "implicit": [{"stat": "max_hp", "op": _ADD, "value": 10.0}]},
	],
}

## The random affix pool.
##   id, stat, op   what it modifies
##   slots          where it can roll
##   min, max       value range at item level 1
##   step           rounding for the rolled value
##   weight         relative chance to be picked
##   scales         false = value doesn't grow with item level
##   min_rarity     lowest rarity that can roll it (default MAGIC)
##   prefix, suffix name fragments for Magic items
const AFFIXES := [
	{"id": "damage", "stat": "damage", "op": _INC, "slots": ["weapon", "chest", "amulet", "ring"],
		"min": 0.05, "max": 0.10, "step": 0.01, "weight": 100, "prefix": "Savage", "suffix": "of Power"},
	{"id": "bolt_flat", "stat": "bolt_damage", "op": _ADD, "slots": ["weapon", "ring"],
		"min": 1.5, "max": 3.5, "step": 0.1, "weight": 80, "prefix": "Sharpened", "suffix": "of Piercing Light"},
	{"id": "rate", "stat": "bolt_rate", "op": _INC, "slots": ["weapon", "helm", "ring"],
		"min": 0.04, "max": 0.09, "step": 0.01, "weight": 80, "prefix": "Swift", "suffix": "of Haste"},
	{"id": "crit", "stat": "crit_chance", "op": _ADD, "slots": ["weapon", "helm", "amulet", "ring"],
		"min": 0.02, "max": 0.05, "step": 0.01, "weight": 70, "prefix": "Keen", "suffix": "of the Eagle"},
	{"id": "crit_mult", "stat": "crit_mult", "op": _ADD, "slots": ["weapon", "amulet", "ring"],
		"min": 0.10, "max": 0.25, "step": 0.01, "weight": 50, "prefix": "Brutal", "suffix": "of Ruin"},
	{"id": "pierce", "stat": "bolt_pierce", "op": _ADD, "slots": ["weapon"],
		"min": 1.0, "max": 1.0, "step": 1.0, "weight": 20, "scales": false, "min_rarity": Rarity.RARE,
		"prefix": "Impaling", "suffix": "of Skewering"},
	{"id": "multishot", "stat": "bolt_count", "op": _ADD, "slots": ["weapon"],
		"min": 1.0, "max": 1.0, "step": 1.0, "weight": 8, "scales": false, "min_rarity": Rarity.LEGENDARY,
		"prefix": "Splitting", "suffix": "of Many"},
	{"id": "aura_damage", "stat": "aura_damage", "op": _INC, "slots": ["chest", "amulet", "ring"],
		"min": 0.08, "max": 0.20, "step": 0.01, "weight": 60, "prefix": "Frostbitten", "suffix": "of Winter"},
	{"id": "aura_radius", "stat": "aura_radius", "op": _INC, "slots": ["helm", "chest", "amulet"],
		"min": 0.05, "max": 0.12, "step": 0.01, "weight": 50, "prefix": "Expansive", "suffix": "of Reach"},
	{"id": "hp", "stat": "max_hp", "op": _ADD, "slots": ["helm", "chest", "boots", "amulet", "ring"],
		"min": 8.0, "max": 20.0, "step": 1.0, "weight": 100, "prefix": "Sturdy", "suffix": "of Vitality"},
	{"id": "hp_inc", "stat": "max_hp", "op": _INC, "slots": ["helm", "chest"],
		"min": 0.04, "max": 0.10, "step": 0.01, "weight": 60, "prefix": "Stalwart", "suffix": "of the Bear"},
	{"id": "armor", "stat": "armor", "op": _ADD, "slots": ["helm", "chest", "boots"],
		"min": 6.0, "max": 14.0, "step": 1.0, "weight": 90, "prefix": "Armored", "suffix": "of Warding"},
	{"id": "regen", "stat": "regen", "op": _ADD, "slots": ["helm", "chest", "amulet"],
		"min": 0.2, "max": 0.6, "step": 0.1, "weight": 60, "prefix": "Mending", "suffix": "of Renewal"},
	{"id": "move", "stat": "move_speed", "op": _INC, "slots": ["boots", "amulet", "ring"],
		"min": 0.03, "max": 0.07, "step": 0.01, "weight": 80, "prefix": "Fleet", "suffix": "of the Wind"},
	{"id": "pickup", "stat": "pickup_radius", "op": _INC, "slots": ["helm", "boots", "amulet"],
		"min": 0.10, "max": 0.25, "step": 0.01, "weight": 50, "prefix": "Magnetic", "suffix": "of Attraction"},
	{"id": "xp", "stat": "xp_gain", "op": _INC, "slots": ["helm", "amulet", "ring"],
		"min": 0.04, "max": 0.10, "step": 0.01, "weight": 50, "prefix": "Studious", "suffix": "of Insight"},
	{"id": "magic_find", "stat": "magic_find", "op": _ADD, "slots": ["helm", "boots", "amulet", "ring"],
		"min": 0.05, "max": 0.15, "step": 0.01, "weight": 40, "prefix": "Gilded", "suffix": "of Fortune"},
]

const RARE_ADJECTIVES: Array[String] = [
	"Grim", "Storm", "Dread", "Ember", "Void", "Gloom", "Rune", "Ashen",
	"Frost", "Cinder", "Hollow", "Wicked", "Fell", "Pale", "Obsidian", "Crimson",
]

const RARE_NOUNS := {
	"weapon": ["Spire", "Coil", "Bane", "Whisper", "Brand", "Reach"],
	"helm": ["Crown", "Visage", "Gaze", "Veil", "Cowl"],
	"chest": ["Shroud", "Carapace", "Bulwark", "Mantle", "Coat"],
	"boots": ["Stride", "Treads", "Step", "Wake", "Tracks"],
	"amulet": ["Heart", "Eye", "Locket", "Sigil", "Totem"],
	"ring": ["Loop", "Seal", "Knot", "Circle", "Halo"],
}

static var _affix_index := {}


static func affix(id: String) -> Dictionary:
	if _affix_index.is_empty():
		for a: Dictionary in AFFIXES:
			_affix_index[a["id"]] = a
	return _affix_index[id]


## Item level of loot dropped when the hero is at `player_level`.
static func ilvl_for_player_level(player_level: int) -> int:
	return 1 + floori(maxi(player_level - 1, 0) / PLAYER_LEVELS_PER_ILVL)


## Multiplier for a modifier's rolled value at an item level.
static func ilvl_scale(ilvl: int, stat := "", op: int = _ADD) -> float:
	var growth := ILVL_GROWTH
	if stat != "":
		var info: Dictionary = STAT_INFO[stat]
		if info.has("growth"):
			growth *= info["growth"]
		elif op != _ADD or info.get("frac", false):
			growth *= PERCENT_GROWTH
	return 1.0 + growth * (maxi(ilvl, 1) - 1)


static func rarity_color(rarity: int) -> Color:
	return RARITIES[rarity]["color"]


static func rarity_name(rarity: int) -> String:
	return RARITIES[rarity]["name"]


## Human-readable text for one modifier, e.g. "+8% Bolt Speed".
static func mod_text(mod: Dictionary) -> String:
	var info: Dictionary = STAT_INFO[mod["stat"]]
	var label: String = info["label"]
	var v: float = mod["value"]
	match mod["op"]:
		_INC:
			return "%+d%% %s" % [roundi(v * 100.0), label]
		_MORE:
			return "%d%% more %s" % [roundi(v * 100.0), label]
		_:
			if info.get("frac", false):
				return "%+d%% %s" % [roundi(v * 100.0), label]
			if absf(v - roundf(v)) < 0.05:
				return "%+d %s" % [roundi(v), label]
			return "%+.1f %s" % [v, label]


## Rough power of a modifier, for "likely upgrade" hints. See STAT_INFO.
static func mod_score(mod: Dictionary) -> float:
	var info: Dictionary = STAT_INFO[mod["stat"]]
	var weight: float = info["w_add"] if mod["op"] == _ADD else info["w_inc"]
	return mod["value"] * weight
