class_name CampaignFacilities
extends RefCounted
## Campaign-lifetime investment only. Prices/effects/previews share this catalog.
## Old schema-v1 saves have zero tiers until their next committed command.

const ORDER := ["wayfinder", "workshop", "veteran_hall"]
const DEFS := {
	"wayfinder": {"name": "Wayfinder Desk", "service": "route", "tiers": [
		{"cost": 60, "name": "Surveyed Roads", "benefit": "Scout danger and base Gold one junction beyond the available roads."},
		{"cost": 120, "name": "Long View", "benefit": "Extend partial scouting to two junctions ahead. Events and equipment prizes still need an Ash Map."},
	]},
	"workshop": {"name": "Workshop", "service": "market", "tiers": [
		{"cost": 90, "name": "Stocked Shelves", "benefit": "Two additional Magic offers (boots and amulet) now and after each successful expedition."},
		{"cost": 180, "name": "Tempered Tools", "benefit": "Reforging costs 20% less. Each item still has one reforge per biome."},
	]},
	"veteran_hall": {"name": "Veteran Hall", "service": "roster", "tiers": [
		{"cost": 80, "name": "Expanded Company", "benefit": "+1 army capacity on every departure; no veteran is required."},
		{"cost": 160, "name": "Company Drill", "benefit": "All minions gain 15% more damage and life on every departure."},
	]},
}

static func fresh() -> Dictionary:
	return {"wayfinder": 0, "workshop": 0, "veteran_hall": 0}

static func levels(state: Dictionary) -> Dictionary:
	var out := fresh()
	var saved: Variant = state.get("facilities", {})
	if saved is Dictionary:
		for id: String in ORDER:
			if saved.get(id, 0) is int: out[id] = clampi(saved.get(id, 0), 0, 2)
	return out

static func tier(state: Dictionary, id: String) -> int:
	return int(levels(state).get(id, 0))

static func validate_levels(value: Variant) -> String:
	if not value is Dictionary or value.size() != ORDER.size(): return "Invalid campaign facilities."
	for id: String in ORDER:
		if not value.get(id) is int or value[id] < 0 or value[id] > 2: return "Invalid facility tier."
	return ""

static func validate_goal(state: Dictionary) -> String:
	var goal: Variant = state.get("facility_goal", {})
	if not goal is Dictionary: return "Invalid facility goal."
	if goal.is_empty(): return ""
	if goal.size() != 2 or not goal.get("id") is String or not DEFS.has(goal["id"]) or not goal.get("tier") is int:
		return "Unknown facility goal."
	if goal["tier"] != tier(state, goal["id"]) + 1 or goal["tier"] > 2: return "Facility goal is not the next tier."
	return ""

static func upgrade(id: String, target_tier: int) -> Dictionary:
	if not DEFS.has(id) or target_tier < 1 or target_tier > 2: return {}
	return DEFS[id]["tiers"][target_tier - 1].duplicate(true)

static func goal(state: Dictionary) -> Dictionary:
	if validate_goal(state) != "": return {}
	var saved: Dictionary = state.get("facility_goal", {})
	if saved.is_empty(): return {}
	var out := upgrade(saved["id"], saved["tier"])
	out.merge({"id": saved["id"], "tier": saved["tier"], "facility_name": DEFS[saved["id"]]["name"]})
	return out

static func reforge_cost(state: Dictionary) -> int:
	return (48 if tier(state, "workshop") >= 2 else 60) * (int(state.get("biome_index", 0)) + 1)

static func army_mods(state_or_loadout: Dictionary) -> Array:
	var out := []
	var rank := tier(state_or_loadout, "veteran_hall")
	if rank >= 1: out.append({"stat": "minion_max", "op": PlayerStats.Op.ADD, "value": 1.0})
	if rank >= 2:
		out.append({"stat": "minion_damage", "op": PlayerStats.Op.MORE, "value": 0.15})
		out.append({"stat": "minion_hp", "op": PlayerStats.Op.MORE, "value": 0.15})
	return out

## Partial intelligence follows connected roads, never permanently reveals nodes.
## Ash Maps retain exclusive full event/prize information and saved reveal flags.
static func scouted_nodes(state: Dictionary, available: Array) -> Dictionary:
	var nodes: Dictionary = state.get("graph", {}).get("nodes", {})
	var frontier: Array[String] = []
	for node: Variant in available:
		var id := str(node.get("id", "")) if node is Dictionary else str(node)
		if nodes.has(id): frontier.append(id)
	var out := {}
	for distance in tier(state, "wayfinder"):
		var next: Array[String] = []
		for id: String in frontier:
			for neighbor: String in nodes[id].get("next", []):
				if not out.has(neighbor):
					out[neighbor] = true
					next.append(neighbor)
		frontier = next
	return out

static func contract_gold(state: Dictionary, node: Dictionary) -> int:
	var contract: Dictionary = CampaignCatalog.CONTRACTS.get(node.get("contract", ""), {})
	var payment := int(contract.get("gold", 0)) * (int(state.get("biome_index", 0)) + 1)
	for effect: Dictionary in state.get("effects", []):
		if effect.get("node_id", "") in [str(node.get("id", "")), "next"]:
			payment += int(effect.get("gold", 0))
	return maxi(0, payment)

static func funding_copy(state: Dictionary, node: Dictionary = {}) -> String:
	var target := goal(state)
	if target.is_empty(): return ""
	var bank := int(state.get("gold", 0))
	var remaining := maxi(0, int(target["cost"]) - bank)
	var text := "TOWN GOAL · %s tier %d · %d / %d G (%s)" % [target["facility_name"], target["tier"], mini(bank, int(target["cost"])), target["cost"], "%d G still needed" % remaining if remaining > 0 else "ready to purchase"]
	if not node.is_empty():
		var payment := contract_gold(state, node)
		text += "\nOn a successful clear: +%d contract G · %d G still needed (excludes optional rewards/shards)." % [payment, maxi(0, int(target["cost"]) - bank - payment)]
	return text
