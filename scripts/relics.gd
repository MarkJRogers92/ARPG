class_name Relics
extends RefCounted
## What Soul Shards (and Bestiary stars) buy beyond the Altar's flat bonuses,
## all chosen in the Reliquary on the title screen:
##
##   Relics           carry one into each night: a build-changing trade, or a
##                    legendary power from the start (the same flags items
##                    grant, see ItemData.POWERS). Bought with shards, or
##                    earned with Bestiary stars.
##   Starting weapon  begin the night with one weapon card already taken
##                    (rank 1, so it levels and evolves like any other).
##   Lost lore        extra level-up cards (Upgrades.DEFS entries with
##                    "unlock"), offered only once bought.
##
## Ownership and picks live in MetaProgress; applied in main.gd right after
## the hero class.

const SOURCE := "relic"

const _ADD := PlayerStats.Op.ADD
const _INC := PlayerStats.Op.INCREASED
const _MORE := PlayerStats.Op.MORE

## cost: Soul Shards; stars: Bestiary stars needed instead (free once reached).
## mods: under the source "relic"; power: a legendary power (its own mods too);
## rerolls: extra level-up rerolls each night.
const DEFS := {
	"glass_skull": {"name": "Glass Skull", "cost": 30, "color": Color(1.0, 0.45, 0.4),
		"desc": "+35% damage. 30% less max health.",
		"mods": [{"stat": "damage", "op": _MORE, "value": 0.35}, {"stat": "max_hp", "op": _MORE, "value": -0.3}]},
	"lodestone": {"name": "Lodestone", "cost": 25, "color": Color(0.7, 0.75, 0.85),
		"desc": "Twice the pickup radius and +40% magic find. 8% slower.",
		"mods": [{"stat": "pickup_radius", "op": _MORE, "value": 1.0}, {"stat": "magic_find", "op": _ADD, "value": 0.4},
			{"stat": "move_speed", "op": _MORE, "value": -0.08}]},
	"bone_dice": {"name": "Bone Dice", "cost": 35, "color": Color(0.95, 0.9, 0.75),
		"desc": "+3 level-up rerolls each night. 10% less XP.", "rerolls": 3,
		"mods": [{"stat": "xp_gain", "op": _MORE, "value": -0.1}]},
	"iron_heart": {"name": "Iron Heart", "cost": 40, "color": Color(0.6, 0.65, 0.7),
		"desc": "+30 armor and +40% max health. 15% less damage.",
		"mods": [{"stat": "armor", "op": _ADD, "value": 30.0}, {"stat": "max_hp", "op": _MORE, "value": 0.4},
			{"stat": "damage", "op": _MORE, "value": -0.15}]},
	"soul_censer": {"name": "Soul Censer", "stars": 5, "color": Color(0.55, 0.9, 1.0), "power": "soul_lantern",
		"desc": "The Soul Lantern from the start: twice the souls, minions rise after 4 fewer."},
	"winter_tear": {"name": "Winter's Tear", "stars": 10, "color": Color(0.7, 0.92, 1.0), "power": "winter_crown",
		"desc": "Endless Winter from the start: Frost Aura (or +1 rank) with 30% more radius; bolts chill 20% of the time."},
	"cinder_heart": {"name": "Cinder Heart", "stars": 15, "color": Color(1.0, 0.55, 0.2), "power": "ember_ring",
		"desc": "The Ring of Embers from the start: every hit may ignite; reactions deal 50% more."},
}
const ORDER := ["glass_skull", "lodestone", "bone_dice", "iron_heart", "soul_censer", "winter_tear", "cinder_heart"]

## Weapon cards a night can start with, and what each costs to unlock once.
const WEAPONS := ["aura", "lightning", "orbit", "obol", "scythe", "nova", "bell", "spikes", "wisps", "trail"]
const WEAPON_COST := 20


static func data(id: String) -> Dictionary:
	return DEFS.get(id, {})


## "N ◆" or "N ★": what it takes to own relic `id`.
static func price_text(id: String) -> String:
	var d := data(id)
	return "%d ★" % d["stars"] if d.has("stars") else "%d ◆" % d["cost"]


static func extra_rerolls(id: String) -> int:
	return int(data(id).get("rerolls", 0))


## Gives `player` relic `relic` (may be "") and starting weapon `weapon`
## (an Upgrades id, may be ""). Call after HeroClass.apply().
static func apply(player: Player, relic: String, weapon: String) -> void:
	var stats := player.stats
	stats.remove_source(SOURCE)
	var d := data(relic)
	if not d.is_empty():
		stats.add_mods(SOURCE, d.get("mods", []))
		var power: String = d.get("power", "")
		if power != "":
			stats.innate_powers[power] = 1
			stats.add_mods(SOURCE, ItemData.POWERS[power].get("mods", []))
		player.inventory.refresh_powers()
	if weapon in WEAPONS and Upgrades.level_of(weapon, stats) == 0:
		Upgrades.apply(weapon, stats)
	stats.recalculate()
	stats.hp = stats.max_hp
