class_name CampaignController
extends Node
## Sole authority for banked campaign facts. Commands clone, validate, persist,
## then publish. Combat and presentation never hold a writable bank balance.

signal changed(snapshot: Dictionary)
signal error_raised(message: String)

var state: Dictionary = {}
var last_error := ""

func snapshot() -> Dictionary:
	return state.duplicate(true)

func _error(message: String) -> Dictionary:
	last_error = message
	error_raised.emit(message)
	return {"ok": false, "error": message}

func _publish(next: Dictionary) -> void:
	state = next
	last_error = ""
	changed.emit(snapshot())

func _commit(next: Dictionary) -> Dictionary:
	next["revision"] = int(next["revision"]) + 1
	if not CampaignSave.write(next): return _error(CampaignSave.last_error)
	_publish(next)
	return {"ok": true, "error": ""}

func _command(kind: String, operation_id: String, arguments: Array, action: Callable, town_only := true) -> Dictionary:
	if state.is_empty(): return _error("No campaign is loaded.")
	if operation_id == "": operation_id = "%s:op:%d:%s" % [state["campaign_id"], state["revision"] + 1, kind]
	var signature := kind + ":" + var_to_str(arguments)
	if state["receipts"].has(operation_id):
		var receipt: Dictionary = state["receipts"][operation_id]
		if receipt["signature"] != signature: return _error("That operation receipt belongs to a different command.")
		return receipt["response"].duplicate(true)
	if town_only and not state["phase"] in ["TOWN", "EVENT_PENDING", "DEPARTURE_READY"]: return _error("This service is available in town.")
	var next := state.duplicate(true)
	var response: Dictionary = action.call(next)
	if not response.get("ok", false): return _error(response.get("error", "Command could not complete."))
	response["operation_id"] = operation_id
	response["error"] = ""
	next["receipts"][operation_id] = {"signature": signature, "response": response.duplicate(true)}
	var saved := _commit(next)
	return response if saved["ok"] else saved

func create(hero_class := "", campaign_seed := 0) -> Dictionary:
	if state.is_empty() and CampaignSave.exists():
		var loaded := load_campaign()
		if not loaded["ok"]: return loaded
	if not state.is_empty():
		var delivered := deliver_outbox()
		if not delivered["ok"]: return delivered
	var hero: String = hero_class if hero_class != "" else MetaProgress.current_class()
	if not HeroClass.CLASSES.has(hero) or not MetaProgress.class_unlocked(hero): return _error("That hero class is not unlocked.")
	var stats := PlayerStats.new()
	MetaProgress.apply(stats)
	var mods := []
	for mod: Dictionary in stats._mods:
		if mod["source"] == "meta": mods.append({"stat": mod["stat"], "op": mod["op"], "value": mod["value"]})
	var account := {"mods": mods, "relic": MetaProgress.current_relic(), "start_weapon": MetaProgress.current_start_weapon(), "rerolls": MetaProgress.rerolls(), "cards": MetaProgress.cards.duplicate(true)}
	var seed_value: int = campaign_seed if campaign_seed != 0 else int(Time.get_ticks_usec())
	var next := CampaignState.fresh(hero, seed_value, account)
	var rng := CampaignCatalog.stream(seed_value, "starting-gear")
	for slot: String in ItemData.SLOTS:
		var record := _item(next, 1, ItemData.Rarity.NORMAL, slot, rng)
		next["inventory"]["items"][record["id"]] = record
		next["inventory"]["equipped"][slot] = record["id"]
	var echo := MetaProgress.chosen_veteran()
	if not echo.is_empty():
		var veteran := _veteran_record(echo, next["campaign_id"] + ":echo")
		next["roster"].append(veteran)
		next["deployed_veteran"] = veteran["id"]
	_refresh_stock(next)
	return _commit(next)

func load_campaign() -> Dictionary:
	var loaded := CampaignSave.read()
	if loaded.is_empty(): return _error(CampaignSave.last_error if CampaignSave.last_error != "" else "No saved campaign.")
	_publish(loaded)
	# Delivery can safely replay after a crash; the profile remembers receipt IDs.
	var delivery := deliver_outbox()
	return {"ok": true, "error": "", "delivery_pending": not delivery["ok"]}

func available_routes() -> Array:
	if state.is_empty() or state["completed"]: return []
	if state["selected_node"] != "": return [state["graph"]["nodes"][state["selected_node"]].duplicate(true)]
	var ids: Array = state["graph"]["start"]
	if not state["cleared_nodes"].is_empty(): ids = state["graph"]["nodes"][state["cleared_nodes"][-1]]["next"]
	var out := []
	for id: String in ids:
		if not state["successful_nodes"].has(id): out.append(state["graph"]["nodes"][id].duplicate(true))
	return out

