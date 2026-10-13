extends SceneTree
## Real death/report/navigation integration in an isolated profile.
## Fixtures weaken starting HP to exercise existing guardian sword / Ogre contact.
## End-to-end fixtures never emit died or inject a killing take_damage call.
## Separate unit cases do directly check Player.take_damage accounting.
var checks := 0
var failures := 0
var main: Node3D
var output := ""

func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true
	RunSave.path = "user://postmortem-test.run"
	CampaignSave.path = "user://postmortem-test.campaign"
	MetaProgress.save_path = "user://postmortem-test.profile"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	root.size = Vector2i(1280,720)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _unit_checks() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	p.stats.hp = 30.0
	p.stats.armor = 0.0
	p.combat_time = 1.0
	p.invulnerable = true
	p.take_damage(20.0, "Blocked")
	check(p.recent_damage.is_empty(), "invulnerability records no incoming damage")
	p.invulnerable = false
	p.take_damage(-5.0, "Invalid")
	p.take_damage(NAN, "Invalid")
	check(p.stats.hp == 30.0 and p.recent_damage.is_empty(), "negative/NaN input cannot heal or poison damage report")
	p.take_damage(5.0, " ")
	p.combat_time = 1.2
	p.take_damage(5.0, " ")
	check(p.recent_damage.size() == 1 and p.recent_damage[0]["damage"]["Unknown source"] == 10.0, "same half-second contact ticks aggregate with an honest unknown source")
	p.combat_time = 1.6
	p.take_damage(999.0, "Ogre Warlord's slam")
	check(p.dead and p.recent_damage.size() == 2 and p.recent_damage[-1]["damage"]["Ogre Warlord's slam"] == 20.0, "fatal overkill records only applied remaining HP")
	var saved := p.recent_damage.duplicate(true)
	p.take_damage(999.0,"After death")
	check(p.recent_damage == saved, "duplicate post-death calls cannot add damage")
	var summary := DeathRecap.recent_summary(saved, 1.6)
	check(summary["trail"].contains("30.0 HP") and summary["takeaway"].contains("67%"), "recent total/share uses real applied HP")
	check(DeathRecap.summary({}, "", true).contains("Unknown source") and not DeathRecap.summary({}, "", true).contains("Untouched"), "empty death report does not invent a killer or claim untouched")
	check(DeathRecap.ranked({"bad": INF, "negative": -1.0, "ok": 2.0}).size() == 1, "invalid legacy totals are ignored")
	check(DeathRecap.recent_snapshot([{}, {"at":INF}, {"at": 0.0, "damage": "bad"}],2.0).is_empty(), "malformed optional save history is ignored")
	var bounded: Array[Dictionary] = []
	for i in 500:
		for k in 25: DeathRecap.record_recent(bounded, float(i)/10.0, "Source %d" % k, 1.0)
	check(bounded.size() <= DeathRecap.RECENT_BINS, "history memory stays bounded in continuous crowds")
	check(bounded.all(func(row: Dictionary) -> bool: return row["damage"].size() <= DeathRecap.RECENT_CAUSES), "per-bucket sources remain bounded without losing their grouped damage")
	check(DeathRecap.recent_snapshot(bounded, 70.0).is_empty(), "old damage expires instead of masquerading as a recent threat")
	p.dead = false
	p.stats.hp = 100.0
	p.stats.armor = 25.0
	p.recent_damage.clear()
	var expected_damage := 12.0 * p.stats.damage_taken_factor()
	p.combat_time = 2.0
	p.take_damage(12.0, "Armored sample")
	check(is_equal_approx(p.recent_damage[0]["damage"]["Armored sample"], expected_damage), "recent history records damage after real armor mitigation")
	var chart := DeathRecap.new()
	chart.show_samples([Vector3(0.02,1,1), Vector3(0.02,0,1)] as Array[Vector3])
	check(not chart.visible, "instant death cannot display an invented one-second health timeline")
	chart.show_samples([Vector3(0,1,1), Vector3(2,0,1)] as Array[Vector3])
	check(chart.visible, "actual elapsed health samples still show a timeline")
	chart.free()
	var ledger := CombatLedger.new()
	ledger.tick(0.02, ["Magic Bolt"])
	ledger.record("Magic Bolt", 25.0)
	check(CombatLedger.summary(ledger.report()).contains("0.02 s sample") and CombatLedger.summary(ledger.report()).contains("DPS not shown"), "sub-second output does not round denominator to misleading zero seconds")
	p.free()

