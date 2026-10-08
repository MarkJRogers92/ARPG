extends SceneTree
## Real campaign mount for the authored first-Graveyard arrival and its
## contract card. Save/profile paths are redirected to disposable user data.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_path := ""
	var capture_moment := "arrival"
	var width := 1280
	var height := 720
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--moment="):
			capture_moment = arg.trim_prefix("--moment=")
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
		and hud._expedition_label.visible and not hud._title_sub.text.to_lower().contains("cursed cache:"),
		"arrival card names the saved realm and contract while objective HUD stays live")
	if not capture_path.is_empty():
		if capture_moment == "return":
			expedition.result = {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"],
				"attempt_id": spec["attempt_id"], "outcome": "failure", "elapsed": 240.0,
				"objectives": {"seals": 1, "elite_dead": false, "cache_claimed": false, "boss_dead": false}}
			scene.call("_finish_expedition_frame")
			await create_timer(0.45).timeout
		elif capture_moment == "busy":
			var player: Player = scene.get("_player")
			var loot: LootManager = scene.get_node("Loot") as LootManager
			var slots := ["weapon", "chest", "helm", "boots", "ring"]
			for index in slots.size():
				var rarity := mini(index, ItemData.Rarity.LEGENDARY)
				var item := ItemGenerator.generate_with(8, rarity, str(slots[index]))
				loot.drop(item, player.pos2 + Vector2.from_angle(-PI * 0.5 + TAU * float(index) / float(slots.size())) * 9.0)
			var swarms: Array = scene.get("_swarms")
			for index in 8:
				var group := swarms[index % swarms.size()] as EnemySwarm
				group.spawn(player.pos2 + Vector2.from_angle(TAU * float(index) / 8.0) * 7.0, 1.0, false)
			var director: ExpeditionDirector = scene.get("_expedition")
			director.contract_id = "breach"
			director.cache_enabled = false
			director.seals = 0
			director._site_claimed = [false, false, false]
			director._sites = [player.pos2 + Vector2(-4.0, -2.0), player.pos2 + Vector2(4.0, -2.0), player.pos2 + Vector2(0.0, 5.0)]
			for visual: Node3D in director._visuals:
				visual.visible = false
			director._visuals.clear()
			for at: Vector2 in director._sites:
				var marker := Node3D.new()
				marker.position = Vector3(at.x, 0.0, at.y)
				scene.add_child(marker)
				director._visuals.append(marker)
			var charger: EnemySwarm
			for candidate_value: Variant in swarms:
				var candidate := candidate_value as EnemySwarm
				if candidate.charger:
					charger = candidate
					break
			if charger != null and charger.count > 0:
				var last := charger.count - 1
				charger.charge_windup = 6.0
				charger._cstate[last] = 1
				charger._ctime[last] = 5.0
				charger._cdir[last] = Vector2(-1.0, 0.0)
			await create_timer(4.0).timeout
		else:
			await create_timer(0.45).timeout
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
