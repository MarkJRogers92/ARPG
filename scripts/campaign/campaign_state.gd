class_name CampaignState
extends RefCounted
## Plain saved facts; no live nodes, resources, positions or combat modifiers.

const SCHEMA_VERSION := 1
const VETERAN_SWARMS := ["Grunts", "Brutes", "Runners", "Cultists", "Lancers", "Gravediggers", "Shieldbearers", "Menders", "Bloaters", "Collectors", "Phylacteries", "Bosses", "FinalBoss", "Goblins", "Rival", "Thralls"]
const PHASES := ["TOWN", "EVENT_PENDING", "DEPARTURE_READY", "EXPEDITION_ACTIVE", "RESULT_PENDING", "CAMPAIGN_COMPLETE", "ABANDONED"]

static func fresh(hero: String, seed_value: int, account: Dictionary) -> Dictionary:
	var id := "campaign-%d-%d" % [Time.get_unix_time_from_system() * 1000000, Time.get_ticks_usec()]
	return {"schema_version": SCHEMA_VERSION, "content_version": CampaignCatalog.CONTENT_VERSION,
		"campaign_id": id, "seed": seed_value, "revision": 0, "phase": "TOWN", "hero_class": hero,
		"biome_index": 0, "gold": 60, "profile_snapshot": account.duplicate(true),
		"inventory": {"items": {}, "equipped": {}, "backpack": [], "tray": []},
		"talents": {"points": 3, "allocated": [], "earned": 3}, "specialization": "", "roster": [],
		"deployed_veteran": "", "graph": CampaignCatalog.route(seed_value, 0), "selected_node": "",
		"cleared_nodes": [], "clauses": [], "effects": [], "event": {}, "event_count": 0,
		"shop": [], "shop_generation": 0, "wager": {}, "reforge": {}, "veteran_candidate": {},
		"departure": {}, "result": {}, "receipts": {}, "successful_nodes": {}, "outbox": [],
		"clause_offers": {}, "item_serial": 0, "attempt_serial": 0, "completed": false}

static func combat_inventory(state: Dictionary) -> Dictionary:
	var inventory: Dictionary = state["inventory"]
	var worn := {}
	for slot: String in inventory["equipped"]:
		var id: String = inventory["equipped"][slot]
		worn[slot] = inventory["items"][id]["data"].duplicate(true)
	var bag := []
	for id: String in inventory["backpack"]:
		bag.append(inventory["items"][id]["data"].duplicate(true))
	return {"equipped": worn, "backpack": bag}

static func validate_item(data: Variant) -> String:
	if not data is Dictionary:
		return "Item data is not a dictionary."
	for key in ["slot", "name", "base_name", "rarity", "ilvl", "implicit", "affixes"]:
		if not data.has(key): return "Item is missing " + key
	if not data["slot"] is String or not data["slot"] in ItemData.SLOTS:
		return "Unknown equipment slot."
	if not data["name"] is String or not data["base_name"] is String:
		return "Invalid item name."
	if not data["rarity"] is int or int(data["rarity"]) < 0 or int(data["rarity"]) > 3 or not data["ilvl"] is int or int(data["ilvl"]) < 1 or int(data["ilvl"]) > 1000:
		return "Invalid item rarity or level."
	if not data["implicit"] is Array or not data["affixes"] is Array or data["affixes"].size() > 8 or data["implicit"].size() > 8:
		return "Invalid modifier list."
	for modifier in data["implicit"] + data["affixes"]:
		if not modifier is Dictionary or not modifier.get("stat", "") in PlayerStats.BASE or not modifier.get("op") is int or not int(modifier["op"]) in [0, 1, 2]:
			return "Unknown stat modifier."
		var value = modifier.get("value")
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 1000000.0:
			return "Nonfinite item modifier."
		if modifier.has("id") and ItemData.affix(str(modifier["id"])).is_empty(): return "Unknown item affix."
	var power = data.get("power", "")
	if not power is String or (power != "" and not ItemData.POWERS.has(power)): return "Unknown item power."
	return ""

