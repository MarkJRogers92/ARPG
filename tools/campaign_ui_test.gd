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
	var acknowledge_response := {"ok": true, "error": ""}

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

	func acknowledge_result(_operation_id := "") -> Dictionary:
		if not acknowledge_response.get("ok", false):
			return acknowledge_response.duplicate(true)
		state["phase"] = "CAMPAIGN_COMPLETE" if state.get("completed", false) else "TOWN"
		changed.emit(snapshot())
		return acknowledge_response.duplicate(true)

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
	if screen not in ["route", "route-rewards"]:
		town._active_service = "ferryman" if screen.begins_with("ferryman") else ("market" if screen == "market-full" else ("pack" if screen in ["comparison", "equipment-tools"] else ("trainer" if screen == "trainer-reaper" else ("route" if screen == "route-effects" else screen))))
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
		elif screen == "market-full":
			_fill_fixture_backpack(controller)
		elif screen == "equipment-tools":
			_fill_equipment_tools_fixture(controller)
		elif screen == "trainer-reaper":
			controller.state["hero_class"] = "reaper"
		elif screen == "result":
			controller.state["phase"] = "RESULT_PENDING"
			controller.state["result"] = {"outcome": "success", "elapsed": 360.0, "gold": 110, "shard_conversion": 12, "talent_points": 1, "items": ["i-rare"], "reserved_prize": "reserved-01", "biome_complete": false, "campaign_complete": false,
				"report": {"contract_id": "breach", "kills": 84, "level": 7, "realm": "graveyard", "died": false, "last_cause": "Bone Lancer", "damage_taken_by": {"Bone Lancer": 45.0, "Graves": 22.0}, "objectives": {"seals": 3}}}
			controller.state["inventory"]["tray"] = ["i-rare", "i-junk"]
			controller.state["wager"] = {"prizes": [{"id": "reserved-01", "data": {"slot": "helm", "name": "Crown of the Last Bell", "base_name": "Crown", "rarity": 3, "ilvl": 12, "implicit": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 8.0}], "affixes": [{"stat": "aura_radius", "op": PlayerStats.Op.INCREASED, "value": 0.2}], "power": "winter_crown"}}]}
		elif screen in ["complete", "complete_pending"]:
			controller.state["phase"] = "CAMPAIGN_COMPLETE"
			if screen == "complete_pending":
				controller.state["outbox"] = [{"id": "fixture:pending", "shards": 5}]
		if screen == "comparison":
			controller.state["inventory"]["items"]["i-rare"]["data"]["power"] = "stormcaller"
			controller.state["inventory"]["items"]["i-rare"]["data"]["affixes"] = [{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.15}, {"stat": "bolt_damage", "op": PlayerStats.Op.ADD, "value": 4.0}]
		if screen == "route-effects":
			controller.state["phase"] = "DEPARTURE_READY"
			controller.state["selected_node"] = "g-1-a"
			controller.state["effects"] = [{"id": "quiet_bell", "node_id": "g-1-a", "mods": [
				{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.25},
				{"stat": "max_hp", "op": PlayerStats.Op.INCREASED, "value": 0.10},
			]}]
		town._state = controller.snapshot()
		town._render()
		if screen == "equipment-tools":
			await process_frame
			var options := _find_option_buttons(town)
			options[0].item_selected.emit(ItemData.SLOTS.find("weapon") + 1)
			await process_frame
			options = _find_option_buttons(town)
			options[1].item_selected.emit(1)
			await process_frame
			var pack_scroll := town._content.get_parent() as ScrollContainer
			pack_scroll.scroll_vertical = mini(360, int(pack_scroll.get_v_scroll_bar().max_value))
		if screen == "comparison":
			town._select_item("i-rare", "weapon")
	await process_frame
	await process_frame
	await process_frame
	if screen == "route-rewards":
		var route_scroll := town._content.get_parent() as ScrollContainer
		route_scroll.scroll_vertical = int(route_scroll.get_v_scroll_bar().max_value)
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
	await _test_equipment_tools(failures)

	# Exercise the market and equipment commands through actual UI button callbacks.
	(town._service_buttons["market"] as Button).pressed.emit()
	await process_frame
	var buy_button := _find_button(root, "Buy ·", true)
	if buy_button == null:
		failures.append("market stock renders a buy action")
	else:
		var backpack_before: int = controller.state["inventory"]["backpack"].size()
		await _press_enter(buy_button)
		var backpack: Array = controller.state["inventory"]["backpack"]
		if backpack.size() != backpack_before + 1:
			failures.append("market button commits a purchase through the controller")
		else:
			var purchased_id := str(backpack[-1])
			var purchased: Dictionary = controller.state["inventory"]["items"][purchased_id]
			var purchase_focus := town.get_viewport().gui_get_focus_owner()
			var purchase_focus_is_action: bool = purchase_focus != null and purchase_focus.get_meta("town_action_focus_kind", "") == "market_stock" and not (purchase_focus as BaseButton).disabled
			var purchase_focus_is_sidebar: bool = purchase_focus == town._service_buttons["market"]
			if not purchase_focus_is_action and not purchase_focus_is_sidebar:
				failures.append("purchase refresh keeps focus on another market action or its sidebar fallback")
			(town._service_buttons["pack"] as Button).pressed.emit()
			await process_frame
			var item_button := _find_button(root, str(purchased["data"].get("name", "")), true)
			if item_button == null:
				failures.append("purchased copy appears in the armory")
			else:
				await _press_enter(item_button)
				var selection_focus := town.get_viewport().gui_get_focus_owner()
				if town._selected_item_id != purchased_id or selection_focus == null or selection_focus.get_meta("equipment_pack_focus_kind", "") != "backpack" or selection_focus.get_meta("equipment_pack_focus_id", "") != purchased_id:
					failures.append("Enter selects purchased gear and keeps focus on its rendered backpack row")
				var equip_button := _find_button(root, "Equip")
				if equip_button == null:
					failures.append("selected item exposes equip action")
				else:
					equip_button.grab_focus()
					await process_frame
					equip_button = _find_button(root, "Equip")
					if equip_button == null:
						failures.append("equip action remains available while selected gear is focused")
					else:
						equip_button.pressed.emit()
						await process_frame
						var equipped_focus := town.get_viewport().gui_get_focus_owner()
						if equipped_focus == null or equipped_focus.get_meta("equipment_pack_focus_kind", "") != "worn" or equipped_focus.get_meta("equipment_pack_focus_id", "") != purchased_id:
							failures.append("real equip refresh moves focus to the selected item's new worn row")
				if str(controller.state["inventory"]["equipped"].get(str(purchased["data"]["slot"]), "")) != purchased_id:
					failures.append("armory equip button commits the selected stable item ID")
				var backpack_after_equip: Array = controller.state["inventory"]["backpack"]
				if not backpack_after_equip.is_empty():
					var junk_id := str(backpack_after_equip[0])
					var junk_record: Dictionary = controller.state["inventory"]["items"][junk_id]
					town._select_item(junk_id, str(junk_record["data"]["slot"]))
					await process_frame
					var lock_button := _find_button(root, "Lock / unlock")
					if lock_button != null:
						lock_button.grab_focus()
						await process_frame
						lock_button = _find_button(root, "Lock / unlock")
						if lock_button != null:
							lock_button.pressed.emit()
							await process_frame
							if not controller.state["inventory"]["items"][junk_id]["locked"]:
								failures.append("lock button protects the selected copy")
							var marked_focus := town.get_viewport().gui_get_focus_owner()
							if marked_focus == null or marked_focus.get_meta("equipment_pack_focus_kind", "") != "backpack" or marked_focus.get_meta("equipment_pack_focus_id", "") != junk_id:
								failures.append("real lock refresh keeps focus on the selected backpack item")
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
		var talent_id := str(talent_button.get_meta("town_action_focus_id", ""))
		await _press_enter(talent_button)
		if int(controller.state["talents"]["points"]) >= talent_before:
			failures.append("trainer allocation spends points through the controller")
		var talent_focus := town.get_viewport().gui_get_focus_owner()
		if talent_focus == null or talent_focus.get_meta("town_action_focus_kind", "") != "talent" or talent_focus.get_meta("town_action_focus_id", "") != talent_id:
			failures.append("allocation refresh keeps focus on the same talent's refund control")
		else:
			var points_after_allocation := int(controller.state["talents"]["points"])
			await _press_enter(talent_focus)
			var refund_focus := town.get_viewport().gui_get_focus_owner()
			if int(controller.state["talents"]["points"]) <= points_after_allocation:
				failures.append("trainer refund returns points through the controller")
			if refund_focus == null or refund_focus.get_meta("town_action_focus_kind", "") != "talent" or refund_focus.get_meta("town_action_focus_id", "") != talent_id:
				failures.append("refund refresh keeps focus on the same talent's allocation control")
			talent_focus = town.get_viewport().gui_get_focus_owner()
			controller.changed.emit(controller.snapshot())
			var market_rail := town._service_buttons["market"] as Button
			market_rail.grab_focus()
			market_rail.pressed.emit()
			await process_frame
			if town._active_service != "market" or town.get_viewport().gui_get_focus_owner() != market_rail:
				failures.append("market navigation before deferred trainer focus restore keeps sidebar focus")
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
	await _test_route_reward_preview(failures)
	await _test_route_preparation_panel(failures)
	await _test_result_report_and_comparison(failures)
	await _test_full_backpack_controls(failures)
	await _test_starting_build_summary(failures)

	for message: String in failures:
		push_error("CAMPAIGN_UI_BEHAVIOR_FAIL: " + message)
	for suffix: String in [".save", ".save.bak", ".save.tmp", ".save.previous", ".meta", ".meta.bak", ".meta.tmp", ".meta.rollback"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_root + suffix))
	controller.free()
	town.free()
	print("CAMPAIGN_UI_BEHAVIOR %s" % ["FAILED" if not failures.is_empty() else "PASSED"])
	quit(1 if not failures.is_empty() else 0)