func choose_route(node_id: String, operation_id := "") -> Dictionary:
	return _command("route", operation_id, [node_id], func(next: Dictionary) -> Dictionary:
		if next["selected_node"] != "": return {"ok": false, "error": "Your committed route must be cleared before choosing another."}
		var allowed := false
		for node: Dictionary in available_routes():
			if node["id"] == node_id: allowed = true
		if not allowed: return {"ok": false, "error": "That route is not connected to your path."}
		next["selected_node"] = node_id
		for veteran: Dictionary in next["roster"]:
			if veteran.get("pledge_node", "") == "next": veteran["pledge_node"] = node_id
		for effect: Dictionary in next["effects"]:
			if effect.get("node_id", "") == "next": effect["node_id"] = node_id
		var node: Dictionary = next["graph"]["nodes"][node_id]
		if node["event"] != "" and next["event_count"] < 2:
			next["event"] = _prepare_event(next, node)
			next["event_count"] += 1
			next["phase"] = "EVENT_PENDING"
		else:
			next["event"] = {}
			next["phase"] = "DEPARTURE_READY"
		return {"ok": true})

func _prepare_event(next: Dictionary, node: Dictionary) -> Dictionary:
	var id: String = node["event"]
	var event: Dictionary = CampaignCatalog.EVENTS[id].duplicate(true)
	event.merge({"id": id, "resolved": false, "offers": {}, "node_id": node["id"]})
	var rng := CampaignCatalog.stream(node["seed"], "event")
	var level := CampaignCatalog.item_level(next["biome_index"], node["depth"])
	if id == "toll": event["offers"]["prize"] = _item(next, level, ItemData.Rarity.MAGIC, node["reward_slot"], rng)
	if id == "coffins":
		for slot: String in ["weapon", "chest", "ring"]:
			var rarity := ItemData.Rarity.RARE if rng.randf() < 0.6 else ItemData.Rarity.MAGIC
			event["offers"][slot] = _item(next, level, rarity, slot, rng)
	if id == "inventory":
		# Offers are attached to exact input copies; preview/reload never rerolls.
		for item_id: String in next["inventory"]["backpack"]:
			var record: Dictionary = next["inventory"]["items"][item_id]
			if record["locked"]: continue
			var slots: Array = ItemData.SLOTS.duplicate()
			slots.erase(record["data"]["slot"])
			var slot: String = slots[rng.randi_range(0, slots.size() - 1)]
			event["offers"][item_id] = _item(next, level, record["data"]["rarity"], slot, rng)
	return event

func resolve_event(choice_id: String, operation_id := "", selection: Dictionary = {}) -> Dictionary:
	return _command("event", operation_id, [choice_id, selection], func(next: Dictionary) -> Dictionary:
		var event: Dictionary = next["event"]
		if next["phase"] != "EVENT_PENDING" or event.get("resolved", true): return {"ok": false, "error": "There is no unresolved event."}
		var valid := false
		for choice: Dictionary in event["choices"]:
			if choice["id"] == choice_id: valid = true
		if not valid: return {"ok": false, "error": "Unknown event choice."}
		var node_id: String = next["selected_node"]
		match event["id"]:
			"toll":
				if choice_id == "pay":
					if next["gold"] < 30: return {"ok": false, "error": "You need 30 Gold; the free passage remains available."}
					next["gold"] -= 30
					_store(next, event["offers"]["prize"])
			"ash_map":
				if choice_id == "gold": next["gold"] += 25
				else:
					event["revealed"] = true
					for route_id: String in next["graph"]["nodes"][node_id]["next"]:
						next["graph"]["nodes"][route_id]["revealed"] = true
			"coffins":
				if choice_id != "leave": _store(next, event["offers"][choice_id])
			"inventory":
				if choice_id == "trade":
					var id: String = selection.get("item_id", "")
					if not event["offers"].has(id) or not next["inventory"]["backpack"].has(id) or next["inventory"]["items"][id]["locked"]: return {"ok": false, "error": "Select an eligible unlocked backpack item."}
					_remove_item(next, id)
					_store(next, event["offers"][id])
			"quiet_bell":
				if choice_id == "accept": next["effects"].append({"id": "quiet_bell", "node_id": node_id, "gold": -30, "mods": [{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.25}, {"stat": "max_hp", "op": PlayerStats.Op.INCREASED, "value": 0.10}]})
			"loaded_passage":
				if choice_id == "gold": next["gold"] += 15
				else: next["effects"].append({"id": "loaded_passage", "node_id": "wager", "odds": 0.05})
			"unfinished":
				if choice_id == "accept": next["effects"].append({"id": "unfinished", "node_id": node_id, "specialist": true, "bonus_rare": true})
		event["resolved"] = true
		event["choice"] = choice_id
		event["selection"] = selection.duplicate(true)
		next["phase"] = "DEPARTURE_READY"
		return {"ok": true})

