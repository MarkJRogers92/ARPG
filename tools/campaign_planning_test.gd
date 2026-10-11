extends SceneTree
## New planning choices through the existing campaign authority and receipts.
var checks := 0
var failures := 0
var prefix := "user://planning-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var controllers: Array[CampaignController] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _controller(label: String, stars := 0) -> CampaignController:
	CampaignSave.path = prefix + "-" + label + ".save"
	MetaProgress.bestiary = {"Goal Fixture": MetaProgress.BESTIARY_STEPS[stars - 1]} if stars > 0 else {}
	MetaProgress._loaded = true
	var controller := CampaignController.new()
	root.add_child(controller)
	controllers.append(controller)
	check(controller.create("battlemage", 58103)["ok"], "new planning campaign")
	var next := controller.snapshot()
	next["gold"] = 2000
	check(controller._commit(next)["ok"], "funded fixture")
	return controller

func _choose(controller: CampaignController, contract := "hunt") -> void:
	var next := controller.snapshot()
	var id: String = controller.available_routes()[0]["id"]
	var node: Dictionary = next["graph"]["nodes"][id]
	node["contract"] = contract
	node["elite"] = false
	node["event"] = ""
	node["commission"] = CampaignPlanning.COMMISSIONS.get(contract, "")
	node["reward_theme"] = CampaignCatalog.reward_theme(contract)
	check(controller._commit(next)["ok"], "authored fixture route")
	check(controller.choose_route(id)["ok"], "route commitment")

func _result(spec: Dictionary, outcome := "success", claimed := true) -> Dictionary:
	return {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"], "outcome": outcome, "elapsed": spec["duration"],
		"objectives": {"seals": 3, "elite_dead": true, "boss_dead": true, "commission_claimed": claimed and spec.get("commission", "") != "", "trial_damage": {"Soul Army": 100.0, "Stormstride": 30.0, "Reactions": 100.0}, "trial_dashes": 8},
		"inventory": spec["starting_loadout"]["inventory"].duplicate(true), "loose_shards": 0, "kills_by": {}, "veteran": {}, "report": {}}

func _clear(controller: CampaignController, spec: Dictionary) -> void:
	check(controller.settle(_result(spec))["ok"], "success settles")
	check(controller.acknowledge_result()["ok"], "acknowledge result")
	if controller.state["wager"].get("status", "") in ["open", "won"]: check(controller.take_wager()["ok"], "claim reserved prize without gambling")

