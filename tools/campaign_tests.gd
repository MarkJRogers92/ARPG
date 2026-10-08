extends SceneTree
## Campaign observables and durable failure probes. All paths are disposable.
var checks := 0
var failures := 0
var controller: CampaignController
var test_root := "user://campaign-test-%d" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func _run() -> void:
	CampaignSave.path = test_root + ".save"
	MetaProgress.save_path = test_root + ".meta"
	MetaProgress.disabled = false
	MetaProgress.load_save()
	controller = CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 71001)["ok"], "new campaign commits")
	check(CampaignState.validate(controller.state) == "", "new campaign validates")
	check(controller.state["gold"] == 60 and controller.state["talents"]["earned"] == 3, "starting resources")
	check(controller.state["inventory"]["equipped"].size() == 6, "six exact starting slots")
	_test_routes()
	_test_transactions()
	_test_attempts()
	_test_outbox()
	_test_reforge()
	_test_overflow()
	_test_wager_pledge()
	_test_completion()
	_test_events()
	_test_clauses()
	_test_recovery()
	_test_validation()
	CampaignSave.fail_stage = ""
	MetaProgress.campaign_fail_save = false
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.previous", ".save.rollback", ".meta", ".meta.bak", ".meta.tmp", ".meta.rollback"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_root + suffix))
	# Atomic crash probes may preserve a prior recovery under a unique name.
	# Remove only this invocation's exact test prefix, never legacy saves.
	var directory := DirAccess.open("user://")
	if directory:
		for file_name: String in directory.get_files():
			if file_name.begins_with(test_root.get_file()): directory.remove(file_name)
	controller.free()
	print("CAMPAIGN TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)

func _test_routes() -> void:
	for seed_value in 100:
		for biome in 3:
			var state := CampaignState.fresh("battlemage", seed_value, {"mods": [], "relic": "", "start_weapon": "", "rerolls": 0, "cards": {}})
			state["biome_index"] = biome
			state["graph"] = CampaignCatalog.route(seed_value, biome)
			check(CampaignState.validate(state) == "", "all generated nodes reach exactly three depths and boss")
			check(state["graph"] == CampaignCatalog.route(seed_value, biome), "route generation deterministic")

func _test_transactions() -> void:
	var first: Dictionary = controller.state["shop"][0]
	check(controller.buy_item(first["id"], "purchase-once")["ok"], "buy finite stock")
	var gold: int = controller.state["gold"]
	check(controller.buy_item(first["id"], "purchase-once")["ok"] and controller.state["gold"] == gold, "same purchase receipt replays without payment")
	check(not controller.buy_item(first["id"])["ok"], "same stock cannot pay again with new receipt")
	check(not controller.sell_items([first["id"]], false, "purchase-once")["ok"], "receipt cannot change command")
	check(controller.mark_item(first["id"], true, false)["ok"], "lock gear")
	check(not controller.sell_items([first["id"]])["ok"], "locked gear protected")
	check(controller.mark_item(first["id"], false, true)["ok"], "explicit junk")
	check(controller.sell_items([first["id"]], true)["ok"], "sell marked junk")
	check(controller.state["gold"] == gold + first["price"] / 4, "authoritative sale valuation")
	var before := controller.snapshot()
	CampaignSave.fail_stage = "write"
	check(not controller.choose_route(controller.available_routes()[0]["id"])["ok"], "injected route write failure")
	check(controller.state == before, "failed transaction leaves committed state")
	CampaignSave.fail_stage = ""

func choose() -> Dictionary:
	if controller.state["selected_node"] == "":
		var response := controller.choose_route(controller.available_routes()[0]["id"])
		check(response["ok"], "route committed")
	if controller.state["phase"] == "EVENT_PENDING":
		var id: String = controller.state["event"]["id"]
		var choice := "leave"
		if id == "ash_map" or id == "loaded_passage": choice = "gold"
		check(controller.resolve_event(choice)["ok"], "safe event always resolves")
	return controller.depart()

func result_for(spec: Dictionary, outcome := "success") -> Dictionary:
	return {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"], "outcome": outcome,
		"elapsed": spec["duration"], "objectives": {"seals": 3, "elite_dead": true, "boss_dead": true},
		"inventory": spec["starting_loadout"]["inventory"].duplicate(true), "loose_shards": 999,
		"kills_by": {"Campaign Test Grunt": 3}, "veteran": {}, "report": {"test": true}}

func finish(spec: Dictionary) -> void:
	check(controller.settle(result_for(spec))["ok"], "valid contract clears")
	check(controller.acknowledge_result()["ok"], "result acknowledgment only changes presentation")
	if controller.state["wager"].get("status", "") in ["open", "won"]: check(controller.take_wager()["ok"], "claim reserved budgeted reward")

func _test_attempts() -> void:
	var spec: Dictionary = choose().get("spec", {})
	check(not spec.is_empty(), "departure saved before mission")
	check(controller.resume_spec() == spec, "interruption restores exact same departure")
	check(not controller.depart()["ok"], "active attempt cannot be replaced by new departure")
	var stock: Array = controller.state["shop"].duplicate(true)
	var gold: int = controller.state["gold"]
	var failed := result_for(spec, "failure")
	check(controller.settle(failed)["ok"], "failed attempt settles")
	check(not controller.depart()["ok"], "pending result blocks departure until acknowledgment")
	check(controller.state["gold"] == gold and controller.state["shop"] == stock, "failure cannot pay or refresh stock")
	check(controller.settle(failed)["ok"], "duplicate failed callback no effect")
	check(controller.acknowledge_result()["ok"], "failure returns to committed route")
	var retry: Dictionary = controller.depart()["spec"]
	check(retry["attempt_id"] != spec["attempt_id"] and retry["mission_seed"] == spec["mission_seed"], "fresh retry identity preserves node seed")
	check(not controller.settle(result_for(spec))["ok"], "stale success rejected after retry")
	CampaignSave.fail_stage = "replace"
	var active := controller.snapshot()
	check(not controller.settle(result_for(retry))["ok"] and controller.state == active, "failed result persistence leaves frozen active departure")
	CampaignSave.fail_stage = ""
	var account_before := MetaProgress.shards
	finish(retry)
	check(MetaProgress.shards == account_before + 5, "one short-clear account award")
	var banked := controller.snapshot()
	check(controller.settle(result_for(retry))["ok"] and controller.state == banked, "duplicate successful callback exact once")
	check(controller.state["talents"]["earned"] == 4, "one new-node talent")

func _test_outbox() -> void:
	var spec: Dictionary = choose()["spec"]
	MetaProgress.campaign_fail_save = true
	var profile_before := MetaProgress.shards
	check(controller.settle(result_for(spec))["ok"], "settlement commits despite profile unavailable")
	check(controller.state["outbox"].size() == 1 and MetaProgress.shards == profile_before, "durable pending profile outbox")
	var old_id: String = controller.state["campaign_id"]
	check(not controller.create("battlemage", 555)["ok"] and controller.state["campaign_id"] == old_id, "replacement blocked by earned pending receipt")
	check(not controller.abandon()["ok"], "abandon cannot lose pending account receipt")
	MetaProgress.campaign_fail_save = false
	var pending := controller.snapshot()
	check(controller.deliver_outbox()["ok"] and MetaProgress.shards == profile_before + 5, "profile reward delivery retries")
	var receipt: Dictionary = pending["outbox"][0]
	check(MetaProgress.apply_campaign_receipt(receipt) and MetaProgress.shards == profile_before + 5, "profile receipt replay exact once")
	# Simulate crash after durable awarded primary moved aside for a new write.
	var profile_path := ProjectSettings.globalize_path(MetaProgress.save_path)
	var rollback_path := ProjectSettings.globalize_path(MetaProgress.save_path + ".rollback")
	DirAccess.remove_absolute(rollback_path)
	check(DirAccess.rename_absolute(profile_path, rollback_path) == OK, "profile crash-window fixture")
	MetaProgress.load_save()
	check(MetaProgress.shards == profile_before + 5 and MetaProgress.campaign_receipts.has(receipt["id"]), "profile recovery retains award and receipt together")
	check(MetaProgress.apply_campaign_receipt(receipt) and MetaProgress.shards == profile_before + 5, "recovered receipt cannot award twice")
	MetaProgress.save()
	check(controller.acknowledge_result()["ok"], "ack successful result")
	check(controller.take_wager()["ok"], "claim second prize")

func _test_reforge() -> void:
	var item_id: String = controller.state["inventory"]["equipped"]["weapon"]
	var old: Dictionary = controller.state["inventory"]["items"][item_id].duplicate(true)
	var gold: int = controller.state["gold"]
	check(controller.reforge_item(item_id, "reforge-once")["ok"], "reforge alternative commits")
	var pending := controller.snapshot()
	check(controller.load_campaign()["ok"] and controller.state == pending, "reforge alternative survives reload")
	check(controller.resolve_reforge(false)["ok"], "keep old roll")
	check(controller.state["inventory"]["items"][item_id]["data"] == old["data"] and controller.state["gold"] == gold - 60, "old roll retains identity and consumes fee")
	check(not controller.reforge_item(item_id)["ok"], "reforge use persists when old kept")

func _test_overflow() -> void:
	var next := controller.snapshot()
	var rng := CampaignCatalog.stream(7, "overflow-fixture")
	while next["inventory"]["backpack"].size() < 24:
		var record := controller._item(next, 3, ItemData.Rarity.MAGIC, "ring", rng)
		controller._store(next, record)
	check(controller._commit(next)["ok"], "full-backpack fixture commits")
	var spec: Dictionary = choose()["spec"]
	finish(spec)
	check(controller.state["inventory"]["tray"].size() == 1, "reserved reward survives overflow")
	var id: String = controller.state["inventory"]["tray"][0]
	check(not controller.claim_item(id)["ok"], "full bag cannot claim duplicate")
	var item_id: String = controller.state["inventory"]["backpack"][0]
	check(controller.sell_items([item_id])["ok"], "free space with explicit sale")
	check(controller.claim_item(id, "claim-once")["ok"] and controller.claim_item(id, "claim-once")["ok"], "claim receipt moves exactly one copy")
	check(controller.state["inventory"]["tray"].is_empty(), "tray emptied once")
	check(not controller.claim_item(id)["ok"], "new claim cannot recreate copy")

func _test_wager_pledge() -> void:
	# Fresh campaign avoids the full bag and establishes a genuine veteran candidate.
	check(controller.create("battlemage", 71002)["ok"], "replace campaign after outbox delivery")
	var spec: Dictionary = choose()["spec"]
	var result := result_for(spec)
	result["veteran"] = {"name": "Sable", "swarm": "Grunts", "role": "brawler", "rank": 3, "deeds": 1000}
	check(controller.settle(result)["ok"] and controller.acknowledge_result()["ok"], "candidate earned after success")
	var id: String = controller.state["veteran_candidate"]["id"]
	check(controller.recruit_veteran(id)["ok"], "recruit stable campaign veteran")
	check(controller.wager(true, "wager-once")["ok"], "pledge commits before presentation")
	var bet: Dictionary = controller.state["wager"].duplicate(true)
	check(controller.load_campaign()["ok"] and controller.state["wager"] == bet, "committed wager outcome survives reload")
	check(controller.wager(true, "wager-once")["ok"] and controller.state["wager"] == bet, "coin replay cannot reroll or pay")
	if bet["status"] == "won": check(controller.take_wager()["ok"], "take won prize")
	check(controller.state["roster"][0]["pledge_node"] == "next", "veteran unavailable until future node")
	var spec2: Dictionary = choose()["spec"]
	check(spec2["starting_loadout"]["veteran"].is_empty(), "pledged veteran not deployed")
	check(controller.state["roster"][0]["pledge_node"] == spec2["node_id"], "pledge binds to committed next node")
	check(controller.settle(result_for(spec2, "retreat"))["ok"] and controller.acknowledge_result()["ok"], "retreat returns town")
	check(controller.state["roster"][0]["pledge_node"] == spec2["node_id"], "retreat cannot free pledged veteran")
	finish(controller.depart()["spec"])
	check(controller.state["roster"][0]["pledge_node"] == "", "successful target releases pledge")

func _test_completion() -> void:
	check(controller.create("battlemage", 91001)["ok"], "new completion campaign")
	var short_count := 0
	var boss_count := 0
	while not controller.state["completed"]:
		var spec: Dictionary = choose()["spec"]
		if spec["final_boss"]:
			boss_count += 1
			var early := result_for(spec)
			early["elapsed"] = 899.9
			check(not controller.settle(early)["ok"], "finale never wins before actual 900 seconds")
			var alive := result_for(spec)
			alive["objectives"]["boss_dead"] = false
			check(not controller.settle(alive)["ok"], "finale must kill actual boss")
		else: short_count += 1
		finish(spec)
	check(short_count == 9 and boss_count == 3, "exactly three short nodes per each of three biomes")
	check(controller.state["talents"]["earned"] == 18, "finite campaign talent budget")
	check(controller.state["phase"] == "CAMPAIGN_COMPLETE" and controller.available_routes().is_empty(), "real campaign complete phase")
	check(MetaProgress.campaign_completions.size() == 1, "one account completion record")

func _test_recovery() -> void:
	var valid := controller.snapshot()
	var file := FileAccess.open(CampaignSave.path + ".previous", FileAccess.WRITE)
	file.store_var(valid)
	file.close()
	file = FileAccess.open(CampaignSave.path, FileAccess.WRITE)
	file.store_string("corrupt primary")
	file.close()
	check(CampaignSave.read() == valid, "valid previous recovers corrupt primary")
	CampaignSave.fail_stage = "replace"
	var changed := valid.duplicate(true)
	changed["revision"] += 1
	check(not CampaignSave.write(changed), "replacement failure injected with corrupt primary")
	check(CampaignSave.read() == valid, "last valid previous survives failed replacement")
	CampaignSave.fail_stage = ""
	check(CampaignSave.write(valid), "valid recovery recommits")

func _test_validation() -> void:
	var bad := controller.snapshot()
	bad["inventory"]["items"][bad["inventory"]["equipped"]["weapon"]] = 1
	check(CampaignState.validate(bad) != "", "malformed nested inventory rejected")
	bad = controller.snapshot()
	bad["profile_snapshot"]["mods"] = [7]
	check(CampaignState.validate(bad) != "", "malformed profile modifiers rejected")
	bad = controller.snapshot()
	bad["talents"]["earned"] = 19
	check(CampaignState.validate(bad) != "", "oversized talents rejected")
	bad = controller.snapshot()
	bad["departure"]["effects"] = [7]
	check(CampaignState.validate(bad) != "", "malformed saved departure effect rejected")
	bad = controller.snapshot()
	bad["departure"]["starting_loadout"]["veteran"] = {"id": "x", "rank": "bad"}
	check(CampaignState.validate(bad) != "", "malformed saved departure veteran rejected")
	bad = controller.snapshot()
	bad["receipts"]["invalid"] = {"signature": 0, "response": 0}
	check(CampaignState.validate(bad) != "", "malformed operation receipt rejected")
	bad = controller.snapshot()
	bad["departure"]["starting_loadout"]["talents"]["allocated"] = [SkillData.ROOT]
	check(CampaignState.validate(bad) != "", "malformed departure talent allocation rejected")


func _event_fixture(event_id: String) -> void:
	check(controller.create("battlemage", 40000 + hash(event_id))["ok"], "event fixture creates")
	if event_id == "inventory":
		check(controller.buy_item(controller.state["shop"][0]["id"])["ok"], "trade input bought as finite copy")
	var next := controller.snapshot()
	var id: String = next["graph"]["start"][0]
	next["graph"]["nodes"][id]["event"] = event_id
	check(controller._commit(next)["ok"] and controller.choose_route(id)["ok"], "authored event committed on combat node")
	var event: Dictionary = controller.state["event"].duplicate(true)
	check(controller.load_campaign()["ok"] and controller.state["event"] == event, "event offers and facts do not reroll on reload")

func _test_events() -> void:
	for event_id: String in CampaignCatalog.EVENTS:
		_event_fixture(event_id)
		var gold: int = controller.state["gold"]
		var event: Dictionary = controller.state["event"].duplicate(true)
		var choice := "leave"
		var selection := {}
		match event_id:
			"toll": choice = "pay"
			"ash_map": choice = "reveal"
			"coffins": choice = "weapon"
			"inventory":
				choice = "trade"
				selection["item_id"] = controller.state["inventory"]["backpack"][0]
			"quiet_bell", "unfinished": choice = "accept"
			"loaded_passage": choice = "odds"
			"honest_ferryman": choice = "view"
		check(controller.resolve_event(choice, "authored-event-once", selection)["ok"], "authored event choice resolves")
		var resolved := controller.snapshot()
		check(controller.resolve_event(choice, "authored-event-once", selection)["ok"] and controller.state == resolved, "event choice receipt exact once")
		match event_id:
			"toll":
				check(controller.state["gold"] == gold - 30 and controller.state["inventory"]["items"].has(event["offers"]["prize"]["id"]), "toll charges campaign Gold for shown copy")
			"ash_map":
				for id: String in controller.state["graph"]["nodes"][controller.state["selected_node"]]["next"]:
					check(controller.state["graph"]["nodes"][id].get("revealed", false), "ash map reveals saved future route details")
			"coffins":
				check(controller.state["inventory"]["items"].has(event["offers"]["weapon"]["id"]), "coffin grants exact committed roll")
			"inventory":
				var old_id: String = selection["item_id"]
				check(not controller.state["inventory"]["items"].has(old_id) and controller.state["inventory"]["items"].has(event["offers"][old_id]["id"]), "trade replaces one exact copy with stored offer")
			"quiet_bell":
				var spec: Dictionary = controller.depart()["spec"]
				check(spec["effects"].size() == 1 and spec["effects"][0]["mods"].size() == 2, "quiet bell stat boon explicitly scoped")
				check(controller.settle(result_for(spec, "failure"))["ok"] and controller.acknowledge_result()["ok"], "boon attempt failure")
				check(controller.state["effects"].size() == 1, "quiet bell survives failure until target success")
				var retry: Dictionary = controller.depart()["spec"]
				check(controller.settle(result_for(retry))["ok"], "quiet bell target clears")
				check(controller.state["result"]["gold"] == CampaignCatalog.CONTRACTS[retry["contract_id"]]["gold"] - 30 and controller.state["effects"].is_empty(), "quiet bell costs once on successful target")
			"loaded_passage":
				var spec: Dictionary = controller.depart()["spec"]
				check(controller.settle(result_for(spec))["ok"] and controller.acknowledge_result()["ok"], "loaded passage reaches town wager")
				check(is_equal_approx(controller.state["wager"]["chance"], 0.75), "odds preview includes explicit five points")
				check(controller.wager()["ok"] and controller.state["effects"].is_empty(), "committed first wager consumes odds once")
			"unfinished":
				var spec: Dictionary = controller.depart()["spec"]
				check(spec["effects"][0].get("specialist", false), "extra encounter is in immutable mission spec")
				check(controller.settle(result_for(spec))["ok"] and controller.state["result"]["items"].size() == 1, "unfinished reward delivered by successful settlement")

func _test_clauses() -> void:
	check(controller.create("battlemage", 91234)["ok"], "Ledger fixture creates")
	var gold: int = controller.state["gold"]
	check(controller.accept_clause("advance_payment", "weapon", 0, "advance-once")["ok"], "advance payment accepted")
	check(controller.state["gold"] == gold + 100, "advance pays bounded biome amount")
	check(controller.accept_clause("advance_payment", "weapon", 0, "advance-once")["ok"] and controller.state["gold"] == gold + 100, "same clause receipt cannot pay again")
	check(not controller.accept_clause("advance_payment")["ok"], "same clause cannot repeat with another receipt")
	check(controller.accept_clause("borrowed_battalion")["ok"], "borrowed battalion accepted")
	check(not controller.accept_clause("stolen_arsenal")["ok"] and controller.state["clauses"].size() == 2, "two-clause budget blocks third")
	var spec: Dictionary = choose()["spec"]
	check(spec["clauses"].size() == 2 and spec["effects"][0]["minions"] == 3, "clauses and node minions are immutable departure rules")
	check(controller.settle(result_for(spec, "failure"))["ok"] and controller.acknowledge_result()["ok"], "Ledger attempt fails")
	var retry: Dictionary = controller.depart()["spec"]
	check(retry["clauses"] == spec["clauses"] and retry["effects"] == spec["effects"], "failure retains clauses and reapplies exactly three minions")
	finish(retry)
	check(controller.state["effects"].is_empty() and controller.state["clauses"].size() == 2, "short success expires node boon and preserves boss debt")
	while controller.state["biome_index"] == 0:
		finish(choose()["spec"])
	check(controller.state["clauses"].is_empty(), "actual finale settlement clears biome Ledger")
	var offers := controller.clause_offers("ring")
	check(offers.size() == 3 and controller.load_campaign()["ok"] and controller.clause_offers("ring") == offers, "targeted Arsenal shows three persistent choices")
	check(controller.accept_clause("stolen_arsenal", "ring", 1)["ok"] and controller.state["inventory"]["items"].has(offers[1]["id"]), "arsenal grants only selected exact Rare")
