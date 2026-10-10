extends SceneTree
## Native visual fixture, not a balance playtest. Arguments: realm output_dir
## stage (gallery/crowd/bench/threats). Uses actual Main, camera and simulation.
## Run only in an isolated project/profile. Bench excludes screenshot readbacks.
var main: Node3D
var player: Player
var realm := "graveyard"
var output := ""
var stage := "crowd"
var frame := 0
var capturing := false
var finished := false
var samples := PackedFloat64Array()
var last_tick := 0
var screenshots: Array[String] = []
var min_enemies := 100000
var max_enemies := 0
var max_shots := 0
var max_warnings := 0
var artifact_failure := false
var hero_class := "battlemage"
var legacy := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: -- <realm> <output_dir> [gallery/crowd/bench]")
		quit(1)
		return
	realm = args[0]
	output = args[1]
	stage = args[2] if args.size() > 2 else "crowd"
	hero_class = args[3] if args.size() > 3 else "battlemage"
	legacy = args.size() > 4 and args[4] == "legacy"
	if legacy:
		ProjectSettings.set_setting("visuals/imported_roster", false)
	DirAccess.make_dir_recursive_absolute(output)
	MetaProgress.disabled = true
	MetaProgress.forced_class = hero_class
	Realm.current = realm
	Realm.in_title = false
	seed(381974)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_setup.call_deferred()


func _setup() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	player = main.get_node("Player")
	player.invulnerable = true
	# RiftDirector owns the runtime invulnerability grace and otherwise clears
	# it every frame. Hold its fixture grace instead of repeatedly dying here.
	main._rift._grace = 100000.0
	player.stats.minion_max = 0 if stage == "threats" else (8 if stage == "gallery" else Army.CAPACITY)
	player.stats.minion_hp = 1000000.0
	main.get_node("WaveDirector").rate_scale = 0.0
	main.get_node("CameraRig").shake_enabled = false
	# Late realm lighting without crossing the dawn/boss-arrival boundary.
	main.elapsed = 720.0
	main.get_node("WaveDirector").elapsed = 720.0
	main.get_node("BossDirector")._next_at = 900.0
	main.get_node("Events")._timer = 100000.0
	main._rival.arrived = true
	main._rival.defeated = true
	main.get_node("Hazards")._timer = 100000.0
	# SFX cooldowns use wall time and pitch consumes global RNG. Remove that
	# nondeterminism from matched visual fixtures, not from production gameplay.
	Sound.instance = null
	for s: EnemySwarm in main._swarms:
		s.despawn_all()
		s.step(0.0, Vector2.ZERO)
	var counts := {"Grunts": 300, "Runners": 240, "Brutes": 70, "Cultists": 60,
		"Lancers": 40, "Shieldbearers": 80, "Menders": 20, "Bloaters": 40}
	for name: String in counts:
		var s := main.get_node_or_null(name) as EnemySwarm
		if s == null:
			continue
		var n := mini(int(counts[name]), s.capacity) if stage != "gallery" else (3 if name == "Grunts" else 0)
		if stage == "threats":
			n = 0
		for i in n:
			var distance := 6.0 + sqrt(float(i)) * 0.42
			var at := Vector2.from_angle(float(i) * 2.399963 + name.length()) * distance
			s.spawn(at)
		for i in s.count:
			s.hp[i] = 1000000.0
		s.step(0.0, Vector2.ZERO)
	var army := main.get_node("Army") as Army
	var grunt := main.get_node("Grunts") as EnemySwarm
	for i in player.stats.minion_max:
		army._raise(army.type_index(grunt), false, false)
		army._pos[i] = Vector2.from_angle(float(i) * 2.399963) * (2.6 + sqrt(float(i)) * 0.6)
	if army.count > 2:
		army.credit(1, 60)
		army.credit(2, 300)
	army._draw()
	Juice.time_effects = false
	if stage == "gallery":
		var camera := main.get_node("CameraRig/Camera3D") as Camera3D
		camera.position *= 0.6
	last_tick = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	if player == null or capturing or finished:
		return false
	frame += 1
	var now := Time.get_ticks_usec()
	if frame > 120:
		samples.append(float(now - last_tick) / 1000.0)
	last_tick = now
	var n: int = main._enemy_count()
	min_enemies = mini(min_enemies, n)
	max_enemies = maxi(max_enemies, n)
	max_shots = maxi(max_shots, main.get_node("EnemyShots").count)
	max_warnings = maxi(max_warnings, main.get_node("Hazards")._pending.size())
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	# Real movement and casts, rather than static cosmetic transforms.
	if stage != "threats" and frame % 240 < 90:
		Input.action_press("move_right")
	elif stage != "threats" and frame % 240 < 180:
		Input.action_press("move_left")
	if frame % 120 == 1:
		_seed_dangers()
	if stage != "bench" and frame in [45, 130, 245, 360]:
		_capture.call_deferred()
	if frame >= (600 if stage == "bench" else 420):
		_finish.call_deferred()
	return false


