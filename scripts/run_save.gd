class_name RunSave
extends RefCounted
## Suspend and resume: one saved night ("Save and quit" in the pause menu,
## "Resume" on the title screen). main.gd builds the snapshot (capture()) and
## puts it back (restore()); this holds the file and what is kept.
##
## Kept: the hero (level, XP, health, position, every lasting stat modifier,
## so upgrades, evolutions, the path and landmark gifts carry over), gear, the
## skill tree, the clock and the night's pressure, the boss schedule, the army
## (each minion's kind and rank; veterans' names are not kept), souls,
## rerolls, the run's shards and kills, the omen, pacts and Ascension, and
## the end screen's records.
## Banish exclusions/remaining uses and measured combat stats also persist.
## Synergy cards persist as upgrade_levels; queued pulses and Warding shrine
## charges are transient, like the blessing itself.
## Not kept, on purpose: the horde itself (a crowd fit for the hour is raised
## around the hero instead), a mid-boss in the field (it comes back shortly),
## and whatever was in flight: shrines, goblins, chests, rifts, the Ferryman's
## loans and bets, the rival, hazards, frenzy and blessings.
##
## A resumed night deletes the save, so it can be resumed once; starting a
## new night abandons it.

const VERSION := 1
static var path := "user://run.save"
## The snapshot to resume, set by the title screen just before the scene
## reloads into the night ({} when starting fresh).
static var pending := {}

## Stat sources rebuilt at the start of every night, or that only last a
## moment: never saved.
const REBUILT := ["meta", "class", "relic", "realm", "omen", "pact", "ascension", "frenzy", "shrine", "loan", "powerup"]


static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func _valid_run(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if int(data.get("version", 0)) != VERSION:
		return false
	if not Realm.REALMS.has(data.get("realm", "")):
		return false
	# restore() reads elapsed without a default: a slot this loader cannot hand
	# over must not be offered, or pressing Resume deletes the only copy and only
	# then fails.
	var elapsed_value = data.get("elapsed")
	if not (elapsed_value is float or elapsed_value is int):
		return false
	return true


static func write(data: Dictionary) -> bool:
	var copy := data.duplicate(true)
	copy["version"] = VERSION
	return CampaignSave.atomic_write(path, copy, "", _valid_run)


## The saved night, or {} if there is none (or it can't be read).
## A damaged primary falls back to its .bak so a crash mid-write never loses a
## suspended night. A complete .tmp is read too: a rename that fails after the
## staged write leaves the whole night there, and clear() would otherwise delete
## the only copy. read_variant rejects a partial file, so this is safe.
static func read() -> Dictionary:
	for suffix in ["", ".bak", ".tmp"]:
		var data = CampaignSave.read_variant(path + suffix)
		if _valid_run(data):
			return (data as Dictionary).duplicate(true)
	return {}


static func clear() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var full: String = path + suffix
		if FileAccess.file_exists(full):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))


## The stat modifiers worth saving: everything but gear and skills (restored
## with the items and the tree) and REBUILT.
static func lasting_mods(stats: PlayerStats) -> Array:
	var out := []
	for m: Dictionary in stats._mods:
		var source: String = m["source"]
		if source.begins_with("gear:") or source.begins_with("skill:") or source in REBUILT:
			continue
		out.append(m.duplicate())
	return out


## Swaps the lasting modifiers on `stats` for saved ones.
static func restore_mods(stats: PlayerStats, mods: Array) -> void:
	for m: Dictionary in lasting_mods(stats):
		stats.remove_source(m["source"])
	for m: Dictionary in mods:
		if PlayerStats.BASE.has(m["stat"]):
			stats.add_mod(m["source"], m["stat"], m["op"], m["value"])
	stats.recalculate()


## "The Frozen Wastes  ·  Reaper  ·  7:32" for the title screen's button.
static func describe(data: Dictionary) -> String:
	var t := int(data.get("elapsed", 0.0))
	return "%s   ·   %s   ·   %d:%02d" % [Realm.data(data["realm"])["name"], HeroClass.data(data.get("hero_class", ""))["name"],
			t / 60, t % 60]
