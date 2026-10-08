extends SceneTree
## Real campaign mount for the authored first-Graveyard arrival and its
## contract card. Save/profile paths are redirected to disposable user data.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_path := ""
	var width := 1280
	var height := 720
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires a windowed renderer; run this test without --headless.")
		quit(2)
		return
	root.size = Vector2i(width, height)
	var token := "first-expedition-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	Controls.apply()
	var controller := CampaignController.new()
	root.add_child(controller)
	var created := controller.create("battlemage", 912020)
	check(bool(created.get("ok", false)), "isolated campaign creates")
	if not created.get("ok", false):
		_report()
		return
	var routes := controller.available_routes()
	check(not routes.is_empty(), "first route is available")
	if routes.is_empty():
		_report()
		return
	var chosen := controller.choose_route(str(routes[0].get("id", "")))
	check(bool(chosen.get("ok", false)), "first route commits through campaign state")
	if controller.state.get("phase") == "EVENT_PENDING":
		var event := controller.state.get("event", {}) as Dictionary
		var choice_id := "leave"
		for choice: Dictionary in event.get("choices", []):
			if str(choice.get("id", "")) == "leave":
				choice_id = "leave"
		var resolved := controller.resolve_event(choice_id)
		check(bool(resolved.get("ok", false)), "the first road event resolves through its saved choice")
	var departure := controller.depart()
	check(bool(departure.get("ok", false)), "the first mission starts from the committed departure")
	if not departure.get("ok", false):
		_report()
		return
	var spec: Dictionary = departure.get("spec", {})
	print("FIRST_EXPEDITION_SPEC node=%s biome=%s contract=%s" % [spec.get("node_id", ""), spec.get("biome_index", -1), spec.get("contract_id", "")])
	Realm.in_title = false
	Realm.current = str(spec.get("biome_id", "graveyard"))
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	scene.expedition_spec = spec.duplicate(true)
	root.add_child(scene)
	for _frame in 12:
		await process_frame
	var expedition := scene.get_node_or_null("ExpeditionDirector") as ExpeditionDirector
	var hud := scene.get_node_or_null("Hud") as Hud
	check(expedition != null, "real combat scene mounts its campaign objective director")
	check(spec.get("node_id", "").begins_with("0:1:") and spec.get("biome_index", -1) == 0,
		"fixture enters the first Graveyard branch")
	check(expedition != null and expedition.get_node_or_null("GraveyardArrivalGate") != null,
		"first Graveyard arrival builds the paired-pier gateway and short causeway")
	var contract_name := str(CampaignCatalog.CONTRACTS.get(str(spec.get("contract_id", "")), {}).get("name", ""))
	check(hud != null and hud._title_main.text == "THE HOLLOW GRAVEYARD" and hud._title_sub.text.contains(contract_name)
		and hud._expedition_label.visible,
		"arrival card names the saved realm and contract while objective HUD stays live")
	if not capture_path.is_empty():
		await create_timer(3.7).timeout # capture after the nonblocking arrival card clears
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			check(false, "first-expedition render has a viewport texture")
			if is_instance_valid(scene):
				scene.free()
			_report()
			return
		var image := viewport_texture.get_image()
		check(image.save_png(capture_path) == OK, "real first-expedition render saves")
	if is_instance_valid(scene):
		scene.free()
	_report()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	if failures.is_empty():
		print("CAMPAIGN_FIRST_EXPEDITION_OK")
		quit(0)
	else:
		print("CAMPAIGN_FIRST_EXPEDITION_FAILED %d" % failures.size())
		quit(1)
