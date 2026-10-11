class_name CampaignCatalog
extends RefCounted
## Authored campaign rules. Consequential randomness always has its own stream.

const CONTENT_VERSION := "expedition-v1"
const BANDS := [[1, 12], [10, 24], [20, 36]]
const MAX_TALENTS := 18
const CONTRACTS := {
	"hunt": {"name": "Hunt", "duration": 300.0, "deadline": 0.0, "gold": 100, "reward": "Balanced equipment", "danger": "A closing pressure wave", "icon": "⚔"},
	"breach": {"name": "Seal the Breach", "duration": 360.0, "deadline": 420.0, "gold": 110, "reward": "Sealkeeper's equipment", "danger": "Three scattered seals", "icon": "◇"},
	"elite_hunt": {"name": "Elite Hunt", "duration": 300.0, "deadline": 420.0, "gold": 140, "reward": "Targeted upper-tier Rare", "danger": "A marked champion at 5:00", "icon": "✦"},
	"cursed_cache": {"name": "Cursed Cache", "duration": 360.0, "deadline": 0.0, "gold": 100, "reward": "Optional cache treasure", "danger": "An optional cursed cache", "icon": "▣"},
	"trial_army": {"name": "Commander's Vigil", "duration": 180.0, "deadline": 240.0, "gold": 90, "reward": "Army-themed Rare", "danger": "Army-led trial · hero weapons disabled", "icon": "⚑"},
	"trial_dash": {"name": "Stormpath Trial", "duration": 180.0, "deadline": 240.0, "gold": 90, "reward": "Mobility-themed Rare", "danger": "Dash-led trial · hero auto-weapons disabled", "icon": "↯"},
	"trial_reaction": {"name": "Rime and Spark", "duration": 180.0, "deadline": 240.0, "gold": 90, "reward": "Elemental-themed Rare", "danger": "Reaction trial · elemental auto-weapons only", "icon": "❄"},
	"finale": {"name": "Biome Finale", "duration": 900.0, "deadline": 0.0, "gold": 250, "reward": "A realm conquered", "danger": "Survive 15:00, then defeat the realm boss", "icon": "♜"},
}
const CLAUSES := {
	"advance_payment": {"name": "Advance Payment", "benefit": "100 Gold × biome", "consequence": "One Debt Collector arrives with the final boss."},
	"stolen_arsenal": {"name": "Stolen Arsenal", "benefit": "Choose a targeted upper-tier Rare", "consequence": "Two shieldbearing elites arrive once below half boss health."},
	"borrowed_battalion": {"name": "Borrowed Battalion", "benefit": "Three ordinary minions on every attempt of the next node", "consequence": "Two fixed reinforcement waves, 45 and 90 seconds after boss arrival."},
}
const EVENTS := {
	"toll": {"name": "The Toll That Wasn't There", "text": "A brass hand waits beside a bridge that yesterday had no keeper.", "choices": [{"id": "pay", "name": "Pay 30 Gold — claim the shown item", "cost": 30}, {"id": "leave", "name": "Leave by the free passage"}]},
	"ash_map": {"name": "A Map Written in Ash", "text": "Someone has traced tomorrow's dangers in the cold ashes of a fire.", "choices": [{"id": "reveal", "name": "Read the map — reveal the roads ahead"}, {"id": "gold", "name": "Sell the parchment — 25 Gold"}]},
	"coffins": {"name": "Three Coffins", "text": "Three intact offerings. Each has a 60% Rare, 40% Magic chance; choose a slot.", "choices": [{"id": "weapon", "name": "Open the weapon coffin"}, {"id": "chest", "name": "Open the armor coffin"}, {"id": "ring", "name": "Open the ring coffin"}, {"id": "leave", "name": "Leave the dead their gifts"}]},
	"inventory": {"name": "A Dead Man's Inventory", "text": "Trade one selected unlocked backpack item for the same rarity in another slot.", "choices": [{"id": "trade", "name": "Trade the selected item"}, {"id": "leave", "name": "Keep your belongings"}]},
	"quiet_bell": {"name": "The Quiet Bell", "text": "A muffled bell offers shelter. The next node pays 30 less Gold, but grants 25% armor and 10% max health until its first clear.", "choices": [{"id": "accept", "name": "Accept its protection"}, {"id": "leave", "name": "Keep the ordinary contract"}]},
	"loaded_passage": {"name": "Loaded Passage", "text": "The Ferryman leaves a weighted coin: +5 percentage points on your next first wager, or a certain 15 Gold.", "choices": [{"id": "odds", "name": "Keep the coin — +5% first-wager chance"}, {"id": "gold", "name": "Take 15 Gold"}]},
	"unfinished": {"name": "The Unfinished Contract", "text": "A named specialist guards unfinished work. Accept one extra encounter for a bonus Rare on this node's first success.", "choices": [{"id": "accept", "name": "Finish the contract — specialist and Rare reward"}, {"id": "leave", "name": "Decline the extra encounter"}]},
	"honest_ferryman": {"name": "The Honest Ferryman", "text": "For once the price is written plainly. Inspect the Ledger; accepting a bargain is optional.", "choices": [{"id": "view", "name": "Read the Ledger without accepting a debt"}, {"id": "leave", "name": "Take the safe route"}]},
}
const PRICES := [20, 50, 100, 220]

