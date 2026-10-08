extends "res://tools/campaign_combat_bot.gd"
## Natural full-campaign acceptance run. Unlike campaign_combat_bot's finale
## fixture, every settlement here comes from Main's live result signal.
##
## godot --headless --path . --fixed-fps 60 -s tools/campaign_journey_bot.gd -- [seed]

const HERO_CLASS := "necromancer"
const MAX_ATTEMPTS_PER_NODE := 3
const STALL_LIMIT_SECONDS := 60.0

var _journey_result := {}
var _journey_running := false
var _journey_failed := false
var _journey_attempt := 0
var _journey_successes := 0
var _journey_biomes := 0
var _journey_town_reload_done := false
var _journey_initial_success_count := 0
var _leg_deadline_msec := 0
var _journey_attempt_ids: Array[String] = []
var _journey_seen_receipts: Array[String] = []
var _run_id := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _seed = int(args[0])
	_hero_class = HERO_CLASS
	_policy = "tank"
	_full_profile = true
	_max_seconds = 90.0 * 60.0
	seed(_seed)
	_wall_deadline_msec = Time.get_ticks_msec() + int(_max_seconds * 2000.0 + 120000.0)
	_setup_journey()


func _setup_journey() -> void:
	var unique := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_run_id = unique
	_campaign_path = "user://campaign_journey_%s.save" % unique
	_profile_path = "user://campaign_journey_profile_%s.save" % unique
	CampaignSave.path = _campaign_path
	MetaProgress.save_path = _profile_path
	MetaProgress.disabled = false
	MetaProgress.load_save()
	# Full-profile is a disposable test account fixture; no live profile is read.
	MetaProgress.classes[HERO_CLASS] = true
	MetaProgress.hero_class = HERO_CLASS
	MetaProgress.shards = 100000
	for id: String in MetaProgress.UPGRADES:
		MetaProgress.ranks[id] = int(MetaProgress.UPGRADES[id]["max"])
	for id: String in Upgrades.DEFS:
		if Upgrades.DEFS[id].has("unlock"): MetaProgress.cards[id] = true
	for id: String in Relics.DEFS: MetaProgress.relics[id] = true
	MetaProgress.relic = "iron_heart"
	for kind in ["Grunts", "Runners", "Brutes", "Chargers"]: MetaProgress.bestiary[kind] = 5000
	_controller = CampaignController.new()
	_controller.name = "NaturalCampaignJourneyController"
	root.add_child(_controller)
	var created := _controller.create(HERO_CLASS, _seed)
	if not created.get("ok", false):
		_fail("campaign creation failed: " + String(created.get("error", "")))
		return
	_allocate_campaign_build()
	_journey_initial_success_count = _controller.state["successful_nodes"].size()
	print("JOURNEY_START seed=%d class=%s fixture=full-profile path=%s" % [_seed, HERO_CLASS, _campaign_path])
	_run_journey.call_deferred()


func _run_journey() -> void:
	while not _journey_failed and not _controller.state["completed"]:
		if not await _town_transaction(): break
		var attempt_result := await _play_selected_node()
		if _journey_failed: break
		if attempt_result.is_empty():
			_fail("expedition yielded no terminal Main result")
			break
		var settled := _controller.settle(attempt_result)
		if not settled.get("ok", false):
			_fail("live result rejected by campaign settlement: " + String(settled.get("error", "")))
			break
		var outcome := String(attempt_result.get("outcome", ""))
		print("JOURNEY_SETTLED node=%s attempt=%s outcome=%s elapsed=%.2f summary=%s" % [
			attempt_result.get("node_id", ""), attempt_result.get("attempt_id", ""), outcome,
			float(attempt_result.get("elapsed", 0.0)), str(_controller.state["result"])])
		if outcome == "success":
			_journey_successes += 1
			if bool(_controller.state["result"].get("biome_complete", false)): _journey_biomes += 1
		var ack := _controller.acknowledge_result()
		if not ack.get("ok", false):
			_fail("result acknowledgment failed: " + String(ack.get("error", "")))
			break
		if outcome != "success":
			_journey_attempt += 1
			if _journey_attempt >= MAX_ATTEMPTS_PER_NODE:
				_fail("same committed mission reached maximum %d attempts" % MAX_ATTEMPTS_PER_NODE)
				break
			print("JOURNEY_RETRY node=%s retry=%d" % [_controller.state["selected_node"], _journey_attempt + 1])
		else:
			_journey_attempt = 0
	if not _journey_failed:
		_validate_final_campaign()
		_finish_journey()


