extends SceneTree
## Transaction, persistence, and retry probes for four settlement stories.
## Every test redirects campaign and meta saves to a unique disposable path.

const Stories = preload("res://scripts/campaign/campaign_stories.gd")
const StoryLife = preload("res://scripts/campaign/campaign_story_life.gd")

var checks := 0
var failures := 0
var test_root := "user://campaign-settlement-stories-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var files: Array[String] = []
var capture_dir := ""
var capture_size := Vector2i(1280, 720)

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var width := 1280
	var height := 720
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Story dialogue captures require a windowed renderer.")
			quit(2)
			return
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(Vector2i(width, height))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(width, height)
		root.size = Vector2i(width, height)
		capture_size = Vector2i(width, height)
		check(root.size == capture_size, "demo capture window is configured to the requested pixel dimensions")
		check(root.get_visible_rect().size == Vector2(capture_size), "demo rendering viewport uses the requested pixel dimensions")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	MetaProgress.disabled = true
	_test_legacy_save()
	_test_whitepass_and_sledwright()
	_test_redwake()
	await _test_walkable_dialogue()
	await _test_story_before_pending_event_resolution()
	await _test_expedition_pickup_site()
	await _test_lantern_retry_and_bank()
	await _test_lantern_missed()
	for file_path in files:
		for suffix in ["", ".bak", ".tmp", ".previous", ".rollback"]:
			var absolute := ProjectSettings.globalize_path(file_path + suffix)
			if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("CAMPAIGN_SETTLEMENT_STORIES %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)

func _new_controller(name: String, biome: int, stage: int) -> CampaignController:
	var base := test_root + "-" + name
	CampaignSave.path = base + ".save"
	MetaProgress.save_path = base + ".meta"
	files.append(CampaignSave.path)
	files.append(MetaProgress.save_path)
	MetaProgress.load_save()
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 92051 + biome * 11 + stage)["ok"], "%s fixture creates in isolated storage" % name)
	var seeded := controller.snapshot()
	seeded["biome_index"] = biome
	seeded["graph"] = CampaignCatalog.route(int(seeded["seed"]), biome)
	seeded["cleared_nodes"] = []
	if stage > 0:
		var route_id: String = seeded["graph"]["start"][0]
		seeded["cleared_nodes"].append(route_id)
		if stage > 1: seeded["cleared_nodes"].append(seeded["graph"]["nodes"][route_id]["next"][0])
	seeded["phase"] = "TOWN"
	seeded["selected_node"] = ""
	seeded["stories"] = Stories.fresh()
	check(controller._commit(seeded)["ok"], "%s fixture resolves to its intended waystop" % name)
	return controller

func _test_legacy_save() -> void:
	var controller := _new_controller("legacy", 0, 0)
	var old_save := controller.snapshot()
	old_save.erase("stories")
	check(CampaignState.validate(old_save) == "", "pre-story schema-v1 save remains valid with no stories member")
	check(controller._commit(old_save)["ok"], "legacy fixture without story history persists")
	check(controller.choose_route(controller.available_routes()[0]["id"])["ok"], "first ordinary command upgrades only the in-memory additive story defaults")
	check(controller.state.get("stories", {}).size() == 4, "legacy campaign receives four empty story records on next committed command")
	controller.free()
	var active := _new_controller("legacy-active", 0, 0)
	var active_spec := _depart(active)
	check(active_spec.get("story_mission", "") == "", "ordinary expedition remains available without accepting a story")
	var old_active := active.snapshot()
	old_active.erase("stories")
	old_active["departure"].erase("story_mission")
	old_active["departure"]["objectives"].erase("lantern_recovery")
	check(CampaignState.validate(old_active) == "", "pre-story active expedition checkpoint stays compatible when both optional fields are absent")
	active.free()
	_test_objective_priority()