func depart(operation_id := "") -> Dictionary:
	return _command("depart", operation_id, [], func(next: Dictionary) -> Dictionary:
		if not next["phase"] in ["TOWN", "DEPARTURE_READY"]: return {"ok": false, "error": "This attempt must settle and its result must be acknowledged before departure."}
		if next["completed"] or next["selected_node"] == "": return {"ok": false, "error": "Choose a route and resolve its event first."}
		if not next["inventory"]["tray"].is_empty(): return {"ok": false, "error": "Claim, sell or discard the rewards in your tray before departure."}
		if not next["reforge"].is_empty(): return {"ok": false, "error": "Choose your reforge roll before departure."}
		if not next["veteran_candidate"].is_empty(): return {"ok": false, "error": "Keep or decline the veteran candidate before departure."}
		if next["wager"].get("status", "") in ["open", "won"]: return {"ok": false, "error": "Take or finish your reserved Ferryman prize before departure."}
		var node: Dictionary = next["graph"]["nodes"][next["selected_node"]]
		var contract: Dictionary = CampaignCatalog.CONTRACTS[node["contract"]]
		next["attempt_serial"] += 1
		var veteran := {}
		for rec: Dictionary in next["roster"]:
			if rec["id"] == next["deployed_veteran"] and rec.get("pledge_node", "") == "":
				veteran = rec.duplicate(true)
				veteran["rank"] = mini(veteran["rank"], next["biome_index"] + 1)
		var effects := []
		for effect: Dictionary in next["effects"]:
			if effect.get("node_id", "") == node["id"]: effects.append(effect.duplicate(true))
		var spec := {"campaign_id": next["campaign_id"], "biome_id": Realm.ORDER[next["biome_index"]], "biome_index": next["biome_index"],
			"node_id": node["id"], "attempt_id": "%s:attempt:%d" % [next["campaign_id"], next["attempt_serial"]], "contract_id": node["contract"],
			"profile_id": "%s:%s:%s" % [Realm.ORDER[next["biome_index"]], node["contract"], "elite" if node["elite"] else "normal"],
			"mission_seed": node["seed"], "content_version": CampaignCatalog.CONTENT_VERSION, "duration": contract["duration"], "deadline": contract["deadline"],
			"final_boss": node["contract"] == "finale", "loot_band": CampaignCatalog.BANDS[next["biome_index"]].duplicate(),
			"item_level": CampaignCatalog.item_level(next["biome_index"], node["depth"], node["contract"] == "elite_hunt"), "elite": node["elite"],
			"objectives": {"seals": 3 if node["contract"] == "breach" else 0}, "effects": effects, "clauses": next["clauses"].duplicate(true),
			"starting_loadout": {"hero_class": next["hero_class"], "profile_snapshot": next["profile_snapshot"].duplicate(true),
				"inventory": CampaignState.combat_inventory(next), "talents": next["talents"].duplicate(true), "specialization": next["specialization"],
				"veteran": veteran, "gold": next["gold"]}}
		next["departure"] = spec.duplicate(true)
		next["phase"] = "EXPEDITION_ACTIVE"
		return {"ok": true, "spec": spec}, false)

func resume_spec() -> Dictionary:
	return state["departure"].duplicate(true) if not state.is_empty() and state["phase"] == "EXPEDITION_ACTIVE" else {}