func _town_transaction() -> bool:
	# Checkpoint reload proves a saved town state can be resumed without rerolls.
	if not _journey_town_reload_done and _journey_successes >= 4:
		var before := _controller.state.duplicate(true)
		var loaded := _controller.load_campaign()
		if not loaded.get("ok", false) or _controller.state != before:
			_fail("town checkpoint reload did not preserve the exact campaign state")
			return false
		_journey_town_reload_done = true
		print("JOURNEY_CHECKPOINT_RELOAD successes=%d" % _journey_successes)
	# Claim every tray item first, creating space only if needed.
	for item_id: String in _controller.state["inventory"]["tray"].duplicate():
		var claimed := _controller.claim_item(item_id)
		if not claimed.get("ok", false):
			_make_bag_space()
			claimed = _controller.claim_item(item_id)
		if not claimed.get("ok", false):
			_fail("could not claim reward %s: %s" % [item_id, claimed.get("error", "")])
			return false
	# Retain the campaign's real build and invest every earned point.
	_allocate_campaign_build()
	# Keep or decline actual veteran candidates through the campaign API.
	if not _controller.state["veteran_candidate"].is_empty():
		var candidate: Dictionary = _controller.state["veteran_candidate"]
		var replace_id := ""
		if _controller.state["roster"].size() >= 3:
			replace_id = String(_controller.state["roster"][0]["id"])
		var recruited := _controller.recruit_veteran(String(candidate["id"]), replace_id)
		if not recruited.get("ok", false): _controller.decline_veteran()
	if not _controller.state["roster"].is_empty():
		var deployed := String(_controller.state["deployed_veteran"])
		if deployed == "": deployed = String(_controller.state["roster"][0]["id"])
		_controller.choose_veteran(deployed)
	if _controller.state["wager"].get("status", "") in ["open", "won"]:
		_controller.take_wager()
	# Buy one actual affordable upgrade when town offers it and capacity permits.
	if _controller.state["inventory"]["backpack"].size() < Inventory.BACKPACK_SIZE:
		for stock: Dictionary in _controller.state["shop"]:
			if int(stock.get("price", 999999)) <= int(_controller.state["gold"]):
				var bought := _controller.buy_item(String(stock["id"]))
				if bought.get("ok", false):
					var record: Dictionary = bought.get("payload", {})
					if _is_upgrade(record):
						var equipped := _controller.equip_item(String(record["id"]))
						print("JOURNEY_SHOP bought=%s equipped=%s" % [record.get("id", ""), equipped.get("ok", false)])
				break
	if _controller.state["selected_node"] == "":
		var routes: Array = _controller.available_routes()
		if routes.is_empty():
			_fail("no next connected campaign route is available")
			return false
		var route: Dictionary = routes[0]
		var chosen := _controller.choose_route(String(route["id"]))
		if not chosen.get("ok", false):
			_fail("could not commit connected route: " + String(chosen.get("error", "")))
			return false
	if _controller.state["phase"] == "EVENT_PENDING":
		var event: Dictionary = _controller.state["event"]
		var choice := String(EVENT_SAFE_CHOICE.get(String(event.get("id", "")), "leave"))
		var resolved := _controller.resolve_event(choice)
		if not resolved.get("ok", false):
			_fail("real town event resolution failed: " + String(resolved.get("error", "")))
			return false
	# Taking a wager can put its prize in the reward tray after the initial
	# claim pass. Drain all rewards after wager and event resolution as well.
	for item_id: String in _controller.state["inventory"]["tray"].duplicate():
		var claimed := _controller.claim_item(item_id)
		if not claimed.get("ok", false):
			_make_bag_space()
			claimed = _controller.claim_item(item_id)
		if not claimed.get("ok", false):
			_fail("could not claim post-wager/event reward %s: %s" % [item_id, claimed.get("error", "")])
			return false
	# Sell marked unlocked junk only when a full bag blocks claiming/departure.
	if _controller.state["inventory"]["backpack"].size() >= Inventory.BACKPACK_SIZE:
		_make_bag_space()
	return true


