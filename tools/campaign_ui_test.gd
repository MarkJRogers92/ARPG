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
				{"id": "stock-01", "price": 50, "data": {"name": "Graveglass Wand", "base_name": "Wand", "slot": "weapon", "rarity": 1, "ilvl": 7, "implicit": [{"stat": "bolt_damage", "op": PlayerStats.Op.INCREASED, "value": 0.12}], "affixes": [], "power": ""}},
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
		return {"id": id, "data": {"slot": slot, "base_name": name, "name": name, "rarity": rarity, "ilvl": 9, "implicit": [{"stat": "max_hp", "op": PlayerStats.Op.ADD, "value": 8}], "affixes": [{"id": "fixture", "stat": "bolt_damage", "op": PlayerStats.Op.INCREASED, "value": 0.1}], "power": ""}, "locked": locked, "junk": junk, "valuation": 100}

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
			controller.state["reforge"] = {"item_id": "i-rare", "old": controller.state["inventory"]["items"]["i-rare"]["data"], "new": {"slot": "weapon", "name": "Ashen Oath, Recast", "base_name": "Ashen Oath", "rarity": 3, "ilvl": 9, "implicit": [], "affixes": [{"id": "recast", "stat": "bolt_damage", "op": PlayerStats.Op.INCREASED, "value": 0.18}]}, "cost": 60, "biome": 0}
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
	await _test_keyboard_entry(town, failures)
	_test_real_snapshot_rendering(town, controller, failures)

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
		var route_view := _find_route_view(town)
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
	await _test_route_preparation_panel(failures)

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