func _test_whitepass_and_sledwright() -> void:
	var whitepass := _new_controller("whitepass", 1, 0)
	var initial_gold: int = whitepass.state["gold"]
	var before_failed_write := whitepass.snapshot()
	CampaignSave.fail_stage = "write"
	check(not whitepass.choose_story("whitepass_aid", "donate")["ok"], "failed disk write rejects the paid Whitepass choice")
	CampaignSave.fail_stage = ""
	check(whitepass.state == before_failed_write, "failed story write does not charge gold or bank the boon")
	check(whitepass.choose_story("whitepass_aid", "donate")["ok"], "Whitepass accepts a disclosed paid practical aid")
	check(whitepass.state["gold"] == initial_gold - 8, "Whitepass charges exactly 8 gold")
	check(whitepass.state["effects"].size() == 1 and whitepass.state["effects"][0]["boon"] == "whitepass_draught", "paid tonic saves its fixed damage benefit")
	check(not whitepass.choose_story("whitepass_aid", "signal")["ok"], "Whitepass cannot award a second choice with a fresh operation id")
	check(CampaignState.validate(whitepass.state) == "", "saved Whitepass story and boon validate together")
	var route: Dictionary = whitepass.available_routes()[0]
	check(whitepass.choose_route(str(route["id"]))["ok"], "committed route can follow the Whitepass conversation")
	if whitepass.state["phase"] == "EVENT_PENDING": check(whitepass.resolve_event("leave")["ok"], "Whitepass route event remains independent from the story")
	check(whitepass.state["effects"][0]["node_id"] == route["id"], "next-road benefit binds to the current committed route")
	var boon_departure: Dictionary = whitepass.depart()
	var boon_spec: Dictionary = boon_departure["spec"]
	check(boon_spec["effects"].any(func(effect: Dictionary) -> bool: return effect.get("id") == "story_boon" and effect.get("node_id") == route["id"]), "departure snapshots the fixed story benefit")
	check(whitepass.settle(_result(boon_spec, "failure", {}))["ok"], "failed attempt retains the committed road benefit")
	check(whitepass.acknowledge_result()["ok"], "Whitepass failure result can be acknowledged")
	var retry_boon: Dictionary = whitepass.depart()
	check(retry_boon["ok"] and retry_boon["spec"]["effects"].any(func(effect: Dictionary) -> bool: return effect.get("id") == "story_boon"), "story benefit remains bound through a retry until the road is cleared")
	whitepass.free()

	var after_route := _new_controller("whitepass-after-route", 1, 0)
	var selected_route: Dictionary = after_route.available_routes()[0]
	check(after_route.choose_route(str(selected_route["id"]))["ok"], "player can select a Whitepass road before speaking to Hessa")
	check(after_route.choose_story("whitepass_aid", "signal")["ok"], "Whitepass conversation remains available after route selection")
	check(after_route.state["effects"].size() == 1 and after_route.state["effects"][0]["node_id"] == selected_route["id"], "after-selection aid binds directly to the already committed route")
	after_route.free()

	var sled := _new_controller("sledwright", 1, 1)
	check(sled.choose_story("sledwright_repair", "canvas")["ok"], "Sledwright commits the free hands-on canvas repair choice")
	check(sled.state["stories"]["sledwright_repair"]["boon"] == "sledwright_canvas", "canvas repair records its distinct fixed road benefit")
	check(CampaignState.validate(sled.state) == "", "saved Sledwright choice validates")
	var tampered := sled.snapshot()
	tampered["stories"]["sledwright_repair"]["boon"] = "whitepass_signal"
	check(CampaignState.validate(tampered) != "", "story choices cannot be edited into a different reward")
	var partial := sled.snapshot()
	partial["stories"].erase("redwake_trade")
	check(CampaignState.validate(partial) != "", "partially supplied story histories reject instead of crashing on commands")
	sled.free()

func _test_redwake() -> void:
	var controller := _new_controller("redwake", 2, 1)
	var before: int = controller.state["gold"]
	var first: Dictionary = controller.choose_story("redwake_trade", "play", "redwake-stake")
	check(first["ok"], "Redwake trade accepts its disclosed single 15-gold stake")
	var record: Dictionary = controller.state["stories"]["redwake_trade"]
	check(record["status"] == "played" and record["stake"] == 15 and record["chance"] == 60, "Redwake commits fixed disclosed stake and odds")
	check(controller.state["gold"] - before == (17 if record["won"] else -15), "Redwake applies exactly the saved +17 or -15 net outcome")
	var after: int = controller.state["gold"]
	check(controller.choose_story("redwake_trade", "play", "redwake-stake")["ok"] and controller.state["gold"] == after, "same Redwake operation receipt cannot charge twice")
	check(not controller.choose_story("redwake_trade", "play", "fresh-redwake-stake")["ok"] and controller.state["gold"] == after, "new receipt cannot replay a completed gamble")
	var resumed := CampaignController.new()
	root.add_child(resumed)
	check(resumed.load_campaign()["ok"], "Redwake outcome reloads from isolated save")
	check(resumed.state["stories"]["redwake_trade"] == record and resumed.state["gold"] == after, "reload preserves the exact trade outcome and payout")
	var crate := StoryLife.new()
	root.add_child(crate)
	crate.configure({"id": "waystop:ember_rift:1"}, {"redwake_trade": record})
	check(crate._crate_lid.visible and crate._coin_pile.visible == bool(record["won"]) and crate._cargo_ash.visible == not bool(record["won"]), "Redwake payout opens the crate with the saved win or loss contents")
	crate.free()
	controller.free()
	resumed.free()

