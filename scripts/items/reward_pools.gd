class_name RewardPools
extends RefCounted
## Original themed subsets of ItemData. No cross-item depletion: separate copies
## may duplicate. One stat/operation per item remains the generator's rule.

const THEMES := {
	"army": {"name": "Army", "stats": ["minion_max", "minion_damage", "minion_hp", "soul_chance", "soul_cost"], "powers": ["lich_shroud", "soul_lantern"]},
	"elemental": {"name": "Elemental", "stats": ["bolt_damage", "aura_damage", "aura_radius", "lightning_damage", "ignite_chance", "burn_dps", "chill_chance", "reaction_damage"], "powers": ["stormcaller", "winter_crown", "storm_eye", "dragonscale", "heart_of_storms", "ember_ring"]},
	"mobility": {"name": "Mobility", "stats": ["move_speed", "dash_cooldown"], "powers": ["stormstride", "blinkfire"]},
}

static func selection_text(theme: String) -> String:
	if not THEMES.has(theme): return "Broad equipment pool."
	return "%s pool: one matching affix if the slot/rarity permits; Legendary powers draw uniformly from matching compatible powers. Otherwise broad compatible gear. Independent copies can repeat; no depletion." % THEMES[theme]["name"]

static func affix_candidates(slot: String, rarity: int, theme := "", thematic_only := false, used: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if thematic_only and not THEMES.has(theme): return out
	for affix: Dictionary in ItemData.AFFIXES:
		if not slot in affix["slots"] or rarity < affix.get("min_rarity", ItemData.Rarity.MAGIC): continue
		if affix.has("theme") and affix["theme"] != theme: continue
		if used.has("%s:%d" % [affix["stat"], affix["op"]]): continue
		if thematic_only and not affix["stat"] in THEMES[theme]["stats"]: continue
		out.append(affix)
	return out

static func power_candidates(slot: String, theme := "") -> Array[String]:
	var out: Array[String] = []
	if THEMES.has(theme):
		for id: String in THEMES[theme]["powers"]:
			if ItemData.POWERS.has(id) and ItemData.POWERS[id]["slot"] == slot: out.append(id)
	return out if not out.is_empty() else ItemData.powers_for(slot)
