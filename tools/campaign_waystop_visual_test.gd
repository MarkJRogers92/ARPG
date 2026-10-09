extends SceneTree
## Checks all authored campaign destinations in the real walk-town node. The
## fixture has no controller or save; optional captures use the real renderer.

var failures: Array[String] = []
var capture_path := ""
var capture_biome := 0
var capture_stage := 0
var capture_completed := false
var capture_width := 1280
var capture_height := 720


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--biome="):
			capture_biome = int(arg.trim_prefix("--biome="))
		elif arg.begins_with("--stage="):
			capture_stage = int(arg.trim_prefix("--stage="))
		elif arg.begins_with("--width="):
			capture_width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			capture_height = int(arg.trim_prefix("--height="))
		elif arg == "--completed":
			capture_completed = true
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires a windowed renderer.")
		quit(2)
		return
	MetaProgress.disabled = true
	var token := "waystop-visual-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	Landmarks.ensure_input()
	Controls.apply()
	CampaignTown.walk_mode = 1
	var controller := CampaignController.new()
	root.add_child(controller)
	check(bool(controller.create("battlemage", 54821).get("ok", false)), "real town fixture creates an isolated campaign")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	for _frame in 3:
		await process_frame
	var walk := town._walk as CampaignWalkTown
	check(is_instance_valid(walk), "real campaign town builds the walkable scene")
	if not is_instance_valid(walk):
		quit(2)
		return
	var hero := walk._hero
	var camera := walk._camera
	var destinations: Array[Dictionary] = []
	var base_state := controller.snapshot()
	var lantern_state := _state_for(0, 0, false, base_state)
	town._on_changed(lantern_state)
	check(is_equal_approx(walk._env.ambient_light_energy, 0.42), "Last Lantern keeps its quieter ambient level")
	town._on_changed(_state_for(0, 1, false, base_state))
	check(is_equal_approx(walk._env.ambient_light_energy, 0.58), "same-biome camp arrival refreshes the warmer ambient level")
	town._on_changed(lantern_state)
	check(is_equal_approx(walk._env.ambient_light_energy, 0.42), "returning to Last Lantern restores its ambient level")
	for biome in 3:
		for stage in 4:
			destinations.append(_state_for(biome, stage, false, base_state))
	destinations.append(_state_for(2, 4, true, base_state))
	var seen_ids: Dictionary = {}
	for state: Dictionary in destinations:
		var expected := CampaignWaystops.resolve(state)
		var stop_id := str(expected["id"])
		town._on_changed(state)
		await process_frame
		check(walk._waystop_id == stop_id, "%s resolves into its owned place identity" % expected["name"])
		check(town._place_header_title.text == str(expected["name"]),
			"%s becomes the real town header title" % expected["name"])
		check(town._place_context.text == str(expected["description"])
			and town._walk_hint.text.contains(str(expected["arrival_line"])),
			"%s supplies the real context and arrival line" % expected["name"])
		var is_lantern := str(expected["kind"]) == "lantern"
		var backdrop: CampaignBackdrop = town._sanctuary
		check(backdrop._place.get("id", "") == stop_id
			and backdrop._journey.visible == is_lantern,
			"%s refreshes the inset place and keeps Last Lantern-only dressing local" % expected["name"])
		var expected_ambient: Color = [Color(0.53, 0.63, 0.79), Color(0.53, 0.71, 0.86), Color(0.68, 0.52, 0.57)][int(expected["biome_index"])]
		if bool(state.get("completed", false)):
			expected_ambient = Color(0.64, 0.73, 0.78)
		check(backdrop._environment_resource.ambient_light_color.is_equal_approx(expected_ambient),
			"%s updates the inset climate lighting from the current journey state" % expected["name"])
		check(walk._hero == hero and walk._camera == camera, "%s keeps the same hero and camera" % expected["name"])
		check(walk._lantern_world.visible == is_lantern, "%s shows only its matching world layer" % expected["name"])
		if is_lantern:
			check(walk._destination_world == null, "The Last Lantern keeps its original scene intact")
		else:
			check(is_instance_valid(walk._destination_world), "%s builds a separate authored settlement" % expected["name"])
			check(walk._destination_world.name.begins_with("Waystop_"), "%s is a named destination scene" % expected["name"])
			check(walk._destination_world.get_node_or_null("ArrivalRoadSouthToRouteNorth") != null,
				"%s keeps the south arrival road open toward the northbound route" % expected["name"])
			check(walk._destination_world.get_node_or_null("WaystopNameboard") != null,
				"%s shows its own name in the environment" % expected["name"])
			check(walk._destination_world.get_node_or_null("LastLantern") == null,
				"%s does not reuse the Last Lantern landmark" % expected["name"])
			check(_has_station_blockers(walk) and not _has_hidden_lantern_blockers(walk),
				"%s keeps station blockers and drops all hidden Last Lantern blockers" % expected["name"])
			if expected["kind"] == "camp":
				check(CampaignWaystopScenery.walk_blockers(walk._destination_world).size() >= 5,
					"%s provides collision footprints for tents, fire, and local honor" % expected["name"])
			if expected["kind"] == "camp" or expected["kind"] == "caravan":
				check(walk._destination_world.get_node_or_null("CanvasShelters") != null
					and walk._destination_world.get_node_or_null("CampsiteBedrollsAndStores") != null,
					"%s builds the shared canvas and lived-in campsite dressing" % expected["name"])
				var shelter_lights := 0
				for child: Node in walk._destination_world.get_children():
					if child is OmniLight3D and child.name.begins_with("ShelterCanvasFill"):
						shelter_lights += 1
				check(shelter_lights >= 2, "%s lights both shelter fronts" % expected["name"])
				if expected["kind"] == "caravan":
					var has_windbreak_footprint := false
					for blocker: Array in CampaignWaystopScenery.walk_blockers(walk._destination_world):
						if Vector2(blocker[0]).distance_to(Vector2(12.5, -0.1)) < 0.05 and float(blocker[1]) >= 2.0:
							has_windbreak_footprint = true
					check(has_windbreak_footprint, "%s blocks the full windbreak or heat-shield footprint" % expected["name"])
			elif expected["kind"] == "refuge":
				check(CampaignWaystopScenery.walk_blockers(walk._destination_world).size() >= 2,
					"%s blocks both shelter tent footprints" % expected["name"])
			elif expected["kind"] == "dawn":
				check(CampaignWaystopScenery.walk_blockers(walk._destination_world).size() >= 2,
					"%s blocks both guest-house footprints" % expected["name"])
			if stage_of(expected) > 0 and expected["kind"] != "dawn":
				check(walk._destination_world.get_node_or_null("LocalRoadHonor") != null,
					"%s uses a local travel honor rather than a restored central tower" % expected["name"])
			if expected["kind"] == "monastery" or expected["kind"] == "ice_chapel" or expected["kind"] == "siege":
				check(walk._destination_world.get_node_or_null("VigilGuardianNave") != null
					or walk._destination_world.get_node_or_null("ChapelOfTheThawIceNave") != null
					or walk._destination_world.get_node_or_null("GateOfEmbersSiegehouse") != null,
					"%s reads as an approach site, with no guardian victory trophy" % expected["name"])
			check(walk._hero_pos.distance_to(Vector2(0, 2.5)) < 0.01,
				"%s places the arriving hero safely in the open courtyard" % expected["name"])
		var same_scene := walk._destination_world
		var same_pos := walk._hero_pos
		var refresh := state.duplicate(true)
		refresh["gold"] = int(refresh.get("gold", 0)) + 5
		town._on_changed(refresh)
		check(walk._destination_world == same_scene and walk._hero_pos == same_pos,
			"same-place refresh keeps scenery and hero position")
		seen_ids[stop_id] = true
		await _test_service_reachability(walk, town, str(expected["name"]))
	check(seen_ids.size() == 13, "all twelve realm stops and Dawn's Rest are unique places")
	if not capture_path.is_empty():
		var state := _state_for(capture_biome, capture_stage, capture_completed, base_state)
		town._on_changed(state)
		await process_frame
		var capture_walk := town._walk as CampaignWalkTown
		check(capture_walk._waystop_id == str(CampaignWaystops.resolve(state).get("id", "")), "capture uses the requested destination state")
		capture_walk._hero_pos = Vector2(0, 2.5)
		capture_walk._place_hero(0.0)
		capture_walk._near = "ledger"
		capture_walk._update_near()
		print("CAPTURE_ARRIVAL pos=", capture_walk._hero_pos, " near=", capture_walk.nearest_station())
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(capture_width, capture_height)
		await create_timer(0.2).timeout
		DisplayServer.window_set_size(Vector2i(capture_width, capture_height))
		await create_timer(0.2).timeout
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var texture := root.get_texture()
		var image: Image = texture.get_image() if texture != null else null
		if image != null:
			print("CAPTURE_PIXELS=", image.get_width(), "x", image.get_height(), " WINDOW=", DisplayServer.window_get_size(), " MODE=", DisplayServer.window_get_mode())
		check(image != null and image.get_width() > 0 and image.get_height() > 0 and image.save_png(capture_path) == OK,
			"real rendered frame saves for " + str(CampaignWaystops.resolve(state)["name"]))
	CampaignTown.walk_mode = -1
	town.free()
	controller.free()
	_report()