func settle(result: Dictionary) -> Dictionary:
	if state.is_empty(): return _error("No campaign is loaded.")
	var spec: Dictionary = state["departure"]
	if spec.is_empty(): return _error("No committed departure.")
	for key in ["campaign_id", "node_id", "attempt_id"]:
		if result.get(key) != spec.get(key): return _error("Stale or unrelated expedition result.")
	var receipt_id: String = spec["attempt_id"] + ":settlement"
	if state["receipts"].has(receipt_id): return state["receipts"][receipt_id]["response"].duplicate(true)
	if state["phase"] != "EXPEDITION_ACTIVE": return _error("This attempt has already ended.")
	if not result.get("outcome", "") in ["success", "failure", "retreat"]: return _error("Unknown expedition outcome.")
	var elapsed_value = result.get("elapsed")
	if not (elapsed_value is float or elapsed_value is int) or not is_finite(float(elapsed_value)) or float(elapsed_value) < 0.0: return _error("Invalid terminal combat time.")
	if not result.get("objectives", {}) is Dictionary or not result.get("kills_by", {}) is Dictionary or not result.get("loose_shards", 0) is int: return _error("Invalid expedition report.")
	for count in result.get("kills_by", {}).values():
		if not count is int or count < 0 or count > 1000000: return _error("Invalid Bestiary report.")
	if result["outcome"] == "success" and not CampaignCatalog.valid_success(spec, result): return _error("The contract's success requirements were not met.")
	var next := state.duplicate(true)
	var summary := {"outcome": result["outcome"], "elapsed": float(elapsed_value), "gold": 0, "shard_conversion": 0,
		"talent_points": 0, "biome_complete": false, "campaign_complete": false, "items": [], "report": result.get("report", {}).duplicate(true)}
	if result["outcome"] == "success":
		if next["successful_nodes"].has(spec["node_id"]): return _error("This node has already paid its reward.")
		var reconciled := _reconcile_inventory(next, result.get("inventory", {}), spec)
		if reconciled != "": return _error(reconciled)
		var biome: int = spec["biome_index"]
		var mult := biome + 1
		var contract: Dictionary = CampaignCatalog.CONTRACTS[spec["contract_id"]]
		var payment: int = contract["gold"] * mult
		var cap := (150 if spec["final_boss"] else 50) * mult
		summary["shard_conversion"] = clampi(result.get("loose_shards", 0), 0, cap)
		var rng := CampaignCatalog.stream(spec["mission_seed"], "settlement")
		for effect: Dictionary in next["effects"]:
			if effect.get("node_id", "") != spec["node_id"]: continue
			payment += int(effect.get("gold", 0))
			if effect.get("bonus_rare", false):
				var bonus := _item(next, spec["item_level"], ItemData.Rarity.RARE, "weapon", rng)
				_store(next, bonus)
				summary["items"].append(bonus["id"])
		if spec["contract_id"] == "cursed_cache" and result["objectives"].get("cache_claimed", false): payment += 50 * mult
		summary["gold"] = maxi(payment, 0)
		next["gold"] += summary["gold"] + summary["shard_conversion"]
		var talent_award := 3 if spec["final_boss"] and biome < 2 else (0 if spec["final_boss"] else 1)
		next["talents"]["points"] += talent_award
		next["talents"]["earned"] += talent_award
		summary["talent_points"] = talent_award
		var node: Dictionary = next["graph"]["nodes"][spec["node_id"]]
		var prize := _item(next, CampaignCatalog.item_level(biome, node["depth"], true), ItemData.Rarity.LEGENDARY if spec["final_boss"] else ItemData.Rarity.RARE, node["reward_slot"], rng)
		if spec["final_boss"]:
			_store(next, prize)
			summary["items"].append(prize["id"])
		else:
			next["wager"] = {"node_id": spec["node_id"], "stage": 0, "status": "open", "prizes": [prize], "chance": _first_odds(next, false), "outcome": {}}
			summary["reserved_prize"] = prize["id"]
		# This attempt's successes and account award commit in the same state.
		next["successful_nodes"][spec["node_id"]] = receipt_id
		next["cleared_nodes"].append(spec["node_id"])
		for veteran: Dictionary in next["roster"]:
			if veteran.get("pledge_node", "") == spec["node_id"]: veteran["pledge_node"] = ""
		var survivor = result.get("veteran", {})
		if survivor is Dictionary and not survivor.is_empty():
			var deployed: Dictionary = spec["starting_loadout"]["veteran"]
			if not deployed.is_empty() and survivor.get("id", "") == deployed.get("id", "") and survivor.get("id", "") != "":
				for veteran: Dictionary in next["roster"]:
					if veteran["id"] == deployed["id"]:
						veteran["deeds"] = maxi(int(veteran["deeds"]), int(survivor.get("deeds", veteran["deeds"])))
						veteran["rank"] = clampi(maxi(veteran["rank"], int(survivor.get("rank", 1))), 1, 3)
			else:
				next["veteran_candidate"] = _veteran_record(survivor, spec["attempt_id"] + ":veteran")
		next["effects"] = next["effects"].filter(func(effect: Dictionary) -> bool: return effect.get("node_id", "") != spec["node_id"])
		next["selected_node"] = ""
		next["event"] = {}
		var account_receipt := {"id": receipt_id + ":account", "shards": 20 if spec["final_boss"] else 5,
			"kills": result.get("kills_by", {}).duplicate(true), "completed": spec["final_boss"] and biome == 2,
			"campaign_id": next["campaign_id"], "hero_class": next["hero_class"]}
		next["outbox"].append(account_receipt)
		if spec["final_boss"]:
			summary["biome_complete"] = true
			next["clauses"] = []
			next["clause_offers"] = {}
			if biome == 2:
				next["completed"] = true
				summary["campaign_complete"] = true
			else:
				next["biome_index"] += 1
				next["graph"] = CampaignCatalog.route(next["seed"], next["biome_index"])
				next["cleared_nodes"] = []
				next["event_count"] = 0
		_refresh_stock(next)
	# Failure keeps the banked inventory and all committed choices intact.
	next["phase"] = "RESULT_PENDING"
	next["result"] = summary
	var response := {"ok": true, "error": "", "result": summary.duplicate(true), "operation_id": receipt_id}
	next["receipts"][receipt_id] = {"signature": "settlement", "response": response.duplicate(true)}
	var committed := _commit(next)
	if not committed["ok"]: return committed
	deliver_outbox()
	return response

