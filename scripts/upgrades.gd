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
##   bolt          optional: improves only Magic Bolt, so the Reaper (no bolts)
##                 never sees it
##   only          optional: a power the hero must have for it to be offered
##   reaper_desc   optional: card text for the Reaper (whose scythes carry
##                 the bolt elements)
##   unlock        optional: Soul Shards to buy it in the Reliquary; until
##                 then it is never offered (see Relics, MetaProgress)
##   icon          optional: the card's icon (see UiIcons), if not its id

const SOURCE := "upgrade"
const _MORE := PlayerStats.Op.MORE
const _ADD := PlayerStats.Op.ADD

const DEFS := {
	"bolt_damage": {
		"name": "Sharper Bolts", "desc": "+25% bolt damage", "max": 8, "bolt": true,
		"mods": [{"stat": "bolt_damage", "op": _MORE, "value": 0.25}],
	},
	"bolt_rate": {
		"name": "Quick Cast", "desc": "Bolts fire 18% faster", "max": 6, "bolt": true,
		"mods": [{"stat": "bolt_rate", "op": _MORE, "value": 0.18}],
	},
	"bolt_count": {
		"name": "Multishot", "desc": "+1 bolt per volley", "max": 5, "bolt": true,
		"mods": [{"stat": "bolt_count", "op": _ADD, "value": 1.0}],
	},
	"bolt_pierce": {
		"name": "Piercing Bolts", "desc": "Bolts pass through +1 enemy", "max": 4, "bolt": true,
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
	# The Reaper's own: in place of the bolt cards.
	"keen_edge": {
		"name": "Keen Edge", "desc": "+25% scythe damage", "max": 8, "only": "reaping",
		"mods": [{"stat": "scythe_damage", "op": _MORE, "value": 0.25}],
	},
	"whirl": {
		"name": "Whirling Throw", "desc": "Scythes are thrown 18% faster", "max": 6, "only": "reaping",
		"mods": [{"stat": "scythe_rate", "op": _MORE, "value": 0.18}],
	},
	"long_reach": {
		"name": "Long Reach", "desc": "Scythes fly 1.5 m farther and cut 15% harder", "max": 4, "only": "reaping",
		"mods": [{"stat": "scythe_range", "op": _ADD, "value": 1.5}, {"stat": "scythe_damage", "op": _MORE, "value": 0.15}],
	},
	# Lost lore: bought once in the Reliquary, then part of the pool.
	"deadly_aim": {
		"name": "Deadly Aim", "desc": "+5% crit chance, +25% crit damage", "max": 5, "unlock": 25, "icon": "bolt_damage",
		"mods": [{"stat": "crit_chance", "op": _ADD, "value": 0.05}, {"stat": "crit_mult", "op": _ADD, "value": 0.25}],
	},
	"bulwark": {
		"name": "Bulwark", "desc": "+15 armor", "max": 5, "unlock": 20, "icon": "max_hp",
		"mods": [{"stat": "armor", "op": _ADD, "value": 15.0}],
	},
	"catalyst": {
		"name": "Catalyst", "desc": "Shatter, Melt and Overload deal 30% more", "max": 4, "unlock": 30, "icon": "frostbite",
		"mods": [{"stat": "reaction_damage", "op": _MORE, "value": 0.3}],
	},
	"spikes": {
		"name": "Grave Spikes", "desc": "Bone spikes burst up under 3 nearby enemies",
		"desc_next": "+1 spike, +25% damage, faster", "max": 5,
		"first_mods": [{"stat": "spikes_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "spikes_level", "op": _ADD, "value": 1.0},
			{"stat": "spikes_count", "op": _ADD, "value": 1.0},
			{"stat": "spikes_damage", "op": _MORE, "value": 0.25},
			{"stat": "spikes_rate", "op": _MORE, "value": 0.12},
		],
	},
	"wisps": {
		"name": "Wisp Lantern", "desc": "Frost wisps hunt down enemies and chill them",
		"desc_next": "+1 wisp, +25% damage, faster", "max": 5,
		"first_mods": [{"stat": "wisp_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "wisp_level", "op": _ADD, "value": 1.0},
			{"stat": "wisp_count", "op": _ADD, "value": 1.0},
			{"stat": "wisp_damage", "op": _MORE, "value": 0.25},
			{"stat": "wisp_rate", "op": _MORE, "value": 0.10},
		],
	},
	"trail": {
		"name": "Brimstone Trail", "desc": "You leave burning ground behind you",
		"desc_next": "+30% burn, 15% wider, +0.5 s", "max": 5,
		"first_mods": [{"stat": "trail_level", "op": _ADD, "value": 1.0}],
		"mods": [
			{"stat": "trail_level", "op": _ADD, "value": 1.0},
			{"stat": "trail_dps", "op": _MORE, "value": 0.30},
			{"stat": "trail_radius", "op": _MORE, "value": 0.15},
			{"stat": "trail_life", "op": _ADD, "value": 0.5},
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
		"reaper_desc": "Scythe throws have a 20% chance to set what they cut on fire",
		"desc_next": "+10% ignite chance, +35% burn damage", "max": 5,
		"first_mods": [{"stat": "ignite_chance", "op": _ADD, "value": 0.2}],
		"mods": [
			{"stat": "ignite_chance", "op": _ADD, "value": 0.1},
			{"stat": "burn_dps", "op": _MORE, "value": 0.35},
		],
	},
	"frostbite": {
		"name": "Frostbite", "desc": "Bolts have a 20% chance to chill (slow) enemies",
		"reaper_desc": "Scythe throws have a 20% chance to chill (slow) what they cut",
		"desc_next": "+10% chill chance, reactions +12% damage", "max": 4,
		"first_mods": [{"stat": "chill_chance", "op": _ADD, "value": 0.2}],
		"mods": [
			{"stat": "chill_chance", "op": _ADD, "value": 0.1},
			{"stat": "reaction_damage", "op": _MORE, "value": 0.12},
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
	# Synergy cards: behavioral upgrades with no innate snapshot powers. They
	# activate from upgrade_levels and rely on the actual affected systems.
	"synergy_relay": {
		"name": "Frost Relay", "desc": "Chain Lightning hitting a chilled enemy releases a frost pulse beyond them.", "max": 1,
		"mods": [], "synergy": true, "icon": "lightning",
	},
	"synergy_escort": {
		"name": "Ashen Escort", "desc": "Soul Army hits on burning enemies release a fire pulse.", "max": 1,
		"mods": [], "synergy": true, "icon": "legion",
	},
	"synergy_wake": {
		"name": "Blade Wake", "desc": "Dashing while Spirit Blades are active sends blades streaking ahead.", "max": 1,
		"mods": [], "synergy": true, "icon": "orbit",
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
##
## Optional extras:
##   banished    regular upgrade ids excluded from this roll (evolutions and
##               the heal fallback are never banished).
##   rng         a RandomNumberGenerator for reproducible rolls; when null the
##               global RNG is used for backward compatibility.
##   weighted    when true, owned weapons are modestly favoured, catalysts for
##               owned evolving weapons are slightly favoured, and cards that
##               touch stats already boosted by the hero's class are modestly
##               favoured; exploration remains possible because every eligible
##               card keeps a positive weight.
static func roll(stats: PlayerStats, n := 3, unlocked_snapshot: Variant = null, banished: Array = [], rng: RandomNumberGenerator = null, weighted: bool = true) -> Array[Dictionary]:
	if n <= 0:
		return []

	var pool: Array[String] = []
	for id: String in DEFS:
		if level_of(id, stats) >= DEFS[id]["max"]:
			continue
		if not offered(id, stats, unlocked_snapshot):
			continue
		if _is_banished(id, banished):
			continue
		pool.append(id)

	var out: Array[Dictionary] = []
	var remaining := pool.duplicate()
	var weights := {}
	if weighted:
		for id: String in remaining:
			weights[id] = _weight_for(id, stats)

	while out.size() < n and not remaining.is_empty():
		var id: String
		if weighted:
			id = _weighted_pick(remaining, weights, rng)
		else:
			id = _uniform_pick(remaining, rng)
		remaining.erase(id)
		out.append(_make_card(id, stats))

	var evolving := Evolutions.ready(stats)
	if not evolving.is_empty():
		var card := Evolutions.card(evolving.pick_random() if rng == null else evolving[rng.randi_range(0, evolving.size() - 1)])
		if out.size() >= n:
			out[0] = card
		else:
			out.push_front(card)
	if out.is_empty():
		out.append(HEAL)
	return out


## Whether this hero can be offered card `id` at all (see `bolt` and `only`).
static func offered(id: String, stats: PlayerStats, unlocked_snapshot: Variant = null) -> bool:
	var def: Dictionary = DEFS.get(id, {})
	if def.is_empty():
		return false
	if def.get("synergy", false):
		return _synergy_offered(id, stats)
	var reaper := stats.powers.has("reaping")
	if reaper and def.get("bolt", false):
		return false
	if def.has("unlock"):
		var unlocked := MetaProgress.card_unlocked(id)
		if unlocked_snapshot is Dictionary:
			unlocked = bool(unlocked_snapshot.get(id, false))
		if not unlocked:
			return false
	return not def.has("only") or stats.powers.has(def["only"])


## True for regular upgrade ids that may be banished. Evolutions and the heal
## fallback are never banished through this API.
static func is_banishable(id: String) -> bool:
	return DEFS.has(id) and id != "heal"


## True when `id` is a regular, non-maxed card that would otherwise be offered
## to this hero, so a banish button can reasonably target it.
static func can_banish(id: String, stats: PlayerStats, unlocked_snapshot: Variant = null) -> bool:
	if not is_banishable(id):
		return false
	if level_of(id, stats) >= DEFS[id]["max"]:
		return false
	return offered(id, stats, unlocked_snapshot)


static func _is_banished(id: String, banished: Array) -> bool:
	if banished.is_empty():
		return false
	for entry: Variant in banished:
		if entry is String and entry == id:
			return true
	return false


static func _synergy_offered(id: String, stats: PlayerStats) -> bool:
	match id:
		"synergy_relay":
			return stats.lightning_level > 0 or _has_chill_source(stats)
		"synergy_escort":
			return stats.minion_max > 0 and _has_burn_source(stats)
		"synergy_wake":
			return stats.orbit_level > 0
	return false


static func _has_chill_source(stats: PlayerStats) -> bool:
	return stats.aura_level > 0 or stats.wisp_level > 0 or stats.chill_chance > 0.0


static func _has_burn_source(stats: PlayerStats) -> bool:
	return stats.ignite_chance > 0.0 or stats.trail_level > 0 or stats.powers.has("pyre")


static func _weight_for(id: String, stats: PlayerStats) -> float:
	var weight := 1.0
	var lvl := level_of(id, stats)
	var def: Dictionary = DEFS[id]
	if lvl > 0 and (def.has("first_mods") or def.get("bolt", false)):
		weight *= 1.5

	for evo_id: String in Evolutions.DEFS:
		var evo: Dictionary = Evolutions.DEFS[evo_id]
		if evo["catalyst"] == id and not Evolutions.taken(evo_id, stats):
			if level_of(evo["weapon"], stats) > 0:
				weight *= 1.35
				break # A shared catalyst gets one bonus, not multiplicative stacking.

	# Early signature support comes from the class modifier source, not from
	# arbitrary gear/upgrade strength. All eligible cards retain positive weight.
	if stats.level <= 5:
		var touched: Array = def["mods"] + def.get("first_mods", [])
		for mod: Dictionary in stats._mods:
			if mod.get("source", "") != "class": continue
			if touched.any(func(candidate: Dictionary) -> bool: return candidate["stat"] == mod["stat"]):
				weight *= 1.25
				break
	return minf(weight, 2.0)


static func _weighted_pick(pool: Array[String], weights: Dictionary, rng: RandomNumberGenerator = null) -> String:
	var total := 0.0
	for id: String in pool:
		total += float(weights.get(id, 1.0))
	var pick := _randf(rng) * total
	var cum := 0.0
	for id: String in pool:
		cum += float(weights.get(id, 1.0))
		if pick <= cum:
			return id
	return pool[-1]


static func _uniform_pick(pool: Array[String], rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		return pool.pick_random()
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _randf(rng: RandomNumberGenerator = null) -> float:
	if rng == null:
		return randf()
	return rng.randf()


static func _make_card(id: String, stats: PlayerStats) -> Dictionary:
	var lvl := level_of(id, stats)
	var def: Dictionary = DEFS[id]
	return {
		"id": id,
		"name": def["name"],
		"level": lvl + 1,
		"max": def["max"],
		"title": "%s  (Lv %d)" % [def["name"], lvl + 1],
		"icon": def.get("icon", id),
		"desc": _desc(id, lvl, stats),
	}


static func _desc(id: String, lvl: int, stats: PlayerStats) -> String:
	var def: Dictionary = DEFS[id]
	if def.get("synergy", false):
		return def["desc"]
	var text: String = def["desc_next"] if (lvl > 0 or already_active(id, stats)) and def.has("desc_next") else def["desc"]
	if lvl == 0 and def.has("reaper_desc") and stats.powers.has("reaping"):
		text = def["reaper_desc"]
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