func _state_for(biome: int, stage: int, completed: bool, base: Dictionary) -> Dictionary:
	var state := base.duplicate(true)
	var clears: Array = []
	var graph: Dictionary = state.get("graph", {})
	var nodes: Dictionary = graph.get("nodes", {})
	var frontier: Array = graph.get("start", []).duplicate()
	for _i in mini(stage, 3):
		if frontier.is_empty():
			break
		var id := str(frontier[0])
		clears.append(id)
		frontier = nodes.get(id, {}).get("next", []).duplicate()
	state["biome_index"] = biome
	state["completed"] = completed
	state["phase"] = "TOWN"
	state["cleared_nodes"] = clears
	return state


func stage_of(place: Dictionary) -> int:
	return int(place.get("stage", 0))


func _test_service_reachability(walk: CampaignWalkTown, town: CampaignTown, stop_name: String) -> void:
	for station: Dictionary in CampaignWalkTown.STATIONS:
		var center: Vector3 = station["at"]
		var path := _path_to_station(walk, Vector2(center.x, center.z))
		check(not path.is_empty(), "%s has a collision-clear route to %s" % [stop_name, station["id"]])
		if path.is_empty():
			continue
		var moved := _follow_path(walk, path)
		check(moved and walk.nearest_station() == station["id"],
			"real movement reaches %s at %s" % [station["id"], stop_name])
		if walk.nearest_station() == station["id"]:
			Input.action_press("interact")
			walk._process(0.016)
			Input.action_release("interact")
			await process_frame
			check(town._active_service == station["id"] and town._panel_open and not walk.walking,
				"E opens the existing %s service panel at %s" % [station["id"], stop_name])
			if town._panel_open:
				town._close_panel()
			check(walk.walking and not town._panel_open, "%s resumes walking after service use" % station["id"])