func _test_starting_build_summary(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	town._active_service = "trainer"
	town._state = fixture.snapshot()
	var baseline_before := town._state.duplicate(true)
	var baseline_preview: Dictionary = CampaignLoadout.preview(town._state)
	var after_baseline_preview := town._state.duplicate(true)
	town._render()
	await process_frame
	if town._state != baseline_before or after_baseline_preview != baseline_before:
		failures.append("starting-build preview and Trainer render leave baseline campaign input unchanged")
	if _find_label(town, "STARTING BUILD") == null or _find_label(town, "Baseline · no route committed") == null:
		failures.append("Trainer shows a baseline summary when no route is committed")
	if _find_label(town, "HP " + _preview_number(float(baseline_preview["max_hp"]))) == null or _find_label(town, "Crit " + String.num(float(baseline_preview["crit_chance"]) * 100.0, 1) + "%") == null:
		failures.append("Trainer renders starting health and critical chance from the preview")
	var expected_bolts := "Primary Bolts · %s dmg per hit · %s s cooldown" % [_preview_number(float(baseline_preview["primary_damage"])), _preview_number(float(baseline_preview["primary_cooldown"]))]
	if _find_label(town, expected_bolts) == null:
		failures.append("starting bolt attack shows its per-hit damage and cooldown")
	var invalid_state := town._state.duplicate(true)
	invalid_state["hero_class"] = "unknown-class"
	town._state = invalid_state
	town._render()
	await process_frame
	if _find_label(town, "Starting build summary unavailable.") == null:
		failures.append("empty loadout preview renders a safe unavailable message")
	town._state = baseline_before.duplicate(true)
	town._render()
	await process_frame
	fixture.state["phase"] = "DEPARTURE_READY"
	fixture.state["selected_node"] = "g-1-a"
	fixture.state["effects"] = [{"id": "borrowed_battalion", "node_id": "g-1-a", "minions": 3}]
	town._state = fixture.snapshot()
	var committed_preview: Dictionary = CampaignLoadout.preview(town._state)
	town._render()
	await process_frame
	if int(committed_preview["effect_count"]) != 1 or int(committed_preview["stat_effect_count"]) != 0 or _find_label(town, "Committed route · no added starting stat modifiers") == null:
		failures.append("non-stat route effects do not get described as starting stat modifiers")
	fixture.state["phase"] = "DEPARTURE_READY"
	fixture.state["hero_class"] = "reaper"
	fixture.state["talents"]["allocated"].append("d2")
	fixture.state["talents"]["points"] -= 1
	fixture.state["inventory"]["items"]["i-weapon"]["data"]["affixes"].append({"id": "fixture_crit", "stat": "crit_chance", "op": PlayerStats.Op.ADD, "value": 0.05})
	fixture.state["effects"] = [{"id": "quiet_bell", "node_id": "g-1-a", "mods": [
		{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.25},
		{"stat": "max_hp", "op": PlayerStats.Op.INCREASED, "value": 0.10},
	]}]
	town._state = fixture.snapshot()
	var equipped_before := town._state.duplicate(true)
	var changed_preview: Dictionary = CampaignLoadout.preview(town._state)
	town._render()
	await process_frame
	if town._state != equipped_before:
		failures.append("rendering the updated starting build leaves equipment and talents unchanged")
	if float(changed_preview["armor"]) <= float(baseline_preview["armor"]) or float(changed_preview["crit_chance"]) <= float(baseline_preview["crit_chance"]):
		failures.append("preview reflects the added armor talent and equipped critical-chance affix")
	var expected_primary := "Primary Reaping Scythe · %s dmg per hit · %s s cooldown" % [_preview_number(float(changed_preview["primary_damage"])), _preview_number(float(changed_preview["primary_cooldown"]))]
	if _find_label(town, expected_primary) == null:
		failures.append("Reaper summary shows its scythe damage and cooldown, not a bolt attack")
	if int(changed_preview["stat_effect_count"]) <= 0 or _find_label(town, "Route stat modifiers included · " + ", ".join(changed_preview["stat_effect_names"])) == null:
		failures.append("Trainer summary identifies included effects from the committed route")
	if _find_label(town, "Armor " + _preview_number(float(changed_preview["armor"]))) == null or _find_label(town, "Army capacity " + str(int(changed_preview["minion_max"]))) == null:
		failures.append("updated Trainer summary reflects equipped gear, talent, and class values")
	town._active_service = "route"
	town._render()
	await process_frame
	if _find_label(town, expected_primary) == null or _find_label(town, "Route stat modifiers included · " + ", ".join(changed_preview["stat_effect_names"])) == null:
		failures.append("route preparation shows the same previewed starting build and route effect")
	town.free()
	fixture.free()


func _preview_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)


