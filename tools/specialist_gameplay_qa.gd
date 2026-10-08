extends SceneTree
## Actual main scene, original camera/lights/HUD and specialist coordinator.
## Controlled cue probes use invulnerability and durable targets; bench mode
## runs a moving hero through a 1,000+ enemy horde. This is QA, not a new mode.
var _main: Node
var _player: Player
var _frame := 0
var _realm := "graveyard"
var _baseline := false
var _bench := false
var _stock_rim := false
var _motion := false
var _output := ""
var _capturing := false
var _report := {}
var _samples := PackedFloat64Array()
var _last := 0
var _cues := {"block": 0, "heal": 0, "fuse": 0, "blast": 0}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_realm = args[0] if args.size() > 0 else "graveyard"
	_baseline = args.size() > 1 and args[1] == "procedural"
	_output = args[2] if args.size() > 2 else "res://build/qa"
	_bench = args.size() > 3 and args[3] == "bench"
	_motion = args.size() > 3 and args[3] == "motion"
	_stock_rim = args.size() > 4 and args[4] == "stock-rim"
	DirAccess.make_dir_recursive_absolute(_output)
	seed(4821)
	MetaProgress.disabled = true
	Realm.current = _realm
	Realm.in_title = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	# Realm.apply_gameplay runs in the parent's _enter_tree. This signal lets
	# the baseline disable only cosmetic descriptors before children's _ready.
	if _baseline:
		_main.tree_entered.connect(func() -> void:
			for child in _main.get_children():
				if child is EnemySwarm: child.specialist_model = ""
		)
	root.add_child(_main)
	current_scene = _main
	_setup.call_deferred()

