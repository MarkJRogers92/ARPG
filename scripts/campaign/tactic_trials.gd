class_name TacticTrials
extends RefCounted
## Three short campaign contracts: original authored kits, not a parallel mode.

const DEFS := {
	"trial_army": {"kit": "Soul Legion rank 2, Soul Harvest rank 1, three ordinary soldiers; rally one if the army falls", "restriction": "Hero weapons disabled; movement and dash remain", "goal": "Survive 3:00 and deal 100 real Soul Army damage", "theme": "army", "relic": "ember_banner", "cards": ["legion", "legion", "harvest"]},
	"trial_dash": {"kit": "Stormstride lightning dash, -1 second dash cooldown before other modifiers, +30% lightning damage", "restriction": "Hero auto-weapons disabled; army remains", "goal": "Survive 3:00, dash 8 times and deal 30 real Stormstride damage", "theme": "mobility", "relic": "blade_compass", "cards": []},
	"trial_reaction": {"kit": "Frost Aura rank 1, Chain Lightning rank 1, Wisp Lantern rank 1", "restriction": "Only elemental auto-weapons; army and physical hero weapons disabled", "goal": "Survive 3:00 and deal 100 real reaction damage", "theme": "elemental", "relic": "relay_lens", "cards": ["aura", "lightning", "wisps"]},
}

static func description(id: String) -> String:
	var d: Dictionary = DEFS.get(id, {})
	return "KIT · %s\nRULE · %s\nGOAL · %s\nACCOUNT CHOICE · Clear to unlock %s; carry one relic, no automatic equip." % [d["kit"], d["restriction"], d["goal"], Relics.data(d["relic"])["name"]] if not d.is_empty() else ""

static func apply(player: Player, id: String) -> void:
	player.challenge_id = ""
	player.stats.remove_source("trial")
	if not DEFS.has(id): return
	player.challenge_id = id
	for card: String in DEFS[id]["cards"]: Upgrades.apply(card, player.stats)
	if id == "trial_dash":
		player.stats.innate_powers["stormstride"] = 1
		player.inventory.refresh_powers()
		player.stats.add_mods("trial", [{"stat": "dash_cooldown", "op": PlayerStats.Op.ADD, "value": -1.0}, {"stat": "lightning_damage", "op": PlayerStats.Op.MORE, "value": 0.3}])
	player.stats.recalculate()

static func allowed_card(id: String, trial: String) -> bool:
	if not DEFS.has(trial): return true
	if id.begins_with("synergy_"): return false
	if trial == "trial_reaction": return id in ["aura", "lightning", "wisps", "trail", "ignite", "frostbite", "move_speed", "max_hp", "regen", "magnet", "bulwark", "deadly_aim", "catalyst"]
	return id in ["legion", "harvest", "move_speed", "max_hp", "regen", "magnet", "bulwark", "deadly_aim", "catalyst"]

static func army_allowed(trial: String) -> bool:
	return trial != "trial_reaction"

static func progress(id: String, damage: Dictionary, dashes: int) -> Dictionary:
	match id:
		"trial_army": return {"done": float(damage.get("Soul Army", 0.0)) >= 100.0, "text": "Army damage %d/100" % mini(int(damage.get("Soul Army", 0.0)), 100)}
		"trial_dash": return {"done": dashes >= 8 and float(damage.get("Stormstride", 0.0)) >= 30.0, "text": "Dashes %d/8 · dash damage %d/30" % [mini(dashes, 8), mini(int(damage.get("Stormstride", 0.0)), 30)]}
		"trial_reaction": return {"done": float(damage.get("Reactions", 0.0)) >= 100.0, "text": "Reaction damage %d/100" % mini(int(damage.get("Reactions", 0.0)), 100)}
	return {"done": true, "text": ""}