func _path_to_station(walk: CampaignWalkTown, center: Vector2) -> Array[Vector2]:
	const GRID := 0.5
	var start := Vector2i(roundi(walk._hero_pos.x / GRID), roundi(walk._hero_pos.y / GRID))
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var goal := Vector2i(9999, 9999)
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var position := Vector2(current) * GRID
		if position.distance_to(center) < 2.0:
			goal = current
			break
		for direction: Vector2i in directions:
			var next: Vector2i = current + direction
			if came_from.has(next):
				continue
			var target := Vector2(next) * GRID
			if not _walk_point_clear(walk, target) or not _walk_point_clear(walk, (position + target) * 0.5):
				continue
			came_from[next] = current
			queue.append(next)
	if goal.x == 9999:
		return []
	var reversed: Array[Vector2] = []
	var cell := goal
	while cell != start:
		reversed.append(Vector2(cell) * GRID)
		cell = came_from[cell]
	reversed.reverse()
	return reversed


func _walk_point_clear(walk: CampaignWalkTown, point: Vector2) -> bool:
	if point.length() >= CampaignWalkTown.PLAZA_RADIUS - 0.05:
		return false
	for blocker: Array in walk._blockers:
		if point.distance_to(blocker[0]) < float(blocker[1]) + 0.12:
			return false
	return true


func _follow_path(walk: CampaignWalkTown, path: Array[Vector2]) -> bool:
	for target: Vector2 in path:
		var guard := 0
		while walk._hero_pos.distance_to(target) > 0.14 and guard < 18:
			var heading := (target - walk._hero_pos).normalized()
			Input.action_press("move_left", maxf(-heading.x, 0.0))
			Input.action_press("move_right", maxf(heading.x, 0.0))
			Input.action_press("move_up", maxf(-heading.y, 0.0))
			Input.action_press("move_down", maxf(heading.y, 0.0))
			var previous := walk._hero_pos
			walk._process(0.04)
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if walk._hero_pos.distance_to(previous) < 0.02:
				return false
			guard += 1
		if walk._hero_pos.distance_to(target) > 0.25:
			return false
	return true


func _has_station_blockers(walk: CampaignWalkTown) -> bool:
	for expected: Array in walk._station_blockers:
		if not walk._blockers.has(expected):
			return false
	return true


func _has_hidden_lantern_blockers(walk: CampaignWalkTown) -> bool:
	var lantern_only_count := walk._lantern_blockers.size() - walk._station_blockers.size()
	for i in lantern_only_count:
		if walk._blockers.has(walk._lantern_blockers[i]):
			return true
	return false




func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	if failures.is_empty():
		print("CAMPAIGN_WAYSTOP_VISUAL_OK")
		quit(0)
	else:
		print("CAMPAIGN_WAYSTOP_VISUAL_FAILED %d" % failures.size())
		quit(1)
