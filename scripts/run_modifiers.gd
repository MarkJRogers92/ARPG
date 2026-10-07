class_name RunModifiers
extends RefCounted
## What makes one night different from the last:
##
##   Pacts of Night  chosen on the title screen once you've conquered a realm.
##                   Each makes the night harder and adds heat; every point of
##                   heat adds 25% to the Soul Shards you earn.
##   Omens           one random rule for every run (shown when it starts), a
##                   twist with an upside and a cost.
##
##   Ascension       levels 1..10, unlocked one at a time by winning at the
##                   level below. Each adds one lasting rule on top of the
##                   ones before, lets the night's pressure (WaveDirector)
##                   climb higher, and adds 10% to the Soul Shards you earn.
##
## Applied by main.gd once the realm is set up (apply()), as stat modifiers
## under "pact" / "omen" / "ascension" and tweaks to the wave and boss directors.

const PACTS := {
	"swarm": {"name": "Swarming Dark", "heat": 1, "desc": "Enemies arrive 30% faster."},
	"hide": {"name": "Iron Hide", "heat": 1, "desc": "Enemies have 40% more health."},
	"hunt": {"name": "The Hunt", "heat": 1, "desc": "Enemies move 15% faster."},
	"elites": {"name": "Elite Uprising", "heat": 1, "desc": "Twice as many elites."},
	"bleak": {"name": "Bleak Night", "heat": 2, "desc": "No health regeneration."},
	"wrath": {"name": "Wrath of Dawn", "heat": 2, "desc": "Bosses have 60% more health and slam 25% more often."},
}
const PACT_ORDER := ["swarm", "hide", "hunt", "elites", "bleak", "wrath"]
const HEAT_BONUS := 0.25

const OMENS := {
	"blood_moon": {"name": "Blood Moon", "color": Color(1.0, 0.35, 0.3), "desc": "Twice as many elites, +40% magic find."},
	"soul_tide": {"name": "Soul Tide", "color": Color(0.55, 0.85, 1.0), "desc": "Double souls. Minions have 25% less health."},
	"glass": {"name": "Glass Cannon", "color": Color(1.0, 0.6, 0.8), "desc": "+40% damage. 30% less max health."},
	"midas": {"name": "Midas Night", "color": Color(1.0, 0.85, 0.3), "desc": "+50% Soul Shards. Enemies have 15% more health."},
	"swift": {"name": "Swift Night", "color": Color(0.5, 1.0, 0.7), "desc": "You and the horde move 20% faster."},
	"restless": {"name": "Restless Dead", "color": Color(0.7, 0.9, 0.6), "desc": "Lancers and Gravediggers twice as often. +25% XP."},
	"ferry": {"name": "Ferryman's Favor", "color": Color(0.6, 0.85, 1.0), "desc": "The Ferryman comes three times, and his odds are 5% better."},
	"quiet": {"name": "Quiet Night", "color": Color(0.75, 0.75, 0.85), "desc": "15% fewer enemies. 25% less XP."},
}
const OMEN_ORDER := ["blood_moon", "soul_tide", "glass", "midas", "swift", "restless", "ferry", "quiet"]
const ASCENSION := [
	"Enemies have 20% more health.",
	"Elites come 50% more often.",
	"Enemy shots fly 30% faster and hit 25% harder.",
	"The horde arrives 20% faster.",
	"Bosses have 50% more health.",
	"Your minions have 25% less life.",
	"Half health regeneration.",
	"The night adapts twice as fast.",
	"Enemies move 10% faster.",
	"The final boss has double health.",
]
const ASCENSION_MAX := 10
const ASCENSION_SHARDS := 0.1
const ASCENSION_PRESSURE := 0.25
## Bots and tests play with no omen (MetaProgress.disabled) unless this names one.
static var forced_omen := ""
## Bots and tests: play at this Ascension (-1: the saved choice).
static var forced_ascension := -1


static func heat(pacts: Array) -> int:
	var h := 0
	for id in pacts:
		h += PACTS.get(id, {}).get("heat", 0)
	return h


## The Soul Shard multiplier for a night with these pacts and omen.
static func shard_mult(pacts: Array, omen: String, ascension := 0) -> float:
	return (1.0 + HEAT_BONUS * heat(pacts)) * (1.5 if omen == "midas" else 1.0) * (1.0 + ASCENSION_SHARDS * ascension)