static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Campaign data is not a dictionary."
	if not _plain(state): return "Invalid campaign value or excessive save structure."
	if state.get("schema_version") != SCHEMA_VERSION: return "Unsupported campaign schema."
	if state.get("content_version") != CampaignCatalog.CONTENT_VERSION: return "Unsupported campaign content version."
	for key in ["campaign_id", "phase", "hero_class", "selected_node", "specialization", "deployed_veteran"]:
		if not state.get(key) is String: return "Invalid field: " + key
	if state["campaign_id"].is_empty() or not state["phase"] in PHASES or not HeroClass.CLASSES.has(state["hero_class"]): return "Unknown campaign identity or phase."
	for key in ["seed", "revision", "biome_index", "gold", "event_count", "shop_generation", "item_serial", "attempt_serial"]:
		if not state.get(key) is int: return "Invalid integer: " + key
	if state["biome_index"] < 0 or state["biome_index"] > 2 or state["gold"] < 0 or state["gold"] > 100000000 or state["event_count"] < 0 or state["event_count"] > 2: return "Campaign quantities are out of range."
	for key in ["inventory", "talents", "profile_snapshot", "graph", "event", "wager", "reforge", "departure", "result", "receipts", "successful_nodes", "veteran_candidate", "clause_offers"]:
		if not state.get(key) is Dictionary: return "Invalid dictionary: " + key
	for key in ["roster", "cleared_nodes", "clauses", "effects", "shop", "outbox"]:
		if not state.get(key) is Array: return "Invalid array: " + key
	if state["specialization"] != "" and Specializations.find(state["hero_class"], state["specialization"]).is_empty(): return "Unknown specialization."
	var talents: Dictionary = state["talents"]
	if not talents.get("points") is int or not talents.get("earned") is int or not talents.get("allocated") is Array: return "Invalid talent data."
	var earned: int = talents["earned"]
	var spent := 0
	var owned := {SkillData.ROOT: true}
	for id in talents["allocated"]:
		if not id is String or id == SkillData.ROOT or not SkillData.NODES.has(id) or owned.has(id): return "Unknown or duplicate talent."
		owned[id] = true
		spent += SkillData.cost(id)
	if earned < 3 or earned > CampaignCatalog.MAX_TALENTS or talents["points"] < 0 or talents["points"] + spent != earned: return "Campaign talent budget does not balance."
	var reached := {SkillData.ROOT: true}
	var frontier: Array = [SkillData.ROOT]
	while not frontier.is_empty():
		for id: String in SkillData.neighbors(frontier.pop_back()):
			if owned.has(id) and not reached.has(id):
				reached[id] = true
				frontier.append(id)
	if reached.size() != owned.size(): return "Disconnected talent allocation."
	var profile_error := validate_profile(state["profile_snapshot"])
	if profile_error != "": return profile_error
	var inv: Dictionary = state["inventory"]
	if not inv.get("items") is Dictionary or not inv.get("equipped") is Dictionary or not inv.get("backpack") is Array or not inv.get("tray") is Array: return "Invalid inventory."
	if inv["backpack"].size() > Inventory.BACKPACK_SIZE: return "Backpack exceeds capacity."
	var located := {}
	for slot in inv["equipped"]:
		if not slot in ItemData.SLOTS: return "Unknown equipped slot."
		var id = inv["equipped"][slot]
		if not inv["items"].has(id): return "Missing equipped item."
		var equipped_record = inv["items"][id]
		if not equipped_record is Dictionary or not equipped_record.get("data") is Dictionary or equipped_record["data"].get("slot") != slot: return "Equipment slot mismatch."
	for id in inv["equipped"].values() + inv["backpack"] + inv["tray"]:
		if not id is String or located.has(id) or not inv["items"].has(id): return "Duplicate or missing inventory copy."
		located[id] = true
	if located.size() != inv["items"].size(): return "Unlocated inventory copy."
	for id in inv["items"]:
		var error := validate_record(inv["items"][id], id)
		if error != "": return error
	var graph: Dictionary = state["graph"]
	if not graph.get("nodes") is Dictionary or not graph.get("start") is Array or graph["start"].size() < 2: return "Invalid route graph."
	var counts := [0, 0, 0, 0]
	for id in graph["nodes"]:
		var node = graph["nodes"][id]
		if not node is Dictionary or node.get("id") != id or not node.get("depth") is int or node["depth"] < 1 or node["depth"] > 4 or not CampaignCatalog.CONTRACTS.has(node.get("contract")) or not node.get("next") is Array or not node.get("seed") is int: return "Invalid route node."
		counts[node["depth"] - 1] += 1
		if (node["depth"] == 4) != (node["contract"] == "finale"): return "Finale depth mismatch."
		if node.get("event", "") != "" and not CampaignCatalog.EVENTS.has(node["event"]): return "Unknown route event."
		if node["depth"] < 4 and node["next"].is_empty(): return "Route has no path to finale."
		for next_id in node["next"]:
			if not graph["nodes"].has(next_id): return "Missing route neighbor."
			var neighbor = graph["nodes"][next_id]
			if not neighbor is Dictionary or neighbor.get("depth") != node["depth"] + 1: return "Invalid route edge."
	if counts[3] != 1: return "Route must have one finale."
	for depth in 3:
		if counts[depth] < 2 or counts[depth] > 3: return "Route depth must have two or three choices."
	var reachable := {}
	frontier = graph["start"].duplicate()
	while not frontier.is_empty():
		var id = frontier.pop_back()
		if not graph["nodes"].has(id): return "Unknown start node."
		if reachable.has(id): continue
		reachable[id] = true
		frontier.append_array(graph["nodes"][id]["next"])
	if reachable.size() != graph["nodes"].size(): return "Unreachable route node."
	for id in state["cleared_nodes"]:
		if not graph["nodes"].has(id): return "Unknown cleared node."
	if state["selected_node"] != "" and not graph["nodes"].has(state["selected_node"]): return "Unknown committed node."
	if state["roster"].size() > 3 or state["clauses"].size() > 2: return "Roster or Ledger exceeds capacity."
	var veteran_ids := {}
	for veteran in state["roster"]:
		if validate_veteran(veteran, false) != "" or veteran_ids.has(veteran["id"]): return "Invalid or duplicate veteran."
		veteran_ids[veteran["id"]] = true
	if state["deployed_veteran"] != "" and not veteran_ids.has(state["deployed_veteran"]): return "Missing deployed veteran."
	var clause_ids := {}
	for clause in state["clauses"]:
		if not clause is Dictionary or not CampaignCatalog.CLAUSES.has(clause.get("id")) or clause_ids.has(clause["id"]) or not clause.get("accepted_biome") is int or clause["accepted_biome"] != state["biome_index"]: return "Invalid or duplicate Ledger clause."
		clause_ids[clause["id"]] = true
	for entry in state["shop"]:
		if not entry is Dictionary or not entry.get("price") is int or entry["price"] < 0 or validate_record(entry.get("item"), "") != "": return "Invalid stock."
	for receipt in state["outbox"]:
		if not receipt is Dictionary or not receipt.get("id") is String or not receipt.get("shards") is int or receipt["shards"] < 0 or not receipt.get("kills") is Dictionary: return "Invalid account receipt."
	var effect_error := validate_effects(state["effects"])
	if effect_error != "": return effect_error
	var candidate_error := validate_veteran(state["veteran_candidate"], true)
	if candidate_error != "": return candidate_error
	for receipt_id in state["receipts"]:
		var operation = state["receipts"][receipt_id]
		if not receipt_id is String or not operation is Dictionary or not operation.get("signature") is String or not operation.get("response") is Dictionary: return "Invalid saved operation receipt."
		var response: Dictionary = operation["response"]
		if response.get("ok") != true or not response.get("error") is String or response.get("operation_id") != receipt_id: return "Invalid operation response."
	if not state["event"].is_empty():
		if not CampaignCatalog.EVENTS.has(state["event"].get("id")) or not state["event"].get("resolved") is bool or not state["event"].get("offers") is Dictionary or not state["event"].get("choices") is Array: return "Invalid route event record."
		for choice in state["event"]["choices"]:
			if not choice is Dictionary or not choice.get("id") is String or not choice.get("name") is String: return "Invalid event choice."
		for offer in state["event"]["offers"].values():
			if validate_record(offer, "") != "": return "Invalid event offer."
	if not state["reforge"].is_empty():
		var reforge: Dictionary = state["reforge"]
		if not inv["items"].has(reforge.get("item_id")) or validate_record(reforge.get("old"), "") != "" or validate_record(reforge.get("new"), "") != "" or not reforge.get("cost") is int or reforge["cost"] < 0: return "Invalid pending reforge."
	if not state["wager"].is_empty():
		var bet: Dictionary = state["wager"]
		if not bet.get("stage") is int or bet["stage"] < 0 or bet["stage"] > 2 or not bet.get("status") in ["open", "won", "lost", "taken"] or not bet.get("prizes") is Array: return "Invalid saved wager."
		if not (bet.get("chance") is float or bet.get("chance") is int) or bet["chance"] < 0.0 or bet["chance"] > 0.85 or not bet.get("outcome") is Dictionary: return "Invalid wager outcome."
		if not bet["outcome"].is_empty() and (not bet["outcome"].get("won") is bool or not bet["outcome"].get("stage") is int): return "Malformed wager outcome."
		for prize in bet["prizes"]:
			if validate_record(prize, "") != "": return "Invalid wager prize."
	for offers in state["clause_offers"].values():
		if not offers is Array or offers.size() != 3: return "Invalid arsenal choices."
		for offer in offers:
			if validate_record(offer, "") != "": return "Invalid arsenal item."
	if not state["departure"].is_empty():
		var spec_error := validate_spec(state["departure"])
		if spec_error != "": return spec_error
	if state["phase"] == "RESULT_PENDING":
		var result: Dictionary = state["result"]
		if not result.get("outcome") in ["success", "failure", "retreat"] or not result.get("elapsed") is float or not is_finite(result["elapsed"]) or result["elapsed"] < 0.0: return "Invalid settled result."
	if state["phase"] == "EXPEDITION_ACTIVE":
		var departure: Dictionary = state["departure"]
		if departure.get("campaign_id") != state["campaign_id"] or departure.get("node_id") != state["selected_node"] or not departure.get("attempt_id") is String: return "Missing departure checkpoint."
	return "" 

