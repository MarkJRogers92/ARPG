extends SceneTree
## Visual fixture for the campaign town. It uses an in-memory controller and
## never opens CampaignSave or MetaProgress for writing.

class FixtureController:
	extends Node
	signal changed(state: Dictionary)
	signal error_raised(message: String)
	var state: Dictionary = {}
	var abandon_response := {"ok": true, "error": ""}
	var delivery_response := {"ok": true, "error": ""}

	func _init() -> void:
		state = {
			"schema_version": 1, "content_version": "ui-fixture", "campaign_id": "fixture",
			"seed": 702, "revision": 1, "phase": "TOWN", "hero_class": "battlemage",
			"biome_index": 0, "gold": 185, "profile_snapshot": {},
			"inventory": {
				"items": {
					"i-weapon": _record("i-weapon", "Moonlit Dirk", "weapon", 2, "Keen", false, false),
					"i-armor": _record("i-armor", "Wayfarer's Mantle", "armor", 1, "Warded", false, false),
					"i-rare": _record("i-rare", "Ashen Oath", "weapon", 3, "Ashen", false, false),
					"i-junk": _record("i-junk", "Cracked Buckler", "offhand", 0, "Cracked", false, true),
				},
				"equipped": {"weapon": "i-weapon", "armor": "i-armor"},
				"backpack": ["i-rare", "i-junk"], "tray": [],
			},
			"talents": {"points": 4, "allocated": ["o1", "d1"], "earned": 5},
			"specialization": "sniper", "roster": [
				{"id": "vet-01", "name": "Cinder", "role": "Vanguard", "rank": 2, "deeds": "Held the western stairs alone.", "pledge_node": ""},
				{"id": "vet-02", "name": "Morrow", "role": "Arcanist", "rank": 1, "deeds": "Returned with a stolen standard.", "pledge_node": ""},
			], "deployed_veteran": "vet-01", "graph": _graph(), "selected_node": "",
			"cleared_nodes": [], "clauses": [], "effects": [], "event": {}, "event_count": 0,
			"shop": {"stock": [
				{"id": "stock-01", "price": 50, "data": {"name": "Graveglass Wand", "base_name": "Wand", "slot": "weapon", "rarity": 1, "ilvl": 7, "implicit": [{"stat": "bolt_damage", "op": "increased", "value": 0.12}], "affixes": [], "power": ""}},
			]}, "shop_generation": 1, "wager": {}, "reforge": {}, "veteran_candidate": {},
			"departure": {}, "result": {}, "receipts": {}, "successful_nodes": 1, "outbox": [], "item_serial": 4, "attempt_serial": 1, "completed": false,
		}

	func snapshot() -> Dictionary:
		return state.duplicate(true)

	func available_routes() -> Array:
		return [{"id": "g-1-a"}, {"id": "g-1-b"}]

	func choose_route(node_id: String, _operation_id := "") -> Dictionary:
		state["selected_node"] = node_id
		state["phase"] = "DEPARTURE_READY"
		changed.emit(snapshot())
		return {"ok": true, "operation_id": "fixture"}

	func depart(_operation_id := "") -> Dictionary:
		return {"ok": true, "spec": {"node_id": state.get("selected_node", "g-1-a")}}

	func clause_offers(_slot: String) -> Array:
		return []

	func resolve_event(_choice_id: String, _operation_id := "", _selection: Dictionary = {}) -> Dictionary:
		state["event"] = {}
		state["phase"] = "DEPARTURE_READY"
		changed.emit(snapshot())
		return {"ok": true, "error": ""}

	func abandon() -> Dictionary:
		if not abandon_response.get("ok", false):
			return abandon_response.duplicate(true)
		state["phase"] = "ABANDONED"
		changed.emit(snapshot())
		return abandon_response.duplicate(true)

	func deliver_outbox() -> Dictionary:
		if delivery_response.get("ok", false):
			state["outbox"] = []
			changed.emit(snapshot())
		return delivery_response.duplicate(true)

	func _record(id: String, name: String, slot: String, rarity: int, affix: String, locked: bool, junk: bool) -> Dictionary:
		return {"id": id, "data": {"slot": slot, "base_name": name, "name": name, "rarity": rarity, "ilvl": 9, "implicit": [{"stat": "max_hp", "op": "add", "value": 8}], "affixes": [{"id": "fixture", "stat": "bolt_damage", "op": "increased", "value": 0.1}], "power": ""}, "locked": locked, "junk": junk, "valuation": 100}

	func _graph() -> Dictionary:
		var nodes := {
			"g-1-a": {"id": "g-1-a", "depth": 1, "contract": "hunt", "elite": false, "event": "quiet_bell", "reward_slot": "weapon", "next": ["g-2-a"]},
			"g-1-b": {"id": "g-1-b", "depth": 1, "contract": "elite_hunt", "elite": true, "event": "", "reward_slot": "armor", "next": ["g-2-a", "g-2-b"]},
			"g-2-a": {"id": "g-2-a", "depth": 2, "contract": "seal_breach", "elite": false, "event": "three_coffins", "reward_slot": "helm", "next": ["g-3-a"]},
			"g-2-b": {"id": "g-2-b", "depth": 2, "contract": "cursed_cache", "elite": true, "event": "", "reward_slot": "trinket", "next": ["g-3-a"]},
			"g-3-a": {"id": "g-3-a", "depth": 3, "contract": "hunt", "elite": false, "event": "", "reward_slot": "offhand", "next": ["g-4-boss"]},
			"g-4-boss": {"id": "g-4-boss", "depth": 4, "contract": "finale", "elite": false, "event": "", "reward_slot": "weapon", "next": []},
		}
		return {"seed": 702, "start": ["g-1-a", "g-1-b"], "nodes": nodes}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var width := 1280
	var height := 720
	var screen := "route"
	var output := "user://campaign-ui-route.png"
	for arg: String in args:
		if arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--screen="):
			screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if screen == "behavior":
		await _run_behavior_test()
		return
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(width, height))
	root.size = Vector2i(width, height)
	var container := SubViewportContainer.new()
	container.position = Vector2.ZERO
	container.size = Vector2(width, height)
	container.stretch = false
	root.add_child(container)
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(capture_viewport)
	var town := CampaignTown.new()
	capture_viewport.add_child(town)
	var controller := FixtureController.new()
	capture_viewport.add_child(controller)
	town.setup(controller)
	if screen != "route":
		town._active_service = "ferryman" if screen.begins_with("ferryman") else screen
		if screen == "event":
			controller.state["phase"] = "EVENT_PENDING"
			controller.state["event"] = {"id": "dead_man_inventory", "title": "Dead Man's Inventory", "description": "A dead traveler offers a replacement from the pack you carried in. Choose the item to trade before you commit.", "offers": {"i-rare": controller.state["inventory"]["items"]["i-rare"]}, "choices": [{"id": "trade", "label": "Trade the selected item", "description": "Receive the displayed offer.", "cost_text": "Consumes the selected backpack item"}, {"id": "leave", "label": "Leave the inventory", "description": "Keep what you have.", "cost_text": "No cost"}]}
		elif screen.begins_with("ferryman"):
			var wager_status := "won" if screen.contains("won") else ("lost" if screen.contains("lost") else "open")
			var wager_stage := 1 if wager_status == "won" else (1 if wager_status == "lost" else 0)
			var prizes: Array = [controller.state["inventory"]["items"]["i-rare"]]
			if wager_status == "won":
				prizes.append(controller.state["inventory"]["items"]["i-armor"])
			controller.state["wager"] = {"node_id": "g-1-a", "stage": wager_stage, "status": wager_status, "prizes": prizes, "chance": 0.68, "detail": "A second crossing raises the reward, but both reserved items are at stake.", "outcome": {"won": wager_status == "won", "chance": 0.68, "stage": wager_stage}}
		elif screen == "roster":
			controller.state["veteran_candidate"] = {"id": "vet-new", "name": "Ash-in-the-Reeds", "role": "Warden", "rank": 1, "deeds": "Carried three souls through the breach.", "pledge_node": ""}
		elif screen == "ledger":
			controller.state["clauses"] = [{"id": "advance_payment", "accepted_biome": 0}]
		elif screen == "market":
			controller.state["reforge"] = {"item_id": "i-rare", "old": controller.state["inventory"]["items"]["i-rare"]["data"], "new": {"slot": "weapon", "name": "Ashen Oath, Recast", "base_name": "Ashen Oath", "rarity": 3, "ilvl": 9, "implicit": [], "affixes": [{"id": "recast", "stat": "bolt_damage", "op": "increased", "value": 0.18}]}, "cost": 60, "biome": 0}
		elif screen == "result":
			controller.state["phase"] = "RESULT_PENDING"
			controller.state["result"] = {"outcome": "success", "elapsed": 360.0, "gold": 110, "shard_conversion": 12, "talent_points": 1, "items": ["i-rare"], "report": {"summary": "The seals are closed. A pack of rare gear came home with you."}}
			controller.state["inventory"]["tray"] = ["i-rare", "i-junk"]
		elif screen in ["complete", "complete_pending"]:
			controller.state["phase"] = "CAMPAIGN_COMPLETE"
			if screen == "complete_pending":
				controller.state["outbox"] = [{"id": "fixture:pending", "shards": 5}]
		town._state = controller.snapshot()
		town._render()
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := capture_viewport.get_texture().get_image()
	if image.is_empty():
		push_error("Campaign UI fixture could not capture the viewport")
		quit(1)
		return
	var save_error := image.save_png(output)
	if save_error != OK:
		push_error("Campaign UI fixture could not save image: %s" % error_string(save_error))
		quit(1)
		return
	print("CAMPAIGN_UI_SCREENSHOT_OK %s %dx%d" % [output, image.get_width(), image.get_height()])
	quit(0)


