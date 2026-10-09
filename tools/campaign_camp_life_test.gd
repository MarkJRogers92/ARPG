extends SceneTree
## Focused behavior and optional 1280x720 renderer capture for the
## Gravediggers' Camp life layer and Mara conversation.

var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var width := 1280
	var height := 720
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
	if not capture_dir.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Camp-life screenshots require a windowed renderer.")
		quit(2)
		return
	if not capture_dir.is_empty():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(width, height))
	root.size = Vector2i(width, height)
	CampaignSave.path = "user://campaign-camp-life-test-%d.save" % Time.get_ticks_usec()
	MetaProgress.save_path = "user://campaign-camp-life-test-%d.meta" % Time.get_ticks_usec()
	MetaProgress.disabled = true
	Landmarks.ensure_input()
	Controls.apply()
	CampaignTown.walk_mode = 1
	var sound := Sound.new()
	sound.name = "TestCampaignSound"
	root.add_child(sound)
	var controller := CampaignController.new()
	root.add_child(controller)
	check(bool(controller.create("battlemage", 74021).get("ok", false)), "isolated real campaign controller creates")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	for _frame in 3:
		await process_frame
	check(is_instance_valid(town._walk), "real town mounts its walkable world")
	if not is_instance_valid(town._walk):
		_report()
		return
	var fixture := controller.snapshot()
	check(town._walk._camp_life == null, "the opening Last Lantern does not gain camp-only residents")
	fixture["cleared_nodes"] = [str(controller.available_routes()[0].get("id", "0:1:0"))]
	fixture["phase"] = "TOWN"
	town._on_changed(fixture)
	await process_frame
	var walk: CampaignWalkTown = town._walk
	check(str(walk._waystop.get("name", "")) == "Gravediggers' Camp", "a first cleared route resolves the camp stop")
	check(is_instance_valid(walk._camp_life), "camp-only life layer is mounted under the destination")
	check(_worker_count(walk) == 3, "Mara and two distinct camp workers are present")
	check(not walk._camp_life._prompt.visible, "Mara's interaction prompt stays hidden beyond speaking range")
	check(is_instance_valid(walk._camp_life._fire_audio) and walk._camp_life._fire_audio.bus == "SFX", "camp crackle uses the existing SFX bus")
	check(walk._camp_life._fire_audio.stream != null, "camp crackle has a loaded local stream")
	check(walk._camp_life._fire_audio.playing, "camp crackle loops while its camp is mounted")
	_test_camp_motion(walk._camp_life)
	var original_snapshot := controller.snapshot()
	var quit_count := [0]
	town.quit_requested.connect(func() -> void: quit_count[0] += 1)

	if not capture_dir.is_empty():
		await _capture("camp")

	_test_service_precedence(town)
	await _test_dialogue_and_state(town, controller, original_snapshot, quit_count)
	_test_guards(town)
	_test_rebind_prompt(town, quit_count)
	_test_waystop_cleanup(town)
	if not capture_dir.is_empty():
		# Rebuild the camp after lifecycle checks, then capture its open dialogue.
		var return_state := controller.snapshot()
		return_state["cleared_nodes"] = [str(controller.available_routes()[0].get("id", "0:1:0"))]
		return_state["phase"] = "TOWN"
		town._on_changed(return_state)
		await process_frame
		walk = town._walk
		walk._hero_pos = CampaignCampLife.MARA_AT + Vector2(1.15, 0.45)
		walk._place_hero(0.0)
		walk._update_near(false)
		walk.mara_used.emit()
		for _frame in 3:
			await process_frame
		await _capture("dialogue")
	_report()


func _test_service_precedence(town: CampaignTown) -> void:
	var walk: CampaignWalkTown = town._walk
	var station: Dictionary = CampaignWalkTown.STATIONS[1]
	var at: Vector3 = station["at"]
	walk._hero_pos = Vector2(at.x, at.z) + Vector2(1.4, 0)
	walk._place_hero(0.0)
	walk._update_near(false)
	check(walk.nearest_station() == "pack", "an existing service remains the nearest interaction")
	Input.action_press("interact")
	walk._process(0.016)
	Input.action_release("interact")
	check(town._active_service == "pack" and town._panel_open and not town._mara_dialogue_open,
		"using a station still opens its original service instead of Mara")
	town._input(_escape_event())
	check(not town._panel_open and walk.walking, "service Escape returns to the active camp")