func _test_walkable_dialogue() -> void:
	Landmarks.ensure_input()
	Controls.apply()
	CampaignTown.walk_mode = 1
	var mara_controller := _new_controller("mara-dialogue", 0, 1)
	var mara_town := CampaignTown.new()
	root.add_child(mara_town)
	mara_town.setup(mara_controller)
	await process_frame
	var camp_walk: CampaignWalkTown = mara_town._walk
	camp_walk._hero_pos = CampaignCampLife.MARA_AT + Vector2(0.8, 0.0)
	camp_walk._place_hero(0.0)
	camp_walk._update_near(false)
	check(camp_walk._camp_life._prompt.visible and camp_walk.nearest_station() == "", "Mara's optional story prompt is visible without covering a service")
	Input.action_press("interact")
	camp_walk._process(0.016)
	Input.action_release("interact")
	check(mara_town._mara_dialogue_open and mara_town._mara_title.text.contains("MARA"), "reboundable Use action opens Mara's named conversation")
	(mara_town._mara_choices.get_child(2) as Button).pressed.emit()
	check(mara_town._mara_copy.text.contains("optional") and mara_town._mara_copy.text.contains("no time or gold"), "Mara explains the optional pickup and its cost-free interaction")
	await process_frame
	_check_dialogue_actions_fit(mara_town)
	await _capture("mara-lantern")
	(mara_town._mara_choices.get_child(0) as Button).pressed.emit()
	check(mara_controller.state["stories"]["lantern_recovery"]["status"] == "accepted", "Mara's page choice commits through the campaign controller")
	mara_town.free()
	mara_controller.free()

	var whitepass := _new_controller("whitepass-dialogue", 1, 0)
	var no_gold := whitepass.snapshot()
	no_gold["gold"] = 0
	check(whitepass._commit(no_gold)["ok"], "Whitepass unaffordability uses an isolated zero-gold fixture")
	var white_town := CampaignTown.new()
	root.add_child(white_town)
	white_town.setup(whitepass)
	await process_frame
	var white_walk: CampaignWalkTown = white_town._walk
	var white_at: Vector3 = white_walk._story_life._base_position
	white_walk._hero_pos = Vector2(white_at.x, white_at.z)
	white_walk._place_hero(0.0)
	white_walk._update_near(false)
	var white_distance := white_walk._hero_pos.distance_to(Vector2(white_at.x, white_at.z))
	check(white_distance >= 0.47 and white_distance <= 2.4 and white_walk._story_life._prompt.visible and white_walk.nearest_station() == "", "Whitepass actor blocks passage but remains inside Use range without service overlap")
	var white_pack: Vector3 = CampaignWalkTown.STATIONS[1]["at"]
	white_walk._hero_pos = Vector2(white_pack.x, white_pack.z) + Vector2(1.4, 0.0)
	white_walk._place_hero(0.0)
	white_walk._update_near(false)
	check(white_walk.nearest_station() == "pack", "Whitepass NPC blocker leaves armory approach usable")
	white_walk._hero_pos = Vector2(white_at.x, white_at.z) + Vector2(0.0, 1.2)
	white_walk._place_hero(0.0)
	white_walk._update_near(false)
	Input.action_press("interact")
	white_walk._process(0.016)
	Input.action_release("interact")
	check(white_town._mara_dialogue_open and white_town._story_dialogue_id == "whitepass_aid", "Use opens Hessa's settlement conversation")
	await _capture("whitepass-intro")
	(white_town._mara_choices.get_child(0) as Button).pressed.emit()
	check((white_town._mara_choices.get_child(0) as Button).disabled and not (white_town._mara_choices.get_child(1) as Button).disabled, "unaffordable paid aid is disabled while practical free aid stays available")
	(white_town._mara_choices.get_child(2) as Button).pressed.emit()
	check(whitepass.state["stories"]["whitepass_aid"]["choice"] == "" and white_town._mara_copy.text.contains("understands"), "Not now closes the request without recording a permanent decline")
	(white_town._mara_choices.get_child(0) as Button).pressed.emit()
	await process_frame
	_check_dialogue_actions_fit(white_town)
	white_walk.story_used.emit("whitepass_aid")
	(white_town._mara_choices.get_child(0) as Button).pressed.emit()
	(white_town._mara_choices.get_child(1) as Button).pressed.emit()
	check(whitepass.state["stories"]["whitepass_aid"]["choice"] == "signal", "free signal-bracing choice is saved")
	check(white_walk._story_life._signal_flame.visible and white_town._mara_copy.text.contains("brazier is braced"), "Whitepass choice changes the brazier and completion dialogue")
	var provisions := StoryLife.new()
	root.add_child(provisions)
	provisions.configure({"id": "waystop:frozen_wastes:0"}, {"whitepass_aid": {"choice": "donate"}})
	check(provisions._supply_bundle.visible, "paid Whitepass aid visibly packs the traveler's road provisions")
	provisions.free()
	white_town.free()
	whitepass.free()

	var sled := _new_controller("sledwright-dialogue", 1, 1)
	var sled_town := CampaignTown.new()
	root.add_child(sled_town)
	sled_town.setup(sled)
	await process_frame
	var sled_walk: CampaignWalkTown = sled_town._walk
	var sled_at: Vector3 = sled_walk._story_life._base_position
	sled_walk._hero_pos = Vector2(sled_at.x, sled_at.z)
	sled_walk._place_hero(0.0)
	sled_walk._update_near(false)
	var sled_distance := sled_walk._hero_pos.distance_to(Vector2(sled_at.x, sled_at.z))
	check(sled_distance >= 0.47 and sled_distance <= 2.4 and sled_walk._story_life._prompt.visible, "Sledwright blocks passage but can still be spoken to")
	var sled_pack: Vector3 = CampaignWalkTown.STATIONS[1]["at"]
	sled_walk._hero_pos = Vector2(sled_pack.x, sled_pack.z) + Vector2(1.4, 0.0)
	sled_walk._place_hero(0.0)
	sled_walk._update_near(false)
	check(sled_walk.nearest_station() == "pack", "Sledwright blocker leaves armory approach usable")
	sled_walk._hero_pos = Vector2(sled_at.x, sled_at.z) + Vector2(0.0, 1.2)
	sled_walk._place_hero(0.0)
	sled_walk._update_near(false)
	Input.action_press("interact")
	sled_walk._process(0.016)
	Input.action_release("interact")
	(sled_town._mara_choices.get_child(1) as Button).pressed.emit()
	check(sled.state["stories"]["sledwright_repair"]["choice"] == "" and sled_town._mara_copy.text.contains("wait until"), "leaving Elian's repair open does not record a permanent decline")
	(sled_town._mara_choices.get_child(0) as Button).pressed.emit()
	sled_walk.story_used.emit("sledwright_repair")
	(sled_town._mara_choices.get_child(0) as Button).pressed.emit()
	check(sled_town._mara_copy.text.contains("+10% armor") and sled_town._mara_copy.text.contains("lash and test"), "Sledwright discloses hands-on repair and accurate benefit")
	(sled_town._mara_choices.get_child(1) as Button).pressed.emit()
	check(sled_town._mara_copy.text.contains("one final test"), "free repair has a second purposeful test interaction")
	(sled_town._mara_choices.get_child(0) as Button).pressed.emit()
	await process_frame
	_check_dialogue_actions_fit(sled_town)
	check(sled_walk._story_life._canvas_splint.visible and not sled_walk._story_life._broken_runner.visible, "completed sled repair replaces the visibly broken runner")
	await _capture("sledwright-repaired")
	sled_town.free()
	sled.free()

	var redwake := _new_controller("redwake-dialogue", 2, 1)
	var poor := redwake.snapshot()
	poor["gold"] = 0
	check(redwake._commit(poor)["ok"], "Redwake affordability uses an isolated zero-gold fixture")
	var red_town := CampaignTown.new()
	root.add_child(red_town)
	red_town.setup(redwake)
	await process_frame
	var red_walk: CampaignWalkTown = red_town._walk
	var red_at: Vector3 = red_walk._story_life._base_position
	red_walk._hero_pos = Vector2(red_at.x, red_at.z)
	red_walk._place_hero(0.0)
	red_walk._update_near(false)
	var red_distance := red_walk._hero_pos.distance_to(Vector2(red_at.x, red_at.z))
	check(red_distance >= 0.47 and red_distance <= 2.4 and red_walk._story_life._prompt.visible, "Juno blocks passage but remains available for Use")
	var trainer: Vector3 = CampaignWalkTown.STATIONS[3]["at"]
	red_walk._hero_pos = Vector2(trainer.x, trainer.z) + Vector2(1.4, 0.0)
	red_walk._place_hero(0.0)
	red_walk._update_near(false)
	check(red_walk.nearest_station() == "trainer", "Redwake NPC blocker leaves trainer approach usable")
	red_walk._hero_pos = Vector2(red_at.x, red_at.z) + Vector2(0.0, 1.2)
	red_walk._place_hero(0.0)
	red_walk._update_near(false)
	Input.action_press("interact")
	red_walk._process(0.016)
	Input.action_release("interact")
	(red_town._mara_choices.get_child(0) as Button).pressed.emit()
	check(red_town._mara_copy.text.contains("60%") and red_town._mara_copy.text.contains("+17 net") and red_town._mara_copy.text.contains("-15"), "Juno explains both outcomes before stake confirmation")
	check((red_town._mara_choices.get_child(0) as Button).disabled and not (red_town._mara_choices.get_child(1) as Button).disabled, "Redwake stake disables below 15 gold while free leave remains available")
	await process_frame
	_check_dialogue_actions_fit(red_town)
	await _capture("redwake-inspection")
	(red_town._mara_choices.get_child(1) as Button).pressed.emit()
	check(redwake.state["stories"]["redwake_trade"]["status"] == "declined", "Juno's visibly permanent free decline records the closed trade")
	red_town.free()
	redwake.free()