static func validate_record(record: Variant, id: String) -> String:
	if not record is Dictionary or not record.get("id") is String or (id != "" and record["id"] != id) or not record.get("locked") is bool or not record.get("junk") is bool or not record.get("valuation") is int or record["valuation"] < 0 or not record.get("reforged_biomes") is Array: return "Invalid item record."
	var error := validate_item(record.get("data"))
	if error != "": return error
	if record["data"].get("campaign_id") != record["id"]: return "Item copy identity mismatch."
	return ""


static func _plain(value: Variant, depth := 0) -> bool:
	if depth > 32: return false
	if value is Dictionary:
		if value.size() > 20000: return false
		for key in value:
			if not (key is String or key is int) or not _plain(value[key], depth + 1): return false
		return true
	if value is Array:
		if value.size() > 20000: return false
		for entry in value:
			if not _plain(entry, depth + 1): return false
		return true
	if value is float: return is_finite(value)
	if value is String: return value.length() <= 100000
	return value == null or value is int or value is bool

static func validate_mods(mods: Variant) -> String:
	if not mods is Array or mods.size() > 1000: return "Invalid modifier snapshot."
	for mod in mods:
		if not mod is Dictionary or not PlayerStats.BASE.has(mod.get("stat")) or not mod.get("op") is int or not mod["op"] in [0, 1, 2]: return "Unknown snapshot modifier."
		var value = mod.get("value")
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 1000000.0: return "Invalid snapshot modifier value."
	return ""

