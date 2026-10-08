extends SceneTree
## Forced walk-town behavior checks. Uses a disposable controller save and can
## capture the real rendered town for a local visual pass.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_path := ""
	var width := 1280
	var height := 720
	var capture_screen := "town"
	for arg: String in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--screen="):
			capture_screen = arg.trim_prefix("--screen=")
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires a windowed renderer; run this test without --headless.")
		quit(2)
		return
	root.size = Vector2i(width, height)
	var token := "walk-town-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	Landmarks.ensure_input()
	Controls.apply()
	CampaignTown.walk_mode = 1
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 712008).get("ok", false), "real isolated campaign creates")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame
	await process_frame
	check(is_instance_valid(town._walk), "forced mode builds a walkable sanctuary in headless test runs")
	if not is_instance_valid(town._walk):
		_report()
		return
	check(not town._body_row.visible and town._walk.walking, "walking view starts with controls available and panels hidden")
	if not capture_path.is_empty():
		if capture_screen == "departure":
			var routes: Array = controller.available_routes()
			if not routes.is_empty():
				var choice := controller.choose_route(str(routes[0].get("id", "")))
				if bool(choice.get("ok", false)) and controller.state.get("phase") == "EVENT_PENDING":
					var event: Dictionary = controller.state.get("event", {})
					var choices: Array = event.get("choices", [])
					if not choices.is_empty():
						controller.resolve_event(str(choices[0].get("id", "leave")))
			town._active_service = "route"
		var capture_state := controller.snapshot()
		capture_state["cleared_nodes"] = ["0:1:0", "0:2:0"]
		if capture_screen == "return":
			capture_state["gold"] = int(capture_state.get("gold", 0)) + 105
			var talents: Dictionary = capture_state.get("talents", {}).duplicate(true)
			talents["points"] = int(talents.get("points", 0)) + 1
			talents["earned"] = int(talents.get("earned", 0)) + 1
			capture_state["talents"] = talents
			capture_state["phase"] = "RESULT_PENDING"
			capture_state["result"] = {"outcome": "success", "elapsed": 300.0, "gold": 100,
				"shard_conversion": 5, "talent_points": 1,
				"report": {"summary": "The first route is clear. Your gear and rewards are waiting in the Last Lantern."}}
		town._on_changed(capture_state)
		if capture_screen == "departure":
			town._open_station("route")
		for _frame in 6:
			await process_frame
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			check(false, "real-render capture has a viewport texture")
			_report()
			return
		var image := viewport_texture.get_image()
		var save_error := image.save_png(capture_path)
		check(save_error == OK, "real-render capture saves (%s)" % error_string(save_error))
		town._on_changed(controller.snapshot())
		if capture_screen == "departure":
			town._close_panel()
	var progress_state := controller.snapshot()
	town._walk.present(progress_state)
	check(_visible_votives(town._walk) == 0, "the apse starts quiet with no cleared route nodes")
	progress_state["cleared_nodes"] = ["0:1:0", "0:2:0"]
	town._walk.present(progress_state)
	check(_visible_votives(town._walk) == 2, "existing cleared-node progress lights matching return votives")
	town._walk.present(controller.snapshot())

	_test_movement_and_pause(town)
	_test_all_stations(town)
	_test_forced_phases_and_escape(town, controller)
	_report()


func _test_movement_and_pause(town: CampaignTown) -> void:
	var walk: CampaignWalkTown = town._walk
	var start := walk._hero_pos
	Input.action_press("move_right")
	walk._process(0.25)
	Input.action_release("move_right")
	check(walk._hero_pos.distance_to(start) > 0.5, "move input moves the hero through the walk-town controller")
	var paused_at := walk._hero_pos
	town._open_station("route")
	Input.action_press("move_up")
	walk._process(0.4)
	Input.action_release("move_up")
	check(walk._hero_pos.distance_to(paused_at) < 0.01, "an open overlay freezes movement")
	check(not walk.walking and town._body_row.visible, "opening a station shows the overlay and freezes the world")
	town._input(_escape_event())
	check(walk.walking and not town._body_row.visible and not town._panel_open, "Escape closes a station panel and resumes walking")