func _test_route_reward_preview(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	var route_view := CampaignRouteView.new()
	root.add_child(route_view)
	var preview_state := fixture.snapshot()
	var preview_state_before := preview_state.duplicate(true)
	var available: Array = fixture.available_routes()
	route_view.present(preview_state, available)
	await process_frame
	var short_route: Dictionary = fixture.state["graph"]["nodes"]["g-1-b"]
	route_view._preview("g-1-b")
	var short_copy := route_view._details.text
	if not short_copy.contains("Base Gold: 140") or not short_copy.contains("before event adjustments or shard conversion"):
		failures.append("short-route preview shows scaled base gold and explains excluded adjustments")
	if not short_copy.contains("+1 Talent Point") or not short_copy.contains("upper-tier Rare Armor prize reserved at the Ferryman"):
		failures.append("short-route preview distinguishes its talent award and reserved Ferryman prize")
	if short_route.get("reward_slot") != "armor":
		failures.append("reward preview reads the node's existing reward slot")
	var cache_state := fixture.snapshot()
	cache_state["biome_index"] = 2
	var cache_state_before := cache_state.duplicate(true)
	var cache_view := CampaignRouteView.new()
	root.add_child(cache_view)
	cache_view.present(cache_state, [fixture.state["graph"]["nodes"]["g-2-b"]])
	cache_view._preview("g-2-b")
	if not cache_view._details.text.contains("Base Gold: 300") or not cache_view._details.text.contains("optional cache adds 150 Gold"):
		failures.append("Cursed Cache preview separates scaled base gold from its optional scaled bonus")
	if cache_state != cache_state_before:
		failures.append("Cursed Cache preview leaves its supplied state unchanged")
	cache_view.free()

	var hidden_route_view := CampaignRouteView.new()
	root.add_child(hidden_route_view)
	var veiled_state := fixture.snapshot()
	var veiled_state_before := veiled_state.duplicate(true)
	hidden_route_view.present(veiled_state, [])
	hidden_route_view._preview("g-1-a")
	if not hidden_route_view._confirm.disabled or hidden_route_view._details.text.contains("CLEAR REWARDS") or hidden_route_view._details.text.contains("Quiet Bell"):
		failures.append("unavailable unrevealed route keeps rewards and event details veiled and cannot commit")
	if veiled_state != veiled_state_before:
		failures.append("veiled-route preview leaves its supplied state unchanged")
	var revealed_state := fixture.snapshot()
	revealed_state["graph"]["nodes"]["g-1-a"]["revealed"] = true
	var revealed_state_before := revealed_state.duplicate(true)
	hidden_route_view.present(revealed_state, [])
	hidden_route_view._preview("g-1-a")
	if not hidden_route_view._confirm.disabled or not hidden_route_view._details.text.contains("CLEAR REWARDS") or not hidden_route_view._details.text.contains("Quiet Bell"):
		failures.append("revealed route shows existing preview details while remaining unavailable for commitment")
	if revealed_state != revealed_state_before:
		failures.append("revealed-route preview leaves its supplied state unchanged")

	var finale: Dictionary = fixture.state["graph"]["nodes"]["g-4-boss"]
	for biome in 3:
		var finale_state := fixture.snapshot()
		finale_state["biome_index"] = biome
		var finale_state_before := finale_state.duplicate(true)
		var finale_view := CampaignRouteView.new()
		root.add_child(finale_view)
		finale_view.present(finale_state, [finale])
		finale_view._preview("g-4-boss")
		var copy := finale_view._details.text
		var expected_gold := 250 * (biome + 1)
		var expected_talents := 3 if biome < 2 else 0
		if not copy.contains("Base Gold: %d" % expected_gold) or not copy.contains("+%d Talent Point" % expected_talents):
			failures.append("finale preview uses biome-scaled gold and the correct talent award for biome %d" % biome)
		if not copy.contains("Legendary Weapon prize banked"):
			failures.append("finale preview identifies its banked Legendary weapon prize")
		if finale_state != finale_state_before:
			failures.append("finale preview leaves its supplied biome-%d state unchanged" % biome)
		finale_view.free()
	if preview_state != preview_state_before:
		failures.append("short-route preview leaves its supplied state unchanged")
	route_view.free()
	hidden_route_view.free()
	fixture.free()


func _test_full_backpack_controls(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	_fill_fixture_backpack(fixture)
	var tray_record: Dictionary = fixture.state["inventory"]["items"]["i-junk"].duplicate(true)
	tray_record["id"] = "i-tray-full-test"
	fixture.state["inventory"]["items"]["i-tray-full-test"] = tray_record
	fixture.state["inventory"]["tray"] = ["i-tray-full-test"]
	root.add_child(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	await process_frame
	var state_before_render := fixture.snapshot()
	var town_state_before_render := town._state.duplicate(true)

	(town._service_buttons["market"] as Button).pressed.emit()
	await process_frame
	var market_copy := _find_label(town, "Backpack · %d / %d — full" % [Inventory.BACKPACK_SIZE, Inventory.BACKPACK_SIZE])
	var buy := _find_button(town, "Buy ·", true)
	if market_copy == null or buy == null or not buy.disabled:
		failures.append("full Market reports capacity and disables purchases")
	if fixture.state != state_before_render or town._state != town_state_before_render:
		failures.append("full Market rendering leaves fixture state unchanged")
	var recovery := _find_button(town, "Open Equipment to free a slot")
	if recovery == null:
		failures.append("full Market exposes its Equipment recovery action")
	else:
		recovery.pressed.emit()
		await process_frame
		var equipment_button := town._service_buttons["pack"] as Button
		var selected_style := equipment_button.get_theme_stylebox("normal") as StyleBoxFlat
		if town._active_service != "pack" or town._content_title.text != "THE ARMORY":
			failures.append("full Market recovery opens Equipment")
		if selected_style == null or selected_style.bg_color != Color(0.19, 0.15, 0.09, 0.96):
			failures.append("recovery navigation highlights Equipment in the service rail")

	var heading := _find_label(town, "BACKPACK · %d / %d" % [Inventory.BACKPACK_SIZE, Inventory.BACKPACK_SIZE])
	if heading == null or _find_label(town, "sell or discard an item here") == null:
		failures.append("full Equipment shows capacity and explains how to make space")
	town._select_item("i-weapon", "weapon")
	await process_frame
	var unequip := _find_button(town, "Unequip")
	if unequip == null or not unequip.disabled:
		failures.append("full Equipment disables unequip because it needs a free slot")
	town._select_item("i-rare", "weapon")
	await process_frame
	var equip := _find_button(town, "Equip")
	if equip == null or equip.disabled:
		failures.append("full Equipment keeps backpack gear equipable")
	town._select_item("i-tray-full-test", "offhand")
	await process_frame
	var claim_selected := _find_button(town, "Claim to backpack")
	var claim_tray := _find_button(town, "Claim")
	if claim_selected == null or not claim_selected.disabled or claim_tray == null or not claim_tray.disabled:
		failures.append("full Equipment disables both reward claim actions")
	if fixture.state != state_before_render or town._state != town_state_before_render:
		failures.append("Equipment capacity controls render without mutating fixture state")

	fixture.state["inventory"]["backpack"].pop_back()
	fixture.changed.emit(fixture.snapshot())
	await process_frame
	var state_after_freeing_slot := fixture.snapshot()
	var town_state_after_freeing_slot := town._state.duplicate(true)
	town._select_item("i-weapon", "weapon")
	await process_frame
	unequip = _find_button(town, "Unequip")
	if unequip == null or unequip.disabled:
		failures.append("state change freeing a slot re-enables unequip")
	town._select_item("i-tray-full-test", "offhand")
	await process_frame
	claim_selected = _find_button(town, "Claim to backpack")
	claim_tray = _find_button(town, "Claim")
	if claim_selected == null or claim_selected.disabled or claim_tray == null or claim_tray.disabled:
		failures.append("state change freeing a slot re-enables both claim actions")
	town._select_item("i-rare", "weapon")
	await process_frame
	equip = _find_button(town, "Equip")
	if equip == null or equip.disabled:
		failures.append("freeing capacity keeps backpack equipment available")
	if fixture.state != state_after_freeing_slot or town._state != town_state_after_freeing_slot:
		failures.append("capacity controls remain read-only after a state change")
	(town._service_buttons["market"] as Button).pressed.emit()
	await process_frame
	buy = _find_button(town, "Buy ·", true)
	if buy == null or buy.disabled:
		failures.append("state change freeing a slot re-enables Market purchases")
	town.free()
	fixture.free()


func _fill_fixture_backpack(controller: FixtureController) -> void:
	var inventory: Dictionary = controller.state["inventory"]
	var items: Dictionary = inventory["items"]
	var backpack: Array = inventory["backpack"]
	var template: Dictionary = items["i-junk"]
	while backpack.size() < Inventory.BACKPACK_SIZE:
		var item_id := "i-capacity-%02d" % backpack.size()
		var record := template.duplicate(true)
		record["id"] = item_id
		record["data"]["name"] = "Capacity Fixture %02d" % backpack.size()
		items[item_id] = record
		backpack.append(item_id)


func _fill_equipment_tools_fixture(controller: FixtureController) -> void:
	var inventory: Dictionary = controller.state["inventory"]
	var items: Dictionary = inventory["items"]
	var backpack: Array = inventory["backpack"]
	backpack.clear()
	inventory["tray"] = ["i-rare"]
	var slots: Array = ItemData.SLOTS
	for index in range(Inventory.BACKPACK_SIZE):
		var item_id := "i-tool-%02d" % index
		var slot := str(slots[index % slots.size()])
		var record: Dictionary = items["i-junk"].duplicate(true)
		record["id"] = item_id
		record["locked"] = index == 0
		record["junk"] = index == 1
		record["data"]["slot"] = slot
		record["data"]["rarity"] = index % 4
		record["data"]["ilvl"] = 20 + index % 5
		record["data"]["name"] = "Gear %02d" % (index % 8)
		items[item_id] = record
		backpack.append(item_id)


func _test_equipment_tools(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	_fill_equipment_tools_fixture(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	town._active_service = "pack"
	town._state = fixture.snapshot()
	var original_state: Dictionary = town._state.duplicate(true)
	town._render()
	await process_frame
	var inventory: Dictionary = town._state["inventory"]
	var items: Dictionary = inventory["items"]
	if inventory["backpack"].size() != Inventory.BACKPACK_SIZE or inventory["tray"] != ["i-rare"]:
		failures.append("equipment fixture shows a full 24-item bag beside a visible reward tray")
	var backpack_choice := _find_button(town, "Gear 00", true)
	if backpack_choice != null:
		await _press_enter(backpack_choice)
	var focused := town.get_viewport().gui_get_focus_owner()
	if town._selected_item_id != "i-tool-00" or focused == null or focused.get_meta("equipment_pack_focus_kind", "") != "backpack" or focused.get_meta("equipment_pack_focus_id", "") != "i-tool-00":
		failures.append("Enter selects a backpack item and keeps focus on its replacement row")
	var scroll := town._content.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
		await process_frame
	var worn_choice := _find_button(town, "Weapon   ·   Moonlit Dirk")
	if worn_choice != null:
		await _press_enter(worn_choice)
	focused = town.get_viewport().gui_get_focus_owner()
	if town._selected_item_id != "i-weapon" or focused == null or focused.get_meta("equipment_pack_focus_kind", "") != "worn" or focused.get_meta("equipment_pack_focus_id", "") != "i-weapon":
		failures.append("Enter selects worn gear and keeps focus on its replacement slot row (selected=%s focus=%s kind=%s id=%s current_row=%s queued_old_row=%s)" % [town._selected_item_id, str(focused), str(focused.get_meta("equipment_pack_focus_kind", "")) if focused else "", str(focused.get_meta("equipment_pack_focus_id", "")) if focused else "", str(_find_button(town, "Weapon   ·   Moonlit Dirk")), str(worn_choice)])
	if scroll != null and focused != null and not _control_intersects_scroll_viewport(scroll, focused):
		failures.append("focused worn replacement row scrolls into view after selecting from a distant position (scroll=%s focused=%s)" % [str(scroll.get_global_rect()), str(focused.get_global_rect())])
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
	var tray_compare := _find_button(town, "Compare")
	if tray_compare != null:
		await _press_enter(tray_compare)
	focused = town.get_viewport().gui_get_focus_owner()
	if town._selected_item_id != "i-rare" or focused == null or focused.get_meta("equipment_pack_focus_kind", "") != "tray" or focused.get_meta("equipment_pack_focus_id", "") != "i-rare":
		failures.append("Enter selects a reward and keeps focus on its replacement Compare control (selected=%s focus=%s kind=%s id=%s)" % [town._selected_item_id, str(focused), str(focused.get_meta("equipment_pack_focus_kind", "")) if focused else "", str(focused.get_meta("equipment_pack_focus_id", "")) if focused else ""])
	if scroll != null and focused != null and not _control_intersects_scroll_viewport(scroll, focused):
		failures.append("focused reward Compare replacement scrolls into view")
	# A controller refresh may queue replacement row focus, but a newly focused
	# sidebar control must keep ownership when the deferred callback runs.
	var backpack_for_external_focus := _find_button(town, "Gear 00", true)
	var market_button := town._service_buttons["market"] as Button
	if backpack_for_external_focus != null:
		backpack_for_external_focus.grab_focus()
		await process_frame
		fixture.changed.emit(fixture.snapshot())
		market_button.grab_focus()
		await process_frame
		if town.get_viewport().gui_get_focus_owner() != market_button or town._active_service != "pack":
			failures.append("controller refresh preserves newly focused sidebar control")
		# Schedule another restore, then navigate before the deferred callback.
		var focused_row := _find_button(town, "Gear 00", true)
		if focused_row != null:
			focused_row.grab_focus()
			await process_frame
			fixture.changed.emit(fixture.snapshot())
			market_button.grab_focus()
			market_button.pressed.emit()
			await process_frame
			if town._active_service != "market" or town.get_viewport().gui_get_focus_owner() != market_button:
				failures.append("service navigation before deferred row-focus restore remains active (service=%s focus=%s)" % [town._active_service, str(town.get_viewport().gui_get_focus_owner())])
			(town._service_buttons["pack"] as Button).pressed.emit()
			await process_frame
	var options := _find_option_buttons(town)
	if options.size() < 2 or options[0].item_count != ItemData.SLOTS.size() + 1 or options[1].item_count != 4:
		failures.append("equipment controls expose all slot filters and four local sort choices")
	else:
		var weapon_filter_index := ItemData.SLOTS.find("weapon") + 1
		options[0].grab_focus()
		options[0].item_selected.emit(weapon_filter_index)
		await process_frame
		if town.get_viewport().gui_get_focus_owner() != town._pack_filter_dropdown:
			failures.append("slot filter keeps keyboard focus on its replacement control")
		if _find_label(town, "Showing 4 of 24") == null:
			failures.append("slot filter reports the rendered subset count")
		var weapon_rows := _backpack_rows(town)
		var expected_weapon_rows: Array[String] = []
		for index in range(Inventory.BACKPACK_SIZE):
			if index % ItemData.SLOTS.size() == ItemData.SLOTS.find("weapon"):
				var item_id := "i-tool-%02d" % index
				expected_weapon_rows.append(_gear_row_text(item_id, items[item_id]))
		if weapon_rows != expected_weapon_rows:
			failures.append("slot dropdown renders only weapon rows in bag order")
		options = _find_option_buttons(town)
		options[1].grab_focus()
		options[1].item_selected.emit(1)
		await process_frame
		if town.get_viewport().gui_get_focus_owner() != town._pack_sort_dropdown:
			failures.append("sort dropdown keeps keyboard focus on its replacement control")
		if town._pack_slot_filter != "weapon" or town._pack_sort != "rarity":
			failures.append("filter and sort controls update only the armory view")
		var expected_sorted_weapon_rows: Array[String] = []
		for rarity in [3, 2, 1, 0]:
			for index in range(Inventory.BACKPACK_SIZE):
				if index % 4 == rarity and index % ItemData.SLOTS.size() == ItemData.SLOTS.find("weapon"):
					var item_id := "i-tool-%02d" % index
					expected_sorted_weapon_rows.append(_gear_row_text(item_id, items[item_id]))
		if _backpack_rows(town) != expected_sorted_weapon_rows:
			failures.append("rarity dropdown renders matching gear by rarity with stable ID ties")
		if _find_label(town, "Ashen Oath") == null:
			failures.append("reward tray remains rendered while backpack filtering and sorting are active")
		options = _find_option_buttons(town)
		options[1].item_selected.emit(2)
		await process_frame
		var expected_ilvl_rows: Array[String] = []
		for index in [18, 12, 6, 0]:
			var item_id := "i-tool-%02d" % index
			expected_ilvl_rows.append(_gear_row_text(item_id, items[item_id]))
		if _backpack_rows(town) != expected_ilvl_rows:
			failures.append("item-level dropdown renders matching gear in descending level order")
		options = _find_option_buttons(town)
		options[1].item_selected.emit(3)
		await process_frame
		var expected_name_rows: Array[String] = []
		for index in [0, 18, 12, 6]:
			var item_id := "i-tool-%02d" % index
			expected_name_rows.append(_gear_row_text(item_id, items[item_id]))
		if _backpack_rows(town) != expected_name_rows:
			failures.append("name dropdown renders matching gear alphabetically with ID ties")
		options = _find_option_buttons(town)
		options[0].item_selected.emit(0)
		await process_frame
		options = _find_option_buttons(town)
		options[1].item_selected.emit(0)
		await process_frame
	var worn_button := _find_button(town, "Weapon   ·   Moonlit Dirk")
	if worn_button != null:
		worn_button.pressed.emit()
	await process_frame
	var unequip := _find_button(town, "Unequip")
	if unequip == null or not unequip.disabled:
		failures.append("full backpack keeps unequip blocked regardless of backpack view state")
	var hidden_selection := _find_button(town, "Gear 02", true)
	if hidden_selection != null:
		hidden_selection.pressed.emit()
	await process_frame
	options = _find_option_buttons(town)
	options[0].item_selected.emit(ItemData.SLOTS.find("weapon") + 1)
	await process_frame
	if _find_label(town, "outside this backpack filter") == null:
		failures.append("filtered-out selection remains inspectable with a clear explanation")
	fixture.changed.emit(fixture.snapshot())
	await process_frame
	if town.get_viewport().gui_get_focus_owner() != town._pack_filter_dropdown:
		failures.append("state refresh falls back to the filter when selected gear is hidden")
	if _find_button(town, "Claim") == null or not _find_button(town, "Claim").disabled:
		failures.append("full backpack keeps reward claim blocked while filtering")
	if town._state != original_state:
		failures.append("equipment filtering and sorting leave the supplied inventory snapshot unchanged")
	for item_id: String in fixture.state["inventory"]["backpack"]:
		fixture.state["inventory"]["items"][item_id]["data"]["slot"] = "weapon"
	fixture.changed.emit(fixture.snapshot())
	await process_frame
	options = _find_option_buttons(town)
	options[0].item_selected.emit(ItemData.SLOTS.find("helm") + 1)
	await process_frame
	if _find_label(town, "Showing 0 of 24") == null or not _backpack_rows(town).is_empty():
		failures.append("empty slot filter renders no backpack rows and reports zero matches")
	if _find_label(town, "Ashen Oath") == null:
		failures.append("no-match backpack filter keeps reward tray rendered")
	options = _find_option_buttons(town)
	options[0].item_selected.emit(0)
	await process_frame
	if _find_button(town, "Gear 00", true) == null or not _find_button(town, "Gear 00", true).text.begins_with("◆ "):
		failures.append("locked gear remains visible with its lock mark")
	if _find_button(town, "Gear 01", true) == null or not _find_button(town, "Gear 01", true).text.begins_with("× "):
		failures.append("junk gear remains visible with its junk mark")
	if _find_label(town, "slot filters never hide rewards") == null:
		failures.append("crowded backpack explains where unfiltered reward-tray items remain")
	var selected_row := _find_button(town, "Gear 02", true)
	if selected_row != null:
		selected_row.pressed.emit()
	await process_frame
	fixture.state["inventory"]["backpack"].erase("i-tool-02")
	fixture.state["inventory"]["items"].erase("i-tool-02")
	fixture.changed.emit(fixture.snapshot())
	await process_frame
	if not town._selected_item_id.is_empty():
		failures.append("selection clears safely when its item disappears from current inventory")
	if town.get_viewport().gui_get_focus_owner() != town._pack_filter_dropdown:
		failures.append("state refresh falls back to the filter after the selected item disappears")
	town.free()
	fixture.free()


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


func _test_result_report_and_comparison(failures: Array[String]) -> void:
	var fixture := FixtureController.new()
	root.add_child(fixture)
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(fixture)
	fixture.state["phase"] = "RESULT_PENDING"
	fixture.state["result"] = {"outcome": "failure", "elapsed": 420.0, "gold": 0, "shard_conversion": 0,
		"talent_points": 0, "items": ["i-rare"], "report": {"contract_id": "elite_hunt", "kills": 9,
		"level": 4, "realm": "graveyard", "died": false, "last_cause": "Old prior hit", "damage_taken_by": {"wolf": 4.0, "bad": INF},
		"objectives": {"elite_dead": false}}}
	fixture.acknowledge_response = {"ok": false, "error": "Fixture acknowledgment failed."}
	town._state = fixture.snapshot()
	town._render()
	await process_frame
	if _find_label(town, "expedition level: 4") == null or _find_label(town, "No contract gold") != null:
		failures.append("result report shows expedition details without inventing a failure recap")
	if _find_label(town, "SLAIN BY:") != null:
		failures.append("timeout-style failure does not turn the last prior hit into a death recap")
	if _find_label(town, "contract did not settle") == null and _find_label(town, "deadline passed") == null:
		failures.append("failure result explains why the expedition did not settle")
	var trainer := _find_button(town, "Visit Trainer")
	if trainer == null:
		failures.append("result exposes a Trainer shortcut with a player-facing label")
	else:
		var shortcut_grid: GridContainer
		for child: Node in town._content.get_children():
			if child is GridContainer and (child as GridContainer).columns == 2:
				shortcut_grid = child as GridContainer
				break
		if shortcut_grid == null or shortcut_grid.get_child_count() != 4:
			failures.append("result shortcuts use a compact two-column grid")
		trainer.pressed.emit()
		await process_frame
		if fixture.state["phase"] != "RESULT_PENDING" or town._active_service == "trainer" or town._feedback.text != "Fixture acknowledgment failed.":
			failures.append("failed result acknowledgment keeps the result screen visible")
	fixture.acknowledge_response = {"ok": true, "error": ""}
	trainer = _find_button(town, "Visit Trainer")
	if trainer != null:
		trainer.pressed.emit()
		await process_frame
		if fixture.state["phase"] == "RESULT_PENDING" or town._active_service != "trainer":
			failures.append("successful acknowledgment opens the selected town service afterward")
	fixture.state["result"] = {"outcome": "success", "gold": 100, "shard_conversion": 5, "talent_points": 1,
		"items": ["i-rare"], "report": {"contract_id": "hunt", "kills": 9, "level": 4, "realm": "graveyard"}}
	fixture.state["phase"] = "RESULT_PENDING"
	town._state = fixture.snapshot()
	town._render()
	await process_frame
	trainer = _find_button(town, "Visit Trainer")
	var gear_heading := _find_label(town, "GEAR BANKED")
	var shortcuts_index := town._content.get_children().find(trainer.get_parent()) if trainer != null else -1
	if trainer == null or gear_heading == null or shortcuts_index < 0 or shortcuts_index > town._content.get_children().find(gear_heading):
		failures.append("successful result places its shortcut grid above the banked gear list")
	var current := {"implicit": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 10.0}],
		"affixes": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 5.0},
			{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.1},
			{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.2},
			{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.5}]}
	var offered := {"implicit": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 8.0}],
		"affixes": [{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.3},
			{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.1},
			{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.1}]}
	var totals := ItemComparison.modifiers(current)
	var rows := ItemComparison.rows(current, offered)
	if not is_equal_approx(float(totals["armor:%d" % PlayerStats.Op.ADD]), 15.0) or not is_equal_approx(float(totals["damage:%d" % PlayerStats.Op.MORE]), 0.8):
		failures.append("item comparison aggregates only matching stat and operation, with multiplicative MORE")
	if rows.size() != 3 or not is_equal_approx(float(ItemComparison.modifiers(offered)["damage:%d" % PlayerStats.Op.MORE]), 0.21):
		failures.append("comparison rows preserve operation distinctions and combine MORE factors correctly")
	if not ItemComparison.modifiers({"power": "soul_lantern"}).has("soul_chance:%d" % PlayerStats.Op.MORE):
		failures.append("comparison includes stat modifiers granted by legendary powers")
	var add_text := ItemComparison.format_value("crit_chance", PlayerStats.Op.ADD, 0.05)
	var increased_text := ItemComparison.format_value("crit_chance", PlayerStats.Op.INCREASED, 0.05)
	if add_text == increased_text or not add_text.begins_with("Added · ") or not increased_text.begins_with("Increased · "):
		failures.append("percentage rows visibly distinguish ADD from INCREASED semantics")
	if not town._comparison_power_text("Worn", {"power": "stormcaller"}).contains(ItemData.POWERS["stormcaller"]["desc"]) or not town._comparison_power_text("Offered", {"power": "stormcaller"}).contains(ItemData.POWERS["stormcaller"]["desc"]):
		failures.append("comparison describes the worn and offered legendary powers separately")
	var power_only_comparison := VBoxContainer.new()
	town.add_child(power_only_comparison)
	town._add_item_comparison(power_only_comparison,
		{"data": {"slot": "amulet", "name": "Heart of Storms", "implicit": [], "affixes": [], "power": "heart_of_storms"}},
		{"data": {"slot": "amulet", "name": "Heart of Storms II", "implicit": [], "affixes": [], "power": "heart_of_storms"}})
	if _find_label(power_only_comparison, ItemData.POWERS["heart_of_storms"]["desc"]) == null:
		failures.append("comparison keeps nonnumeric legendary powers visible when there are no modifier rows")
	power_only_comparison.free()
	var old_result := {"outcome": "failure", "report": {"contract_id": "hunt"}}
	if not town._result_reward_ids(old_result, fixture.state["inventory"]["items"]).is_empty():
		failures.append("failed attempts never claim banked field gear")
	fixture.state["phase"] = "RESULT_PENDING"
	fixture.state["result"] = {"outcome": "retreat", "elapsed": 12.0, "report": {"summary": "We turned back safely.", "contract_id": "hunt"}}
	town._state = fixture.snapshot()
	town._render()
	await process_frame
	if _find_label(town, "Untouched all night") != null:
		failures.append("legacy reports without damage fields do not invent an untouched-night recap")
	fixture.state["phase"] = "RESULT_PENDING"
	fixture.state["result"] = {"outcome": "success", "reserved_prize": "reserved-id", "items": [], "report": {}}
	fixture.state["wager"] = {"prizes": [{"id": "reserved-id", "data": {"slot": "weapon", "implicit": [], "affixes": [], "power": ""}}]}
	fixture.state["inventory"]["items"]["reserved-id"] = fixture.state["wager"]["prizes"][0]
	town._state = fixture.snapshot()
	var rewards := town._result_reward_ids(fixture.state["result"], fixture.state["inventory"]["items"])
	if rewards.has("reserved-id"):
		failures.append("Ferryman-reserved prize stays outside banked reward comparison")
	fixture.state["phase"] = "TOWN"
	fixture.state["wager"]["status"] = "open"
	town._state = fixture.snapshot()
	town._active_service = "ferryman"
	town._render()
	if _find_label(town, "Reserved prize · not yet banked or owned") == null:
		failures.append("open Ferryman prize is labeled reserved")
	fixture.state["wager"]["status"] = "won"
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "Reserved prize · not yet banked or owned") == null:
		failures.append("won but untaken Ferryman prize remains labeled reserved")
	fixture.state["wager"]["status"] = "taken"
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "PRIZE TAKEN · BANKED") == null:
		failures.append("taken Ferryman prize is labeled banked")
	fixture.state["wager"]["status"] = "lost"
	fixture.state["wager"]["prizes"] = []
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "PRIZE WAS FORFEITED") == null:
		failures.append("lost Ferryman prize is labeled forfeited")
	fixture.state["phase"] = "RESULT_PENDING"
	fixture.state["result"] = {"outcome": "failure", "elapsed": 500.0, "report": {"contract_id": "breach"}}
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "Seal objective:") != null or _find_label(town, "contract deadline passed") != null:
		failures.append("legacy result omits unknown objectives and needs a recorded alive state before inferring a deadline")
	fixture.state["result"]["report"] = {"contract_id": "cursed_cache"}
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "Cursed cache:") != null:
		failures.append("legacy report does not invent an unopened cache when its objective is missing")
	fixture.state["result"]["elapsed"] = 420.0
	fixture.state["result"]["report"] = {"contract_id": "elite_hunt", "died": false}
	town._state = fixture.snapshot()
	town._render()
	if _find_label(town, "contract deadline passed while you were still alive") == null or _find_label(town, "Marked elite:") != null:
		failures.append("deadline explanation requires recorded survival and elapsed deadline while omitting unknown elite details")
	fixture.state["completed"] = true
	fixture.state["result"] = {"outcome": "success", "campaign_complete": true, "report": {"contract_id": "finale", "kills": 100, "level": 9, "realm": "ember_rift"}}
	town._state = fixture.snapshot()
	town._render()
	await process_frame
	if _find_button(town, "Visit ", true) != null or _find_button(town, "Review Equipment") != null:
		failures.append("final campaign result does not offer service shortcuts around completion")
	var final_continue := _find_button(town, "Continue to town")
	if final_continue != null:
		final_continue.pressed.emit()
		await process_frame
		if fixture.state["phase"] != "CAMPAIGN_COMPLETE" or town._content_title.text != "THE ROAD ENDS IN DAWN":
			failures.append("final victory acknowledgment presents the campaign completion screen")
	var before_comparison := town._state.duplicate(true)
	var empty_comparison := VBoxContainer.new()
	town.add_child(empty_comparison)
	town._add_item_comparison(empty_comparison, {}, {"data": {"slot": "weapon", "name": "Test Blade", "implicit": [], "affixes": [], "power": ""}})
	if _find_label(empty_comparison, "Worn: empty slot") == null or town._state != before_comparison:
		failures.append("empty-slot comparison is clear and read-only")
	empty_comparison.free()
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