static func validate_profile(profile: Dictionary) -> String:
	var error := validate_mods(profile.get("mods"))
	if error != "": return error
	if not profile.get("relic") is String or (profile["relic"] != "" and not Relics.DEFS.has(profile["relic"])): return "Unknown starting relic."
	if not profile.get("start_weapon") is String or (profile["start_weapon"] != "" and not Relics.WEAPONS.has(profile["start_weapon"])): return "Unknown starting weapon."
	if not profile.get("rerolls") is int or profile["rerolls"] < 0 or not profile.get("cards") is Dictionary: return "Invalid starting profile selection."
	for id in profile["cards"]:
		if not Upgrades.DEFS.has(id): return "Unknown profile card."
	return ""

static func validate_spec(spec: Dictionary) -> String:
	for key in ["campaign_id", "node_id", "attempt_id", "biome_id", "contract_id", "profile_id", "content_version"]:
		if not spec.get(key) is String: return "Invalid departure identity."
	if not Realm.REALMS.has(spec["biome_id"]) or not CampaignCatalog.CONTRACTS.has(spec["contract_id"]) or spec["content_version"] != CampaignCatalog.CONTENT_VERSION: return "Unknown departure content."
	for key in ["biome_index", "mission_seed", "item_level"]:
		if not spec.get(key) is int: return "Invalid departure integer."
	if spec["biome_index"] < 0 or spec["biome_index"] > 2 or spec["item_level"] < 1 or spec["item_level"] > 36: return "Invalid departure tier."
	for key in ["duration", "deadline"]:
		if not (spec.get(key) is float or spec.get(key) is int) or not is_finite(float(spec[key])) or spec[key] < 0: return "Invalid departure timing."
	if not spec.get("final_boss") is bool or not spec.get("elite") is bool or not spec.get("loot_band") is Array or spec["loot_band"].size() != 2 or not spec.get("effects") is Array or not spec.get("clauses") is Array or not spec.get("objectives") is Dictionary: return "Invalid departure rules."
	if spec["loot_band"] != CampaignCatalog.BANDS[spec["biome_index"]] or spec["biome_id"] != Realm.ORDER[spec["biome_index"]]: return "Invalid departure loot band."
	var contract: Dictionary = CampaignCatalog.CONTRACTS[spec["contract_id"]]
	if spec["duration"] != contract["duration"] or spec["deadline"] != contract["deadline"] or spec["final_boss"] != (spec["contract_id"] == "finale"): return "Departure contract policy was changed."
	var effect_error := validate_effects(spec["effects"])
	if effect_error != "": return effect_error
	var clauses := {}
	for clause in spec["clauses"]:
		if not clause is Dictionary or not CampaignCatalog.CLAUSES.has(clause.get("id")) or clauses.has(clause["id"]) or clause.get("accepted_biome") != spec["biome_index"]: return "Invalid departure Ledger."
		clauses[clause["id"]] = true
	if clauses.size() > 2: return "Departure Ledger exceeds capacity."
	if not spec["objectives"].get("seals") is int or spec["objectives"]["seals"] < 0 or spec["objectives"]["seals"] > 3: return "Invalid departure objectives."
	var loadout = spec.get("starting_loadout")
	if not loadout is Dictionary or not loadout.get("profile_snapshot") is Dictionary or not loadout.get("inventory") is Dictionary or not loadout.get("talents") is Dictionary or not loadout.get("veteran") is Dictionary: return "Invalid departure loadout."
	var error := validate_profile(loadout["profile_snapshot"])
	if error != "": return error
	error = validate_veteran(loadout["veteran"], true)
	if error != "": return error
	if not loadout["veteran"].is_empty() and loadout["veteran"]["rank"] > spec["biome_index"] + 1: return "Departure veteran exceeds biome rank."
	if not HeroClass.CLASSES.has(loadout.get("hero_class")) or not loadout.get("specialization") is String or not loadout.get("gold") is int or loadout["gold"] < 0: return "Invalid departure character."
	if loadout["specialization"] != "" and Specializations.find(loadout["hero_class"], loadout["specialization"]).is_empty(): return "Unknown departure specialization."
	var inv: Dictionary = loadout["inventory"]
	if not inv.get("equipped") is Dictionary or not inv.get("backpack") is Array or inv["backpack"].size() > Inventory.BACKPACK_SIZE: return "Invalid departure inventory."
	var copies := {}
	for slot in inv["equipped"]:
		if not slot in ItemData.SLOTS or not inv["equipped"][slot] is Dictionary or inv["equipped"][slot].get("slot") != slot: return "Invalid departure equipment slot."
	for item in inv["equipped"].values() + inv["backpack"]:
		error = validate_item(item)
		if error != "": return error
		var id = item.get("campaign_id", "")
		if not id is String or id == "" or copies.has(id): return "Duplicate departure inventory identity."
		copies[id] = true
	var talents: Dictionary = loadout["talents"]
	if not talents.get("points") is int or not talents.get("allocated") is Array: return "Invalid departure talent allocation."
	var owned := {SkillData.ROOT: true}
	var spent := 0
	for id in talents["allocated"]:
		if not id is String or id == SkillData.ROOT or not SkillData.NODES.has(id) or owned.has(id): return "Unknown or duplicate departure talent."
		owned[id] = true
		spent += SkillData.cost(id)
	if not talents.get("earned") is int or talents["earned"] < 3 or talents["earned"] > 18 or talents["points"] < 0 or talents["points"] + spent != talents["earned"]: return "Invalid departure talent budget."
	var reached := {SkillData.ROOT: true}
	var frontier: Array = [SkillData.ROOT]
	while not frontier.is_empty():
		for id: String in SkillData.neighbors(frontier.pop_back()):
			if owned.has(id) and not reached.has(id):
				reached[id] = true
				frontier.append(id)
	if reached.size() != owned.size(): return "Disconnected departure talents."
	return ""