func _capture(name: String) -> void:
	if capture_dir.is_empty(): return
	for _attempt in range(4):
		root.mode = Window.MODE_WINDOWED
		root.size = capture_size
		DisplayServer.window_set_size(capture_size)
		await process_frame
		await RenderingServer.frame_post_draw
		if root.size == capture_size and root.get_visible_rect().size == Vector2(capture_size.x, capture_size.y): break
	print("CAPTURE_DIMENSIONS %s window=%s root=%s viewport=%s image=%s" % [name, DisplayServer.window_get_size(), root.size, root.get_visible_rect().size, root.get_texture().get_image().get_size()])
	check(root.size == capture_size, "%s window remains at the requested capture size" % name)
	check(root.get_visible_rect().size == Vector2(capture_size.x, capture_size.y), "%s render viewport remains at the requested capture size" % name)
	var destination := ProjectSettings.globalize_path("%s/%s.png" % [capture_dir, name])
	var screenshot := root.get_texture().get_image()
	if screenshot.get_size() != capture_size:
		screenshot.resize(capture_size.x, capture_size.y, Image.INTERPOLATE_LANCZOS)
	check(screenshot.get_size() == capture_size, "%s capture is exactly %dx%d" % [name, capture_size.x, capture_size.y])
	screenshot.save_png(destination)