func _play_selected_node() -> Dictionary:
	var departure := _controller.depart()
	if not departure.get("ok", false):
		_fail("real departure rejected: " + String(departure.get("error", "")))
		return {}
	var spec: Dictionary = departure["spec"]
	_contract = String(spec["contract_id"])
	_biome = String(spec["biome_id"])
	_journey_attempt_ids.append(String(spec["attempt_id"]))
	if _biome == "ember" and spec["contract_id"] == "finale": _preserve_final_ember_checkpoint()
	var starting: Dictionary = spec["starting_loadout"]
	if starting["hero_class"] != HERO_CLASS or starting["talents"] != _controller.state["talents"] or starting["specialization"] != _controller.state["specialization"]:
		_fail("departure snapshot lost selected class, talents, or specialization")
		return {}
	if spec["effects"] != _effects_for_node(String(spec["node_id"])):
		_fail("departure snapshot has incorrect node-scoped temporary effects")
	var chosen := String(_controller.state["deployed_veteran"])
	print("JOURNEY_DEPART biome=%s node=%s contract=%s depth=%d seed=%d attempt=%s effects=%s veteran=%s" % [
		spec["biome_id"], spec["node_id"], spec["contract_id"], int(_controller.state["graph"]["nodes"][spec["node_id"]]["depth"]),
		int(spec["mission_seed"]), spec["attempt_id"], str(spec["effects"]), chosen])
	_main = load("res://scenes/main.tscn").instantiate()
	_main.expedition_spec = spec.duplicate(true)
	_journey_result = {}
	_journey_running = true
	_release_interact = false
	_next_interact = 0.0
	_next_pickup_scan_frame = _frame
	_pickup_target = Vector2.INF
	_next_gear = 1.0
	_next_report = 60.0
	_items = 0
	_dash_count = 0
	_observed_final_arrival_at = -1.0
	_observed_initial_final_seals = -1
	_observed_advance_payment_at = -1.0
	_observed_stolen_arsenal_at = -1.0
	_observed_borrowed_reinforcement_times.clear()
	_observed_reinforcement_count = 0
	_leg_deadline_msec = Time.get_ticks_msec() + int((float(spec["duration"]) + 180.0) * 1000.0)
	_main.expedition_finished.connect(_on_journey_result)
	root.add_child(_main)
	await process_frame
	if not _check_fresh_departure(spec): return {}
	var start_elapsed := float(_main.elapsed)
	var stable_seconds := 0.0
	while _journey_result.is_empty() and not _journey_failed:
		await process_frame
		if Time.get_ticks_msec() >= _leg_deadline_msec:
			_fail("per-mission watchdog expired for %s" % spec["node_id"])
			break
		if not is_instance_valid(_main):
			_fail("Main disappeared before emitting a terminal result")
			break
		if float(_main.elapsed) > start_elapsed + 1.0:
			start_elapsed = float(_main.elapsed)
			stable_seconds = 0.0
		else:
			stable_seconds += 1.0 / 60.0
		if stable_seconds >= STALL_LIMIT_SECONDS:
			_fail("expedition elapsed time stalled for 60 fixed-frame simulation seconds")
			break
		# Existing bot methods perform real frame input. The journey runner has no
		# clock, damage, health, inventory, or outcome shortcuts.
		if is_instance_valid(_player):
			_sample_campaign_telemetry()
			_steer_and_interact()
			if _main._hud._upgrade_root.visible: _pick_upgrade()
			if _main.elapsed >= _next_gear:
				_next_gear = _main.elapsed + 1.0
				_player.inventory.equip_upgrades()
			if _main.elapsed >= _next_report:
				_next_report += 60.0
				_report("JOURNEY")
	if _journey_failed: return {}
	var actual := _journey_result.duplicate(true)
	_journey_running = false
	# Synchronous teardown guarantees no campaign actors or global bindings leak
	# into the next Main scene.
	var player_ref: WeakRef = weakref(_player)
	root.remove_child(_main)
	_main.free()
	_main = null
	_player = null
	_director = null
	_swarms.clear()
	await process_frame
	if player_ref.get_ref() != null or Elements.player != null:
		_fail("scene teardown retained player/global actor before next mission")
		return {}
	if actual.get("campaign_id") != spec["campaign_id"] or actual.get("node_id") != spec["node_id"] or actual.get("attempt_id") != spec["attempt_id"]:
		_fail("Main emitted a stale or mismatched attempt result")
		return {}
	return actual


func _on_journey_result(result: Dictionary) -> void:
	_journey_result = result.duplicate(true)


