extends SceneTree
## Paired shrine contracts through real Main / EventDirector. No permanent rewards.
var checks := 0
var failures := 0
var main: Node
var events: EventDirector
var player: Player
var output := ""
var grants := 0
func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true
	RunSave.pending = {}
	RunSave.path = "user://crossroads-test.run"
	Realm.in_title = false; Realm.daily = false; Realm.current = "graveyard"
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func _capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "rendered " + name)
func _clear_events() -> void:
	for e: Dictionary in events._events: e["node"].queue_free()
	events._events.clear()
	events._refresh_discovery_prompt(player.pos2)
func _new_pair() -> Dictionary:
	_clear_events()
	check(events._start_crossroads(Vector2(0,-7)), "pair creates in a clear fixture")
	return events._events[-1]
func _run() -> void:
	seed(81713)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	main.set_process(false)
	await process_frame
	player = main._player; events = main._events
	player.invulnerable = true
	# Collision fixtures are separate from the real-terrain render/gameplay run.
	Obstacles.clear()
	events.announced.connect(func(text: String, _color: Color) -> void:
		if text.begins_with("Blessing of "): grants += 1)
	var e := _new_pair()
	var first: Dictionary = e["choices"][0]
	var second: Dictionary = e["choices"][1]
	check(first["blessing"] != second["blessing"] and e["choices"].size() == 2, "two distinct known blessings")
	check(first["at"].distance_to(second["at"]) > events.shrine_radius * 2.0, "choice circles cannot overlap")
	check(not events._start_crossroads(Vector2(10,10)) and events._events.size() == 1, "one pair cap prevents accumulating extra nodes")
	check(events.markers().size() == 1 and events.markers()[0]["label"] == "CHOOSE A BLESSING", "one shared discovery marker")
	var before_shards: int = main._run_shards
	var before_skill := player.skills.points
	var before_blessing := events.blessing
	player.position = Vector3((first["at"]).x,0,(first["at"]).y)
	events._update_events(1.0)
	check(first["charge"] > 0.0 and first["charge"] < 1.0 and events.blessing == before_blessing, "partial charge grants nothing")
	check(events.discovery_prompt.contains(first["blessing"].to_upper()) and events.discovery_prompt.contains("Hold 2.5 s"), "nearby cue states chosen effect and exact rounded charge time")
	var partial: float = first["charge"]
	player.position = Vector3((second["at"]).x,0,(second["at"]).y)
	events._update_events(0.5)
	check(first["charge"] < partial and second["charge"] > 0.0 and grants == 0, "changing sides decays abandoned progress with no reward")
	var parent: Node3D = e["node"]
	for i in 8: events._update_events(0.5)
	check(events._events.is_empty() and grants == 1 and events.blessing == second["blessing"], "exactly one selected blessing commits and removes both options")
	check(is_equal_approx(events.blessing_left, events.blessing_time), "choice grants the existing duration")
	check(main._run_shards == before_shards and player.skills.points == before_skill and events.shards == 0, "no extra currency or permanent advancement")
	check(events.discovery_prompt.is_empty() and events.markers().is_empty(), "choice removes prompt and marker")
	check(events._update_crossroads(e,first["at"],10.0) and grants == 1, "reentrant/stale event cannot grant the other blessing")
	await process_frame
	check(not is_instance_valid(parent), "both altar trees free after completion")
	var mods := player.stats._mods.filter(func(m: Dictionary) -> bool: return m["source"] == "shrine")
	check(mods.size() == EventDirector.BLESSINGS[second["blessing"]]["mods"].size(), "only selected shrine modifiers are active")
	events._update_blessing(events.blessing_time + 0.1)
	check(events.blessing.is_empty() and player.stats._mods.all(func(m: Dictionary) -> bool: return m["source"] != "shrine"), "blessing expires through existing cleanup")
	for repeat in 3:
		e = _new_pair()
		first = e["choices"][0]
		player.position = Vector3((first["at"]).x,0,(first["at"]).y)
		var snapshot: float = first["charge"]
		paused = true
		for i in 3: await process_frame
		check(first["charge"] == snapshot, "pausing cannot charge the choice")
		paused = false
		player.dead = true
		events._update_events(1.0)
		check(first["charge"] == snapshot, "dead player cannot complete a choice")
		player.dead = false
		player.position = Vector3((Vector2(50,50)).x,0,(Vector2(50,50)).y)
		e["age"] = 90.01
		parent = e["node"]
		events._update_events(0.0)
		await process_frame
		check(events._events.is_empty() and not is_instance_valid(parent), "expired pair frees both altars on repeated runs")
	check(grants == 1, "expiry/death/pauses never add a grant")
	# An obstructed footprint must be rejected, without allocating any nodes.
	Obstacles.set_circles([[Vector2.ZERO,20.0]],Rect2(-30,-30,60,60))
	var children := events.get_child_count()
	check(not events._start_crossroads(Vector2.ZERO) and events.get_child_count() == children, "blocked pair sites allocate nothing")
	Obstacles.clear()
	# Existing single-shrine and authored recovery path stay single and predictable.
	events._start_shrine(Vector2.ZERO,"Warding")
	check(events._events.size() == 1 and events._events[0]["kind"] == "shrine" and events._events[0]["blessing"] == "Warding", "authored Warding remains a single shrine")
	_clear_events()
	events.configure_opportunity({},"test-opportunity")
	check(events.start_opportunity() and events._events.size() == 1 and events._events[0].get("opportunity",false), "campaign recovery remains the authored single reward")
	check(not events.start_opportunity(), "campaign opportunity remains idempotent")
	_clear_events()
	# Exercise the real random-event selection path, not only the constructor.
	var found := false
	for i in 20:
		_clear_events()
		events._start_random()
		if events._events.any(func(row: Dictionary) -> bool: return row["kind"] == "crossroads"):
			found = true; break
	check(found,"normal random-event path can produce a paired discovery")
	_clear_events()
	# Visual fixture retains real terrain/obstacles and the actual Main camera.
	player.position = Vector3((Vector2.ZERO).x,0,(Vector2.ZERO).y)
	main._decor._center = Vector2i(99999,99999)
	main._decor.follow(player.pos2)
	var placed := false
	for i in 40:
		var at := events._clear_spot(7.0,11.0,events.shrine_radius + 0.5)
		if at != Vector2.INF and events._start_crossroads(at): placed = true; break
	check(placed,"pair has reachable clear footprints in real generated terrain")
	if placed:
		e = events._events[-1]
		for choice: Dictionary in e["choices"]:
			check(not Obstacles.blocked(choice["at"],events.shrine_radius+0.5),"real shrine footprint avoids solid scenery")
		main._process(0.0)
		for child in main._hud._toasts.get_children(): child.queue_free()
		for i in 60: await process_frame
		await _capture("crossroads_discovery")
		first = e["choices"][0]
		player.position = Vector3((first["at"]).x,0,(first["at"]).y)
		for i in 50: main._process(1.0/60.0)
		for i in 60: await process_frame
		await _capture("crossroads_holding")
		check(main._hud._prompt_label.text.contains(first["blessing"].to_upper()),"actual Main surfaces event guidance")
	var snapshot: Dictionary = main.capture()
	check(RunSave.write(snapshot), "active choice can suspend through existing version-1 save")
	var saved := RunSave.read()
	check(saved["version"] == 1 and RunSave.lasting_mods(player.stats).all(func(m: Dictionary) -> bool: return m["source"] != "shrine"), "transient blessing does not enter lasting save modifiers")
	main.queue_free()
	for i in 4: await process_frame
	RunSave.pending = saved
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	main.set_process(false)
	await process_frame
	check(main._events._events.is_empty() and main._events.blessing == "" and main._player.warding_charge_left == 0.0, "actual resumed scene does not resurrect transient choices or charges")
	check(is_equal_approx(main.elapsed, float(saved["elapsed"])), "resume keeps combat clock without replaying a choice reward")
	main.queue_free()
	for i in 4: await process_frame
	print("CROSSROADS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
