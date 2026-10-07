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
## Player settings (see SETTINGS for the defaults).
static var settings := {}
## Hero classes bought, and the one picked (see HeroClass).
static var classes := {}
static var hero_class := "battlemage"
## Kills per enemy (by its name in the realm) across every night; see BESTIARY_STEPS.
static var bestiary := {}
## Pacts of Night chosen for the next runs (see RunModifiers).
static var pacts: Array = []
## The Daily Night: date -> best kills.
static var daily := {}
## The Crypt: veterans laid to rest after a night, to rise again in another
## ({"id", "name", "swarm", "label", "role", "elite", "deeds", "rank", "nights"}),
## at most CRYPT_SIZE. One of them (crypt_chosen, an id; -1 for none) rises
## at the hero's side when a night begins. If it falls, it's gone for good,
## remembered among the fallen (newest first).
static var crypt: Array = []
## Ascension: the level chosen for the next nights, and the highest unlocked
## (winning a realm at level N unlocks N + 1; see RunModifiers.ASCENSION).
static var ascension := 0
## The nemesis: a rival necromancer that escaped (or saw the hero fall) and
## will return, stronger: {"name", "rank", "stolen", "escapes"}, or {}.
## nemeses_slain counts the ones put down for good.
static var nemesis := {}
static var nemeses_slain := 0
const NEMESIS_MAX_RANK := 5
static var ascension_unlocked := 0
static var fallen: Array = []
static var crypt_chosen := -1
const CRYPT_SIZE := 3
const FALLEN_KEPT := 12
## Kills of one kind that each earn a star; every star is +1% damage, for good.
const BESTIARY_STEPS := [100, 1000, 5000]
const SAVE_VERSION := 2

const SETTINGS := {"music_volume": 0.7, "sfx_volume": 0.8, "shake": true, "numbers": true}
static var _loaded := false


static func load_save() -> void:
	_loaded = true
	shards = 0
	ranks = {}
	realms = {}
	settings = {}
	classes = {}
	hero_class = "battlemage"
	bestiary = {}
	pacts = []
	daily = {}
	crypt = []
	fallen = []
	crypt_chosen = -1
	ascension = 0
	ascension_unlocked = 0
	nemesis = {}
	nemeses_slain = 0
	if disabled:
		return
	var data = _read(save_path)
	if not (data is Dictionary):
		# A broken or missing save: fall back to the last good one.
		data = _read(save_path + ".bak")
	if data is Dictionary:
		shards = int(data.get("shards", 0))
		var saved = data.get("ranks", {})
		if saved is Dictionary:
			for id: String in saved:
				if UPGRADES.has(id):
					ranks[id] = clampi(int(saved[id]), 0, UPGRADES[id]["max"])
		var saved_settings = data.get("settings", {})
		if saved_settings is Dictionary:
			for key: String in saved_settings:
				if SETTINGS.has(key):
					settings[key] = saved_settings[key]
		var saved_classes = data.get("classes", {})
		if saved_classes is Dictionary:
			classes = saved_classes
		hero_class = data.get("hero_class", "battlemage")
		var saved_bestiary = data.get("bestiary", {})
		if saved_bestiary is Dictionary:
			bestiary = saved_bestiary
		var saved_pacts = data.get("pacts", [])
		if saved_pacts is Array:
			pacts = saved_pacts.filter(func(p) -> bool: return RunModifiers.PACTS.has(p))
		var saved_daily = data.get("daily", {})
		if saved_daily is Dictionary:
			daily = saved_daily
		var saved_crypt = data.get("crypt", [])
		if saved_crypt is Array:
			crypt = saved_crypt.filter(func(v) -> bool: return v is Dictionary and v.has("id") and v.has("name"))
		var saved_fallen = data.get("fallen", [])
		if saved_fallen is Array:
			fallen = saved_fallen.filter(func(v) -> bool: return v is Dictionary)
		crypt_chosen = int(data.get("crypt_chosen", -1))
		ascension_unlocked = clampi(int(data.get("ascension_unlocked", 0)), 0, RunModifiers.ASCENSION_MAX)
		ascension = clampi(int(data.get("ascension", 0)), 0, ascension_unlocked)
		var saved_nemesis = data.get("nemesis", {})
		if saved_nemesis is Dictionary and saved_nemesis.has("name"):
			nemesis = saved_nemesis
		nemeses_slain = int(data.get("nemeses_slain", 0))
		var saved_realms = data.get("realms", {})
		if saved_realms is Dictionary:
			for id: String in saved_realms:
				if Realm.REALMS.has(id) and saved_realms[id] is Dictionary:
					realms[id] = saved_realms[id]


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_var() if file else null