func _run_behavior_test() -> void:
	var temp_root := "user://campaign-ui-behavior-%d" % Time.get_ticks_usec()
	CampaignSave.path = temp_root + ".save"
	MetaProgress.save_path = temp_root + ".meta"
	MetaProgress.disabled = true
	var controller := CampaignController.new()
	root.add_child(controller)
	var failures: Array[String] = []
	if not controller.create("battlemage", 70913).get("ok", false):
		failures.append("real controller creates an isolated campaign")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame

	# Exercise the market and equipment commands through actual UI button callbacks.
	(town._service_buttons["market"] as Button).pressed.emit()
	await process_frame
	var buy_button := _find_button(root, "Buy ·", true)
	if buy_button == null:
		failures.append("market stock renders a buy action")
	else:
		var backpack_before: int = controller.state["inventory"]["backpack"].size()
		buy_button.pressed.emit()
		await process_frame
		var backpack: Array = controller.state["inventory"]["backpack"]
		if backpack.size() != backpack_before + 1:
			failures.append("market button commits a purchase through the controller")
		else:
			var purchased_id := str(backpack[-1])
			var purchased: Dictionary = controller.state["inventory"]["items"][purchased_id]
			(town._service_buttons["pack"] as Button).pressed.emit()
			await process_frame
			var item_button := _find_button(root, str(purchased["data"].get("name", "")), true)
			if item_button == null:
				failures.append("purchased copy appears in the armory")
			else:
				item_button.pressed.emit()
				await process_frame
				var equip_button := _find_button(root, "Equip")
				if equip_button == null:
					failures.append("selected item exposes equip action")
				else:
					equip_button.pressed.emit()
					await process_frame
					if str(controller.state["inventory"]["equipped"].get(str(purchased["data"]["slot"]), "")) != purchased_id:
						failures.append("armory equip button commits the selected stable item ID")
					var backpack_after_equip: Array = controller.state["inventory"]["backpack"]
					if not backpack_after_equip.is_empty():
						var junk_id := str(backpack_after_equip[0])
						var junk_record: Dictionary = controller.state["inventory"]["items"][junk_id]
						town._select_item(junk_id, str(junk_record["data"]["slot"]))
						var lock_button := _find_button(root, "Lock / unlock")
						if lock_button != null:
							lock_button.pressed.emit()
							await process_frame
							if not controller.state["inventory"]["items"][junk_id]["locked"]:
								failures.append("lock button protects the selected copy")
							lock_button = _find_button(root, "Lock / unlock")
							if lock_button != null:
								lock_button.pressed.emit()
								await process_frame
						var junk_button := _find_button(root, "Mark / unmark junk")
						if junk_button != null:
							junk_button.pressed.emit()
							await process_frame
							if not controller.state["inventory"]["items"][junk_id]["junk"]:
								failures.append("junk button marks only the chosen copy")
							var sell_button := _find_button(root, "Sell marked junk")
							if sell_button != null:
								sell_button.pressed.emit()
								await process_frame
								if controller.state["inventory"]["items"].has(junk_id):
									failures.append("sell marked junk sends eligible IDs to the controller")

	# A point-bearing talent and an optional Ledger bargain both update through commands.
	(town._service_buttons["trainer"] as Button).pressed.emit()
	await process_frame
	var talents: Dictionary = controller.state["talents"]
	var selected_talent := ""
	for id: String in SkillData.NODES:
		if id == SkillData.ROOT or talents["allocated"].has(id):
			continue
		var definition: Dictionary = SkillData.NODES[id]
		var reachable := SkillData.neighbors(id).any(func(neighbor: String) -> bool: return neighbor == SkillData.ROOT or talents["allocated"].has(neighbor))
		if reachable and int(talents["points"]) >= int(SkillData.COSTS[definition["tier"]]):
			selected_talent = str(definition["name"])
			break
	var talent_before := int(talents["points"])
	var talent_button := _find_button(root, selected_talent, true)
	if talent_button == null or selected_talent.is_empty():
		failures.append("trainer exposes a reachable affordable talent")
	else:
		talent_button.pressed.emit()
		await process_frame
		if int(controller.state["talents"]["points"]) >= talent_before:
			failures.append("trainer allocation spends points through the controller")
	(town._service_buttons["ledger"] as Button).pressed.emit()
	await process_frame
	var gold_before: int = controller.state["gold"]
	var clause_button := _find_button(root, "Accept Advance Payment")
	if clause_button == null:
		failures.append("Ledger lists an available bargain")
	else:
		clause_button.pressed.emit()
		await process_frame
		if controller.state["gold"] != gold_before + 100 or controller.state["clauses"].size() != 1:
			failures.append("Ledger bargain commits the displayed benefit and obligation")

	# Commit a route, resolve any seeded event, and depart through the UI action.
	(town._service_buttons["route"] as Button).pressed.emit()
	await process_frame
	var routes: Array = controller.available_routes()
	if routes.is_empty():
		failures.append("real campaign exposes a starting route")
	else:
		var route_view := town._content.get_child(0) as CampaignRouteView
		var route_id := str(routes[0].get("id", ""))
		var route_card := _find_button(root, route_view._node_title(route_view._nodes[route_id]))
		if route_card != null:
			route_card.pressed.emit()
			await process_frame
			if not str(controller.state["selected_node"]).is_empty():
				failures.append("route preview does not commit before confirmation")
		var choose_button := _find_button(root, "Choose this route")
		if choose_button == null or choose_button.disabled:
			failures.append("available route can be explicitly committed")
		else:
			choose_button.pressed.emit()
		await process_frame
		if controller.state["phase"] == "EVENT_PENDING":
			var event: Dictionary = controller.state["event"]
			var choices: Array = event.get("choices", [])
			var event_choice: Button
			for choice: Dictionary in choices:
				var candidate := _find_button(root, str(choice.get("name", "")), true)
				if candidate != null and not candidate.disabled:
					event_choice = candidate
					break
			if event_choice == null:
				failures.append("event presents at least one affordable, valid choice")
			else:
				event_choice.pressed.emit()
				await process_frame
			if controller.state["phase"] != "DEPARTURE_READY":
				failures.append("event choice resolves the route checkpoint")
		var departure_signal: Array[Dictionary] = []
		town.expedition_requested.connect(func(spec: Dictionary) -> void: departure_signal.append(spec))
		var depart_button := _find_button(root, "Depart for the committed route")
		if depart_button == null or depart_button.disabled:
			failures.append("resolved route exposes departure button")
		else:
			depart_button.pressed.emit()
			await process_frame
			if controller.state["phase"] != "EXPEDITION_ACTIVE" or departure_signal.size() != 1 or departure_signal[0].is_empty():
				failures.append("departure UI emits the committed controller spec")
			else:
				var spec: Dictionary = departure_signal[0]
				var terminal := {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"], "outcome": "retreat", "elapsed": 12.0, "objectives": {}, "kills_by": {}, "loose_shards": 0, "report": {"summary": "We turned back before the pressure closed in."}}
				var settlement: Dictionary = controller.settle(terminal)
				await process_frame
				if not settlement.get("ok", false) or _find_button(root, "Claim") != null:
					failures.append("result screen shows no actions that the controller forbids")
				var continue_button := _find_button(root, "Continue to town")
				if continue_button == null:
					failures.append("result has one clear acknowledgment action")
				else:
					continue_button.pressed.emit()
					await process_frame
					if controller.state["phase"] != "DEPARTURE_READY":
						failures.append("result acknowledgment returns to the committed town route")
				var abandon_events: Array[int] = []
				town.quit_requested.connect(func() -> void: abandon_events.append(1))
				var abandon_button := _find_button(root, "Abandon Campaign")
				if abandon_button == null:
					failures.append("town shows a separate whole-campaign abandon action")
				else:
					abandon_button.pressed.emit()
					var confirm := _find_confirmation(root)
					if confirm == null or not confirm.dialog_text.contains("unfinished route"):
						failures.append("abandon action requires a clear campaign-loss confirmation")
					else:
						confirm.confirmed.emit()
						confirm.hide()
						await process_frame
						if controller.state["phase"] != "ABANDONED" or abandon_events.size() != 1:
							failures.append("confirmed abandon commits through the controller before returning to title")
	await _test_event_and_retryable_abandon(failures)

	for message: String in failures:
		push_error("CAMPAIGN_UI_BEHAVIOR_FAIL: " + message)
	for suffix: String in [".save", ".save.bak", ".save.tmp", ".save.previous", ".meta", ".meta.bak", ".meta.tmp", ".meta.rollback"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_root + suffix))
	controller.free()
	town.free()
	print("CAMPAIGN_UI_BEHAVIOR %s" % ["FAILED" if not failures.is_empty() else "PASSED"])
	quit(1 if not failures.is_empty() else 0)