func _check_dialogue_actions_fit(town: CampaignTown) -> void:
	var viewport_height := get_root().get_visible_rect().size.y
	check(town._mara_dialogue.get_global_rect().end.y <= viewport_height, "dialogue panel remains inside the viewport")
	for child: Node in town._mara_choices.get_children():
		var button := child as Button
		check(button.get_global_rect().end.y <= viewport_height, "dialogue action '%s' remains visible at the viewport bottom" % button.text)

func _test_lantern_retry_and_bank() -> void:
	var controller := _new_controller("lantern", 0, 1)
	check(controller.choose_story("lantern_recovery", "accept")["ok"], "Mara's optional expedition errand can be accepted")
	var spec := _depart(controller)
	check(spec.get("story_mission", "") == "lantern_recovery" and spec.get("objectives", {}).get("lantern_recovery", false), "accepted lantern becomes a committed expedition objective")
	var wrong_mission := controller.snapshot()
	wrong_mission["departure"]["story_mission"] = ""
	wrong_mission["departure"]["objectives"]["lantern_recovery"] = false
	check(CampaignState.validate(wrong_mission) != "", "active accepted lantern cannot be detached from its saved mission")
	var wrong_story := controller.snapshot()
	wrong_story["stories"]["lantern_recovery"].merge({"status": "complete", "recovered": true, "reward_paid": true}, true)
	check(CampaignState.validate(wrong_story) != "", "active lantern mission rejects a completed story record")
	var mismatched := spec.duplicate(true)
	mismatched["objectives"]["lantern_recovery"] = false
	check(CampaignState.validate_spec(mismatched) != "", "lantern mission cannot detach from its objective flag")
	var report := _result(spec, "failure", {"lantern_recovered": true})
	check(controller.settle(report).get("ok", false), "failed attempt settles even if the local pickup happened before death")
	check(controller.state["stories"]["lantern_recovery"]["status"] == "accepted" and not controller.state["stories"]["lantern_recovery"]["recovered"], "death loses the unbanked lantern pickup while keeping the errand active")
	check(controller.acknowledge_result()["ok"], "failed lantern attempt result can be acknowledged")
	controller.free()
	controller = CampaignController.new()
	root.add_child(controller)
	check(controller.load_campaign()["ok"], "active lantern errand survives save reload after failure")
	var retry := controller.depart()
	check(retry["ok"] and retry["spec"]["story_mission"] == "lantern_recovery" and retry["spec"]["node_id"] == spec["node_id"], "retry keeps the road and committed lantern mission")
	var retry_spec: Dictionary = retry["spec"]
	var success_report := _result(retry_spec, "success", {"lantern_recovered": true, "seals": 3, "elite_dead": true, "boss_dead": true})
	var paid_before: int = controller.state["gold"]
	var state_before_failed_payout := controller.snapshot()
	CampaignSave.fail_stage = "write"
	check(not controller.settle(success_report)["ok"], "failed settlement write cannot pay the recovered lantern")
	CampaignSave.fail_stage = ""
	check(controller.state == state_before_failed_payout, "failed recovery settlement leaves accepted errand and gold unchanged")
	check(controller.settle(success_report)["ok"], "successful recovery settles atomically")
	check(controller.state["stories"]["lantern_recovery"]["status"] == "complete" and controller.state["stories"]["lantern_recovery"]["reward_paid"], "lantern and its paid flag bank together")
	check(controller.state["gold"] >= paid_before + 25, "recovered lantern adds the modest 25-gold reward to normal settlement")
	check(controller.state["result"].get("story_message", "").contains("Mara's brass lantern came home"), "settlement result carries the lantern payoff forward")
	check(controller.state["phase"] == "RESULT_PENDING" and CampaignState.validate(controller.state) == "", "automatic waystop transition preserves a valid memorial record")
	var memorial_town := CampaignTown.new()
	root.add_child(memorial_town)
	memorial_town.setup(controller)
	await process_frame
	check(is_instance_valid(memorial_town._walk._story_life._memorial) and memorial_town._walk._story_life._memorial_status == "complete", "real next settlement displays Mara's returned-lantern memorial")
	memorial_town.free()
	var resumed := CampaignController.new()
	root.add_child(resumed)
	check(resumed.load_campaign()["ok"], "completed lantern record reloads")
	var resumed_town := CampaignTown.new()
	root.add_child(resumed_town)
	resumed_town.setup(resumed)
	await process_frame
	check(is_instance_valid(resumed_town._walk._story_life._memorial) and resumed_town._walk._story_life._memorial_status == "complete", "reloaded next settlement rebuilds the persistent lantern memorial")
	resumed_town.free()
	resumed.free()
	controller.free()