## A random omen (or a set one, for the Daily Night: `pick` in 0..1).
static func roll_omen(pick := -1.0) -> String:
	var r := pick if pick >= 0.0 else randf()
	return OMEN_ORDER[mini(int(r * OMEN_ORDER.size()), OMEN_ORDER.size() - 1)]


## Sets up the night. `main` is the main scene (its nodes are looked up by name).
static func apply(main: Node, pacts: Array, omen: String, ascension := 0) -> void:
	var director := main.get_node("WaveDirector") as WaveDirector
	var bosses := main.get_node("BossDirector") as BossDirector
	var player := main.get_node("Player") as Player
	var swarms := main.get_tree().get_nodes_in_group(EnemySwarm.GROUP) if main.is_inside_tree() else []
	var pact_mods := []
	for id in pacts:
		match id:
			"swarm": director.rate_scale *= 1.3
			"hide": director.hp_scale *= 1.4
			"hunt":
				for s: EnemySwarm in swarms:
					if not s.boss:
						s.move_speed *= 1.15
			"elites":
				director.elites_per_minute *= 2.0
				director.elites_per_minute_max *= 2.0
			"bleak": pact_mods.append({"stat": "regen", "op": PlayerStats.Op.MORE, "value": -1.0})
			"wrath":
				for s: EnemySwarm in swarms:
					if s.boss:
						s.max_hp *= 1.6
				bosses.slam_interval *= 0.75
	var omen_mods := []
	match omen:
		"blood_moon":
			director.elites_per_minute *= 2.0
			director.elites_per_minute_max *= 2.0
			omen_mods.append({"stat": "magic_find", "op": PlayerStats.Op.ADD, "value": 0.4})
		"soul_tide":
			omen_mods.append({"stat": "soul_chance", "op": PlayerStats.Op.MORE, "value": 1.0})
			omen_mods.append({"stat": "minion_hp", "op": PlayerStats.Op.MORE, "value": -0.25})
		"glass":
			omen_mods.append({"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.4})
			omen_mods.append({"stat": "max_hp", "op": PlayerStats.Op.MORE, "value": -0.3})
		"midas":
			director.hp_scale *= 1.15
		"swift":
			omen_mods.append({"stat": "move_speed", "op": PlayerStats.Op.MORE, "value": 0.2})
			for s: EnemySwarm in swarms:
				s.move_speed *= 1.2
		"restless":
			for s: EnemySwarm in swarms:
				if s.charger or s.raise_interval > 0.0:
					s.spawn_share *= 2.0
			omen_mods.append({"stat": "xp_gain", "op": PlayerStats.Op.MORE, "value": 0.25})
		"ferry":
			var ferry := main.get("_ferryman") as Ferryman
			if ferry:
				ferry.extra_visit()
				ferry.odds_bonus = 0.05
		"quiet":
			director.rate_scale *= 0.85
			omen_mods.append({"stat": "xp_gain", "op": PlayerStats.Op.MORE, "value": -0.25})
	var asc_mods := []
	director.pressure_max += ASCENSION_PRESSURE * ascension
	for level in range(1, mini(ascension, ASCENSION_MAX) + 1):
		match level:
			1: director.hp_scale *= 1.2
			2:
				director.elites_per_minute *= 1.5
				director.elites_per_minute_max *= 1.5
			3:
				for s: EnemySwarm in swarms:
					s.shot_speed *= 1.3
					s.shot_damage *= 1.25
				bosses.final_shot_speed *= 1.3
			4: director.rate_scale *= 1.2
			5:
				for s: EnemySwarm in swarms:
					if s.boss and String(s.name) != "FinalBoss":
						s.max_hp *= 1.5
			6: asc_mods.append({"stat": "minion_hp", "op": PlayerStats.Op.MORE, "value": -0.25})
			7: asc_mods.append({"stat": "regen", "op": PlayerStats.Op.MORE, "value": -0.5})
			8: director.pressure_rate *= 2.0
			9:
				for s: EnemySwarm in swarms:
					if not s.boss:
						s.move_speed *= 1.1
			10:
				for s: EnemySwarm in swarms:
					if String(s.name) == "FinalBoss":
						s.max_hp *= 2.0
	var stats := player.stats
	stats.remove_source("pact")
	stats.remove_source("omen")
	stats.remove_source("ascension")
	stats.add_mods("pact", pact_mods)
	stats.add_mods("omen", omen_mods)
	stats.add_mods("ascension", asc_mods)
	stats.recalculate()
	stats.hp = stats.max_hp
