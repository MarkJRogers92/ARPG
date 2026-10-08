extends SceneTree
## Parent-integrated acceptance harness for the expedition scene lifecycle.
## Run only after UI and combat changes have been integrated into this checkout:
## godot --headless --path /Users/markrogers/ARPG -s <this-file>
## All persistence is redirected to unique disposable paths. MetaProgress is
## disabled so no profile load or write can touch a player's existing save.

var checks := 0
var failures := 0
var shell: CampaignShell
var previous_result := {}
var stale_failure_result := {}
var test_root := "user://campaign_lifecycle_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	CampaignSave.path = test_root + ".save"
	MetaProgress.save_path = test_root + ".meta"
	MetaProgress.disabled = true
	MetaProgress.load_save()
	var seed_controller := CampaignController.new()
	root.add_child(seed_controller)
	check(seed_controller.create("battlemage", Time.get_ticks_usec())["ok"], "isolated campaign checkpoint created")
	var seeded := seed_controller.state.duplicate(true)
	seeded["profile_snapshot"]["mods"] = [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.25}]
	seeded["profile_snapshot"]["relic"] = "cinder_heart"
	seeded["profile_snapshot"]["start_weapon"] = "aura"
	check(seed_controller._commit(seeded)["ok"], "test account snapshot includes a stat, relic power, and starting weapon")
	seed_controller.free()
	Realm.in_title = true
	Realm.daily = false
	root.add_child(load("res://scenes/campaign.tscn").instantiate())
	shell = root.get_child(root.get_child_count() - 1) as CampaignShell
	await process_frame
	check(shell.controller != null and shell.controller.state.get("phase", "") == "TOWN", "real campaign shell loads into town")
	check(_is_town(shell.get("_view")), "town view mounted by campaign shell")
	if shell.controller == null or shell.controller.state.is_empty():
		_finish()
		return

	# Give the first departure a persistent skill allocation and specialization
	# when the content tree exposes a valid starting choice. The assertions below
	# compare saved snapshot facts across multiple fresh Main instances.
	var controller := shell.controller
	if SkillData.NODES.has("o1"):
		var allocation := controller.allocate_talent("o1", "life-talent")
		if allocation.get("ok", false):
			check(controller.state["talents"]["allocated"].has("o1"), "campaign talent remains banked in town")
	var gear_before: Dictionary = controller.state["inventory"]["equipped"].duplicate(true)
	var backpack_before: Array = controller.state["inventory"]["backpack"].duplicate(true)
	var talents_before: Array = controller.state["talents"]["allocated"].duplicate(true)
	var specialization_before: String = controller.state["specialization"]
	var snapshot_before: Dictionary = controller.state["profile_snapshot"].duplicate(true)
	var observed_attempts: Array[String] = []
	var combat_instances: Array[WeakRef] = []
	var cycles := 0
	var retry_spec := _depart(controller, true)
	if retry_spec.is_empty():
		check(false, "first attempt can be committed before failure and retry")
	else:
		observed_attempts.append(String(retry_spec["attempt_id"]))
		shell.call("_mount_combat", retry_spec)
		await process_frame
		var failed_main: Node = shell.get("_view")
		var failed_army: Army = failed_main.get("_army")
		check(failed_main.get("_army").veterans().is_empty(), "borrowed battalion fixture starts without a veteran")
		check(failed_army.count == 3, "borrowed battalion adds three minions without a veteran; actual=%d" % failed_army.count)
		var failed_expedition: ExpeditionDirector = failed_main.get("_expedition")
		failed_expedition.result = {"campaign_id": retry_spec["campaign_id"], "node_id": retry_spec["node_id"],
			"attempt_id": retry_spec["attempt_id"], "outcome": "failure", "elapsed": 1.0, "objectives": {}}
		var failed_hud: Hud = failed_main.get("_hud")
		failed_hud.set_prompt("test failure prompt", Color.WHITE)
		failed_main.get("_player").dead = true
		check(failed_hud._prompt_label.visible, "visible interaction prompt is seeded before the failure result")
		failed_main.call("_finish_expedition_frame")
		check(not failed_hud._prompt_label.visible, "death result clears the interaction prompt during the return ritual")
		stale_failure_result = failed_main.get("_expedition_result").duplicate(true)
		failed_main.call("_emit_expedition_result")
		await process_frame
		await process_frame
		check(controller.state["phase"] == "RESULT_PENDING" and controller.state["result"]["outcome"] == "failure",
			"real Main failure result returns to town without a success payout")
		var failed_node: String = retry_spec["node_id"]
		check(controller.acknowledge_result()["ok"], "failed attempt result can be acknowledged")
		check(controller.state["selected_node"] == failed_node, "failed attempt keeps the same route node committed")
		var veteran := controller._veteran_record({"name": "QA Veteran", "swarm": "Grunts", "role": "brawler", "rank": 1, "deeds": 0}, "campaign-lifecycle:qa-veteran")
		var veteran_state := controller.state.duplicate(true)
		veteran_state["roster"] = [veteran]
		veteran_state["deployed_veteran"] = veteran["id"]
		check(controller._commit(veteran_state)["ok"], "veteran-equipped campaign fixture commits to disposable save")
		var retry := controller.depart()
		check(retry["ok"], "failed route can be retried")
		retry_spec = retry["spec"]
		check(retry_spec["node_id"] == failed_node and retry_spec["mission_seed"] == controller.state["graph"]["nodes"][failed_node]["seed"],
			"retry keeps the saved node and mission seed")
		check(retry_spec["attempt_id"] != observed_attempts[-1], "retry receives a fresh attempt identity")
		check(not controller.settle(stale_failure_result)["ok"], "old failure callback cannot settle the fresh retry")
		check(Elements.player == null, "failed combat teardown clears static combat bindings")
	while cycles < 3:
		var spec: Dictionary = retry_spec if cycles == 0 else _depart(controller)
		if spec.is_empty():
			check(false, "controller creates a new departure for another lifecycle cycle")
			break
		if not observed_attempts.has(String(spec["attempt_id"])):
			observed_attempts.append(String(spec["attempt_id"]))
		check(spec["starting_loadout"]["inventory"]["equipped"].keys().size() == gear_before.size(), "departure carries equipped campaign loadout")
		check(spec["starting_loadout"]["talents"]["allocated"] == talents_before, "departure carries banked campaign talents")
		check(spec["starting_loadout"]["specialization"] == specialization_before, "departure carries banked specialization")
		check(spec["starting_loadout"]["profile_snapshot"] == snapshot_before, "departure preserves captured account snapshot")
		if not previous_result.is_empty():
			check(not controller.settle(previous_result)["ok"], "result from an earlier attempt is rejected during the fresh departure")
		var starting_preview: Dictionary = CampaignLoadout.preview(controller.snapshot())

		shell.call("_mount_combat", spec)
		await process_frame
		var combat: Node = shell.get("_view")
		check(combat != null and combat.get("_campaign") == true, "shell mounts a real campaign Main scene")
		if combat == null:
			break
		combat_instances.append(weakref(combat))
		if cycles == 0:
			var army: Army = combat.get("_army")
			check(army.veterans().size() == 1, "retry loads the deployed campaign veteran")
			check(army.count - army.veterans().size() == 3,
				"borrowed battalion adds three more minions beside a deployed veteran; total=%d veterans=%d" % [army.count, army.veterans().size()])
		var player: Player = combat.get("_player")
		check(is_instance_valid(player), "combat Main constructs a fresh player")
		if is_instance_valid(player):
			_check_starting_preview_matches_player(starting_preview, player, cycles)
		check(Elements.player == player, "combat scene binds its player to global combat helpers")
		check(String(combat.get("_hero_class")) == String(spec["starting_loadout"]["hero_class"]), "combat uses departure hero class")
		check(combat.get("_player").inventory.equipped.keys().size() == gear_before.size(), "combat player receives saved equipped gear")
		check(Elements.has_power("ember_ring"), "campaign combat applies the captured relic power")
		check(player.stats.values["damage"] > 1.24, "campaign combat applies captured account stat modifiers")
		check(player.stats.aura_level > 0.0, "campaign combat applies captured starting weapon")
		if talents_before.has("o1"):
			check(player.skills.is_allocated("o1"), "combat skill tree receives the saved campaign allocation")
		if specialization_before != "":
			check(player.stats._mods.any(func(mod: Dictionary) -> bool: return mod["source"] == "spec"),
				"combat stats receive the saved class specialization modifiers")

		if cycles == 0:
			var skill_screen: SkillTreeScreen = combat.get("_skill_screen")
			var skill_before := player.skills.to_dict().duplicate(true)
			var stats_before := player.stats._mods.duplicate(true)
			skill_screen.open()
			check(skill_screen.read_only and skill_screen._reset_button.disabled, "campaign combat talents are inspectable with reset disabled")
			check(skill_screen._details.text.contains("town Trainer"), "campaign inspection explains where talents can change")
			for id: String in SkillData.ids():
				if player.skills.can_allocate(id):
					skill_screen._on_node_pressed(id)
					break
			if not talents_before.is_empty():
				var refund := InputEventMouseButton.new()
				refund.button_index = MOUSE_BUTTON_RIGHT
				refund.pressed = true
				skill_screen._on_node_input(refund, talents_before[0])
				skill_screen._on_node_pressed(talents_before[0])
			skill_screen._on_reset_pressed()
			check(player.skills.to_dict() == skill_before and player.stats._mods == stats_before,
				"campaign inspection rejects allocate, refund and reset without changing combat stats")
			check(controller.state["talents"]["allocated"] == talents_before, "inspection preserves the banked talent build")
			skill_screen.close()

		# Accelerated boundary fixture: produce a valid Main result at its contract
		# threshold without simulating mission pacing or changing Engine.time_scale.
		# Parent owns the separate real-frame contract/finale acceptance runs.
		var expedition: ExpeditionDirector = combat.get("_expedition")
		var result_objectives := {"seals": 3, "elite_dead": true, "cache_claimed": true, "boss_dead": true}
		expedition.result = {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
			"outcome": "success", "elapsed": float(spec["duration"]), "objectives": result_objectives}
		combat.get("_director").elapsed = float(spec["duration"])
		var combat_hud: Hud = combat.get("_hud")
		combat_hud.set_prompt("test success prompt", Color.WHITE)
		check(combat_hud._prompt_label.visible, "visible interaction prompt is seeded before the success result")
		combat.call("_finish_expedition_frame")
		check(not combat_hud._prompt_label.visible, "success result clears the interaction prompt during the return ritual")
		previous_result = combat.get("_expedition_result").duplicate(true)
		var report: Dictionary = previous_result.get("report", {})
		check(report.get("died") == false and report.get("objectives") == result_objectives,
			"campaign result report includes survival state and a copy of settled objectives")
		check(report.get("damage_taken_by") is Dictionary and report.get("last_cause") is String,
			"campaign result report includes serializable damage causes and last cause")
		combat.call("_emit_expedition_result")
		await process_frame
		await process_frame
		check(_is_town(shell.get("_view")), "Main result settles through controller and returns to town")
		check(controller.state["phase"] == "RESULT_PENDING", "result commit remains pending until presentation acknowledgment")
		if controller.state["phase"] == "RESULT_PENDING":
			check(controller.acknowledge_result()["ok"], "town acknowledges the already-settled expedition")
		check(Elements.player == null, "combat teardown clears static player binding")
		check(not paused and is_equal_approx(Engine.time_scale, 1.0), "town return restores unpaused normal-speed game")
		check(controller.state["inventory"]["equipped"] == gear_before, "successful cycle retains equipped copy identities")
		for banked_id in backpack_before:
			check(controller.state["inventory"]["items"].has(banked_id), "successful cycle retains each pre-existing backpack copy")
		check(controller.state["talents"]["allocated"] == talents_before, "successful cycle retains allocated talents")
		check(controller.state["specialization"] == specialization_before, "successful cycle retains specialization")
		check(controller.state["profile_snapshot"] == snapshot_before, "successful cycle retains captured profile snapshot")
		cycles += 1
		if cycles == 1:
			var paths: Array = Specializations.paths(controller.state["hero_class"])
			if not paths.is_empty():
				var chosen_path: String = paths[0]["id"]
				var specialization := controller.choose_specialization(chosen_path, "life-specialization")
				check(specialization["ok"], "first successful expedition unlocks class specialization")
				specialization_before = controller.state["specialization"]

	check(observed_attempts.size() == cycles + 1, "failure and retry each receive a unique active attempt")
	var unique_attempts := {}
	for attempt_id in observed_attempts:
		unique_attempts[attempt_id] = true
	check(unique_attempts.size() == observed_attempts.size(), "repeat departures use fresh attempt identities")
	for ref in combat_instances:
		check(ref.get_ref() == null, "previous Main scene is freed before the next combat scene")

	if controller.state.get("phase", "") == "TOWN":
		var weapon_id: String = controller.state["inventory"]["equipped"]["weapon"]
		check(not controller.discard_item(weapon_id)["ok"], "equipped campaign gear cannot be discarded")
		check(controller.unequip_item("weapon")["ok"], "banked campaign gear can be unequipped")
		check(controller.equip_item(weapon_id)["ok"], "same banked gear copy can be re-equipped")
		check(controller.state["inventory"]["equipped"]["weapon"] == weapon_id, "re-equipping preserves the stable gear identity")

	if controller.state.get("phase", "") == "TOWN":
		var interrupted := _depart(controller)
		check(not interrupted.is_empty(), "interruption fixture commits its departure before mounting combat")
		if not interrupted.is_empty():
			shell.call("_mount_combat", interrupted)
			await process_frame
			var main: Node = shell.get("_view")
			var outgoing_player: WeakRef = weakref(main.get("_player"))
			var attempt_id := String(interrupted["attempt_id"])
			main.call("_on_pause_save_and_quit")
			await process_frame
			check(controller.state["phase"] == "EXPEDITION_ACTIVE", "save-and-quit preserves active departure checkpoint")
			var resumed := controller.resume_spec()
			check(resumed == interrupted and resumed["attempt_id"] == attempt_id, "interrupted departure reloads with the same attempt identity")
			check(shell.get("_view") == null, "save-and-quit exits combat through shell teardown")
			check(outgoing_player.get_ref() == null, "save-and-quit frees the outgoing combat player")
			check(Elements.player == null or Elements.player != outgoing_player.get_ref(), "save-and-quit removes the stale combat player binding")
			check(not paused and is_equal_approx(Engine.time_scale, 1.0), "save-and-quit restores normal time state")
			var reload := CampaignController.new()
			root.add_child(reload)
			check(reload.load_campaign()["ok"] and reload.resume_spec() == interrupted, "fresh controller reloads the committed departure checkpoint")
			reload.free()

	# Verify equipped-copy guards while in town. Unequip/re-equip must preserve the
	# same copy identity, and an equipped copy cannot be discarded.
	if controller.state.get("phase", "") == "TOWN":
		var weapon_id: String = controller.state["inventory"]["equipped"]["weapon"]
		check(not controller.discard_item(weapon_id)["ok"], "equipped campaign gear cannot be discarded")
		check(controller.unequip_item("weapon")["ok"], "banked campaign gear can be unequipped")
		check(controller.equip_item(weapon_id)["ok"], "same banked gear copy can be re-equipped")
		check(controller.state["inventory"]["equipped"]["weapon"] == weapon_id, "re-equipping preserves the stable gear identity")

	_finish()

