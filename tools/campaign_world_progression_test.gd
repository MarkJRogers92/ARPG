extends SceneTree
## Isolated checks for composed first-Graveyard field dressing and town
## progression. All campaign saves are unique temporary user:// files.

var failures: Array[String] = []
var capture_path := ""
var capture_kind := ""
var capture_stage := "mid"
var viewport_width := 1280
var viewport_height := 720
var main_process_intercepted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--kind="):
			capture_kind = arg.trim_prefix("--kind=")
		elif arg.begins_with("--stage="):
			capture_stage = arg.trim_prefix("--stage=")
		elif arg.begins_with("--width="):
			viewport_width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			viewport_height = int(arg.trim_prefix("--height="))
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires a windowed renderer; run this test without --headless.")
		quit(2)
		return
	root.size = Vector2i(viewport_width, viewport_height)
	var token := "world-progression-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	Landmarks.ensure_input()
	Controls.apply()
	CampaignTown.walk_mode = 1
	await _test_town_progression()
	_test_seeded_chapel_placement()
	await _test_live_first_expedition()
	_report()


func _test_town_progression() -> void:
	var walk := CampaignWalkTown.new()
	root.add_child(walk)
	await process_frame
	await process_frame
	var state := {
		"biome_index": 0, "completed": false, "cleared_nodes": [], "successful_nodes": {},
		"hero_class": "battlemage", "inventory": {"equipped": {"weapon": ""}, "items": {}},
	}
	var original := state.duplicate(true)
	walk.present(state)
	check(_count_progress_groups(walk) == 1 and walk._journey_dressing.get_child_count() == 0,
		"fresh town starts with no saved-route trophy dressing")
	check(walk._journey_dressing.get_parent() == walk._lantern_world,
		"journey progression dressing stays owned by Last Lantern and hides with it")
	check(_visible_votives(walk) == 0 and not walk._ferryman_story.visible,
		"fresh town keeps return lights and the Ferryman's story quiet")

	var first_return := state.duplicate(true)
	first_return["cleared_nodes"] = ["0:1:0"]
	first_return["successful_nodes"] = {"0:1:0": "receipt-1"}
	walk.present(first_return)
	check(_visible_votives(walk) == 1 and _has_progress_node(walk, "FirstRoadMemorial"),
		"the first saved clear lights a votive and raises its memorial")
	check(walk._ferryman_story.visible and walk._ferryman_story.text.contains("A light came home"),
		"the Ferryman's line responds to the first real campaign receipt")

	var frozen_return := first_return.duplicate(true)
	frozen_return["biome_index"] = 1
	frozen_return["cleared_nodes"] = [] # this campaign field resets at biome advancement
	walk.present(frozen_return)
	check(_has_progress_node(walk, "LichKingTrophy") and not _has_progress_node(walk, "FrostColossusTrophy")
		and _has_progress_node(walk, "FirstRoadMemorial"),
		"entering the Frozen Wastes keeps the first memorial and displays the defeated Graveyard guardian")
	check(walk._ferryman_story.text.contains("Lich's crown"),
		"the first guardian story names the Lich whose trophy is displayed")
	check(_visible_votives(walk) == 0, "per-biome votives follow the existing cleared_nodes list")

	var rift_return := frozen_return.duplicate(true)
	rift_return["biome_index"] = 2
	walk.present(rift_return)
	check(_has_progress_node(walk, "LichKingTrophy") and _has_progress_node(walk, "FrostColossusTrophy"),
		"entering the Ember Rift preserves the Graveyard trophy and adds the Frozen guardian")

	var completed := rift_return.duplicate(true)
	completed["completed"] = true
	walk.present(completed)
	check(_has_progress_node(walk, "RestoredLanternArch") and _has_progress_node(walk, "RestoredLanternGarden"),
		"campaign completion restores the Lantern's arch and garden")
	check(walk._ferryman_story.text == "At last, dawn has found the road.",
		"the town story reaches its completion line")
	check(walk._env.ambient_light_color.is_equal_approx(Color(0.96, 0.72, 0.43))
		and walk._env.background_color.is_equal_approx(Color(0.23, 0.14, 0.065)),
		"completion warms the walk-town lighting into a dawn palette")
	check(_count_progress_groups(walk) == 1, "milestone changes replace dressing without stale duplicate nodes")
	check(walk._journey_dressing.get_parent() == walk._lantern_world,
		"completed progression dressing remains inside Last Lantern")
	check(state == original, "town presentation reads campaign data without mutating it")

	if not capture_path.is_empty() and capture_kind == "town":
		var capture_state := _town_capture_state(capture_stage)
		walk.present(capture_state)
		for _frame in 5:
			await process_frame
		var texture := root.get_texture()
		if texture == null:
			check(false, "town capture viewport texture exists")
		else:
			check(texture.get_image().save_png(capture_path) == OK, "town milestone render saves")
	walk.free()