func _test_route_preparation_panel(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	fixture.state["phase"] = "DEPARTURE_READY"
	fixture.state["selected_node"] = "g-1-a"
	fixture.state["inventory"]["tray"] = ["i-rare"]
	fixture.state["reforge"] = {"item_id": "i-rare"}
	fixture.state["wager"] = {"status": "won"}
	fixture.state["talents"] = {"points": 2, "allocated": [], "earned": 5}
	fixture.state["specialization"] = ""
	fixture.state["deployed_veteran"] = "vet-01"
	fixture.state["clauses"] = [{"id": "advance_payment"}]
	fixture.state["biome_index"] = 2
	town._state = fixture.snapshot()
	town._render()
	await process_frame
	if town._sanctuary._biome_index != 2 or not town._sanctuary._journey.has_node("FrostColossusHeart"):
		failures.append("town refresh presents the current biome and earned guardian trophies")
	var scenery := town._sanctuary._journey
	town._render()
	if town._sanctuary._journey != scenery:
		failures.append("ordinary town refresh does not rebuild unchanged sanctuary geometry")
	var blockers := town._departure_blockers()
	if blockers.size() < 3 or not blockers.any(func(entry: Dictionary) -> bool: return str(entry.get("text", "")).contains("reward") or str(entry.get("text", "")).contains("tray")):
		failures.append("route preparation distinguishes required tray and service decisions")
	var depart := _find_button(town, "Depart for the committed route")
	if depart == null or not depart.disabled:
		failures.append("committed route is not marked ready while required preparation blocks departure")
	if _find_button(town, "Open Trainer") == null:
		failures.append("unspent talents and unlocked specialization remain actionable optional choices")
	if _find_button(town, "Open Veterans") != null or _find_label(town, "Morrow is available in the Crypt") != null:
		failures.append("a usable deployed veteran prevents a redundant Crypt prompt")
	var mission_label := _find_label(town, "Committed mission")
	if mission_label == null or not mission_label.text.contains(str(CampaignCatalog.CONTRACTS["hunt"]["name"])):
		failures.append("route preparation names the committed mission contract")
	var clauses_label := _find_label(town, "Ledger obligations")
	var clause_name := str(CampaignCatalog.CLAUSES["advance_payment"]["name"])
	if clauses_label == null or not clauses_label.text.contains(clause_name):
		failures.append("route preparation names the current ledger obligations")
	if mission_label != null and mission_label.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
		failures.append("mission copy wraps within the preparation panel")
	var armory := _find_button(town, "Open Armory")
	if armory != null:
		armory.pressed.emit()
		await process_frame
		if town._active_service != "pack":
			failures.append("required reward-tray action opens the existing Armory service")
	fixture.state["inventory"]["tray"] = []
	fixture.state["reforge"] = {}
	fixture.state["wager"] = {}
	fixture.state["outbox"] = [{"id": "fixture:pending", "shards": 5}]
	town._state = fixture.snapshot()
	town._active_service = "route"
	town._render()
	await process_frame
	if not town._departure_blockers().is_empty():
		failures.append("pending profile delivery is not mislabeled as a departure blocker")
	var delivery_copy := _find_label(town, "Profile rewards still await delivery")
	depart = _find_button(town, "Depart for the committed route")
	if delivery_copy == null or depart == null or depart.disabled:
		failures.append("pending profile delivery is disclosed while legal departure remains available")
	town._state["phase"] = "RESULT_PENDING"
	if town._departure_blockers().is_empty():
		failures.append("a phase that forbids departure is never shown as ready")
	town._state["phase"] = "DEPARTURE_READY"
	town._state["completed"] = true
	if town._departure_blockers().is_empty():
		failures.append("a completed campaign is never shown as ready")
	town._state["completed"] = false
	town._state["roster"][0]["pledge_node"] = "g-1-a"
	town._state["deployed_veteran"] = "vet-01"
	town._active_service = "route"
	town._render()
	await process_frame
	if _find_button(town, "Open Veterans") == null or _find_label(town, "Morrow is available in the Crypt") == null:
		failures.append("a pledged deployed veteran makes the first unpledged Crypt veteran actionable")
	town._state["roster"] = []
	town._state["deployed_veteran"] = ""
	town._render()
	await process_frame
	if _find_button(town, "Open Veterans") != null:
		failures.append("an empty Crypt does not create a preparation action with no available veteran")
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


func _test_keyboard_entry(town: CampaignTown, failures: Array[String]) -> void:
	var route_button: Button = town._service_buttons.get("route")
	var focus_owner := town.get_viewport().gui_get_focus_owner()
	if route_button == null or focus_owner != route_button:
		failures.append("new town gives keyboard and gamepad focus to the route map")
		return
	var accept := InputEventKey.new()
	accept.keycode = KEY_DOWN
	accept.physical_keycode = KEY_DOWN
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	var next_focus := town.get_viewport().gui_get_focus_owner()
	if next_focus == null or next_focus == route_button:
		failures.append("ui_down moves focus through the town service rail")
		return
	var pack_button: Button = town._service_buttons.get("pack")
	if pack_button == null:
		failures.append("equipment service button exists for keyboard navigation")
		return
	pack_button.grab_focus()
	var activate := InputEventKey.new()
	activate.keycode = KEY_ENTER
	activate.physical_keycode = KEY_ENTER
	activate.pressed = true
	Input.parse_input_event(activate)
	await process_frame
	activate.pressed = false
	Input.parse_input_event(activate)
	await process_frame
	if town._active_service != "pack":
		failures.append("ui_accept activates the focused service without mouse input")


func _test_real_snapshot_rendering(town: CampaignTown, controller: CampaignController, failures: Array[String]) -> void:
	var original_state := controller.snapshot()
	var generated_percent_record: Dictionary = {}
	var generated_percent_modifier: Dictionary = {}
	for record_value: Variant in original_state.get("inventory", {}).get("items", {}).values():
		if not record_value is Dictionary:
			continue
		var data: Dictionary = record_value.get("data", {})
		for modifier_value: Variant in data.get("implicit", []) + data.get("affixes", []):
			if modifier_value is Dictionary and modifier_value.get("op") in [PlayerStats.Op.INCREASED, PlayerStats.Op.MORE]:
				generated_percent_record = record_value
				generated_percent_modifier = modifier_value
				break
		if not generated_percent_record.is_empty():
			break
	if generated_percent_record.is_empty():
		failures.append("real controller gear includes a numeric increased/more modifier")
	else:
		var expected_text := ItemData.mod_text(generated_percent_modifier)
		var detail := VBoxContainer.new()
		town.add_child(detail)
		town._add_item_detail(detail, generated_percent_record)
		var saw_percentage := false
		for child: Node in detail.get_children():
			if child is Label and (child as Label).text.contains("%"):
				saw_percentage = true
				break
		if town._modifier_text(generated_percent_modifier) != expected_text or not saw_percentage:
			failures.append("real controller gear renders its increased/more modifier as a percentage")
		detail.free()

	var transition_state := original_state.duplicate(true)
	transition_state["biome_index"] = 1
	var seed := int(transition_state["seed"])
	var previous_graph := CampaignCatalog.route(seed, 0)
	transition_state["successful_nodes"] = {}
	for previous_node_id: Variant in previous_graph["nodes"]:
		transition_state["successful_nodes"][str(previous_node_id)] = "receipt-" + str(previous_node_id)
	transition_state["graph"] = CampaignCatalog.route(seed, 1)
	var depth_one := str(transition_state["graph"]["start"][0])
	var depth_two := str(transition_state["graph"]["nodes"][depth_one]["next"][0])
	transition_state["cleared_nodes"] = [depth_one, depth_two]
	controller._publish(transition_state)
	var biome_value := town._root.find_child("Value_biome", true, false) as Label
	if biome_value == null or not biome_value.text.ends_with("2 / 3 clears"):
		failures.append("biome transition displays only this realm's three short-node clears")
	controller._publish(original_state)


func _find_confirmation(node: Node) -> ConfirmationDialog:
	if node is ConfirmationDialog:
		return node as ConfirmationDialog
	for child: Node in node.get_children():
		var found := _find_confirmation(child)
		if found != null:
			return found
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.contains(text):
		return node as Label
	for child: Node in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _find_route_view(node: Node) -> CampaignRouteView:
	if node is CampaignRouteView:
		return node as CampaignRouteView
	for child: Node in node.get_children():
		var found := _find_route_view(child)
		if found != null:
			return found
	return null