func _check_fresh_departure(spec: Dictionary) -> bool:
	_player = _main.get_node_or_null("Player") as Player
	_director = _main.get_node_or_null("ExpeditionDirector") as ExpeditionDirector
	if _player == null or _director == null:
		_fail("Main did not mount Player and ExpeditionDirector")
		return false
	_swarms.clear()
	for node in get_nodes_in_group(EnemySwarm.GROUP):
		if node is EnemySwarm: _swarms.append(node)
	# add_child(_main) advances one fixed frame before the harness resumes.
	var valid: bool = _player.stats.level == 1 and _main.elapsed <= (1.0 / 60.0) + 0.001 and _main._director.elapsed <= (1.0 / 60.0) + 0.001
	valid = valid and _player.stats.xp == 0
	if not valid:
		_fail("fresh Main departure did not reset level/time/xp (level=%d time=%.3f xp=%d)" % [
			_player.stats.level, _main.elapsed, _player.stats.xp])
		return false
	print("JOURNEY_FRESH_MAIN level=%d elapsed=%.3f xp=%d" % [_player.stats.level, _main.elapsed, _player.stats.xp])
	return true


func _effects_for_node(node_id: String) -> Array:
	var out := []
	for effect: Dictionary in _controller.state["effects"]:
		if effect.get("node_id", "") == node_id: out.append(effect.duplicate(true))
	return out


func _is_upgrade(record: Dictionary) -> bool:
	if record.is_empty(): return false
	var data: Dictionary = record.get("data", {})
	var slot := String(data.get("slot", ""))
	var equipped_id := String(_controller.state["inventory"]["equipped"].get(slot, ""))
	if equipped_id == "": return true
	var current: Dictionary = _controller.state["inventory"]["items"].get(equipped_id, {})
	return int(data.get("ilvl", 0)) > int(current.get("data", {}).get("ilvl", 0)) or int(data.get("rarity", 0)) > int(current.get("data", {}).get("rarity", 0))


func _make_bag_space() -> void:
	var inventory: Dictionary = _controller.state["inventory"]
	var candidates: Array[String] = []
	for item_id: String in inventory["backpack"]:
		var record: Dictionary = inventory["items"].get(item_id, {})
		if not record.is_empty() and not record.get("locked", false) and not record.get("junk", false):
			_controller.mark_item(item_id, false, true)
			candidates.append(item_id)
			break
	if not candidates.is_empty():
		_controller.sell_items(candidates, true)


func _validate_final_campaign() -> void:
	var state: Dictionary = _controller.state
	var receipt_ids: Array[String] = []
	for receipt_id: String in state["receipts"]:
		if state["receipts"][receipt_id].get("signature", "") == "settlement": receipt_ids.append(String(receipt_id))
	var completion_count := 0
	for completion: Dictionary in MetaProgress.campaign_completions:
		if completion.get("campaign_id", "") == state["campaign_id"]: completion_count += 1
	var successful: int = state["successful_nodes"].size()
	var spent_talents := 0
	for talent_id in state["talents"]["allocated"]:
		if String(talent_id) != SkillData.ROOT:
			spent_talents += SkillData.cost(String(talent_id))
	var assertions := {
		"completed campaign": state["completed"] and state["phase"] == "CAMPAIGN_COMPLETE",
		"exactly 12 successful missions": successful == 12,
		"exactly three biome completions": _journey_biomes == 3,
		"all 18 earned talent points accounted for": int(state["talents"]["earned"]) == 18 and spent_talents + int(state["talents"]["points"]) == 18,
		"account reward outbox empty": state["outbox"].is_empty(),
		"single full-campaign completion receipt": completion_count == 1,
		"one settlement receipt per actual attempt": receipt_ids.size() == _journey_attempt_ids.size(),
		"town checkpoint reload exercised": _journey_town_reload_done,
		"attempt identities unique": _journey_attempt_ids.size() == _unique_count(_journey_attempt_ids),
	}
	for label in assertions:
		if not assertions[label]: _fail("final invariant failed: %s (successful=%d biomes=%d talents=%d outbox=%d completions=%d receipts=%d attempts=%d)" % [
			label, successful, _journey_biomes, state["talents"]["earned"], state["outbox"].size(), completion_count, receipt_ids.size(), _journey_attempt_ids.size()])
	print("JOURNEY_FINAL %s" % str(assertions))


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values: unique[value] = true
	return unique.size()