func _town_capture_state(stage: String) -> Dictionary:
	var state := {
		"biome_index": 0, "completed": false, "cleared_nodes": [], "successful_nodes": {},
		"hero_class": "battlemage", "inventory": {"equipped": {"weapon": ""}, "items": {}},
	}
	if stage == "mid":
		state["biome_index"] = 1
		state["successful_nodes"] = {"0:1:0": "r1", "0:2:0": "r2", "0:3:0": "r3", "1:1:0": "r4"}
	elif stage == "completed":
		state["biome_index"] = 2
		state["completed"] = true
		state["successful_nodes"] = {"0:1:0": "r1", "0:2:0": "r2", "0:3:0": "r3", "1:1:0": "r4", "1:2:0": "r5", "2:1:0": "r6", "2:2:0": "r7"}
	return state


func _test_seeded_chapel_placement() -> void:
	Obstacles.clear()
	var samples: Array[Dictionary] = [
		{"seed": 31, "sites": []},
		{"seed": 1312, "sites": [Vector2(10.0, 0.0)]},
		{"seed": 99173, "sites": [Vector2(-12.0, 3.0), Vector2(8.0, -10.0), Vector2(14.0, 11.0)]},
		{"seed": 41013, "sites": [Vector2(0.0, -20.0), Vector2(13.0, 12.0)]},
	]
	for sample: Dictionary in samples:
		var seed := int(sample["seed"])
		var sites: Array[Vector2] = []
		for site_value: Variant in sample["sites"]:
			sites.append(site_value as Vector2)
		var first := GraveyardExpeditionScenery.select_chapel_site(seed, sites)
		var repeated := GraveyardExpeditionScenery.select_chapel_site(seed, sites)
		check(first != Vector2.INF and first.is_equal_approx(repeated),
			"seed %d selects the same valid chapel patch on repeat" % seed)
		check(first.length() >= 16.0 and not Obstacles.blocked(first, 4.2),
			"seed %d keeps the chapel outside spawn clearance" % seed)
		for site: Vector2 in sites:
			check(first.distance_to(site) >= 9.0, "seed %d keeps chapel clear of each objective" % seed)

	var primary := GraveyardExpeditionScenery.select_chapel_site(31, [])
	Obstacles.set_circles([[primary, 7.0]], Rect2(Vector2(-60, -60), Vector2(120, 120)))
	var detoured := GraveyardExpeditionScenery.select_chapel_site(31, [])
	check(not detoured.is_equal_approx(primary) and not Obstacles.blocked(detoured, 4.2),
		"chapel selection steps around existing colliding scenery")
	Obstacles.clear()

	var host := Node3D.new()
	root.add_child(host)
	var sites: Array[Vector2] = [Vector2(8.0, -2.0), Vector2(-8.0, 8.0), Vector2(13.0, 11.0)]
	var mission := {"node_id": "0:1:1", "biome_index": 0, "mission_seed": 99173, "final_boss": false}
	var circles_before := Obstacles.circles.size()
	GraveyardExpeditionScenery.build(host, mission, sites)
	check(host.get_node_or_null("GraveyardArrivalGate") != null
		and host.get_node_or_null("GraveyardProcessionalCauseway") != null,
		"first-route scene builds its named gate and processional causeway")
	var chapel := host.get_node_or_null("ProcessionalChapel") as Node3D
	check(chapel != null, "first-route scene builds the roofless chapel pocket")
	for index in sites.size():
		var clearing := host.get_node_or_null("MemorialClearing_%d" % (index + 1)) as MeshInstance3D
		check(clearing != null and Vector2(clearing.position.x, clearing.position.z).is_equal_approx(sites[index]),
			"objective %d receives a clearing centered on its saved location" % (index + 1))
		check(not Obstacles.blocked(sites[index], 1.25), "objective %d remains reachable after dressing" % (index + 1))
	check(Obstacles.circles.size() == circles_before,
		"authored scenery adds no transient collision circles to chunk-owned obstacles")
	host.free()