func _find_option_buttons(node: Node) -> Array[OptionButton]:
	var found: Array[OptionButton] = []
	if node is OptionButton:
		found.append(node as OptionButton)
	for child: Node in node.get_children():
		found.append_array(_find_option_buttons(child))
	return found


func _backpack_rows(node: Node) -> Array[String]:
	var rows: Array[String] = []
	if node is Button and (node as Button).text.contains("Gear "):
		rows.append((node as Button).text)
	for child: Node in node.get_children():
		rows.append_array(_backpack_rows(child))
	return rows


func _press_enter(control: Control) -> void:
	control.grab_focus()
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame


func _control_intersects_scroll_viewport(scroll: ScrollContainer, control: Control) -> bool:
	return scroll.get_global_rect().intersects(control.get_global_rect())


func _gear_row_text(item_id: String, record: Dictionary) -> String:
	var mark := "◆ " if bool(record.get("locked", false)) else ("× " if bool(record.get("junk", false)) else "")
	var data: Dictionary = record.get("data", {})
	return "%s%s  ·  %s" % [mark, data.get("name", data.get("base_name", "Item")), ItemData.rarity_name(int(data.get("rarity", 0)))]


func _find_route_view(node: Node) -> CampaignRouteView:
	if node is CampaignRouteView:
		return node as CampaignRouteView
	for child: Node in node.get_children():
		var found := _find_route_view(child)
		if found != null:
			return found
	return null