func _preserve_final_ember_checkpoint() -> void:
	var source := ProjectSettings.globalize_path(_campaign_path)
	var destination := _artifact_directory() + "/journey-seed%d-%s-final-ember-checkpoint.save" % [_seed, _run_id]
	var staged := destination + ".tmp"
	var source_hash := FileAccess.get_md5(source)
	if source_hash == "":
		_fail("final Ember departure checkpoint was not readable for preservation")
		return
	if DirAccess.copy_absolute(source, staged) != OK or FileAccess.get_md5(staged) != source_hash:
		_fail("final Ember departure checkpoint copy did not verify")
		return
	if FileAccess.get_md5(source) != source_hash or DirAccess.rename_absolute(staged, destination) != OK:
		_fail("final Ember departure checkpoint changed or could not be saved")
		return
	print("JOURNEY_FINAL_EMBER_CHECKPOINT path=%s md5=%s earned=%d allocated=%s points=%d" % [
		destination, source_hash, int(_controller.state["talents"]["earned"]),
		str(_controller.state["talents"]["allocated"]), int(_controller.state["talents"]["points"])])


func _artifact_directory() -> String:
	var configured := OS.get_environment("CAMPAIGN_JOURNEY_ARTIFACT_DIR")
	if configured == "": configured = "user://campaign_journey_artifacts"
	var absolute := ProjectSettings.globalize_path(configured) if configured.begins_with("user://") else configured
	if not DirAccess.dir_exists_absolute(absolute): DirAccess.make_dir_recursive_absolute(absolute)
	return absolute


func _preserve_failed_fixture() -> void:
	var destination_dir := _artifact_directory()
	for source_path in [_campaign_path, _campaign_path + ".bak", _campaign_path + ".previous", _campaign_path + ".rollback",
		_profile_path, _profile_path + ".bak", _profile_path + ".previous", _profile_path + ".rollback"]:
		var source := ProjectSettings.globalize_path(source_path)
		if not FileAccess.file_exists(source_path): continue
		var destination := destination_dir + "/journey-seed%d-%s-%s" % [_seed, _run_id, source_path.get_file()]
		var staged := destination + ".tmp"
		var source_hash := FileAccess.get_md5(source)
		if source_hash == "" or DirAccess.copy_absolute(source, staged) != OK or FileAccess.get_md5(staged) != source_hash:
			printerr("JOURNEY_PRESERVE_WARNING: could not verify failure fixture copy for " + source_path)
			continue
		if FileAccess.get_md5(source) == source_hash:
			if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
			if DirAccess.rename_absolute(staged, destination) == OK: print("JOURNEY_FAILURE_FIXTURE path=%s md5=%s" % [destination, source_hash])
			else: printerr("JOURNEY_PRESERVE_WARNING: could not commit failure fixture copy for " + source_path)


func _finish_journey() -> void:
	if _done: return
	if _journey_failed: _preserve_failed_fixture()
	_exit_code = 1 if _journey_failed else 0
	print("JOURNEY_EXIT_CODE=%d successes=%d attempts=%d biomes=%d" % [_exit_code, _journey_successes, _journey_attempt_ids.size(), _journey_biomes])
	_done = true
	_cleanup_started = false


func _fail(message: String) -> void:
	_journey_failed = true
	printerr("JOURNEY_FAILURE: " + message)
	_finish_journey()


func _process(delta: float) -> bool:
	_frame += 1
	if Input.is_action_pressed("dash"): Input.action_release("dash")
	if _release_interact:
		Input.action_release("interact")
		_release_interact = false
	if _done:
		if not _cleanup_started:
			_cleanup_started = true
			if is_instance_valid(_main):
				root.remove_child(_main)
				_main.free()
			_main = null
			if is_instance_valid(_controller): _controller.free()
			return false
		_cleanup_wait_frames += 1
		if _cleanup_wait_frames < 2: return false
		_cleanup_journey_files()
		quit(_exit_code)
		return true
	if Time.get_ticks_msec() >= _wall_deadline_msec:
		_fail("overall campaign watchdog expired")
		return false
	# The async runner owns mission and town transitions. The base bot's process
	# body would attempt its single-contract setup, so only use its helper methods.
	return false


func _cleanup_journey_files() -> void:
	# Preserve originals after a failed journey even if copying the fixture to the
	# artifact directory failed; they remain available for diagnosis or resume.
	if _journey_failed: return
	for path in [_campaign_path, _campaign_path + ".bak", _campaign_path + ".previous", _campaign_path + ".rollback", _campaign_path + ".tmp",
		_profile_path, _profile_path + ".bak", _profile_path + ".previous", _profile_path + ".rollback", _profile_path + ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(absolute)