func _test_lantern_missed() -> void:
	var controller := _new_controller("lantern-missed", 0, 1)
	check(controller.choose_story("lantern_recovery", "accept")["ok"], "separate missed fixture accepts the optional errand")
	var spec := _depart(controller)
	var report := _result(spec, "success", {"seals": 3, "elite_dead": true, "boss_dead": true, "lantern_recovered": false})
	check(controller.settle(report)["ok"], "ordinary route success can bank without finding Mara's optional lantern")
	check(controller.state["stories"]["lantern_recovery"]["status"] == "missed" and not controller.state["stories"]["lantern_recovery"]["reward_paid"], "road advancement records the missed optional errand without penalty reward")
	check(controller.state["result"].get("story_message", "").contains("empty hook"), "result warns that the empty hook travels onward")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame
	check(is_instance_valid(town._walk._story_life._memorial) and town._walk._story_life._memorial_status == "missed", "missed errand has a visible empty hook at the actual next town")
	town.free()
	controller.free()

func _test_expedition_pickup_site() -> void:
	var controller := _new_controller("lantern-field", 0, 1)
	check(controller.choose_story("lantern_recovery", "accept")["ok"], "field fixture accepts Mara's errand")
	var spec := _depart(controller)
	Realm.in_title = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.expedition_spec = spec.duplicate(true)
	root.add_child(main)
	await process_frame
	await process_frame
	var expedition: ExpeditionDirector = main.get("_expedition")
	var site_index := expedition._site_ids.find("lantern_recovery")
	check(site_index >= 0 and not expedition.lantern_recovered, "real campaign expedition creates a marked brass-lantern site")
	if site_index >= 0:
		var site: Vector2 = expedition._sites[site_index]
		main.get("_player").global_position = Vector3(site.x, 0.0, site.y)
		check(expedition.interaction_prompt().get("text", "").contains("Recover Mara's brass lantern"), "field prompt names the same nearest lantern the Use action will reach")
		Input.action_press("interact")
		expedition.tick_objectives(0.016)
		Input.action_release("interact")
		check(expedition.lantern_recovered and not expedition._visuals[site_index].visible, "Use picks up the real world lantern and removes its marker")
	main.free()
	controller.free()

