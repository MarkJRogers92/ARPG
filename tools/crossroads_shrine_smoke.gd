extends SceneTree
## Normal Main, actual movement/charging and enemy combat. Only event arrival is
## accelerated near spawn for this bounded demonstration; stats/rewards unchanged.
var main: Node
var player: Player
var events: EventDirector
var pair: Dictionary
var first: Dictionary
var second: Dictionary
var frame := 0
var phase := 0
var hold := 0
var granted := false
var grant_count := 0
var chosen := ""
var done := false
var output := ""
var captures := false
func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true
	MetaProgress.settings["shake"] = false
	RunSave.pending = {}; RunSave.path = "user://crossroads-smoke.run"
	Realm.in_title = false; Realm.daily = false; Realm.current = "graveyard"
	root.size = Vector2i(1280,720)
	seed(418511)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_start.call_deferred()
func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	player = main._player; events = main._events
	for i in 40:
		var at := events._clear_spot(7.0,11.0,events.shrine_radius + 0.5)
		if at != Vector2.INF and events._start_crossroads(at): break
	if events._events.is_empty():
		push_error("FAIL: no valid paired site in this seed"); quit(1); return
	pair = events._events[-1]
	first = pair["choices"][0]; second = pair["choices"][1]
	chosen = second["blessing"]
	events.announced.connect(func(text: String, _color: Color) -> void:
		if text.begins_with("Blessing of "):
			granted = true; grant_count += 1)
	print("SMOKE CHOICES: ",first["blessing"]," ",first["at"]," / ",chosen," ",second["at"])
func _process(_delta: float) -> bool:
	if main == null or done: return false
	frame += 1
	for action in ["move_left","move_right","move_up","move_down","dash"]: Input.action_release(action)
	if main._hud._upgrade_root.visible: main._hud._choose(0)
	if frame > 90:
		match phase:
			0:
				_walk(first["at"])
				if first["charge"] >= 0.22:
					phase = 1
					_capture.call_deferred("crossroads_first_considered")
			1:
				_walk(second["at"])
				if second["charge"] >= 0.35:
					phase = 2
					_capture.call_deferred("crossroads_chosen_holding")
			2:
				_walk(second["at"])
				if granted:
					phase = 3
					_capture.call_deferred("crossroads_reward_received")
			3:
				hold += 1
				if hold > 180: _finish.call_deferred()
	if player.dead or frame > 2400: _finish.call_deferred()
	return false
func _walk(at: Vector2) -> void:
	var direction := at - player.pos2
	if direction.length() < 0.35: return
	direction = direction.normalized()
	Input.action_press("move_right" if direction.x >= 0.0 else "move_left",absf(direction.x))
	Input.action_press("move_down" if direction.y >= 0.0 else "move_up",absf(direction.y))
func _capture(name: String) -> void:
	if output == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _finish() -> void:
	if done: return
	done = true
	for action in ["move_left","move_right","move_up","move_down","dash"]: Input.action_release(action)
	var passed := phase == 3 and grant_count == 1 and not player.dead and events.blessing == chosen and bool(pair["claimed"]) and events.discovery_prompt.is_empty()
	var result := {"passed":passed,"frames":frame,"seconds":main.elapsed,"hero_hp":player.stats.hp,"kills":main.kills,"chosen":chosen,"grants":grant_count,"blessing":events.blessing,"blessing_seconds_left":events.blessing_left,"changed_choice":phase==3,"main_camera":str(main.get_node("CameraRig/Camera3D").get_path()),"accelerated_arrival":true,"invulnerable":player.invulnerable}
	print("CROSSROADS MAIN SMOKE: ",JSON.stringify(result))
	if output != "":
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("crossroads_smoke.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"));file.close()
	main.queue_free()
	for i in 4: await process_frame
	quit(0 if passed else 1)
