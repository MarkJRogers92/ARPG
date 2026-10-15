extends SceneTree
## Real campaign combat mount: first binding, report delivery and guardian tactics.

var checks := 0
var failures := 0
var controller: CampaignController
var spec: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	seed(21937)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
	MetaProgress.disabled = true
	CampaignSave.path = "user://army-first-%d.save" % Time.get_ticks_usec()
	Controls.apply()
	controller = CampaignController.new()
	root.add_child(controller)
	var created := controller.create("battlemage", 21937)
	_check(created.get("ok", false), "disposable opening campaign creates")
	if not created.get("ok", false):
		quit(1)
		return
	var routes := controller.available_routes()
	var chosen := controller.choose_route(str(routes[0]["id"]))
	_check(chosen.get("ok", false), "opening route commits")
	if controller.state.get("phase", "") == "EVENT_PENDING":
		_check(controller.resolve_event("leave").get("ok", false), "opening event resolves")
	var departure := controller.depart()
	_check(departure.get("ok", false), "opening expedition departs")
	spec = departure.get("spec", {})
	if spec.is_empty():
		quit(1)
		return
	await _test_opening_binding()
	await _test_drop_exclusions()
	await _test_guardians()
	controller.free()
	print("ARMY FIRST INTEGRATION %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)


func _mount(mission: Dictionary) -> Node:
	Realm.in_title = false
	Realm.current = str(mission.get("biome_id", "graveyard"))
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	scene.set("expedition_spec", mission.duplicate(true))
	root.add_child(scene)
	scene.set_process(false)
	(scene.get("_player") as Player).stats.soul_chance = 0.0
	await process_frame
	for swarm: EnemySwarm in scene.get("_swarms"):
		swarm.step(0.0, (scene.get("_player") as Player).pos2)
	scene.call("_process", 0.0)
	if DisplayServer.get_name() != "headless":
		for _frame in 6:
			await process_frame
	return scene


func _kill_grunt(scene: Node, elite := false) -> void:
	var player := scene.get("_player") as Player
	var grunts := scene.get("_grunts") as EnemySwarm
	grunts.spawn(player.pos2, 1.0, elite)
	grunts.damage(grunts.count - 1, 1000000.0)


func _dispose(scene: Node) -> void:
	paused = false
	scene.queue_free()
	await process_frame
	await process_frame
	Elements.reset()


func _test_opening_binding() -> void:
	var scene := await _mount(spec)
	var army := scene.get("_army") as Army
	var souls := scene.get("_souls") as GemSwarm
	var player := scene.get("_player") as Player
	var hud := scene.get("_hud") as Hud
	_check(army.count == 0 and souls.count == 0, "opening fixture has no prepared army")
	_kill_grunt(scene)
	_check(souls.count == player.stats.soul_cost and army.count == 0,
		"first ordinary kill leaves exactly one binding's normal souls without bypassing pickup")
	souls.step(0.0, player.pos2, player.stats.pickup_radius)
	for value: int in souls.collected:
		army.collect_soul(value)
	scene.call("_process", 0.0)
	_check(army.count == 1 and army._elite[0] == 0, "collecting the opening souls binds one ordinary ally")
	_check(hud._soul_label.text.contains("ARMY 1/"), "normal combat HUD refresh shows the newly bound ally")
	_check(hud._title_main.text == "A FOE BECOMES AN ALLY" and hud._title_sub.text.contains("Ghoul")
		and hud._title_sub.text.contains(Controls.tag("army_stance")),
		"first real soul binding names the foe and current stance key")
	_check(not paused and Engine.time_scale == 1.0, "binding spotlight never pauses or slows combat")
	await _capture(scene, "binding")
	hud.title_card("Later combat", "This card should remain", Color.WHITE, true)
	for _i in player.stats.soul_cost:
		army.collect_soul(Army.soul_value(army.type_index(scene.get("_grunts")), false, false))
	_check(army.count == 2 and hud._title_main.text == "LATER COMBAT", "later bindings do not replay the spotlight")
	_kill_grunt(scene)
	_check(souls.count == 0, "opening soul grant cannot repeat after its first kill")
	army.credit(0, 60)
	scene.call("_request_expedition_result", "retreat")
	var result: Dictionary = scene.get("_expedition_result")
	var report: Dictionary = result.get("report", {})
	var story: Dictionary = report.get("army_story", {})
	_check(int(story.get("kills", -1)) == 60 and int(story.get("promotions", -1)) == 1,
		"terminal result carries the actual mission army deeds")
	var settled := controller.settle(result)
	_check(settled.get("ok", false) and settled.get("result", {}).get("report", {}).get("army_story", {}) == story,
		"authoritative retreat settlement preserves the optional army account")
	var reloaded := CampaignController.new()
	root.add_child(reloaded)
	_check(reloaded.load_campaign().get("ok", false) and reloaded.state.get("result", {}).get("report", {}).get("army_story", {}) == story,
		"army account survives an actual campaign save/reload")
	reloaded.free()
	var before := souls.count
	_kill_grunt(scene)
	_check(souls.count == before, "terminal combat cannot grant additional opening souls")
	await _dispose(scene)


func _test_drop_exclusions() -> void:
	for variant: String in ["later", "prepared", "restricted", "elite", "partial"]:
		var mission := spec.duplicate(true)
		if variant == "later": mission["node_id"] = "0:2:probe"
		if variant == "prepared": mission["preparation"] = "recruits"
		if variant == "restricted": mission["contract_id"] = "trial_reaction"
		var scene := await _mount(mission)
		var army := scene.get("_army") as Army
		var souls := scene.get("_souls") as GemSwarm
		var hud := scene.get("_hud") as Hud
		if variant == "partial":
			army.souls = 3
			army._votes[0] = 3
		if variant == "prepared":
			_check(army.count == 2 and hud._title_main.text != "A FOE BECOMES AN ALLY",
				"prepared recruits do not masquerade as the first collected-soul binding")
			while army.count > 0:
				army._remove(army.count - 1, true, false)
		_kill_grunt(scene, variant == "elite")
		var expected := (scene.get("_player") as Player).stats.soul_cost - 3 if variant == "partial" else (1 if variant == "elite" else 0)
		_check(souls.count == expected,
			"%s does not receive a redundant first-binding soul grant" % variant)
		if variant == "elite":
			souls.step(0.0, (scene.get("_player") as Player).pos2, 10.0)
			for value: int in souls.collected:
				army.collect_soul(value)
			_check(army.count == 1 and army._elite[0] == 1 and hud._title_main.text == "A FOE BECOMES AN ALLY",
				"a naturally collected elite soul still gives the real champion binding spotlight")
		await _dispose(scene)


func _test_guardians() -> void:
	for realm: String in ["graveyard", "frozen", "ember"]:
		var mission := spec.duplicate(true)
		mission["biome_id"] = realm
		mission["biome_index"] = ["graveyard", "frozen", "ember"].find(realm)
		mission["contract_id"] = "finale"
		mission["final_boss"] = true
		var scene := await _mount(mission)
		var mechanics := scene.get("_final_mech") as FinalMechanics
		var boss := scene.get("_final") as EnemySwarm
		var army := scene.get("_army") as Army
		var player := scene.get("_player") as Player
		army._raise(army.type_index(scene.get("_grunts")), false, false)
		(scene.get("_bosses") as BossDirector)._spawn_final()
		var boss_card := (scene.get("_hud") as Hud)._title_main.text
		for _i in player.stats.soul_cost:
			army.collect_soul(Army.soul_value(army.type_index(scene.get("_grunts")), false, false))
		_check((scene.get("_hud") as Hud)._title_main.text == boss_card,
			"a first binding during a guardian fight cannot replace its danger introduction")
		boss.pos[0] = player.pos2 + Vector2(0.0, -8.0)
		boss.step(0.0, player.pos2)
		mechanics.tick(0.0)
		_check(mechanics.has_method("army_phase"), "%s guardian exposes its actual tactic phase" % realm)
		if not mechanics.has_method("army_phase"):
			await _dispose(scene)
			continue
		if realm == "graveyard":
			boss.hp[0] = mechanics._max_hp * 0.6
			mechanics.tick(0.0)
			mechanics._wards.step(0.0, player.pos2)
			_check(str(mechanics.call("army_phase")) == "warded" and boss.damage_taken == 0.0,
				"Lich tactic is active only while the real ward protects him")
			army.cycle_stance("swarm")
			army._find_target(0, player.pos2, player.pos2)
			_check(army._target_id[0] >= 0 and army._swarms[army._target_swarm[0]] == mechanics._wards,
				"campaign Swarm chooses reachable phylacteries over the invulnerable Lich")
			scene.call("_process", 0.0)
			_check((scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("phylacteries") and
				(scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("SWARM"), "real campaign HUD shows the live ward tactic")
			await _capture(scene, "lich")
			mechanics._wards.despawn_all()
			mechanics.tick(0.0)
			_check(str(mechanics.call("army_phase")) == "" and army.stance == "swarm" and army._priority_target == null,
				"ward break clears the objective opportunity without changing stance")
		elif realm == "frozen":
			mechanics._timer = 0.0
			mechanics.tick(0.0)
			_check(str(mechanics.call("army_phase")) == "fracture", "Colossus warning uses the live fracture windup")
			scene.call("_process", 0.0)
			_check((scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("GUARD"), "real campaign HUD suggests regrouping during fracture")
			await _capture(scene, "fracture")
			mechanics.tick(FinalMechanics.FRACTURE_WINDUP)
			_check(str(mechanics.call("army_phase")) == "exposed" and boss.damage_taken == 2.0,
				"exposure starts its feedback and double damage on the actual strike frame")
			mechanics.tick(FinalMechanics.EXPOSED_TIME)
			_check(str(mechanics.call("army_phase")) == "" and boss.damage_taken == 1.0,
				"Colossus opportunity ends with the real exposure window")
			mechanics.army = null
			mechanics._timer = 0.0
			mechanics.tick(0.0)
			mechanics.tick(FinalMechanics.FRACTURE_WINDUP)
			_check(boss.damage_taken == 1.0, "Classic-linked mechanics preserve the original next-tick exposure timing")
			mechanics.tick(0.0)
			_check(boss.damage_taken == 2.0, "Classic exposure still applies on the following tick")
		else:
			_check(str(mechanics.call("army_phase")) == "sealed", "Tyrant tactic follows actual cinder seals")
			scene.call("_process", 0.0)
			_check((scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("GUARD"), "real campaign HUD pairs meteor luring with the regroup option")
			await _capture(scene, "seals")
			while mechanics.seals_left() > 0:
				mechanics._break_seals_near(mechanics._seals[0]["at"])
			mechanics.tick(0.0)
			_check(str(mechanics.call("army_phase")) == "open" and boss.damage_taken == 1.0,
				"Tyrant's attack opportunity begins after his last seal breaks")
		_check(army.stance == ("swarm" if realm == "graveyard" else "hunt"), "guardian tactics never auto-switch army stance")
		while army.count > 0:
			army._remove(army.count - 1, false, false)
		scene.call("_process", 0.0)
		_check(not (scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("SWARM") and
			not (scene.get("_hud") as Hud)._campaign_guidance_label.text.contains("GUARD"), "players without an army receive no stance instructions")
		boss.hp[0] = 0.0
		mechanics.tick(0.0)
		_check(str(mechanics.call("army_phase")) == "", "dead guardian clears its tactic phase")
		mechanics.army = army
		army.set_priority_target(mechanics._wards)
		mechanics.queue_free()
		await process_frame
		_check(army._priority_target == null, "deferred mechanic removal clears a still-living army's target priority")
		await _dispose(scene)


func _capture(scene: Node, moment: String) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			for swarm: EnemySwarm in scene.get("_swarms"):
				swarm.step(0.0, (scene.get("_player") as Player).pos2)
			(scene.get("_army") as Army).step(0.0)
			await create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--capture=") + "-" + moment + ".png"
			var image := root.get_texture().get_image()
			_check(image.get_size() == Vector2i(1280, 720), "native fixture is actually rendered at 720p")
			if moment == "binding":
				_check((scene.get("_hud") as Hud)._title_card.modulate.a > 0.5, "first-binding banner is visibly on screen at capture")
			_check(image.save_png(path) == OK, "native army fixture capture saves")