func _setup() -> void:
	# Keep the QA window and UI scale consistent with the startup resolution.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_player = _main.get_node("Player")
	_player.invulnerable = true
	_main.get_node("WaveDirector").rate_scale = 0.0
	for swarm: EnemySwarm in get_nodes_in_group(EnemySwarm.GROUP):
		swarm.despawn_all()
		swarm.step(0.0, Vector2.ZERO)
	var camera: Camera3D = _main.get_node("CameraRig/Camera3D")
	_report = {"realm": _realm, "appearance": "procedural" if _baseline else "mixed", "full_game_scene": "scenes/main.tscn", "renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "camera_fov": camera.fov, "camera_transform": str(camera.transform), "viewport": [root.size.x, root.size.y], "separate_save_directory": ProjectSettings.globalize_path("user://"), "controlled_qa": true, "movie_recording": OS.has_feature("movie"), "physics_fps": Engine.physics_ticks_per_second, "probes": [], "screenshots": []}
	for name in ["Shieldbearers", "Menders", "Bloaters"]:
		var s := _main.get_node(name) as EnemySwarm
		if _stock_rim:
			var layer := s.get("_variant_layer") as MultiMeshInstance3D
			if layer != null:
				for surface in layer.multimesh.mesh.get_surface_count():
					var material := layer.multimesh.mesh.surface_get_material(surface) as ShaderMaterial
					material.set_shader_parameter("rim_color", Color(1.0, 0.55, 0.45))
					material.set_shader_parameter("rim_strength", 0.35)
		s.shield_blocked.connect(func(_at: Vector2) -> void: _cues.block += 1)
		s.mend_called.connect(func(_at: Vector2) -> void: _cues.heal += 1)
		s.fuse_lit.connect(func(_id: int, _at: Vector2) -> void: _cues.fuse += 1)
		s.detonated.connect(func(_id: int, _at: Vector2) -> void: _cues.blast += 1)
		if _baseline and s.get("_variant_layer") != null:
			push_error("Procedural benchmark still has variant batch")
			quit(2)
			return
	if _bench:
		var grunts := _main.get_node("Grunts") as EnemySwarm
		for i in 1000:
			grunts.spawn(Vector2.from_angle(float(i) * 2.399963) * (8.0 + sqrt(float(i)) * 0.5))
		for name in ["Shieldbearers", "Menders", "Bloaters"]:
			var s := _main.get_node(name) as EnemySwarm
			for i in s.capacity:
				s.spawn(Vector2.from_angle(float(i) * 2.399963) * (10.0 + sqrt(float(i))), 1.0, i % 12 == 0)
		_report["enemy_count_at_start"] = _main._enemy_count()
		_report["specialist_counts_at_start"] = {}
		for name in ["Shieldbearers", "Menders", "Bloaters"]:
			var s := _main.get_node(name) as EnemySwarm
			_report.specialist_counts_at_start[name] = s.count
			for i in s.count: s.hp[i] = 100000.0
			s.fuse_range = 0.0 # identical fixed populations for timing; fuse tested in cue mode
		for i in grunts.count: grunts.hp[i] = 100000.0
		_main.elapsed = 400.0
		_main.get_node("WaveDirector").elapsed = 400.0
	else:
		_place_pair("Shieldbearers", Vector2(-4.8, -4.5), Vector2(-2.6, -4.5))
		_place_pair("Menders", Vector2(2.8, -5.8), Vector2(5.0, -5.8))
		_place_pair("Bloaters", Vector2(-6.0, -8.0), Vector2(6.0, -8.0))
	_last = Time.get_ticks_usec()

func _place_pair(name: String, a: Vector2, b: Vector2) -> void:
	var s := _main.get_node(name) as EnemySwarm
	for p: Vector2 in [a, b]:
		s.spawn(p, 1.0, false)
		s.hp[s.count - 1] = 10000.0 # durable cue targets; production stats unchanged
		MultiMeshUtil.set_facing(s._buffer, (s.count - 1) * 20, -p.normalized())

func _process(_delta: float) -> bool:
	if _player == null or _capturing: return false
	_frame += 1
	if _bench: _player.stats.hp = _player.stats.max_hp # keep the benchmark alive
	var now := Time.get_ticks_usec()
	if _bench and _frame > 120:
		_samples.append(float(now - _last) / 1000.0)
	_last = now
	if _motion:
		_player.stats.hp = _player.stats.max_hp
		Input.action_press("move_right")
		if _frame % 30 == 0:
			for name in ["Shieldbearers", "Menders", "Bloaters"]:
				var s := _main.get_node(name) as EnemySwarm
				for i in s.count:
					var o := i * 20
					var forward := Vector2(-s._buffer[o + 2], -s._buffer[o + 10]).normalized()
					_report.probes.append({"cue": "travel", "role": name, "frame": _frame, "appearance": int(s._appearance[i]) if not s._appearance.is_empty() else 0, "position": [s.pos[i].x, s.pos[i].y], "hero": [_player.pos2.x, _player.pos2.y], "forward_dot_toward_hero": forward.dot((_player.pos2 - s.pos[i]).normalized())})
		if _frame == 180: _capture("movement")
		if _frame >= 300: _finish()
		return false
	var hud := _main.get_node("Hud") as Hud
	if hud._upgrade_root.visible: hud._choose(0)
	if _bench:
		var heading: String = ["move_right", "move_down", "move_left", "move_up"][(_frame / 180) % 4]
		for action: String in ["move_right", "move_down", "move_left", "move_up"]:
			if action == heading: Input.action_press(action)
			else: Input.action_release(action)
		if _frame == 100: _capture("horde")
		if _frame >= 360: _finish()
		return false
	if _frame == 45: _capture("combat")
	if _frame == 80:
		var shields := _main.get_node("Shieldbearers") as EnemySwarm
		for i in shields.count:
			shields._block_ready = 0
			Elements.source = "Magic Bolt"
			var hp0 := shields.hp[i]
			Elements.hit(shields, i, 5.0)
			_report.probes.append({"cue": "block", "appearance": int(shields._appearance[i]) if not shields._appearance.is_empty() else 0, "damage": hp0 - shields.hp[i], "expected_damage": 5.0 * shields.direct_taken})
	if _frame == 81: _capture("block")
	if _frame == 130:
		var shields := _main.get_node("Shieldbearers") as EnemySwarm
		for i in shields.count: shields.hp[i] = shields.max_hp * 0.5
		var menders := _main.get_node("Menders") as EnemySwarm
		for i in menders.count: menders._fire[i] = 0.0
	if _frame == 132: _capture("heal")
	if _frame == 170:
		for name in ["Shieldbearers", "Menders"]:
			var s := _main.get_node(name) as EnemySwarm
			for i in s.count:
				Elements.source = "Other"
				Elements.hit(s, i, 0.25, Elements.FROST if i == 0 else Elements.FIRE)
	if _frame == 172: _capture("status")
	if _frame == 210: Input.action_press("move_right")
	if _frame == 280:
		Input.action_release("move_right")
		_capture("movement")
	if _frame == 340:
		var s := _main.get_node("Bloaters") as EnemySwarm
		s.despawn_all()
		s.step(0.0, _player.pos2)
		var p := _player.pos2
		_place_pair("Bloaters", p + Vector2(-0.75, 0), p + Vector2(0.75, 0))
	if _frame == 355: _capture("fuse")
	if _frame == 406: _capture("blast")
	if _frame >= 430: _finish()
	return false

func _capture(label: String) -> void:
	_capturing = true
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s_%s.png" % [_output, _realm, "procedural" if _baseline else "mixed", label]
	var pixels := root.get_texture().get_image()
	var result := pixels.save_png(path)
	_report.screenshots.append({"cue": label, "path": path, "save_result": result, "frame": _frame, "pixels": [pixels.get_width(), pixels.get_height()]})
	print("FULL_GAME_CAPTURE ", path)
	_capturing = false
	_last = Time.get_ticks_usec()

func _finish() -> void:
	for action: String in ["move_right", "move_down", "move_left", "move_up"]: Input.action_release(action)
	_report["cues"] = _cues
	_report["enemy_count_at_end"] = _main._enemy_count()
	_report["body_batches"] = []
	for name in ["Shieldbearers", "Menders", "Bloaters"]:
		var s := _main.get_node(name) as EnemySwarm
		var layer := s.get("_variant_layer") as MultiMeshInstance3D
		_report.body_batches.append({"role": name, "capacity": s.capacity, "count": s.count, "old": s.multimesh.visible_instance_count, "new": layer.multimesh.visible_instance_count if layer != null else 0})
	if not _samples.is_empty():
		_samples.sort()
		var total := 0.0
		for t in _samples: total += t
		_report["frame_ms"] = {"samples": _samples.size(), "mean": total / _samples.size(), "median": _samples[_samples.size() / 2], "p95": _samples[int(_samples.size() * 0.95)]}
	var file := FileAccess.open("%s/%s_%s%s.json" % [_output, _realm, "procedural" if _baseline else "mixed", "_bench" if _bench else ("_motion" if _motion else "_cues")], FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	file.close()
	print("FULL_GAME_QA_COMPLETE ", JSON.stringify(_report.get("frame_ms", _cues)))
	quit()