## Writes the save safely: to a temporary file first, then swapped in, with
## the previous save kept as a backup, so a crash mid-write loses nothing.
static func save() -> void:
	if disabled:
		return
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({"version": SAVE_VERSION, "shards": shards, "ranks": ranks, "realms": realms,
			"settings": settings, "classes": classes, "hero_class": hero_class,
			"bestiary": bestiary, "pacts": pacts, "daily": daily,
			"crypt": crypt, "fallen": fallen, "crypt_chosen": crypt_chosen,
			"ascension": ascension, "ascension_unlocked": ascension_unlocked,
			"nemesis": nemesis, "nemeses_slain": nemeses_slain})
	file.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return
	if FileAccess.file_exists(save_path):
		dir.rename(save_path.get_file(), save_path.get_file() + ".bak")
	dir.rename(tmp.get_file(), save_path.get_file())


## Counts a night's kills in the Bestiary: {name: kills}. Returns the names
## that earned a new star.
static func record_kills(kills_by: Dictionary) -> Array:
	_ensure_loaded()
	var starred := []
	for kind: String in kills_by:
		var before := stars(kind)
		bestiary[kind] = bestiary.get(kind, 0) + kills_by[kind]
		if stars(kind) > before:
			starred.append(kind)
	save()
	return starred


static func stars(kind: String) -> int:
	var n: int = bestiary.get(kind, 0)
	var s := 0
	for step: int in BESTIARY_STEPS:
		if n >= step:
			s += 1
	return s


static func total_stars() -> int:
	var s := 0
	for kind: String in bestiary:
		s += stars(kind)
	return s


static func set_pacts(list: Array) -> void:
	_ensure_loaded()
	pacts = list.duplicate()
	save()


## True once any realm has been conquered (Pacts open up then).
static func any_won() -> bool:
	_ensure_loaded()
	for id: String in realms:
		if realms[id].get("won", false):
			return true
	return disabled


static func record_daily(date: String, kills: int) -> bool:
	_ensure_loaded()
	if kills <= daily.get(date, -1):
		return false
	daily[date] = kills
	save()
	return true


static func set_ascension(level: int) -> void:
	_ensure_loaded()
	ascension = clampi(level, 0, ascension_unlocked)
	save()


## A realm was won at Ascension `level`: the next level opens. True if it did.
static func record_ascension_win(level: int) -> bool:
	_ensure_loaded()
	if disabled or level < ascension_unlocked or ascension_unlocked >= RunModifiers.ASCENSION_MAX:
		return false
	ascension_unlocked = level + 1
	save()
	return true


## A rival got away (or outlived the hero): it will be back, a rank stronger.
static func nemesis_escaped(rival_name: String, stolen: int) -> void:
	_ensure_loaded()
	if disabled:
		return
	if nemesis.get("name", "") != rival_name:
		nemesis = {"name": rival_name, "rank": 0, "stolen": 0, "escapes": 0}
	nemesis["rank"] = mini(int(nemesis["rank"]) + 1, NEMESIS_MAX_RANK)
	nemesis["stolen"] = int(nemesis["stolen"]) + stolen
	nemesis["escapes"] = int(nemesis["escapes"]) + 1
	save()


## The nemesis is destroyed for good.
static func nemesis_slain() -> void:
	_ensure_loaded()
	if disabled:
		return
	nemesis = {}
	nemeses_slain += 1
	save()