static func stream(seed_value: int, purpose: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [seed_value, CONTENT_VERSION, purpose])
	return rng

static func item_level(biome: int, depth: int, upper := false) -> int:
	var band: Array = BANDS[clampi(biome, 0, 2)]
	var t := clampf(float(depth - 1) / 3.0, 0.0, 1.0)
	if upper:
		t = maxf(t, 0.65)
	return roundi(lerpf(band[0], band[1], t))

static func valuation(data: Dictionary, biome: int) -> int:
	return PRICES[clampi(int(data.get("rarity", 0)), 0, 3)] * (biome + 1)

static func sale_value(record: Dictionary) -> int:
	return maxi(0, int(record.get("valuation", 0)) / 4)

static func route(seed_value: int, biome: int, trials: Array = []) -> Dictionary:
	var rng := stream(seed_value, "route:%d" % biome)
	var nodes := {}
	var layers := []
	var types: Array = ["hunt", "breach", "elite_hunt", "cursed_cache"]
	var event_ids: Array = EVENTS.keys()
	var offset := rng.randi_range(0, 3)
	for depth in range(1, 4):
		var layer := []
		for choice in rng.randi_range(2, 3):
			var id := "%d:%d:%d" % [biome, depth, choice]
			var contract: String = types[(offset + depth + choice - 1) % types.size()]
			nodes[id] = {"id": id, "depth": depth, "contract": contract, "elite": choice > 0 and rng.randf() < 0.35,
				"seed": int(rng.randi()), "event": event_ids[rng.randi_range(0, event_ids.size() - 1)] if rng.randf() < 0.65 else "",
				"next": [], "reward_slot": ItemData.SLOTS[rng.randi_range(0, ItemData.SLOTS.size() - 1)]}
			layer.append(id)
		# Keep at least one ordinary contract at every junction. Only owned
		# trials enter newly generated roads; legacy graphs remain unchanged.
		var owned_trials := trials.filter(func(trial: Variant) -> bool: return TacticTrials.DEFS.has(trial))
		if not owned_trials.is_empty():
			var trial: String = owned_trials[(depth - 1 + biome) % owned_trials.size()]
			nodes[layer[-1]]["contract"] = trial
			nodes[layer[-1]]["elite"] = false
		for id: String in layer:
			var contract: String = nodes[id]["contract"]
			nodes[id]["commission"] = CampaignPlanning.COMMISSIONS.get(contract, "")
			nodes[id]["reward_theme"] = reward_theme(contract)
		layers.append(layer)
	var boss := "%d:boss" % biome
	nodes[boss] = {"id": boss, "depth": 4, "contract": "finale", "elite": false, "seed": int(rng.randi()), "event": "", "next": [], "reward_slot": "weapon"}
	for depth in 3:
		for id: String in layers[depth]:
			if depth < 2:
				var next_layer: Array = layers[depth + 1]
				var position: int = layers[depth].find(id)
				nodes[id]["next"] = [next_layer[position % next_layer.size()], next_layer[(position + 1) % next_layer.size()]]
			else:
				nodes[id]["next"] = [boss]
	return {"seed": seed_value, "content_version": CONTENT_VERSION, "start": layers[0], "nodes": nodes}

static func reward_theme(contract: String) -> String:
	if TacticTrials.DEFS.has(contract): return TacticTrials.DEFS[contract]["theme"]
	return {"hunt": "army", "breach": "elemental", "elite_hunt": "mobility", "cursed_cache": "army"}.get(contract, "")

static func valid_success(spec: Dictionary, result: Dictionary) -> bool:
	var t := float(result.get("elapsed", -1.0))
	if not is_finite(t) or t < float(spec["duration"]) or (float(spec["deadline"]) > 0.0 and t > float(spec["deadline"]) + 0.05):
		return false
	var objectives: Dictionary = result.get("objectives", {})
	if TacticTrials.DEFS.has(spec["contract_id"]):
		var damage: Variant = objectives.get("trial_damage", {})
		var dashes: Variant = objectives.get("trial_dashes", 0)
		if not damage is Dictionary or not dashes is int or dashes < 0: return false
		for value: Variant in damage.values():
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return false
		return bool(TacticTrials.progress(spec["contract_id"], damage, dashes)["done"])
	match spec["contract_id"]:
		"breach": return int(objectives.get("seals", 0)) >= 3
		"elite_hunt": return objectives.get("elite_dead", false) == true
		"finale": return objectives.get("boss_dead", false) == true
	return true