func _new_main(guardian: bool) -> void:
	Realm.current = "graveyard"
	Realm.in_title = false
	Realm.daily = false
	main = load("res://scenes/pilot/guardian_encounter.tscn" if guardian else "res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._player.stats.hp = 8.0 if guardian else 0.1
	if not guardian:
		var grunts: EnemySwarm = main.get_node("Brutes")
		grunts.spawn(main._player.pos2)

func _wait_for_recap() -> void:
	for frame in 1200:
		await process_frame
		if main._hud._game_over_root.visible:
			for i in 5: await process_frame
			return
	check(false, "real enemy death reaches the end screen within 20 simulated seconds")

func _check_recap(cause: String) -> void:
	var p: Player = main._player
	var h: Hud = main._hud
	check(p.dead and main._game_over and h._game_over_root.visible, "actual death completes the report flow")
	check(p.last_cause == cause and h._recap_label.text.contains("SLAIN BY:  " + cause), "real damage source reaches killing-blow text: " + cause)
	var recorded := DeathRecap.recent_summary(p.recent_damage, main.elapsed)
	check(h._recent_damage_label.text == recorded["trail"] and h._takeaway_label.text == recorded["takeaway"], "visible recent trail/takeaway match recorded telemetry")
	check(h._report.text.contains("%d total" % int(Elements.metrics.report()["total"])), "outgoing report matches final actual non-overkill damage")
	check(root.get_visible_rect().encloses(h._restart_button.get_global_rect()), "restart action is fully on-screen at 720p")
	check(not h._recap_scroll.is_ancestor_of(h._restart_button), "end actions are outside the clipped report scroll")
	check(h._recap_scroll.scroll_vertical == 0, "fresh report opens at its cause-of-death heading")
	check(h._recap_scroll.get_global_rect().encloses(h._recap_label.get_global_rect()), "cause of death is initially visible")
	var before := [main._death_shards, MetaProgress.shards, main._dying, h._report.text]
	main._on_player_died()
	main._on_player_died()
	check(before == [main._death_shards, MetaProgress.shards, main._dying, h._report.text], "duplicate death notification cannot settle or restart the report")

func _capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "rendered capture saves: " + name)

func _clear_scene() -> void:
	if is_instance_valid(current_scene): current_scene.queue_free()
	current_scene = null
	main = null
	for i in 4: await process_frame

