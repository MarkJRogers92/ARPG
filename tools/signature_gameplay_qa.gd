extends SceneTree
## Bounded actual-scene encounter and same-count horde checks in one window.
## Uses the safe preview copy. Accelerated loan timing and durable horde HP
## are QA controls only; the production mechanics are exercised unchanged.
var _cases := [["graveyard", true, false], ["graveyard", false, false], ["ember", false, false], ["ember", true, true], ["ember", false, true]]
var _case := -1
var _main: Node
var _player: Player
var _ferry: Ferryman
var _collector: EnemySwarm
var _frame := 0
var _busy := true
var _output := ""
var _report := {}
var _samples := PackedFloat64Array()
var _last := 0

func _initialize() -> void:
	_output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_output)
	MetaProgress.disabled = true
	_next.call_deferred()

func _next() -> void:
	if _main != null:
		paused = false
		root.remove_child(_main)
		_main.free()
	_case += 1
	if _case >= _cases.size():
		var output := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "--script", "res://tools/tests.gd", "--log-file", _output + "/final-unit.log"], output, true)
		print("FINAL_UNIT_EXIT ", code)
		for line in output: print(line)
		quit(code)
		return
	seed(4821)
	_frame = 0
	_samples.clear()
	var realm: String = _cases[_case][0]
	var baseline: bool = _cases[_case][1]
	Realm.current = realm
	Realm.in_title = false
	_main = load("res://scenes/main.tscn").instantiate()
	if baseline:
		_main.tree_entered.connect(func() -> void:
			for child in _main.get_children():
				if child is EnemySwarm: child.specialist_model = ""
		)
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_ferry = _main._ferryman
	_collector = _main.get_node("Collectors")
	_ferry.authored_model = not baseline
	_ferry._schedule.clear()
	_main.get_node("WaveDirector").rate_scale = 0.0
	_player.invulnerable = true
	for s: EnemySwarm in get_nodes_in_group(EnemySwarm.GROUP):
		s.despawn_all(); s.step(0.0, Vector2.ZERO)
	var camera: Camera3D = _main.get_node("CameraRig/Camera3D")
	_report = {"base": "5983ee15200ad84d73601196c420876bb7999462", "realm": realm, "appearance": "procedural" if baseline else "mixed", "actual_scene": "scenes/main.tscn", "camera_fov": camera.fov, "camera_transform": str(camera.transform), "device": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "save_directory": ProjectSettings.globalize_path("user://"), "controlled_qa": true, "movie_recording": false, "screenshots": [], "checks": {}}
	if _cases[_case][2]:
		var grunts := _main.get_node("Grunts") as EnemySwarm
		for i in 1000: grunts.spawn(Vector2.from_angle(i * 2.399963) * (8.0 + sqrt(float(i)) * 0.5))
		for name in ["Shieldbearers", "Menders", "Bloaters", "Collectors"]:
			var s := _main.get_node(name) as EnemySwarm
			s.fuse_range = 0.0 # fixed populations; fuse is checked by specialist cue QA
			for i in s.capacity: s.spawn(Vector2.from_angle(i * 2.399963) * (10.0 + sqrt(float(i))), 1.0, i % 12 == 0)
		for s: EnemySwarm in get_nodes_in_group(EnemySwarm.GROUP):
			for i in s.count: s.hp[i] = 100000.0
		_main.elapsed = 400.0
		_main.get_node("WaveDirector").elapsed = 400.0
		_report["enemies_at_start"] = _main._enemy_count()
	else:
		_ferry.rng.seed = 4821
		_report.checks["visit_arrives"] = _ferry._arrive()
		# Keep the encounter visible at the actual camera, with its own light/decal.
		_ferry._visit.at = Vector2(-3.2, -3.0)
		(_ferry._visit.node as Node3D).position = Vector3(-3.2, 0, -3.0)
		_main._army._raise(0, false, false, true)
		_report.checks["minions_before"] = _main._army.count
	_last = Time.get_ticks_usec()
	_busy = false

