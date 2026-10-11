class_name CampaignPlanning
extends RefCounted
## Small town choices. All mutation belongs to CampaignController.

const PREPARATIONS := {
	"recovery": {"name": "Recovery draught", "cost": 30, "desc": "Once this attempt, falling to 25% HP restores 35% max HP. No manual input."},
	"survey": {"name": "Road survey", "cost": 15, "desc": "Choose a route first. On departure, reveal its first still-hidden connected road (including its finale if next). Knowledge survives failure."},
	"recruits": {"name": "Two field recruits", "cost": 25, "desc": "Begin this attempt with two ordinary soldiers, within army capacity. They are not banked veterans."},
}
const BENEFITS := {
	"supplier": {"name": "Supplier rescued", "desc": "20 Gold off one Market purchase; unused credit expires on departure."},
	"tools": {"name": "Workshop tools recovered", "desc": "One free reforge (normal per-item/biome limit); unused credit expires on departure."},
	"veteran": {"name": "Veteran escorted home", "desc": "One free preparation; unused voucher expires on departure."},
}
const COMMISSIONS := {
	"hunt": "supplier", "breach": "tools", "elite_hunt": "veteran",
}
const DETOURS := {
	"supplier": {"title": "Supplier rescue", "action": "Rescue supplier", "copy": "Optional: reach the marked supplier, interact, then clear the Hunt for one Market credit."},
	"tools": {"title": "Workshop salvage", "action": "Recover tools", "copy": "Optional: collect the marked tool chest, then close the Breach for one free reforge."},
	"veteran": {"title": "Veteran escort", "action": "Escort veteran", "copy": "Optional: reach the marked veteran, interact, then defeat the champion for one preparation voucher."},
}

static func fresh() -> Dictionary:
	return {"preparation": "", "town_benefits": {}, "fatigue_enabled": false}

static func materialize(state: Dictionary) -> void:
	for key: String in fresh():
		if not state.has(key): state[key] = fresh()[key]

static func preparation_cost(state: Dictionary, id: String) -> int:
	if not PREPARATIONS.has(id): return -1
	return 0 if state.get("town_benefits", {}).has("veteran") else int(PREPARATIONS[id]["cost"])

static func market_cost(state: Dictionary, price: int) -> int:
	return maxi(price - (20 if state.get("town_benefits", {}).has("supplier") else 0), 0)

static func reforge_cost(state: Dictionary) -> int:
	return 0 if state.get("town_benefits", {}).has("tools") else CampaignFacilities.reforge_cost(state)

static func selected_contract(state: Dictionary) -> String:
	return str(state.get("graph", {}).get("nodes", {}).get(state.get("selected_node", ""), {}).get("contract", ""))

static func survey_target(state: Dictionary) -> String:
	var nodes: Dictionary = state.get("graph", {}).get("nodes", {})
	var chosen: Dictionary = nodes.get(state.get("selected_node", ""), {})
	for id: String in chosen.get("next", []):
		if not nodes[id].get("revealed", false): return id
	return ""

static func available(state: Dictionary, veteran: Dictionary) -> bool:
	return veteran.get("pledge_node", "") == "" and (not state.get("fatigue_enabled", false) or int(veteran.get("fatigue", 0)) < 2)

static func veteran_copy(state: Dictionary, veteran: Dictionary, contract := "") -> String:
	var fatigue := int(veteran.get("fatigue", 0))
	var availability := "Available"
	if veteran.get("pledge_node", "") != "": availability = "Pledged until %s clears" % veteran["pledge_node"]
	elif state.get("fatigue_enabled", false) and fatigue >= 2: availability = "Resting (2/2 fatigue)"
	elif state.get("fatigue_enabled", false): availability += " · fatigue %d/2" % fatigue
	var role := str(veteran.get("role", "brawler"))
	var fit := "Reliable frontline support"
	if contract == "trial_reaction": fit = "Army disabled for this trial; this veteran rests at home"
	elif contract == "breach": fit = "Ranged support suits scattered objectives" if role == "ranged" else "Guard stance protects objective stops"
	elif contract in ["elite_hunt", "trial_dash"]: fit = "Focus Hunt stance on the marked threat"
	elif contract == "trial_army": fit = "Army-led kit: any veteran adds a steady opening"
	var rank := mini(int(veteran.get("rank", 1)), int(state.get("biome_index", 0)) + 1)
	return "%s · %s · rank %d (departure %d) · %d deeds\n%s" % [availability, role, int(veteran.get("rank", 1)), rank, int(veteran.get("deeds", 0)), fit]

static func validate(state: Dictionary) -> String:
	if state.has("preparation") and (not state["preparation"] is String or state["preparation"] != "" and not PREPARATIONS.has(state["preparation"])): return "Unknown preparation slot."
	if state.has("fatigue_enabled") and not state["fatigue_enabled"] is bool: return "Invalid fatigue option."
	if state.has("town_benefits"):
		if not state["town_benefits"] is Dictionary or state["town_benefits"].size() > BENEFITS.size(): return "Invalid town benefits."
		for id: Variant in state["town_benefits"]:
			var record: Variant = state["town_benefits"][id]
			if not BENEFITS.has(id) or not record is Dictionary or not record.get("node_id") is String or record.get("expires") != "departure": return "Invalid town benefit lifetime."
	return ""