func _test_dialogue_and_state(town: CampaignTown, controller: CampaignController, before: Dictionary, quit_count: Array) -> void:
	var walk: CampaignWalkTown = town._walk
	walk._hero_pos = CampaignCampLife.MARA_AT + Vector2(0.12, 0.08)
	walk._place_hero(0.0)
	check(walk._hero_pos.distance_to(CampaignCampLife.MARA_AT) >= 0.47, "Mara has a small walk blocker so the hero cannot pass through her")
	walk._update_near(false)
	check(walk._camp_life._prompt.visible, "Mara's prompt appears only inside her speaking range")
	check(walk.nearest_station() == "", "Mara's approach does not overlap a service range")
	Input.action_press("interact")
	walk._process(0.016)
	Input.action_release("interact")
	check(town._mara_dialogue_open and not walk.walking and town._mara_dialogue.visible,
		"the real interact action opens Mara's conversation and freezes movement")
	check(not walk._camp_life._prompt.visible, "the 3D interaction prompt hides while the conversation is open")
	await process_frame
	check(get_root().gui_get_focus_owner() == town._mara_choices.get_child(0), "keyboard focus starts on the first dialogue choice")
	var stopped := walk._hero_pos
	Input.action_press("move_right")
	walk._process(0.25)
	Input.action_release("move_right")
	check(walk._hero_pos.distance_to(stopped) < 0.01, "conversation pauses movement")
	(town._mara_choices.get_child(0) as Button).pressed.emit()
	check(town._mara_copy.text.contains("Bellwether") and town._mara_copy.text.contains("bells"),
		"the road question gives grounded Bellwether and bell warning")
	await process_frame
	check(get_root().gui_get_focus_owner() == town._mara_choices.get_child(0), "topic response moves keyboard focus to Ask something else")
	(town._mara_choices.get_child(0) as Button).pressed.emit()
	await process_frame
	check(get_root().gui_get_focus_owner() == town._mara_choices.get_child(0), "returning to the question list restores choice focus")
	(town._mara_choices.get_child(1) as Button).pressed.emit()
	check(town._mara_copy.text.contains("neighbors") and town._mara_copy.text.contains("dark"),
		"the personal question explains why the cemetery crew stays")
	await process_frame
	(town._mara_choices.get_child(0) as Button).pressed.emit()
	await process_frame
	town._input(_escape_event())
	check(not town._mara_dialogue_open and walk.walking and quit_count[0] == 0,
		"Escape closes the conversation without leaving the campaign")
	check(controller.snapshot() == before, "Mara's repeatable dialogue changes no campaign or reward state")


func _test_guards(town: CampaignTown) -> void:
	var walk: CampaignWalkTown = town._walk
	for phase: String in ["EVENT_PENDING", "RESULT_PENDING", "CAMPAIGN_COMPLETE"]:
		var state := town._state.duplicate(true)
		state["phase"] = phase
		town._on_changed(state)
		check(not walk._camp_talk_enabled, "%s disables camp conversation" % phase)
		town._open_mara_dialogue()
		check(not town._mara_dialogue_open, "%s cannot open Mara dialogue" % phase)
	var service_state := town._state.duplicate(true)
	service_state["phase"] = "TOWN"
	town._on_changed(service_state)
	town._open_station("route")
	town._open_mara_dialogue()
	check(town._panel_open and not town._mara_dialogue_open, "an open service panel blocks NPC interaction")
	town._input(_escape_event())


func _test_rebind_prompt(town: CampaignTown, quit_count: Array) -> void:
	var walk: CampaignWalkTown = town._walk
	Controls.rebind("interact", KEY_F)
	var prompt: Label3D = walk._camp_life._prompt
	walk._update_near(false)
	check(Controls.tag("interact") == "[F]" and prompt.text.contains("[F]"), "Mara's prompt follows the player's current Use binding")
	walk._hero_pos = CampaignCampLife.MARA_AT
	walk._place_hero(0.0)
	walk._update_near(false)
	Input.action_press("interact")
	walk._process(0.016)
	Input.action_release("interact")
	check(town._mara_dialogue_open, "the rebound Use action still opens the conversation")
	(town._mara_choices.get_child(town._mara_choices.get_child_count() - 1) as Button).pressed.emit()
	check(not town._mara_dialogue_open and quit_count[0] == 0, "the Leave choice closes the conversation without leaving the campaign")
	Controls.reset()
	check(Controls.tag("interact") != "[F]", "the default Use binding restores after the rebind check")