func _run() -> void:
	seed(78133)
	_unit_checks()
	await process_frame
	_new_main(true)
	await _wait_for_recap()
	_check_recap("Soulforged Guardian")
	await _capture("guardian_postmortem")
	var h: Hud = main._hud
	await _action("ui_up")
	check(h._recap_scroll.has_focus(), "keyboard/controller Up enters report from sticky actions")
	await _action("ui_down")
	check(h._recap_scroll.scroll_vertical > 0, "focused report scrolls with directional input")
	await _action("ui_cancel")
	check(h._restart_button.has_focus() and h._game_over_root.visible and not paused, "Cancel returns focus without dismissing death or opening Pause")
	await _capture("guardian_postmortem_scrolled")
	h._restart_button.pressed.emit()
	h._restart_button.pressed.emit() # repeated activation before deferred reload
	for i in 4: await process_frame
	main = current_scene
	check(main.has_node("Guardians"), "Rise again reloads the same opt-in encounter")
	check(not main._player.dead and main._player.recent_damage.is_empty() and main._player.damage_taken_by.is_empty(), "new run starts without stale death/damage")
	main._player.stats.hp = 8.0
	await _wait_for_recap()
	_check_recap("Soulforged Guardian")
	main._hud.realms_pressed.emit()
	for i in 4: await process_frame
	main = current_scene
	check(main._in_title and not main.has_node("Guardians"), "guardian Choose realm reaches the normal title")
	await _capture("returned_to_title")
	await _clear_scene()
	_new_main(false)
	await _wait_for_recap()
	_check_recap(main.get_node("Brutes").display_name)
	check(not main._hud._recap_label.text.contains("Soulforged"), "regular-enemy report cannot inherit prior guardian cause")
	await _capture("regular_enemy_postmortem")
	await _long_report_layout()
	# Old optional fields must clear on reusing a report widget too.
	main._hud.set_recap("Victory", [] as Array[Vector3])
	check(not main._hud._recent_damage_label.visible and not main._hud._takeaway_label.visible, "victory/legacy recap clears prior recent details")
	await _clear_scene()
	await _save_checks()
	await _campaign_checks()
	print("POSTMORTEM: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _long_report_layout() -> void:
	# Explicit synthetic layout stress; never presented as real combat telemetry.
	var h: Hud = main._hud
	var original := h._report.text
	h._report.text = "Long report layout stress row\n".repeat(40)
	for i in 3: await process_frame
	h._recap_scroll.scroll_vertical = 100000
	for i in 3: await process_frame
	check(h._recap_scroll.scroll_vertical > 500 and root.get_visible_rect().encloses(h._restart_button.get_global_rect()), "long reports scroll without moving or clipping actions")
	h.hide_end()
	h._report.text = original
	h.show_game_over(main.elapsed, main.kills, main._player.stats.level)
	for i in 3: await process_frame
	check(h._recap_scroll.scroll_vertical == 0 and h._restart_button.has_focus(), "reopening a report resets scroll and keyboard action focus")
	h._endless_button.show()
	h._code_button.show()
	for i in 3: await process_frame
	check(root.get_visible_rect().encloses(h._code_button.get_global_rect()) and root.get_visible_rect().encloses(h._endless_button.get_global_rect()), "victory plus daily-code four-action footer fits at 720p")
	h._endless_button.hide()
	h._code_button.hide()

func _save_checks() -> void:
	_new_main(false)
	main.set_process(false)
	for swarm: EnemySwarm in main._swarms: swarm.despawn_all()
	var p: Player = main._player
	p.stats.hp = p.stats.max_hp
	main.elapsed = 25.0
	p.combat_time = 25.0
	p.take_damage(5.0, "Ice Wraith")
	var expected := p.recent_damage.duplicate(true)
	check(RunSave.write(main.capture()), "suspend writes optional recent report data to real isolated disk save")
	var saved := RunSave.read()
	check(saved["recent_damage"] == expected and saved["version"] == 1, "save version stays compatible and keeps telemetry")
	await _clear_scene()
	_new_main(false)
	main.set_process(false)
	main._restore(saved)
	check(main._player.recent_damage == expected and main._player.combat_time == 25.0, "resume restores damage history on the combat clock")
	saved.erase("recent_damage")
	main._restore(saved)
	check(main._player.recent_damage.is_empty(), "old version-1 save loads with explicitly empty recent history")
	RunSave.clear()
	await _clear_scene()

func _campaign_checks() -> void:
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 871301).get("ok", false), "disposable campaign created")
	controller.free()
	var shell := load("res://scenes/campaign.tscn").instantiate() as CampaignShell
	root.add_child(shell)
	current_scene = shell
	await process_frame
	controller = shell.controller
	var routes: Array = controller.available_routes()
	check(not routes.is_empty(), "campaign offers a route")
	if routes.is_empty(): await _clear_scene(); return
	check(controller.choose_route(str(routes[0]["id"])).get("ok", false), "campaign route commits")
	if controller.state["phase"] == "EVENT_PENDING":
		var event: String = controller.state["event"].get("id", "")
		check(controller.resolve_event("gold" if event in ["ash_map", "loaded_passage"] else "leave").get("ok", false), "route event resolves")
	var departure := controller.depart()
	check(departure.get("ok", false), "campaign departs through real controller")
	if not departure.get("ok", false): await _clear_scene(); return
	shell._mount_combat(departure["spec"])
	main = shell._view
	main._player.stats.hp = 0.1
	main.get_node("Brutes").spawn(main._player.pos2)
	for frame in 1200:
		await process_frame
		if controller.state["phase"] == "RESULT_PENDING": break
	check(controller.state["phase"] == "RESULT_PENDING", "real campaign enemy death returns to pending town report")
	var result: Dictionary = controller.state.get("result", {}).duplicate(true)
	check(result.get("outcome") == "failure" and result.get("report", {}).get("last_cause") == "Ogre", "campaign failure records actual enemy cause")
	check(not result.get("report", {}).get("recent_damage", []).is_empty(), "campaign settlement carries final damage history")
	check(result.get("gold", -1) == 0 and result.get("talent_points", -1) == 0, "death report cannot grant success rewards")
	await _capture("campaign_postmortem")
	await _clear_scene()
	shell = load("res://scenes/campaign.tscn").instantiate() as CampaignShell
	root.add_child(shell)
	current_scene = shell
	await process_frame
	controller = shell.controller
	check(controller.state.get("phase") == "RESULT_PENDING" and controller.state.get("result") == result, "pending report survives closing/reopening campaign from disk")
	var town: Node = shell._view
	var buttons := town.find_children("*", "Button", true, false)
	var continue_button: Button
	for button: Button in buttons:
		if button.text == "Continue to town": continue_button = button; break
	check(continue_button != null, "after-action report has a real Continue action")
	if continue_button:
		continue_button.grab_focus()
		for i in 3: await process_frame
		check((town._content.get_parent() as ScrollContainer).get_global_rect().encloses(continue_button.get_global_rect()), "keyboard focus scrolls Continue fully into the campaign report viewport")
		continue_button.pressed.emit()
		await process_frame
		check(controller.state.get("phase") == "DEPARTURE_READY" and shell._view is CampaignTown, "Continue returns to hub with the failed route still committed")
	await _capture("campaign_returned_to_hub")
	check(not controller.settle(result).get("ok", false), "duplicate stale campaign result cannot pay or reopen a completed report")
	await _clear_scene()