func _test_live_first_expedition() -> void:
	var token := "world-first-live-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	CampaignShell.new_requested = true
	var shell := (load("res://scenes/campaign.tscn") as PackedScene).instantiate() as CampaignShell
	root.add_child(shell)
	for _frame in 4:
		await process_frame
	var controller := shell.controller
	check(controller != null and not controller.state.is_empty(), "live fixture creates an isolated campaign through Shell")
	var routes := controller.available_routes()
	if routes.is_empty():
		check(false, "live fixture has a first Graveyard route")
		shell.free()
		return
	var selected := controller.choose_route(str(routes[0].get("id", "")))
	check(bool(selected.get("ok", false)), "live fixture commits the first route")
	if controller.state.get("phase") == "EVENT_PENDING":
		var resolved := false
		for choice: Dictionary in controller.state.get("event", {}).get("choices", []):
			if bool(controller.resolve_event(str(choice.get("id", ""))).get("ok", false)):
				resolved = true
				break
		check(resolved, "live fixture resolves its road event")
	var departure := controller.depart()
	check(bool(departure.get("ok", false)), "live fixture departs through campaign state")
	if not departure.get("ok", false):
		shell.free()
		return
	var mission: Dictionary = departure.get("spec", {})
	check(str(mission.get("node_id", "")).begins_with("0:1:"), "live fixture is a first Graveyard branch")
	var town := shell._view
	check(town != null and town.has_signal("expedition_requested"), "Shell has mounted the real town departure signal")
	node_added.connect(_pause_main_process_until_arrival_is_dressed)
	town.expedition_requested.emit(mission)
	for _frame in 10:
		await process_frame
	var main := shell._view
	var director := main.get_node_or_null("ExpeditionDirector") as ExpeditionDirector
	check(main is Node3D and director != null, "deferred Shell departure mounts the real combat scene and director")
	check(main_process_intercepted, "fixture disables Main's first-process decor fallback before director placement")
	if director != null:
		check(director.get_node_or_null("GraveyardArrivalGate") != null
			and director.get_node_or_null("GraveyardProcessionalCauseway") != null,
			"real first arrival mounts its entry composition")
		check(director.get_node_or_null("ProcessionalChapel") != null,
			"real first arrival mounts its collision-cleared chapel pocket")
		check(director._sites.size() == 0 or director.get_node_or_null("MemorialClearing_1") != null,
			"real objective sites receive visual settings without moving their source locations")
		var decor := main.get_node("Decor") as WorldDecor
		var player := main.get_node("Player") as Player
		var current_chunk := Vector2i(floori(player.pos2.x / decor.chunk_size), floori(player.pos2.y / decor.chunk_size))
		check(decor._center == current_chunk and not decor.placed.is_empty(),
			"deferred arrival scenery forces the actual player region before reading occupied props")
	# Resume normal camera/HUD updates only after the placement-order assertions.
	main.set_process(true)
	if not capture_path.is_empty() and capture_kind == "field":
		if director != null and not director._sites.is_empty():
			var site: Vector2 = director._sites[0]
			main.get_node("Player").global_position = Vector3(site.x, 0.2, site.y)
			for _frame in 3:
				await process_frame
		await create_timer(3.7).timeout
		var texture := root.get_texture()
		if texture == null:
			check(false, "field capture viewport texture exists")
		else:
			check(texture.get_image().save_png(capture_path) == OK, "authored field render saves")
	shell.free()
	CampaignTown.walk_mode = -1


func _visible_votives(walk: CampaignWalkTown) -> int:
	var count := 0
	for votive: MeshInstance3D in walk._returning_votives:
		if votive.visible:
			count += 1
	return count


func _pause_main_process_until_arrival_is_dressed(node: Node) -> void:
	if node.get_script() != load("res://scripts/main.gd"):
		return
	# Main._process normally initializes WorldDecor on its first tick. Pausing
	# that fallback makes the regression test prove director placement explicitly
	# initializes the correct region after a real deferred Shell mount.
	node.set_process(false)
	main_process_intercepted = true
	node_added.disconnect(_pause_main_process_until_arrival_is_dressed)


func _has_progress_node(walk: CampaignWalkTown, node_name: String) -> bool:
	return is_instance_valid(walk._journey_dressing.get_node_or_null(node_name))


func _count_progress_groups(walk: CampaignWalkTown) -> int:
	return _count_named_groups(walk, "JourneyProgressDressings")


func _count_named_groups(node: Node, expected_name: String) -> int:
	var count := 1 if node.name == expected_name else 0
	for child: Node in node.get_children():
		count += _count_named_groups(child, expected_name)
	return count


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	if failures.is_empty():
		print("CAMPAIGN_WORLD_PROGRESSION_OK")
		quit(0)
	else:
		print("CAMPAIGN_WORLD_PROGRESSION_FAILED %d" % failures.size())
		quit(1)