func _test_waystop_cleanup(town: CampaignTown) -> void:
	var walk: CampaignWalkTown = town._walk
	var life := walk._camp_life
	var audio := life._fire_audio
	var children_before := walk._destination_world.get_child_count()
	var later := town._state.duplicate(true)
	later["cleared_nodes"] = ["0:1:0", "0:2:0"]
	town._on_changed(later)
	check(not is_instance_valid(life) and not is_instance_valid(audio), "leaving the camp frees its workers and local audio")
	check(walk._camp_life == null and walk._waystop.get("name") != "Gravediggers' Camp", "later stops contain no stale camp-life reference")
	town._open_mara_dialogue()
	check(not town._mara_dialogue_open, "Mara is unavailable after leaving Gravediggers' Camp")
	var fresh := town._state.duplicate(true)
	fresh["cleared_nodes"] = ["0:1:0"]
	town._on_changed(fresh)
	check(is_instance_valid(walk._camp_life) and _worker_count(walk) == 3, "returning to camp creates one clean set of workers")
	check(walk._destination_world.get_child_count() <= children_before, "waystop refresh does not accumulate scenery or camp actors")


func _test_camp_motion(life: CampaignCampLife) -> void:
	var smoke: MeshInstance3D = life._smoke[0]["node"]
	var smoke_before := smoke.position
	var embers: MeshInstance3D = life._embers[0]["node"]
	var ember_before := embers.position
	var firekeeper := _worker_by_role(life, "firekeeper")
	var worker_arm: Node3D = firekeeper["arms"][0]
	var arm_before := worker_arm.rotation.z
	var repairer := _worker_by_role(life, "repairer")
	var hammer: MeshInstance3D = repairer["hammer"]
	var hammer_before := hammer.global_transform
	var light_before := life._fire_light.light_energy
	life._process(0.21)
	check(not smoke.position.is_equal_approx(smoke_before) and not embers.position.is_equal_approx(ember_before),
		"smoke and embers have frame-driven movement")
	check(not is_equal_approx(worker_arm.rotation.z, arm_before), "the firekeeper has a distinct warming-hands motion")
	check(not hammer.global_transform.is_equal_approx(hammer_before), "the repairer's hammer follows its active work arm")
	check(not is_equal_approx(life._fire_light.light_energy, light_before), "the hearth light flickers subtly")


func _worker_by_role(life: CampaignCampLife, role: String) -> Dictionary:
	for worker: Dictionary in life._workers:
		if str(worker.get("role", "")) == role:
			return worker
	return {}


func _worker_count(walk: CampaignWalkTown) -> int:
	if not is_instance_valid(walk._camp_life):
		return 0
	var count := 0
	for child: Node in walk._camp_life.get_children():
		if child is Node3D and child.name in ["Mara", "Firekeeper", "Repairer"]:
			count += 1
	return count


func _capture(name: String) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var dir_error := DirAccess.make_dir_recursive_absolute(capture_dir)
	check(dir_error == OK, "capture directory is available")
	for _attempt in 12:
		if root.size == Vector2i(1280, 720):
			break
		await create_timer(0.25).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := capture_dir.path_join("%s.png" % name)
	check(root.size == Vector2i(1280, 720) and image.get_width() == 1280 and image.get_height() == 720,
		"%s capture uses native viewport pixels (%dx%d)" % [name, image.get_width(), image.get_height()])
	check(image.save_png(path) == OK, "%s capture saved to %s" % [name, path])
	print("CAPTURE: %s %dx%d %s" % [name, image.get_width(), image.get_height(), path])


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	CampaignTown.walk_mode = -1
	MetaProgress.disabled = false
	if failures.is_empty():
		print("CAMPAIGN_CAMP_LIFE_OK")
		quit(0)
	else:
		print("CAMPAIGN_CAMP_LIFE_FAILED %d" % failures.size())
		quit(1)