## Lays a veteran to rest (or brings one back to rest, with its new deeds).
## Returns its crypt id, or -1 if the Crypt is full of greater ones.
static func entomb(rec: Dictionary) -> int:
	_ensure_loaded()
	if disabled:
		return -1
	var id: int = rec.get("crypt", -1)
	for v: Dictionary in crypt:
		if v["id"] == id:
			v["deeds"] = rec["deeds"]
			v["rank"] = rec["rank"]
			v["nights"] = int(v.get("nights", 1)) + 1
			save()
			return id
	id = 1
	for v: Dictionary in crypt:
		id = maxi(id, int(v["id"]) + 1)
	for v: Dictionary in fallen:
		id = maxi(id, int(v.get("id", 0)) + 1)
	var entry := {"id": id, "name": rec["name"], "swarm": rec["swarm"], "label": rec["label"], "role": rec["role"],
			"elite": rec["elite"], "deeds": rec["deeds"], "rank": rec["rank"], "nights": 1}
	crypt.append(entry)
	if crypt.size() > CRYPT_SIZE:
		# The least of them makes room (it may be the newcomer).
		var least := 0
		for k in crypt.size():
			if crypt[k]["deeds"] < crypt[least]["deeds"]:
				least = k
		var gone: Dictionary = crypt[least]
		crypt.remove_at(least)
		if gone["id"] == crypt_chosen:
			crypt_chosen = -1
		if gone["id"] == id:
			save()
			return -1
	if crypt_chosen < 0:
		crypt_chosen = id
	save()
	return id


## A veteran from the Crypt fell in battle: gone for good.
static func crypt_fell(id: int) -> void:
	_ensure_loaded()
	if disabled:
		return
	for k in crypt.size():
		if crypt[k]["id"] == id:
			var v: Dictionary = crypt[k]
			crypt.remove_at(k)
			fallen.push_front(v)
			fallen = fallen.slice(0, FALLEN_KEPT)
			if crypt_chosen == id:
				crypt_chosen = -1
			save()
			return


## The veteran picked to rise at the start of a night ({} for none).
static func chosen_veteran() -> Dictionary:
	_ensure_loaded()
	for v: Dictionary in crypt:
		if v["id"] == crypt_chosen:
			return v
	return {}


static func choose_veteran(id: int) -> void:
	_ensure_loaded()
	crypt_chosen = id
	save()


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
	var starred := total_stars()
	if starred > 0:
		stats.add_mod(SOURCE, "damage", PlayerStats.Op.INCREASED, 0.01 * starred)
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


static func class_unlocked(id: String) -> bool:
	_ensure_loaded()
	return HeroClass.data(id)["cost"] == 0 or disabled or classes.get(id, false)


## Buys a class if it's affordable. Returns true when it's (now) unlocked.
static func unlock_class(id: String) -> bool:
	if class_unlocked(id):
		return true
	var cost: int = HeroClass.data(id)["cost"]
	if shards < cost:
		return false
	shards -= cost
	classes[id] = true
	save()
	return true


static func select_class(id: String) -> void:
	_ensure_loaded()
	if class_unlocked(id):
		hero_class = id
		save()


## The class to play: the picked one, or the Battlemage for bots and tests.
static func current_class() -> String:
	_ensure_loaded()
	if disabled and forced_class == "":
		return "battlemage"
	return forced_class if forced_class != "" else hero_class


## Bots can force a class (balance_bot's class= option).
static var forced_class := ""


static func setting(key: String):
	_ensure_loaded()
	return settings.get(key, SETTINGS[key])


static func set_setting(key: String, value) -> void:
	_ensure_loaded()
	settings[key] = value
	save()


static func rerolls() -> int:
	return 0 if disabled else rank("insight")


## Shards for a finished run: a share for time survived and kills, on top of
## what elites and bosses already dropped during it.
static func run_bonus(seconds: float, kills: int) -> int:
	# Kills count with diminishing returns: a late-game horde dies by the
	# hundred thousand, and the Altar shouldn't be maxed by one night.
	return floori(seconds / 60.0) * 2 + floori(sqrt(float(kills)) / 6.0)


## Of the Soul Shards picked up during a night (spent at wells, forges and the
## Night Market), this share is banked at the end.
const BANKED_RUN_SHARDS := 0.25