func _test_event_and_retryable_abandon(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	await process_frame
	fixture.state["phase"] = "EVENT_PENDING"
	fixture.state["event"] = {"id": "honest_ferryman", "name": "The Honest Ferryman", "text": "The Ledger shows every bargain.", "choices": [{"id": "view", "name": "Read the Ledger without accepting a debt"}, {"id": "leave", "name": "Take the safe route"}]}
	town._state = fixture.snapshot()
	town._render()
	var view_choice := _find_button(town, "Read the Ledger without accepting a debt", true)
	if view_choice == null:
		failures.append("Honest Ferryman event exposes its ledger choice")
	else:
		view_choice.pressed.emit()
		await process_frame
		if town._active_service != "ledger" or town._content_title.text != "THE FERRYMAN'S LEDGER":
			failures.append("Honest Ferryman view choice opens the Ledger")

	fixture.state["phase"] = "TOWN"
	fixture.state["event"] = {}
	fixture.state["outbox"] = [{"id": "fixture:pending", "shards": 5}]
	fixture.abandon_response = {"ok": false, "error": "Earned profile rewards are pending; retry delivery before leaving."}
	town._state = fixture.snapshot()
	town._render()
	var delivery_button := _find_button(town, "Retry Profile Rewards")
	var abandon_button := _find_button(town, "Abandon Campaign")
	var quit_events: Array[int] = []
	town.quit_requested.connect(func() -> void: quit_events.append(1))
	if delivery_button == null or not delivery_button.visible or abandon_button == null:
		failures.append("pending profile rewards remain retryable beside the abandon action")
	else:
		abandon_button.pressed.emit()
		var confirm := _find_confirmation(town)
		if confirm != null:
			confirm.confirmed.emit()
			confirm.hide()
			await process_frame
		if quit_events.size() != 0 or str(fixture.state["phase"]) == "ABANDONED":
			failures.append("failed reward delivery keeps the campaign open and retryable")
		delivery_button = _find_button(town, "Retry Profile Rewards")
		if delivery_button != null:
			delivery_button.pressed.emit()
			await process_frame
			if not fixture.state["outbox"].is_empty():
				failures.append("town retry button forwards account reward delivery")
	town.free()
	fixture.free()


func _find_button(node: Node, text: String, prefix := false) -> Button:
	if node is Button:
		var button := node as Button
		if (button.text.contains(text) if prefix else button.text == text):
			return button
	for child: Node in node.get_children():
		var found := _find_button(child, text, prefix)
		if found != null:
			return found
	return null


func _find_confirmation(node: Node) -> ConfirmationDialog:
	if node is ConfirmationDialog:
		return node as ConfirmationDialog
	for child: Node in node.get_children():
		var found := _find_confirmation(child)
		if found != null:
			return found
	return null