func _process(_delta: float) -> bool:
	if _busy: return false
	_frame += 1
	_player.stats.hp = _player.stats.max_hp
	var hud := _main.get_node("Hud") as Hud
	if hud._upgrade_root.visible: hud._choose(0)
	if _cases[_case][2]:
		var now := Time.get_ticks_usec()
		if _frame > 120: _samples.append(float(now - _last) / 1000.0)
		_last = now
		var heading: String = ["move_right", "move_down", "move_left", "move_up"][(_frame / 90) % 4]
		for action: String in ["move_right", "move_down", "move_left", "move_up"]:
			if action == heading: Input.action_press(action)
			else: Input.action_release(action)
		if _frame == 100: _capture("horde")
		if _frame >= 300: _finish_case()
		return false
	if _frame == 20: _capture("ferryman")
	if _frame == 30: _ferry.open_table()
	if _frame == 32: _capture("wager")
	if _frame == 40:
		_ferry._on_chosen("borrow")
		_report.checks["loan_seconds"] = _ferry._loan_left
		_report.checks["collector_delay_seconds"] = _ferry._collector_in
		_ferry._on_chosen("leave")
		# Accelerate the wait, then exercise the real loan arrival path.
		_ferry._collector_in = 0.01
		_ferry._update_loan(0.02)
		_collector.pos[0] = Vector2(3.8, -3.8)
		_collector.hp[0] = 10000.0
		_collector.step(0.0, _player.pos2)
	if _frame == 55: _capture("collector")
	if _frame == 65: Input.action_press("move_right")
	if _frame == 95:
		Input.action_release("move_right")
		var o := 0
		var front := Vector2(-_collector._buffer[o + 2], -_collector._buffer[o + 10]).normalized()
		_report.checks["moving_front_dot_toward_hero"] = front.dot((_player.pos2 - _collector.pos[0]).normalized())
		_capture("collector_movement")
	if _frame == 110:
		_collector.pos[0] = _player.pos2 + Vector2(0.01, 0)
		_collector._fire[0] = 0.0
	if _frame == 115:
		_report.checks["minions_after_seize"] = _main._army.count
		_report.checks["away_after_seize"] = _main._army.away.size()
		_capture("seize")
	if _frame == 130: _collector.damage(0, 1.0e6)
	if _frame == 135:
		_report.checks["minions_after_collector_death"] = _main._army.count
		_report.checks["away_after_collector_death"] = _main._army.away.size()
		_capture("return")
	if _frame >= 150: _finish_case()
	return false

func _capture(label: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s_%s.png" % [_output, _report.realm, _report.appearance, label]
	var pixels := root.get_texture().get_image()
	var error := pixels.save_png(path)
	_report.screenshots.append({"cue": label, "file": path, "pixels": [pixels.get_width(), pixels.get_height()], "save_result": error})
	print("SIGNATURE_CAPTURE ", path)
	_last = Time.get_ticks_usec()
	_busy = false

func _finish_case() -> void:
	_busy = true
	for action: String in ["move_right", "move_down", "move_left", "move_up"]: Input.action_release(action)
	_report["enemies_at_end"] = _main._enemy_count()
	if not _samples.is_empty():
		_samples.sort()
		var total := 0.0
		for v in _samples: total += v
		_report["frame_ms"] = {"samples": _samples.size(), "mean": total / _samples.size(), "median": _samples[_samples.size() / 2], "p95": _samples[int(_samples.size() * 0.95)]}
	var suffix := "horde" if _cases[_case][2] else "encounter"
	var file := FileAccess.open("%s/%s_%s_%s.json" % [_output, _report.realm, _report.appearance, suffix], FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  ")); file.close()
	print("SIGNATURE_CASE_COMPLETE ", JSON.stringify(_report.get("frame_ms", _report.checks)))
	_next.call_deferred()
