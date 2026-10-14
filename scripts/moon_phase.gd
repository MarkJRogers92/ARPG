class_name MoonPhase
extends RefCounted
## The real moon: the lunar phase on the player's calendar date shapes every
## Classic night. Four phases, each with a small boon (New Moon's costs a
## darker night). Stacks with omens, pacts and Ascension; Daily Nights use the
## Daily's date at 00:00 UTC so everyone gets the same moon; Campaign runs
## never apply it. Applied by main.gd right after RunModifiers.apply().

const SYNODIC_DAYS := 29.530588853
## A new moon: 2000-01-06 18:14 UTC.
const REFERENCE_UNIX := 947182440.0
const DAY_SECONDS := 86400.0

## Age (days) bounds: new is age < NEW_END or > WANING_END.
const NEW_END := 1.85
const WAXING_END := 12.91
const FULL_END := 16.61
const WANING_END := 27.68

## Every number lives here. "light" scales the realm's sun and ambient light,
## "elites" the elite rate, "shards" the Soul Shards earned, "xp" / "soul" /
## "magic_find" are player stat bonuses, "enemy_speed" scales the (non-boss) horde's pace.
const PHASES := {
	"new": {"name": "New Moon", "color": Color(0.6, 0.62, 0.85), "desc": "A darker night, 25% more elites, +20% Soul Shards.",
			"light": 0.75, "elites": 1.25, "shards": 1.2},
	"waxing": {"name": "Waxing Moon", "color": Color(0.85, 0.9, 0.6), "desc": "+10% XP.", "xp": 0.1},
	"full": {"name": "Full Moon", "color": Color(1.0, 0.95, 0.75), "desc": "The dead are restless: +30% soul chance, enemies move 8% faster.",
			"soul": 0.3, "enemy_speed": 1.08},
	"waning": {"name": "Waning Moon", "color": Color(0.7, 0.8, 1.0), "desc": "+15% magic find.", "magic_find": 0.15},
}
const ORDER := ["new", "waxing", "full", "waning"]

## Tests and bots: "" is the real moon (bots and tests get none, see
## night_phase), a phase id forces it, "none" forces no moon.
static var override := ""


static func age_days(unix_time: float) -> float:
	return fposmod((unix_time - REFERENCE_UNIX) / DAY_SECONDS, SYNODIC_DAYS)


static func phase_for(unix_time: float) -> String:
	var age := age_days(unix_time)
	if age < NEW_END or age > WANING_END:
		return "new"
	if age <= WAXING_END:
		return "waxing"
	if age <= FULL_END:
		return "full"
	return "waning"


## The moment this night's moon is read at: the Daily's date at 00:00 UTC, or now.
static func night_unix(daily: bool) -> float:
	if daily:
		return float(Time.get_unix_time_from_datetime_string(Realm.today()))
	return Time.get_unix_time_from_system()


## This night's phase id, or "" for no moon. Bots and tests (MetaProgress.disabled)
## get no moon unless `override` names one.
static func night_phase(daily: bool) -> String:
	if override == "none":
		return ""
	if override != "":
		return override if PHASES.has(override) else ""
	if MetaProgress.disabled:
		return ""
	return phase_for(night_unix(daily))


static func shard_mult(phase: String) -> float:
	return float(PHASES.get(phase, {}).get("shards", 1.0))


## "New Moon  ·  A darker night..." for banners and the title screen.
static func title(phase: String) -> String:
	var p: Dictionary = PHASES.get(phase, {})
	if p.is_empty():
		return ""
	return "%s  ·  %s" % [p["name"], p["desc"]]


## Sets up the night's moon on `main` (idempotent for stats; "" clears it).
static func apply(main: Node, phase: String) -> void:
	var p: Dictionary = PHASES.get(phase, {})
	var player := main.get_node("Player") as Player
	player.stats.remove_source("moon")
	var atmosphere := main.get_node_or_null("Atmosphere") as Atmosphere
	if atmosphere:
		atmosphere.light_scale = float(p.get("light", 1.0))
	if p.is_empty():
		player.stats.recalculate()
		return
	var director := main.get_node("WaveDirector") as WaveDirector
	if p.has("elites"):
		director.elites_per_minute *= p["elites"]
		director.elites_per_minute_max *= p["elites"]
	if p.has("enemy_speed"):
		var swarms := main.get_tree().get_nodes_in_group(EnemySwarm.GROUP) if main.is_inside_tree() else []
		for s: EnemySwarm in swarms:
			if not s.boss:
				s.move_speed *= p["enemy_speed"]
	var mods := []
	if p.has("xp"):
		mods.append({"stat": "xp_gain", "op": PlayerStats.Op.MORE, "value": p["xp"]})
	if p.has("soul"):
		mods.append({"stat": "soul_chance", "op": PlayerStats.Op.MORE, "value": p["soul"]})
	if p.has("magic_find"):
		mods.append({"stat": "magic_find", "op": PlayerStats.Op.ADD, "value": p["magic_find"]})
	player.stats.add_mods("moon", mods)
	player.stats.recalculate()