func _reconcile_inventory(next: Dictionary, incoming: Variant, spec: Dictionary) -> String:
	if not incoming is Dictionary or not incoming.get("equipped") is Dictionary or not incoming.get("backpack") is Array: return "Missing disposable combat inventory."
	if incoming["backpack"].size() > Inventory.BACKPACK_SIZE: return "Combat inventory exceeds backpack capacity."
	var banked: Dictionary = next["inventory"]["items"]
	var ids := {}
	var worn := {}
	var bag := []
	for slot in incoming["equipped"]:
		var data = incoming["equipped"][slot]
		if not data is Dictionary or data.get("slot") != slot: return "Invalid combat equipment slot."
		worn[slot] = data.get("campaign_id", "")
	for data in incoming["equipped"].values() + incoming["backpack"]:
		var error := CampaignState.validate_item(data)
		if error != "": return error
		var id = data.get("campaign_id", "")
		if not id is String or id == "" or ids.has(id): return "Missing or duplicate combat copy identity."
		ids[id] = true
		if banked.has(id):
			if banked[id]["data"] != data: return "A banked item's exact roll changed during combat."
		else:
			if not id.begins_with(spec["attempt_id"] + ":drop:") or data["ilvl"] < spec["loot_band"][0] or data["ilvl"] > spec["loot_band"][1]: return "Combat loot is outside this attempt's tier or identity."
			banked[id] = _record(data, spec["biome_index"])
	for data: Dictionary in incoming["backpack"]: bag.append(data["campaign_id"])
	for id in next["inventory"]["equipped"].values() + next["inventory"]["backpack"]:
		if not ids.has(id): return "Banked equipment cannot be discarded inside an expedition."
	next["inventory"]["equipped"] = worn
	next["inventory"]["backpack"] = bag
	return ""

func acknowledge_result(operation_id := "") -> Dictionary:
	return _command("acknowledge", operation_id, [], func(next: Dictionary) -> Dictionary:
		if next["phase"] != "RESULT_PENDING": return {"ok": false, "error": "No result is awaiting acknowledgment."}
		next["phase"] = "CAMPAIGN_COMPLETE" if next["completed"] else ("DEPARTURE_READY" if next["selected_node"] != "" else "TOWN")
		return {"ok": true}, false)

func deliver_outbox() -> Dictionary:
	if state.is_empty(): return {"ok": true, "error": ""}
	while not state["outbox"].is_empty():
		var receipt: Dictionary = state["outbox"][0]
		if not MetaProgress.apply_campaign_receipt(receipt): return _error("Earned account rewards are pending. The profile could not be saved; retry delivery before replacing this campaign.")
		var next := state.duplicate(true)
		next["outbox"].pop_front()
		var saved := _commit(next)
		if not saved["ok"]: return saved
	return {"ok": true, "error": ""}

func abandon() -> Dictionary:
	var delivery := deliver_outbox()
	if not delivery["ok"]: return delivery
	if state.is_empty(): return {"ok": true, "error": ""}
	var next := state.duplicate(true)
	next["phase"] = "ABANDONED"
	return _commit(next)

func _record(data: Dictionary, biome: int) -> Dictionary:
	return {"id": data["campaign_id"], "data": data.duplicate(true), "locked": false, "junk": false,
		"valuation": CampaignCatalog.valuation(data, biome), "reforged_biomes": []}

