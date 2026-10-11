extends SceneTree
## Campaign facility transactions, old saves, retry snapshots and real UI paths.
var checks := 0
var failures := 0
var test_path := "user://facility-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var files: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _new_controller(label: String, gold := 2000, seed_value := 58103) -> CampaignController:
	CampaignSave.path = test_path + "-" + label + ".save"
	files.append(CampaignSave.path)
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", seed_value)["ok"], "fixture creates in disposable storage")
	var state := controller.snapshot()
	state["gold"] = gold
	check(controller._commit(state)["ok"], "fixture bank persists")
	return controller

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	MetaProgress.disabled = true
	Controls.apply()
	_transactions()
	_legacy_and_validation()
	_shop_and_forge()
	_departure_and_retry()
	_success_and_progress()
	_seed_budgets()
	await _views()
	for path in files:
		for suffix in ["", ".bak", ".tmp", ".previous", ".rollback"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("CAMPAIGN_FACILITIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _transactions() -> void:
	var controller := _new_controller("commands")
	check(controller.pin_facility("workshop", 1, "goal")["ok"], "next facility goal pins through command path")
	var pinned := controller.snapshot()
	check(CampaignSave.read() == pinned, "pinned concrete tier survives reload")
	check(not controller.buy_facility("workshop", 2)["ok"], "tier two cannot bypass its prerequisite")
	check(controller.state == pinned, "invalid command does not spend or migrate state")
	CampaignSave.fail_stage = "write"
	check(not controller.buy_facility("workshop", 1, "purchase")["ok"], "failed write rejects purchase")
	CampaignSave.fail_stage = ""
	check(controller.state == pinned and CampaignSave.read() == pinned, "failed write leaves live and banked facts unchanged")
	var bought := controller.buy_facility("workshop", 1, "purchase")
	check(bought["ok"], "tier one purchases after write recovery")
	check(controller.state["gold"] == 1910 and controller.state["facilities"]["workshop"] == 1, "listed price charged exactly")
	check(controller.state["facility_goal"].is_empty(), "purchased goal is cleared, not silently moved to tier two")
	var after := controller.snapshot()
	check(controller.buy_facility("workshop", 1, "purchase") == bought, "same operation receipt replays identical response")
	check(controller.state == after, "replayed purchase cannot charge or generate duplicate offers")
	check(not controller.buy_facility("workshop", 1, "another-id")["ok"], "new operation cannot repurchase owned tier")
	check(not controller.buy_facility("workshop", 2, "purchase")["ok"], "reused receipt cannot purchase a different tier")
	check(not controller.pin_facility("unknown", 1)["ok"], "unknown goal rejected")
	check(not controller.pin_facility("wayfinder", 2)["ok"], "goal must be concrete next tier")
	for id: String in CampaignFacilities.ORDER:
		var first := CampaignFacilities.tier(controller.state, id) + 1
		for tier in range(first, 3):
			var bank: int = controller.state["gold"]
			check(controller.buy_facility(id, tier)["ok"], "each authored tier is purchasable")
			check(bank - controller.state["gold"] == CampaignFacilities.upgrade(id, tier)["cost"], "every authored price agrees with spend")
	check(CampaignSave.read() == controller.state, "all tiers survive exact save/read")
	controller.free()
	var poor := _new_controller("poor", 0)
	var before := poor.snapshot()
	check(not poor.buy_facility("wayfinder", 1)["ok"] and poor.state == before, "unaffordable purchase never changes facts")
	check(poor.pin_facility("wayfinder", 1)["ok"], "a poor player can pin a free goal")
	check(poor.pin_facility("")["ok"] and poor.state["facility_goal"].is_empty(), "goal unpins without cost")
	poor.free()

func _legacy_and_validation() -> void:
	var controller := _new_controller("legacy")
	var old := controller.snapshot()
	old.erase("facilities")
	old.erase("facility_goal")
	check(CampaignState.validate(old) == "", "old schema-v1 campaign without new fields remains valid")
	check(controller._commit(old)["ok"], "legacy facts can be saved without migration")
	check(controller.load_campaign()["ok"] and not controller.state.has("facilities"), "legacy loading does not rewrite saves")
	check(CampaignFacilities.levels(controller.state) == CampaignFacilities.fresh(), "legacy tier getters have zero defaults")
	check(controller.pin_facility("wayfinder", 1)["ok"] and controller.state["facilities"] == CampaignFacilities.fresh(), "next committed command materializes additive defaults")
	var baseline := controller.snapshot()
	for value: Variant in [null, [], {"wayfinder": 0}, {"wayfinder": 1.0, "workshop": 0, "veteran_hall": 0}, {"wayfinder": -1, "workshop": 0, "veteran_hall": 0}, {"wayfinder": 3, "workshop": 0, "veteran_hall": 0}]:
		var bad := baseline.duplicate(true)
		bad["facilities"] = value
		check(CampaignState.validate(bad) != "", "malformed tiers rejected without coercion")
	for value: Variant in [null, [], {"id": "unknown", "tier": 1}, {"id": "workshop", "tier": 2}, {"id": "wayfinder", "tier": 1.0}]:
		var bad := baseline.duplicate(true)
		bad["facility_goal"] = value
		check(CampaignState.validate(bad) != "", "invalid/stale/premature goals rejected")
	controller.free()

func _shop_and_forge() -> void:
	var controller := _new_controller("shop")
	var original: Array = controller.state["shop"].duplicate(true)
	check(original.size() == 6, "ordinary six original offers unchanged at zero tier")
	check(controller.buy_facility("workshop", 1)["ok"], "shelf expansion purchases")
	check(controller.state["shop"].size() == 8 and controller.state["shop"].slice(0, 6) == original, "expansion appends without rerolling or replacing original copies")
	for slot: String in ["boots", "amulet"]:
		var matches: Array = controller.state["shop"].filter(func(entry: Dictionary) -> bool: return entry.get("facility_stock", "") == slot)
		check(matches.size() == 1 and matches[0]["item"]["data"]["slot"] == slot and matches[0]["item"]["data"]["rarity"] == ItemData.Rarity.MAGIC, "extra offer matches its disclosed slot and rarity")
	var saved := controller.snapshot()
	check(controller.load_campaign()["ok"] and controller.state == saved, "reloading shelves cannot reroll additions")
	check(controller.buy_facility("workshop", 2)["ok"] and controller.state["shop"].size() == 8, "tier two adds discount without duplicating tier-one shelves")
	for biome in 3:
		var state := controller.snapshot()
		state["biome_index"] = biome
		state["graph"] = CampaignCatalog.route(state["seed"], biome)
		check(controller._commit(state)["ok"], "forge fixture biome validates")
		var stock_id: String = controller.state["shop"][0]["id"]
		if not controller.state["shop"][0]["purchased"]: check(controller.buy_item(stock_id)["ok"], "forge copy purchased")
		var item_id: String = controller.state["inventory"]["backpack"][0]
		var bank: int = controller.state["gold"]
		check(controller.reforge_item(item_id)["ok"], "discounted reforge offered once in each biome")
		check(controller.state["reforge"]["cost"] == 48 * (biome + 1) and bank - controller.state["gold"] == 48 * (biome + 1), "fee preview, pending choice and debit agree")
		check(controller.resolve_reforge(false)["ok"], "original may still be kept")
		check(not controller.reforge_item(item_id)["ok"], "discount does not grant additional reforge uses")
	controller.free()

func _depart(controller: CampaignController) -> Dictionary:
	if controller.state["selected_node"] == "":
		check(controller.choose_route(controller.available_routes()[0]["id"])["ok"], "route commits")
	if controller.state["phase"] == "EVENT_PENDING":
		var choices: Array = controller.state["event"]["choices"]
		var free_choice: String = choices[-1]["id"]
		check(controller.resolve_event(free_choice)["ok"], "existing attached event resolves before departure")
	check(controller.reset_talents()["ok"], "fixture does not leave required talent allocation")
	# Departure requires allocation, not merely points; use the current connected nodes.
	for id: String in SkillData.neighbors(SkillData.ROOT):
		if controller.state["talents"]["points"] >= SkillData.cost(id): controller.allocate_talent(id)
	var departure := controller.depart()
	check(departure["ok"], "facility owner still departs through existing authority")
	return departure.get("spec", {})

func _result(spec: Dictionary, outcome: String) -> Dictionary:
	return {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"], "outcome": outcome,
		"elapsed": 5.0, "objectives": {}, "kills_by": {}, "loose_shards": 0}

func _departure_and_retry() -> void:
	var controller := _new_controller("retry")
	check(controller.buy_facility("veteran_hall", 1)["ok"] and controller.buy_facility("veteran_hall", 2)["ok"], "army tiers bought before departure")
	var frozen_before := controller.snapshot()
	var preview := CampaignLoadout.preview(controller.state)
	check(controller.snapshot() == frozen_before, "build preview is read-only")
	check(preview.has("minion_damage") and preview.has("minion_hp"), "build preview includes facility-affected army stats")
	var spec := _depart(controller)
	if spec.is_empty():
		controller.free()
		return
	check(spec["starting_loadout"]["facilities"] == controller.state["facilities"], "departure freezes complete tier facts")
	var player := Player.new()
	CampaignLoadout.apply(player, "battlemage", spec["starting_loadout"], spec["effects"])
	var committed_preview := CampaignLoadout.preview(controller.state)
	check(is_equal_approx(player.stats.minion_max, committed_preview["minion_max"]) and is_equal_approx(player.stats.minion_damage, committed_preview["minion_damage"]) and is_equal_approx(player.stats.minion_hp, committed_preview["minion_hp"]), "town preview and actual committed departure agree")
	var plain_loadout: Dictionary = spec["starting_loadout"].duplicate(true)
	plain_loadout.erase("facilities")
	var plain := Player.new()
	CampaignLoadout.apply(plain, "battlemage", plain_loadout, spec["effects"])
	check(player.stats.minion_max == plain.stats.minion_max + 1, "capacity applies to actual built player")
	check(is_equal_approx(player.stats.minion_damage, plain.stats.minion_damage * 1.15) and is_equal_approx(player.stats.minion_hp, plain.stats.minion_hp * 1.15), "company drill applies disclosed multiplicative effects")
	check(player.stats.mods_from("campaign_facilities").size() == 3, "facility source has exactly three bounded modifiers")
	player.free()
	plain.free()
	var active := controller.snapshot()
	check(not controller.buy_facility("wayfinder", 1)["ok"] and controller.state == active, "active expedition cannot change its committed facilities")
	var changed := active.duplicate(true)
	changed["departure"]["starting_loadout"]["facilities"]["veteran_hall"] = 0
	check(CampaignState.validate(changed) != "", "tampered active departure cannot remove or change tiers")
	check(controller.load_campaign()["ok"] and controller.resume_spec() == spec, "resume preserves exact committed loadout")
	check(controller.settle(_result(spec, "failure"))["ok"] and controller.acknowledge_result()["ok"], "failure returns to existing retry flow")
	var retry := controller.depart()
	check(retry["ok"] and retry["spec"]["starting_loadout"]["facilities"] == spec["starting_loadout"]["facilities"], "retry keeps tiers without charging again")
	controller.free()
	var legacy := _new_controller("legacy-active")
	var old_spec := _depart(legacy)
	var old := legacy.snapshot()
	old.erase("facilities")
	old.erase("facility_goal")
	old["departure"]["starting_loadout"].erase("facilities")
	check(not old_spec.is_empty() and CampaignState.validate(old) == "", "pre-facility active departure still validates and resumes with zero tiers")
	legacy.free()

func _seed_budgets() -> void:
	var total := 0
	for id: String in CampaignFacilities.ORDER:
		for tier in [1, 2]: total += int(CampaignFacilities.upgrade(id, tier)["cost"])
	for seed_value in range(1, 201):
		var budget: int = CampaignState.fresh("battlemage", seed_value, {})["gold"]
		for biome in 3:
			var graph := CampaignCatalog.route(seed_value, biome)
			for depth in [1, 2, 3, 4]:
				var floor_gold := 1000000
				for node: Dictionary in graph["nodes"].values():
					if node["depth"] == depth: floor_gold = mini(floor_gold, CampaignCatalog.CONTRACTS[node["contract"]]["gold"] * (biome + 1))
				budget += floor_gold
		check(budget >= total, "every sampled route seed permits all tiers from ordinary clear gold without needing optional content")


func _success_and_progress() -> void:
	var controller := _new_controller("progress", 200)
	check(controller.buy_facility("workshop", 1)["ok"], "success fixture owns shelf tier")
	check(controller.pin_facility("workshop", 2)["ok"], "expensive next tier goal pins")
	var spec := _depart(controller)
	if spec.is_empty():
		controller.free()
		return
	var tiers := CampaignFacilities.levels(controller.state)
	var stock: Array = controller.state["shop"].duplicate(true)
	var generation: int = controller.state["shop_generation"]
	var bank: int = controller.state["gold"]
	var node: Dictionary = controller.state["graph"]["nodes"][spec["node_id"]]
	var expected := CampaignFacilities.contract_gold(controller.state, node)
	var result := _result(spec, "success")
	result["elapsed"] = float(spec["duration"])
	result["objectives"] = {"seals": 3, "elite_dead": true, "boss_dead": true}
	result["inventory"] = CampaignState.combat_inventory(controller.state)
	var response := controller.settle(result)
	check(response["ok"], "normal clear settles through existing authority")
	check(controller.state["gold"] == bank + expected, "funding goal projection agrees with actual contract payout without optional rewards")
	check(controller.state["shop_generation"] == generation + 1 and controller.state["shop"].size() == 8 and controller.state["shop"] != stock, "success refreshes original offers plus exactly two shelf offers")
	check(controller.state["facility_goal"] == {"id": "workshop", "tier": 2} and CampaignFacilities.levels(controller.state) == tiers, "clear retains exact next-tier goal and owned investments")
	var saved := controller.snapshot()
	check(controller.settle(result) == response and controller.state == saved, "settlement receipt cannot refresh workshop or fund a goal twice")
	check(controller.acknowledge_result()["ok"], "next town entered normally")
	check(controller.buy_facility("workshop", 2)["ok"] and controller.state["facility_goal"].is_empty(), "clear funding permits goal purchase and clears only purchased goal")
	controller.free()

func _views() -> void:
	CampaignTown.walk_mode = 1
	var controller := _new_controller("views", 300)
	check(controller.pin_facility("workshop", 1)["ok"], "UI goal saved")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	town._open_station("market")
	await process_frame
	var pin := town.find_child("PinFacility_workshop", true, false) as Button
	var buy := town.find_child("BuyFacility_workshop", true, false) as Button
	check(pin != null and pin.text == "Unpin town goal" and buy != null and not buy.disabled, "real existing Market exposes matching goal and affordable purchase")
	if buy != null: buy.pressed.emit()
	await process_frame
	check(controller.state["facilities"]["workshop"] == 1 and controller.state["gold"] == 210, "real UI purchase routes to same transactional command")
	check(controller.buy_facility("wayfinder", 1)["ok"] and controller.buy_facility("wayfinder", 2)["ok"], "scouting tiers bought for view test")
	var state := controller.snapshot()
	var view := CampaignRouteView.new()
	root.add_child(view)
	view.present(state, controller.available_routes())
	var scouted := CampaignFacilities.scouted_nodes(state, controller.available_routes())
	check(not scouted.is_empty(), "scouting reaches connected successors")
	var future: String = scouted.keys()[0]
	for id: String in scouted:
		if not str(state["graph"]["nodes"][id]["event"]).is_empty(): future = id; break
	# Attach a known event to this disposable presentation snapshot if the seed
	# has none in scout range, so the hidden-data assertion is discriminating.
	if str(state["graph"]["nodes"][future]["event"]).is_empty():
		state["graph"]["nodes"][future]["event"] = CampaignCatalog.EVENTS.keys()[0]
	view.present(state, controller.available_routes())
	check(not str(view._nodes[future]["event"]).is_empty(), "scouting fixture actually contains hidden event detail")
	view._preview(future)
	check(view._details.text.contains("WAYFINDER SCOUTING") and view._confirm.disabled, "partial scouting discloses information, never unlocks choosing future road")
	check(not view._details.text.contains("Event:") and not view._details.text.contains("prize reserved"), "partial scouting protects Ash Map event/equipment detail")
	state["graph"]["nodes"][future]["revealed"] = true
	view.present(state, controller.available_routes())
	view._preview(future)
	check(view._details.text.contains("CLEAR REWARDS"), "saved Ash Map still supplies full prize details")
	check(view._details.text.contains("Event:"), "full reveal exposes the event that partial scouting withheld")
	view.hide() # Isolated route-view probe must not overlay actual town captures.
	var baseline := controller.snapshot()
	for i in 5: town._walk.present(baseline)
	var dressing: Node3D = town._walk._facility_dressing
	check(is_instance_valid(dressing) and dressing.get_child_count() == 2, "upgraded station dressing is bounded and stable across repeated presentations")
	check(controller.snapshot() == baseline, "views never mutate saved tiers, offers or reveal flags")
	check(controller.pin_facility("veteran_hall", 1)["ok"], "next goal switches without cost")
	town._select_service("route")
	await process_frame
	var route_view: Array = town._content.get_children().filter(func(node: Node) -> bool: return node is CampaignRouteView and not node.is_queued_for_deletion())
	check(not route_view.is_empty(), "existing Route service still presents its map")
	var funding := CampaignFacilities.funding_copy(controller.state, controller.available_routes()[0])
	check(funding.contains("TOWN GOAL") and funding.contains("excludes optional rewards/shards"), "funding projection discloses its denominator/exclusions")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("facility-route-720.png"))
		town._select_service("market")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("facility-market-720.png"))
		town._close_panel()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("facility-town-720.png"))
		var rich := controller.snapshot()
		rich["gold"] = 2000
		check(controller._commit(rich)["ok"], "native tier-two fixture has disposable funding")
		check(controller.buy_facility("workshop", 2)["ok"], "native Workshop tier two comes from real command")
		check(controller.buy_facility("veteran_hall", 1)["ok"] and controller.buy_facility("veteran_hall", 2)["ok"], "native Veteran Hall tiers come from real command")
		town._close_panel()
		for station: Dictionary in CampaignWalkTown.STATIONS:
			if station["id"] not in ["route", "market", "roster"]: continue
			var at: Vector3 = station["at"]
			town._walk._hero_pos = Vector2(at.x, at.z)
			town._walk._place_hero(0)
			town._walk._update_near(false)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("facility-tier2-%s-720.png" % station["id"]))
	view.free()
	town.free()
	controller.free()