static func validate_veteran(record: Variant, allow_empty: bool) -> String:
	if not record is Dictionary: return "Invalid veteran record."
	if record.is_empty(): return "" if allow_empty else "Missing veteran identity."
	for field in ["id", "name", "swarm", "label", "role", "pledge_node"]:
		if not record.get(field) is String: return "Invalid veteran field: " + field
	if record["id"] == "" or not record["swarm"] in VETERAN_SWARMS or not Army.ROLES.has(record["role"]): return "Unknown veteran identity or archetype."
	for field in ["rank", "deeds", "elite", "nights"]:
		if not record.get(field) is int or record[field] < 0: return "Invalid veteran quantity."
	if record["rank"] < 1 or record["rank"] > 3 or record["elite"] > 1: return "Invalid veteran rank."
	return ""

static func validate_effects(effects: Array) -> String:
	for effect in effects:
		if not effect is Dictionary or not effect.get("id") in ["quiet_bell", "loaded_passage", "unfinished", "borrowed_battalion"] or not effect.get("node_id") is String: return "Invalid scoped event effect."
		if effect.has("mods") and validate_mods(effect["mods"]) != "": return "Invalid event modifiers."
		match effect["id"]:
			"quiet_bell":
				if not effect.get("gold") is int or effect["gold"] != -30 or not effect.get("mods") is Array: return "Invalid Quiet Bell contract."
			"loaded_passage":
				if not (effect.get("odds") is float or effect.get("odds") is int) or effect["odds"] != 0.05: return "Invalid Loaded Passage odds."
			"unfinished":
				if effect.get("specialist") != true or effect.get("bonus_rare") != true: return "Invalid unfinished contract."
			"borrowed_battalion":
				if effect.get("minions") != 3: return "Invalid borrowed minion budget."
	return ""