func _item(next: Dictionary, level: int, rarity: int, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	next["item_serial"] += 1
	var item := ItemGenerator.generate_with(level, rarity, slot, rng)
	item.campaign_id = "%s:item:%d" % [next["campaign_id"], next["item_serial"]]
	return _record(item.to_dict(), next["biome_index"])

func _store(next: Dictionary, record: Dictionary) -> void:
	var inv: Dictionary = next["inventory"]
	if inv["items"].has(record["id"]): return
	inv["items"][record["id"]] = record.duplicate(true)
	if not inv["equipped"].has(record["data"]["slot"]): inv["equipped"][record["data"]["slot"]] = record["id"]
	elif inv["backpack"].size() < Inventory.BACKPACK_SIZE: inv["backpack"].append(record["id"])
	else: inv["tray"].append(record["id"])

func _remove_item(next: Dictionary, id: String) -> void:
	next["inventory"]["backpack"].erase(id)
	next["inventory"]["tray"].erase(id)
	next["inventory"]["items"].erase(id)

func _refresh_stock(next: Dictionary) -> void:
	next["shop_generation"] += 1
	var rng := CampaignCatalog.stream(next["seed"], "shop:%d" % next["shop_generation"])
	var stock := []
	var depth: int = mini(next["cleared_nodes"].size() + 1, 4)
	for index in 6:
		var rarity := ItemData.Rarity.MAGIC if index < 3 else ItemData.Rarity.RARE
		if index == 0: rarity = ItemData.Rarity.NORMAL
		if index == 5 and next["biome_index"] > 0: rarity = ItemData.Rarity.LEGENDARY
		var record := _item(next, CampaignCatalog.item_level(next["biome_index"], depth), rarity, ItemData.SLOTS[index], rng)
		stock.append({"id": record["id"], "item": record, "price": record["valuation"], "purchased": false})
	next["shop"] = stock

func buy_item(stock_id: String, operation_id := "") -> Dictionary:
	return _command("buy", operation_id, [stock_id], func(next: Dictionary) -> Dictionary:
		for entry: Dictionary in next["shop"]:
			if entry["id"] != stock_id: continue
			if entry["purchased"]: return {"ok": false, "error": "That copy has already been purchased."}
			if next["gold"] < entry["price"]: return {"ok": false, "error": "Not enough campaign Gold."}
			if next["inventory"]["backpack"].size() >= Inventory.BACKPACK_SIZE: return {"ok": false, "error": "Make backpack space before buying."}
			next["gold"] -= entry["price"]
			entry["purchased"] = true
			_store(next, entry["item"])
			return {"ok": true, "payload": entry["item"].duplicate(true)}
		return {"ok": false, "error": "Unknown stock copy."})

func sell_items(item_ids: Array, marked_only := false, operation_id := "") -> Dictionary:
	return _command("sell", operation_id, [item_ids, marked_only], func(next: Dictionary) -> Dictionary:
		var income := 0
		var sold := []
		for id in item_ids:
			if sold.has(id) or not next["inventory"]["items"].has(id): return {"ok": false, "error": "Duplicate or missing sale copy."}
			var record: Dictionary = next["inventory"]["items"][id]
			if next["inventory"]["equipped"].values().has(id) or record["locked"] or (marked_only and not record["junk"]):
				if marked_only: continue
				return {"ok": false, "error": "Equipped and locked items cannot be sold."}
			if next["reforge"].get("item_id", "") == id: return {"ok": false, "error": "Finish this item's reforge choice first."}
			income += CampaignCatalog.sale_value(record)
			_remove_item(next, id)
			sold.append(id)
		next["gold"] += income
		return {"ok": true, "payload": {"gold": income, "sold": sold}})

func equip_item(item_id: String, operation_id := "") -> Dictionary:
	return _command("equip", operation_id, [item_id], func(next: Dictionary) -> Dictionary:
		var inv: Dictionary = next["inventory"]
		if not inv["backpack"].has(item_id): return {"ok": false, "error": "Claim that item into the backpack before equipping."}
		var slot: String = inv["items"][item_id]["data"]["slot"]
		var position: int = inv["backpack"].find(item_id)
		inv["backpack"].remove_at(position)
		if inv["equipped"].has(slot): inv["backpack"].insert(position, inv["equipped"][slot])
		inv["equipped"][slot] = item_id
		return {"ok": true})

func unequip_item(slot: String, operation_id := "") -> Dictionary:
	return _command("unequip", operation_id, [slot], func(next: Dictionary) -> Dictionary:
		var inv: Dictionary = next["inventory"]
		if not inv["equipped"].has(slot) or inv["backpack"].size() >= Inventory.BACKPACK_SIZE: return {"ok": false, "error": "No equipped item or no backpack space."}
		inv["backpack"].append(inv["equipped"][slot])
		inv["equipped"].erase(slot)
		return {"ok": true})

func mark_item(item_id: String, locked: bool, junk: bool, operation_id := "") -> Dictionary:
	return _command("mark", operation_id, [item_id, locked, junk], func(next: Dictionary) -> Dictionary:
		if not next["inventory"]["items"].has(item_id): return {"ok": false, "error": "Unknown item copy."}
		var record: Dictionary = next["inventory"]["items"][item_id]
		record["locked"] = locked
		record["junk"] = junk and not locked
		return {"ok": true})

func claim_item(item_id: String, operation_id := "") -> Dictionary:
	return _command("claim", operation_id, [item_id], func(next: Dictionary) -> Dictionary:
		var inv: Dictionary = next["inventory"]
		if not inv["tray"].has(item_id): return {"ok": false, "error": "This reward has already been claimed."}
		if inv["backpack"].size() >= Inventory.BACKPACK_SIZE: return {"ok": false, "error": "Make backpack space before claiming."}
		inv["tray"].erase(item_id)
		inv["backpack"].append(item_id)
		return {"ok": true})

func discard_item(item_id: String, operation_id := "") -> Dictionary:
	return _command("discard", operation_id, [item_id], func(next: Dictionary) -> Dictionary:
		if not next["inventory"]["items"].has(item_id) or next["inventory"]["equipped"].values().has(item_id) or next["inventory"]["items"][item_id]["locked"]: return {"ok": false, "error": "Only unlocked, unequipped items can be discarded."}
		if next["reforge"].get("item_id", "") == item_id: return {"ok": false, "error": "Finish the reforge choice first."}
		_remove_item(next, item_id)
		return {"ok": true})

func reforge_item(item_id: String, operation_id := "") -> Dictionary:
	return _command("reforge", operation_id, [item_id], func(next: Dictionary) -> Dictionary:
		if not next["reforge"].is_empty(): return {"ok": false, "error": "Finish the existing reforge choice first."}
		if not next["inventory"]["items"].has(item_id): return {"ok": false, "error": "Unknown item copy."}
		var record: Dictionary = next["inventory"]["items"][item_id]
		var biome: int = next["biome_index"]
		var cost := 60 * (biome + 1)
		if record["reforged_biomes"].has(biome): return {"ok": false, "error": "This item has already been reforged in this biome."}
		if next["gold"] < cost: return {"ok": false, "error": "Not enough Gold for this reforge."}
		var rng := CampaignCatalog.stream(next["seed"], "reforge:%s:%d" % [item_id, biome])
		var old := record.duplicate(true)
		var item := ItemGenerator.generate_with(record["data"]["ilvl"], record["data"]["rarity"], record["data"]["slot"], rng)
		item.campaign_id = item_id
		record["reforged_biomes"].append(biome)
		var alternative := record.duplicate(true)
		alternative["data"] = item.to_dict().duplicate(true)
		next["gold"] -= cost
		next["reforge"] = {"item_id": item_id, "old": old, "new": alternative, "cost": cost, "biome": biome}
		return {"ok": true, "payload": next["reforge"].duplicate(true)})

func resolve_reforge(keep_new: bool, operation_id := "") -> Dictionary:
	return _command("reforge_choice", operation_id, [keep_new], func(next: Dictionary) -> Dictionary:
		if next["reforge"].is_empty(): return {"ok": false, "error": "No reforge choice is pending."}
		if keep_new:
			var current: Dictionary = next["inventory"]["items"][next["reforge"]["item_id"]]
			# The roll changes; protection, valuation, identity and consumed-use
			# history still belong to the same live campaign copy.
			current["data"] = next["reforge"]["new"]["data"].duplicate(true)
		next["reforge"] = {}
		return {"ok": true})

func _talent_command(kind: String, node_id: String, operation_id: String) -> Dictionary:
	return _command(kind, operation_id, [node_id], func(next: Dictionary) -> Dictionary:
		var tree := SkillTree.new(PlayerStats.new())
		tree.restore(next["talents"])
		var ok := false
		if kind == "talent_allocate": ok = tree.allocate(node_id)
		elif kind == "talent_refund": ok = tree.refund(node_id)
		else:
			tree.reset()
			ok = true
		if not ok: return {"ok": false, "error": "That talent is unavailable, unaffordable, or supports another owned talent."}
		var earned: int = next["talents"]["earned"]
		next["talents"] = tree.to_dict()
		next["talents"]["earned"] = earned
		return {"ok": true})

func allocate_talent(node_id: String, operation_id := "") -> Dictionary:
	if not SkillData.NODES.has(node_id): return _error("Unknown talent.")
	return _talent_command("talent_allocate", node_id, operation_id)

func refund_talent(node_id: String, operation_id := "") -> Dictionary:
	return _talent_command("talent_refund", node_id, operation_id)

func reset_talents(operation_id := "") -> Dictionary:
	return _talent_command("talent_reset", "", operation_id)

func choose_specialization(path_id: String, operation_id := "") -> Dictionary:
	return _command("specialization", operation_id, [path_id], func(next: Dictionary) -> Dictionary:
		if next["talents"]["earned"] <= 3: return {"ok": false, "error": "Specialization unlocks after your first short expedition success."}
		if path_id != "" and Specializations.find(next["hero_class"], path_id).is_empty(): return {"ok": false, "error": "Unknown class specialization."}
		next["specialization"] = path_id
		return {"ok": true})

func _veteran_record(source: Dictionary, id: String) -> Dictionary:
	return {"id": id, "name": str(source.get("name", "Unnamed Veteran")), "swarm": str(source.get("swarm", "Grunts")),
		"label": str(source.get("label", "Veteran")), "role": str(source.get("role", "brawler")), "elite": clampi(int(source.get("elite", 0)), 0, 1),
		"deeds": maxi(0, int(source.get("deeds", 0))), "rank": clampi(int(source.get("rank", 1)), 1, 3),
		"nights": maxi(0, int(source.get("nights", 0))), "pledge_node": ""}

func choose_veteran(veteran_id: String, operation_id := "") -> Dictionary:
	return _command("deploy", operation_id, [veteran_id], func(next: Dictionary) -> Dictionary:
		if veteran_id == "":
			next["deployed_veteran"] = ""
			return {"ok": true}
		for veteran: Dictionary in next["roster"]:
			if veteran["id"] == veteran_id:
				if veteran["pledge_node"] != "": return {"ok": false, "error": "This veteran is pledged until the bound node clears."}
				next["deployed_veteran"] = veteran_id
				return {"ok": true}
		return {"ok": false, "error": "Unknown campaign veteran."})

func recruit_veteran(candidate_id: String, replace_id := "", operation_id := "") -> Dictionary:
	return _command("recruit", operation_id, [candidate_id, replace_id], func(next: Dictionary) -> Dictionary:
		if next["veteran_candidate"].get("id", "") != candidate_id: return {"ok": false, "error": "That candidate is no longer available."}
		if replace_id != "":
			var found := false
			for veteran: Dictionary in next["roster"]:
				if veteran["id"] != replace_id: continue
				if veteran["pledge_node"] != "": return {"ok": false, "error": "A pledged veteran cannot be replaced."}
				found = true
				next["roster"].erase(veteran)
				if next["deployed_veteran"] == replace_id: next["deployed_veteran"] = ""
				break
			if not found: return {"ok": false, "error": "Unknown replacement veteran."}
		if next["roster"].size() >= 3: return {"ok": false, "error": "Choose an unpledged veteran to replace; the roster holds three."}
		next["roster"].append(next["veteran_candidate"].duplicate(true))
		if next["deployed_veteran"] == "": next["deployed_veteran"] = candidate_id
		next["veteran_candidate"] = {}
		return {"ok": true})

func decline_veteran(operation_id := "") -> Dictionary:
	return _command("decline_veteran", operation_id, [], func(next: Dictionary) -> Dictionary:
		next["veteran_candidate"] = {}
		return {"ok": true})

func clause_offers(slot := "weapon") -> Array:
	if state.is_empty() or not slot in ItemData.SLOTS: return []
	if state["clause_offers"].has(slot): return state["clause_offers"][slot].duplicate(true)
	var response := _command("clause_offers", "", [slot], func(next: Dictionary) -> Dictionary:
		var rng := CampaignCatalog.stream(next["seed"], "arsenal:%d:%s" % [next["biome_index"], slot])
		var offers := []
		for index in 3: offers.append(_item(next, CampaignCatalog.item_level(next["biome_index"], 3, true), ItemData.Rarity.RARE, slot, rng))
		next["clause_offers"][slot] = offers
		return {"ok": true, "payload": offers})
	return response.get("payload", []).duplicate(true) if response["ok"] else []

func accept_clause(clause_id: String, slot := "weapon", offer_index := 0, operation_id := "") -> Dictionary:
	if not CampaignCatalog.CLAUSES.has(clause_id): return _error("Unknown Ledger bargain.")
	if clause_id == "stolen_arsenal" and clause_offers(slot).is_empty(): return _error("Could not prepare this arsenal offer.")
	return _command("clause", operation_id, [clause_id, slot, offer_index], func(next: Dictionary) -> Dictionary:
		if next["clauses"].size() >= 2: return {"ok": false, "error": "The biome Ledger already holds two clauses."}
		for clause: Dictionary in next["clauses"]:
			if clause["id"] == clause_id: return {"ok": false, "error": "This bargain is already committed for the biome."}
		if clause_id == "stolen_arsenal":
			if not next["clause_offers"].has(slot) or offer_index < 0 or offer_index >= next["clause_offers"][slot].size(): return {"ok": false, "error": "Select one of the three shown offers."}
			_store(next, next["clause_offers"][slot][offer_index])
		elif clause_id == "advance_payment": next["gold"] += 100 * (next["biome_index"] + 1)
		else:
			next["effects"].append({"id": "borrowed_battalion", "node_id": next["selected_node"] if next["selected_node"] != "" else "next", "minions": 3})
		next["clauses"].append({"id": clause_id, "accepted_biome": next["biome_index"]})
		return {"ok": true})

func _first_odds(next: Dictionary, pledge: bool) -> float:
	var chance := 0.8 if pledge else 0.7
	for effect: Dictionary in next["effects"]:
		if effect["id"] == "loaded_passage": chance += float(effect.get("odds", 0.0))
	return minf(0.85, chance)

func wager(pledge := false, operation_id := "") -> Dictionary:
	return _command("wager", operation_id, [pledge], func(next: Dictionary) -> Dictionary:
		var bet: Dictionary = next["wager"]
		if not bet.get("status", "") in ["open", "won"] or int(bet.get("stage", 2)) >= 2: return {"ok": false, "error": "No further wager is available."}
		var stage: int = bet["stage"]
		if pledge and stage != 0: return {"ok": false, "error": "A veteran pledge only improves the first wager."}
		if pledge:
			var selected := false
			for veteran: Dictionary in next["roster"]:
				if veteran["id"] != next["deployed_veteran"] or veteran["pledge_node"] != "": continue
				veteran["pledge_node"] = next["selected_node"] if next["selected_node"] != "" else "next"
				selected = true
			if not selected: return {"ok": false, "error": "Select an available veteran before pledging."}
		var chance := _first_odds(next, pledge) if stage == 0 else 0.45
		var rng := CampaignCatalog.stream(next["seed"], "wager:%s:%d" % [bet["node_id"], stage])
		var won := rng.randf() < chance
		bet["stage"] = stage + 1
		bet["chance"] = chance
		bet["outcome"] = {"won": won, "chance": chance, "stage": stage + 1}
		if stage == 0: next["effects"] = next["effects"].filter(func(effect: Dictionary) -> bool: return effect["id"] != "loaded_passage")
		if won:
			var original: Dictionary = bet["prizes"][0]
			var legendary := ItemGenerator.generate_with(original["data"]["ilvl"], ItemData.Rarity.LEGENDARY, original["data"]["slot"], rng)
			if stage == 0:
				legendary.campaign_id = original["id"]
				bet["prizes"][0] = _record(legendary.to_dict(), next["biome_index"])
			else:
				var second := _item(next, legendary.ilvl, ItemData.Rarity.LEGENDARY, legendary.slot, rng)
				bet["prizes"].append(second)
			bet["status"] = "won"
		else:
			bet["prizes"] = []
			bet["status"] = "lost"
		return {"ok": true, "payload": bet.duplicate(true)})

func take_wager(operation_id := "") -> Dictionary:
	return _command("take_wager", operation_id, [], func(next: Dictionary) -> Dictionary:
		var bet: Dictionary = next["wager"]
		if not bet.get("status", "") in ["open", "won"]: return {"ok": false, "error": "That prize has already been resolved."}
		for prize: Dictionary in bet["prizes"]: _store(next, prize)
		bet["status"] = "taken"
		return {"ok": true})