func _test_all_stations(town: CampaignTown) -> void:
	var walk: CampaignWalkTown = town._walk
	for station: Dictionary in CampaignWalkTown.STATIONS:
		var center: Vector3 = station["at"]
		var approach := _approach_point(walk, Vector2(center.x, center.z))
		check(not approach.is_equal_approx(Vector2.INF), "%s has a clear walk-up point" % station["id"])
		if approach.is_equal_approx(Vector2.INF):
			continue
		walk._hero_pos = approach
		walk._place_hero(0.0)
		walk._update_near()
		check(walk.nearest_station() == station["id"], "%s is reachable inside its interaction range" % station["id"])
		if walk.nearest_station() == station["id"]:
			Input.action_press("interact")
			walk._process(0.016)
			Input.action_release("interact")
			check(town._active_service == station["id"] and town._panel_open,
				"using %s opens its existing campaign service panel" % station["id"])
			town._input(_escape_event())
			check(town._walk.walking and not town._panel_open, "Escape returns from %s to walking" % station["id"])


func _approach_point(walk: CampaignWalkTown, center: Vector2) -> Vector2:
	for distance in [1.2, 1.55, 1.9, 2.2]:
		for step in 32:
			var candidate: Vector2 = center + Vector2.from_angle(TAU * float(step) / 32.0) * float(distance)
			if candidate.length() > CampaignWalkTown.PLAZA_RADIUS - 0.1:
				continue
			var clear := true
			for blocker: Array in walk._blockers:
				if candidate.distance_to(blocker[0]) < float(blocker[1]) + 0.12:
					clear = false
					break
			if clear:
				return candidate
	return Vector2.INF


func _visible_votives(walk: CampaignWalkTown) -> int:
	var count := 0
	for votive: MeshInstance3D in walk._returning_votives:
		if votive.visible:
			count += 1
	return count


func _test_forced_phases_and_escape(town: CampaignTown, controller: CampaignController) -> void:
	var state := controller.snapshot()
	var quit_count := [0]
	town.quit_requested.connect(func() -> void: quit_count[0] += 1)
	state["phase"] = "EVENT_PENDING"
	state["event"] = {"id": "quiet_bell", "title": "The Quiet Bell", "choices": []}
	town._on_changed(state)
	check(town._body_row.visible and not town._walk.walking, "a pending road event forces its overlay open")
	town._input(_escape_event())
	check(town._body_row.visible and not town._walk.walking and quit_count[0] == 0,
		"Escape cannot abandon an unresolved road event")
	state["phase"] = "RESULT_PENDING"
	state["event"] = {}
	state["result"] = {"outcome": "failure", "gold": 0, "shard_conversion": 0, "talent_points": 0, "report": {"summary": "The expedition ended."}}
	town._on_changed(state)
	check(town._body_row.visible and not town._walk.walking, "a pending expedition result forces its return panel open")
	town._input(_escape_event())
	check(town._body_row.visible and not town._walk.walking, "Escape cannot dismiss an unacknowledged expedition result")
	state["phase"] = "TOWN"
	town._on_changed(state)
	town._input(_escape_event())
	check(town._active_service == "route" and quit_count[0] == 0,
		"Escape from another station returns to the route board first")
	town._input(_escape_event())
	check(quit_count[0] == 1, "Escape from the open plaza keeps its save-and-leave behavior")
	CampaignTown.walk_mode = -1


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
	if failures.is_empty():
		print("CAMPAIGN_WALK_TOWN_OK")
		quit(0)
	else:
		print("CAMPAIGN_WALK_TOWN_FAILED %d" % failures.size())
		quit(1)