func _test_story_before_pending_event_resolution() -> void:
	var controller := _new_controller("pending-story", 1, 0)
	var seeded := controller.snapshot()
	var node_id: String = seeded["graph"]["start"][0]
	seeded["graph"]["nodes"][node_id]["event"] = "ash_map"
	seeded["selected_node"] = node_id
	seeded["phase"] = "EVENT_PENDING"
	seeded["event"] = controller._prepare_event(seeded, seeded["graph"]["nodes"][node_id])
	check(controller._commit(seeded)["ok"], "story-before-event fixture saves a real unresolved route event")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame
	var talk: Button
	for child: Node in town._content.get_children():
		if child is Button and str((child as Button).text).contains("Speak with Hessa"):
			talk = child as Button
			break
	check(talk != null and town._story_available("whitepass_aid"), "unresolved event preserves an explicit Whitepass conversation option")
	if talk != null:
		talk.pressed.emit()
		check(town._mara_dialogue_open and town._story_dialogue_id == "whitepass_aid", "Hessa's dialogue opens above the pending road event")
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		town._input(escape)
		check(not town._mara_dialogue_open and controller.state["phase"] == "EVENT_PENDING", "Escape returns from story dialogue to the still-forced event choice")
	town.free()
	controller.free()

func _test_objective_priority() -> void:
	var director := ExpeditionDirector.new()
	director.contract_id = "breach"
	director.seals = 3
	director.duration = 360.0
	director.deadline = 420.0
	var wave := WaveDirector.new()
	wave.elapsed = 420.0
	director._wave = wave
	check(director.objective_text().begins_with("All seals closed"), "completed seals retain extraction wording after the deadline boundary")
	director.contract_id = "elite_hunt"
	director._elite_spawned = true
	director.elite_dead = true
	check(director.objective_text().begins_with("Marked elite defeated"), "elite victory text keeps priority after its spawn flag stays set")
	director.free()
	wave.free()

func _depart(controller: CampaignController) -> Dictionary:
	if controller.state["selected_node"] == "":
		var route := controller.choose_route(controller.available_routes()[0]["id"])
		check(route["ok"], "story test route commits")
	if controller.state["phase"] == "EVENT_PENDING": check(controller.resolve_event("leave")["ok"], "story test event resolves without altering story choice")
	var departure := controller.depart()
	check(departure["ok"], "story test departure commits")
	return departure.get("spec", {})

func _result(spec: Dictionary, outcome: String, objectives: Dictionary) -> Dictionary:
	return {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
		"outcome": outcome, "elapsed": spec["duration"] if outcome == "success" else 1.0,
		"objectives": objectives, "inventory": spec["starting_loadout"]["inventory"].duplicate(true),
		"loose_shards": 0, "kills_by": {}, "veteran": {}, "report": {}}
