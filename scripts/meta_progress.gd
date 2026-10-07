class_name MetaProgress
extends RefCounted
## Progress that survives between runs: Soul Shards, earned in every run, and
## the permanent upgrades bought with them at the Altar (on the death screen).
## Saved to user://meta.save with store_var (not JSON, which turns ints into
## floats).
##
## Each rank of an upgrade adds its `mods` once, under the stat source "meta",
## at the start of a run. Costs grow per rank: cost * (1 + growth * rank).
## The bots and tests set `disabled` so a player's saved upgrades can't change
## their results.

## Where progress is saved. Tests point it somewhere else.
static var save_path := "user://meta.save"
const SOURCE := "meta"

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED

const UPGRADES := {
	"vigor": {"name": "Vigor", "desc": "+8% max HP", "max": 5, "cost": 10, "growth": 0.6,
		"mods": [{"stat": "max_hp", "op": _INC, "value": 0.08}]},
	"might": {"name": "Might", "desc": "+6% damage", "max": 5, "cost": 12, "growth": 0.6,
		"mods": [{"stat": "damage", "op": _INC, "value": 0.06}]},
	"swiftness": {"name": "Swiftness", "desc": "+3% move speed", "max": 5, "cost": 8, "growth": 0.6,
		"mods": [{"stat": "move_speed", "op": _INC, "value": 0.03}]},
	"wisdom": {"name": "Wisdom", "desc": "+8% XP gain", "max": 5, "cost": 10, "growth": 0.6,
		"mods": [{"stat": "xp_gain", "op": _INC, "value": 0.08}]},
	"fortune": {"name": "Fortune", "desc": "+10% magic find", "max": 5, "cost": 8, "growth": 0.5,
		"mods": [{"stat": "magic_find", "op": _ADD, "value": 0.10}]},
	"renewal": {"name": "Renewal", "desc": "+0.3 HP per second", "max": 5, "cost": 8, "growth": 0.5,
		"mods": [{"stat": "regen", "op": _ADD, "value": 0.3}]},
	"insight": {"name": "Insight", "desc": "+1 reroll per run", "max": 3, "cost": 15, "growth": 1.0,
		"mods": []},
}

## Bots and tests turn this on: nothing is loaded, applied or saved.
static var disabled := false

static var shards := 0
static var ranks := {}
## Realm id -> {"won": bool, "endless": seconds survived past dawn (best)}.
static var realms := {}
static var _loaded := false


static func load_save() -> void:
	_loaded = true
	shards = 0
	ranks = {}
	realms = {}
	if disabled or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var data = file.get_var()
	if data is Dictionary:
		shards = int(data.get("shards", 0))
		var saved = data.get("ranks", {})
		if saved is Dictionary:
			for id: String in saved:
				if UPGRADES.has(id):
					ranks[id] = clampi(int(saved[id]), 0, UPGRADES[id]["max"])
		var saved_realms = data.get("realms", {})
		if saved_realms is Dictionary:
			for id: String in saved_realms:
				if Realm.REALMS.has(id) and saved_realms[id] is Dictionary:
					realms[id] = saved_realms[id]


static func save() -> void:
	if disabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var({"shards": shards, "ranks": ranks, "realms": realms})


static func _ensure_loaded() -> void:
	if not _loaded:
		load_save()


static func rank(id: String) -> int:
	_ensure_loaded()
	return ranks.get(id, 0)


## Shards needed for the next rank, or -1 when it's maxed.
static func cost(id: String) -> int:
	var def: Dictionary = UPGRADES[id]
	var r := rank(id)
	if r >= def["max"]:
		return -1
	return roundi(def["cost"] * (1.0 + def["growth"] * r))


static func can_buy(id: String) -> bool:
	var c := cost(id)
	return c >= 0 and shards >= c


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	shards -= cost(id)
	ranks[id] = rank(id) + 1
	save()
	return true


static func add_shards(n: int) -> void:
	_ensure_loaded()
	shards += n
	save()


## Adds every bought rank's modifiers to `stats` for a new run.
static func apply(stats: PlayerStats) -> void:
	_ensure_loaded()
	if disabled:
		return
	stats.remove_source(SOURCE)
	for id: String in UPGRADES:
		for r in rank(id):
			stats.add_mods(SOURCE, UPGRADES[id]["mods"])
	stats.recalculate()
	stats.hp = stats.max_hp


## The first realm is always open; each later one opens when the one before
## it has been won.
static func is_unlocked(id: String) -> bool:
	var i := Realm.index(id)
	return i <= 0 or disabled or is_won(Realm.ORDER[i - 1])


static func is_won(id: String) -> bool:
	_ensure_loaded()
	return realms.get(id, {}).get("won", false)


static func endless_best(id: String) -> float:
	_ensure_loaded()
	return realms.get(id, {}).get("endless", 0.0)


static func record_win(id: String) -> void:
	_ensure_loaded()
	var r: Dictionary = realms.get(id, {})
	r["won"] = true
	realms[id] = r
	save()


static func record_endless(id: String, seconds_past_dawn: float) -> void:
	_ensure_loaded()
	var r: Dictionary = realms.get(id, {})
	r["endless"] = maxf(r.get("endless", 0.0), seconds_past_dawn)
	realms[id] = r
	save()


static func rerolls() -> int:
	return 0 if disabled else rank("insight")


## Shards for a finished run: a share for time survived and kills, on top of
## what elites and bosses already dropped during it.
static func run_bonus(seconds: float, kills: int) -> int:
	return floori(seconds / 60.0) * 2 + floori(kills / 150.0)