func _run() -> void:
	MetaProgress.disabled = true
	MetaProgress._loaded = true
	_test_preparation()
	_test_survey()
	_test_town_credits()
	_test_fatigue()
	_test_trials()
	_test_legacy_and_validation()
	_test_profile_receipt()
	CampaignSave.fail_stage = ""
	MetaProgress.campaign_fail_save = false
	MetaProgress.disabled = true
	for controller in controllers: controller.free()
	var directory := DirAccess.open("user://")
	for name: String in directory.get_files():
		if name.begins_with(prefix.get_file()): directory.remove(name)
	print("CAMPAIGN PLANNING %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)

func _test_preparation() -> void:
	var c := _controller("preparation")
	check(not c.state["fatigue_enabled"], "fatigue is optional and defaults off")
	var before := c.snapshot()
	CampaignSave.fail_stage = "write"
	check(not c.buy_preparation("recovery", "recover-kit")["ok"] and c.state == before, "failed preparation save cannot spend or pack")
	CampaignSave.fail_stage = ""
	check(c.buy_preparation("recovery", "recover-kit")["ok"], "paid one slot")
	var paid := c.snapshot()
	check(paid["gold"] == 1970 and paid["preparation"] == "recovery", "copy and actual spending agree")
	check(c.buy_preparation("recovery", "recover-kit")["ok"] and c.state == paid, "preparation command replay no duplicate payment")
	check(not c.buy_preparation("recruits")["ok"], "cannot silently replace paid slot")
	_choose(c)
	var spec: Dictionary = c.depart("prep-depart")["spec"]
	check(spec["preparation"] == "recovery" and c.state["preparation"] == "", "depart consumes and freezes kit")
	check(c.resume_spec() == spec and c.depart("prep-depart")["spec"] == spec, "resume and operation replay keep exact kit")
	check(not c.buy_preparation("recruits")["ok"], "active combat cannot buy a second kit")
	var active := c.snapshot()
	CampaignSave.fail_stage = "replace"
	check(not c.settle(_result(spec, "failure"))["ok"] and c.state == active, "terminal save failure preserves exact active spec")
	CampaignSave.fail_stage = ""
	check(c.settle(_result(spec, "failure"))["ok"], "failed attempt settles")
	check(c.state["town_benefits"].is_empty(), "failure cannot award service credit")
	check(c.acknowledge_result()["ok"], "failed result acknowledged")
	var retry: Dictionary = c.depart()["spec"]
	check(retry["preparation"] == "" and retry["contract_prize"] == spec["contract_prize"] and retry["opportunity_roll"] == spec["opportunity_roll"], "retry consumes kit but cannot reroll committed gear")
	check(retry["attempt_id"] != spec["attempt_id"], "retry fresh identity")

func _test_survey() -> void:
	var c := _controller("survey")
	check(not c.buy_preparation("survey")["ok"], "survey requires a committed hidden successor")
	_choose(c)
	var target := CampaignPlanning.survey_target(c.state)
	check(target != "", "survey has useful connected road")
	check(c.buy_preparation("survey")["ok"] and c.state["gold"] == 1985, "survey price honest")
	var spec: Dictionary = c.depart()["spec"]
	check(c.state["graph"]["nodes"][target]["revealed"], "one target revealed on departure")
	check(target in c.state["graph"]["nodes"][spec["node_id"]]["next"], "survey is connected not arbitrary global road")
	check(c.settle(_result(spec, "failure"))["ok"] and c.state["graph"]["nodes"][target]["revealed"], "survey knowledge persists failure")

func _test_town_credits() -> void:
	for contract: String in CampaignPlanning.COMMISSIONS:
		var c := _controller("credits-" + contract)
		_choose(c, contract)
		var spec: Dictionary = c.depart()["spec"]
		_clear(c, spec)
		var benefit: String = CampaignPlanning.COMMISSIONS[contract]
		check(c.state["town_benefits"].has(benefit) and c.state["town_benefits"][benefit]["expires"] == "departure", "claimed successful detour grants one expiring service")
		var settled := c.snapshot()
		check(c.settle(_result(spec))["ok"] and c.state == settled, "duplicate result cannot refresh or add credit")
		var before := c.snapshot()
		CampaignSave.fail_stage = "write"
		var entry: Dictionary = c.state["shop"][1]
		if benefit == "supplier":
			check(not c.buy_item(entry["id"], "credit-use")["ok"] and c.state == before, "failed supplier use rolls back")
		elif benefit == "tools":
			check(not c.reforge_item(c.state["inventory"]["equipped"]["weapon"], "credit-use")["ok"] and c.state == before, "failed tools use rolls back")
		else: check(not c.buy_preparation("recruits", "credit-use")["ok"] and c.state == before, "failed voucher use rolls back")
		CampaignSave.fail_stage = ""
		if benefit == "supplier":
			var cost := CampaignPlanning.market_cost(c.state, entry["price"])
			check(c.buy_item(entry["id"], "credit-use")["ok"] and c.state["gold"] == before["gold"] - cost, "supplier discount agrees with spending")
		elif benefit == "tools":
			check(c.reforge_item(c.state["inventory"]["equipped"]["weapon"], "credit-use")["ok"] and c.state["gold"] == before["gold"], "tools grant a free reforge")
			check(c.resolve_reforge(false)["ok"], "normal reforge usage remains consumed")
		else: check(c.buy_preparation("recruits", "credit-use")["ok"] and c.state["gold"] == before["gold"], "voucher one free preparation")
		check(not c.state["town_benefits"].has(benefit), "service consumption removes benefit")
		# Add another legitimate test credit and leave it unused.
		var next := c.snapshot()
		next["town_benefits"][benefit] = {"node_id": spec["node_id"], "expires": "departure"}
		check(c._commit(next)["ok"], "unused-credit fixture")
		_choose(c)
		check(c.depart()["ok"] and c.state["town_benefits"].is_empty(), "unused service expires on next departure")
	var skipped := _controller("skipped-detour")
	_choose(skipped)
	var skipped_spec: Dictionary = skipped.depart()["spec"]
	check(skipped.settle(_result(skipped_spec, "success", false))["ok"] and skipped.state["town_benefits"].is_empty(), "skipping detour retains base clear but no free town service")

func _test_fatigue() -> void:
	var c := _controller("fatigue")
	var next := c.snapshot()
	var base := {"name": "Echo", "swarm": "Grunts", "label": "Ghoul", "role": "brawler", "rank": 3, "deeds": 12, "elite": 0, "nights": 1}
	next["roster"] = [c._veteran_record(base, "one"), c._veteran_record(base, "two")]
	next["roster"][1]["fatigue"] = 1
	next["deployed_veteran"] = "one"
	check(c._commit(next)["ok"] and c.set_fatigue(true, "fatigue-on")["ok"], "enable light fatigue explicitly")
	_choose(c)
	var spec: Dictionary = c.depart()["spec"]
	check(spec["starting_loadout"]["veteran"]["rank"] == 1, "veteran biome rank cap retained")
	_clear(c, spec)
	check(c.state["roster"][0]["fatigue"] == 1 and c.state["roster"][1]["fatigue"] == 0, "only successful clear advances deployed/idle fatigue")
	var settled := c.snapshot()
	check(c.settle(_result(spec))["ok"] and c.state == settled, "duplicate clear cannot tick fatigue")
	_choose(c)
	var second: Dictionary = c.depart()["spec"]
	check(c.settle(_result(second, "failure"))["ok"], "fatigue failure fixture")
	check(c.state["roster"][0]["fatigue"] == 1, "failure never ticks fatigue")
	check(c.acknowledge_result()["ok"], "ack failure")
	var third: Dictionary = c.depart()["spec"]
	_clear(c, third)
	check(c.state["roster"][0]["fatigue"] == 2 and not CampaignPlanning.available(c.state, c.state["roster"][0]), "second deployed clear rests veteran")
	check(not c.choose_veteran("one")["ok"], "cannot select resting veteran")
	var before := c.snapshot()
	CampaignSave.fail_stage = "write"
	check(not c.recover_veteran("one", "recovery-once")["ok"] and c.state == before, "recovery charge save failure rolls back")
	CampaignSave.fail_stage = ""
	check(c.recover_veteran("one", "recovery-once")["ok"] and c.state["gold"] == before["gold"] - 20, "recovery cost and immediate availability")
	var recovered := c.snapshot()
	check(c.recover_veteran("one", "recovery-once")["ok"] and c.state == recovered, "recovery receipt exact once")
	var fallback := c.snapshot()
	for veteran: Dictionary in fallback["roster"]: veteran["fatigue"] = 2
	check(c._commit(fallback)["ok"], "all-resting fixture")
	_choose(c)
	var ordinary: Dictionary = c.depart()["spec"]
	check(ordinary["starting_loadout"]["veteran"].is_empty(), "all resting never prevents departure with ordinary army")

func _test_trials() -> void:
	for id: String in TacticTrials.DEFS:
		var c := _controller(id, 3)
		var relic_id: String = TacticTrials.DEFS[id]["relic"]
		MetaProgress.relics.erase(relic_id)
		_choose(c, id)
		if id == "trial_reaction": check(not c.buy_preparation("recruits")["ok"], "cannot pay for an unusable trial preparation")
		var spec: Dictionary = c.depart()["spec"]
		check(CampaignState.validate_spec(spec) == "" and spec["duration"] == 180.0 and spec["deadline"] == 240.0, "trial uses authoritative short clock")
		var result := _result(spec)
		check(CampaignCatalog.valid_success(spec, result), "boundary trial goal counts")
		result["objectives"]["trial_damage"] = {}
		check(not CampaignCatalog.valid_success(spec, result), "cannot clear missing measured goal")
		result = _result(spec)
		result["elapsed"] = 179.99
		check(not CampaignCatalog.valid_success(spec, result), "minimum survival time enforced")
		result["elapsed"] = 240.1 # Beyond the existing 0.05 s serialization tolerance.
		check(not CampaignCatalog.valid_success(spec, result), "deadline authoritative")
		_clear(c, spec)
		check(MetaProgress.relics.get(relic_id, false) and c.state["result"]["choice_unlock"].contains(Relics.data(relic_id)["name"]), "trial completion earns an account choice through receipt")
		check(MetaProgress.relic == "", "choice reward never auto-equips or changes frozen kit")
		var prize: Dictionary = c.state["inventory"]["items"][spec["contract_prize"]["id"]]
		check(prize == spec["contract_prize"], "trial reward exact committed copy")
	for stars in 4:
		var unlocked := NextGoals.available_trials(stars)
		for seed_value in 50:
			var graph := CampaignCatalog.route(seed_value, 0, unlocked)
			for node: Dictionary in graph["nodes"].values():
				check(not TacticTrials.DEFS.has(node["contract"]) or node["contract"] in unlocked, "locked trials cannot leak to roads")

func _test_legacy_and_validation() -> void:
	var c := _controller("legacy")
	_choose(c)
	var spec: Dictionary = c.depart()["spec"]
	var legacy := c.snapshot()
	for key: String in CampaignPlanning.fresh(): legacy.erase(key)
	for key in ["preparation", "commission", "contract_prize", "opportunity_roll"]: legacy["departure"].erase(key)
	legacy["graph"]["nodes"][spec["node_id"]].erase("committed_prize")
	legacy["graph"]["nodes"][spec["node_id"]].erase("opportunity_roll")
	check(CampaignState.validate(legacy) == "" and c._commit(legacy)["ok"], "additive old active departure remains valid")
	var bytes := FileAccess.get_file_as_bytes(CampaignSave.path)
	check(c.load_campaign()["ok"] and FileAccess.get_file_as_bytes(CampaignSave.path) == bytes, "load-only legacy does not rewrite bytes")
	var old_result := _result(c.resume_spec(), "failure")
	check(c.settle(old_result)["ok"] and c.state.has("preparation") and not c.state["fatigue_enabled"], "legacy failure materializes safe defaults")
	var invalid := spec.duplicate(true)
	invalid["opportunity_roll"] = 9
	check(CampaignState.validate_spec(invalid) != "", "scalar opportunity rejected safely")
	invalid = spec.duplicate(true)
	invalid["preparation"] = "unknown"
	check(CampaignState.validate_spec(invalid) != "", "unknown preparation rejected")
	var bad := c.snapshot()
	bad["roster"] = [{"fatigue": 99}]
	check(CampaignState.validate(bad) != "", "corrupt veteran rejected")

func _test_profile_receipt() -> void:
	MetaProgress.save_path = prefix + ".meta"
	MetaProgress.disabled = false
	MetaProgress.realms = {"graveyard": {"endless": 123.0}}
	MetaProgress.campaign_receipts = {}
	MetaProgress.relics = {}
	MetaProgress.weapons = {}
	var receipt := {"id": "goal-receipt", "shards": 5, "kills": {"Ghoul": 100}, "realm_won": "graveyard", "unlock_relic": "blade_compass", "completed": false}
	var before := MetaProgress.realms.duplicate(true)
	MetaProgress.campaign_fail_save = true
	check(not MetaProgress.apply_campaign_receipt(receipt) and MetaProgress.realms == before and not MetaProgress.relics.has("blade_compass"), "failed account write cannot publish realm or choice unlock")
	MetaProgress.campaign_fail_save = false
	check(MetaProgress.apply_campaign_receipt(receipt) and MetaProgress.is_won("graveyard") and MetaProgress.endless_best("graveyard") == 123.0, "campaign guardian wins realm without dropping endless record")
	var shards := MetaProgress.shards
	MetaProgress.load_save()
	check(MetaProgress.is_won("graveyard") and MetaProgress.apply_campaign_receipt(receipt) and MetaProgress.shards == shards, "realm goal and exact-once reward persist reload")
	check(MetaProgress.relic_owned("blade_compass") and MetaProgress.total_stars() < Relics.DEFS["blade_compass"]["stars"], "trial relic persists below the alternative star threshold")
	check(not MetaProgress.package_owned("wake"), "trial receipt cannot bypass starting weapon ownership")
	MetaProgress.weapons["orbit"] = true
	check(MetaProgress.pick_package("wake") and MetaProgress.relic == "blade_compass" and MetaProgress.start_weapon == "orbit", "trial-owned package is selectable below the alternative star threshold")
	MetaProgress.load_save()
	check(MetaProgress.package_owned("wake") and MetaProgress.relic == "blade_compass" and MetaProgress.start_weapon == "orbit", "trial-owned package selection persists reload")
	check(NextGoals.choice_rows()[0]["owned"], "existing authoritative star evaluator unlocks choices")