func _depart(controller: CampaignController, add_battalion := false) -> Dictionary:
	if controller.state.get("wager", {}).get("status", "") in ["open", "won"]:
		if not controller.take_wager().get("ok", false): return {}
	if not controller.state.get("veteran_candidate", {}).is_empty():
		if not controller.decline_veteran().get("ok", false): return {}
	var routes: Array = controller.available_routes()
	if routes.is_empty():
		return {}
	var route: Dictionary = routes[0]
	if route.get("contract", "") == "finale" and routes.size() > 1:
		for candidate: Dictionary in routes:
			if candidate.get("contract", "") != "finale":
				route = candidate
				break
	var chosen := controller.choose_route(String(route["id"]))
	if not chosen.get("ok", false):
		return {}
	if controller.state["phase"] == "EVENT_PENDING":
		var event: Dictionary = controller.state["event"]
		var choice := "leave"
		if event.get("id", "") == "ash_map" or event.get("id", "") == "loaded_passage":
			choice = "gold"
		if not controller.resolve_event(choice).get("ok", false):
			return {}
	if add_battalion and not controller.accept_clause("borrowed_battalion").get("ok", false):
		return {}
	var departure := controller.depart()
	return departure.get("spec", {}) if departure.get("ok", false) else {}

func _check_starting_preview_matches_player(preview: Dictionary, player: Player, cycle: int) -> void:
	var stats: PlayerStats = player.stats
	check(preview.has("max_hp") and is_equal_approx(float(preview.get("max_hp", -1.0)), stats.max_hp),
		"cycle %d preview max health matches mounted combat" % cycle)
	check(preview.has("armor") and is_equal_approx(float(preview.get("armor", -1.0)), stats.armor),
		"cycle %d preview armor matches mounted combat" % cycle)
	check(preview.has("move_speed") and is_equal_approx(float(preview.get("move_speed", -1.0)), stats.move_speed),
		"cycle %d preview movement speed matches mounted combat" % cycle)
	check(preview.has("crit_chance") and is_equal_approx(float(preview.get("crit_chance", -1.0)), stats.crit_chance),
		"cycle %d preview critical chance matches mounted combat" % cycle)
	check(preview.has("minion_max") and int(preview.get("minion_max", -1)) == stats.minion_max,
		"cycle %d preview army capacity matches mounted combat" % cycle)
	var is_reaper := String(player.get_parent().get("_hero_class")) == "reaper" and stats.powers.has("reaping") and stats.scythe_level > 0
	var primary_damage := stats.scythe_damage if is_reaper else stats.bolt_damage
	var primary_cooldown := stats.scythe_cooldown if is_reaper else stats.bolt_cooldown
	check(preview.has("primary_damage") and is_equal_approx(float(preview.get("primary_damage", -1.0)), primary_damage),
		"cycle %d preview primary attack damage matches mounted combat" % cycle)
	check(preview.has("primary_cooldown") and is_equal_approx(float(preview.get("primary_cooldown", -1.0)), primary_cooldown),
		"cycle %d preview primary attack cooldown matches mounted combat" % cycle)

func _is_town(view: Node) -> bool:
	return is_instance_valid(view) and view.get_script() != null and String(view.get_script().resource_path).ends_with("campaign_town.gd")

func _finish() -> void:
	paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(shell):
		shell.free()
	Elements.reset()
	Obstacles.clear()
	Juice.reset()
	CampaignSave.fail_stage = ""
	MetaProgress.disabled = false
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.previous", ".save.rollback", ".meta", ".meta.bak", ".meta.tmp", ".meta.previous", ".meta.rollback"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_root + suffix))
	print("CAMPAIGN LIFECYCLE %s (%d checks, %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