func _seed_dangers() -> void:
	var shots := main.get_node("EnemyShots") as EnemyShots
	if stage == "threats":
		shots.clear()
		for i in 3:
			var at := Vector2(-3.5 + i * 3.5, -4.5)
			shots.spawn(at, Vector2.DOWN, 0.0, 1.0, [Elements.FIRE, Elements.FROST, Elements.NONE][i], "Palette fixture")
		return
	for i in (24 if stage != "gallery" else 6):
		var dir := Vector2.from_angle(float(i) * TAU / (24.0 if stage != "gallery" else 6.0))
		shots.spawn(player.pos2 + dir * 7.0, -dir, 2.5, 1.0, [Elements.FIRE, Elements.FROST, Elements.NONE][i % 3], "Readability fixture")
	var hazards := main.get_node("Hazards") as HazardDirector
	for at in [player.pos2 + Vector2(2.8, 1.2), player.pos2 + Vector2(-2.5, -2.0)]:
		hazards._start(at, 1.7, 2.0, Color(1.0, 0.5, 0.15) if realm == "ember" else Color(0.55, 0.85, 1.0))


func _capture() -> void:
	capturing = true
	# macOS can restore a previous fullscreen backing surface after startup.
	# Request physical pixels through DisplayServer as well as Window and wait
	# for the resize event; never accept/downsample a wrong-size screenshot.
	for retry in 60:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame
		if root.size == Vector2i(1280, 720):
			break
	await RenderingServer.frame_post_draw
	var path := output.path_join("%s-%s-%03d.png" % [realm, stage, frame])
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720) or image.save_png(path) != OK:
		artifact_failure = true
		push_error("Readability fixture capture failed or has wrong dimensions: " + path)
	else:
		screenshots.append(path)
	last_tick = Time.get_ticks_usec()
	capturing = false


func _finish() -> void:
	if capturing or finished:
		return
	finished = true
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	var sorted := samples.duplicate()
	sorted.sort()
	var report := {"realm": realm, "stage": stage, "device": RenderingServer.get_video_adapter_name(),
		"hero_class": hero_class, "imported_class": player._visual.imported_class(),
		"legacy_baseline": legacy,
		"viewport": [root.size.x, root.size.y], "frames": frame, "sample_count": samples.size(),
		"median_frame_ms": sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0,
		"p95_frame_ms": sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0,
		"enemy_range": [min_enemies, max_enemies], "army_count": main.get_node("Army").count,
		"hero_alive": not player.dead, "hero_hp": player.stats.hp,
		"max_shots": max_shots, "max_hazard_warnings": max_warnings, "screenshots": screenshots,
		"samples_ms": samples, "limits": "Invulnerable automated hero, durable enemies and allies; SFX calls disabled for RNG parity. Not human balance evidence. Native submission/interval timing, not isolated GPU cost or a performance guarantee."}
	var expected_army := 0 if stage == "threats" else (8 if stage == "gallery" else Army.CAPACITY)
	var okay: bool = not player.dead and main.get_node("Army").count == expected_army and not artifact_failure
	okay = okay and player._visual.imported_class() == ("" if legacy else hero_class)
	okay = okay and (stage == "bench" or screenshots.size() == 4)
	report["passed"] = okay
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("COMBAT_READABILITY_QA_COMPLETE ", JSON.stringify(report))
	Elements.reset()
	Juice.reset()
	main.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	# Allow asynchronous audio retirement; this is not a production quit change.
	var end := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < end:
		await process_frame
	quit(0 if okay else 1)
