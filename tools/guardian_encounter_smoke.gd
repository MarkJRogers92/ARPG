extends SceneTree
## Actual Main-loop bot/capture. No direct enemy damage, presentation requests,
## camera changes or injected rewards. The normal player weapons do the fighting.
var main: Node3D
var swarm: GuardianSwarm
var player: Player
var frame := 0
var max_frames := 60 * 90
var guardian_kills := 0
var blade_contacts := 0
var blade_damage := 0.0
var contact_frames: Array[int] = []
var incoming_hits := 0
var states := {}
var seen_ids := {}
var max_visuals := 0
var max_deaths := 0
var output := ""
var finishing := false
var dodge_frames := 0
var dodged_swings := {}
var dodge_attempts := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: max_frames = int(float(args[0]) * 60)
	if args.size() > 1: output = args[1]
	seed(78133)
	root.size = Vector2i(1280,720)
	_start.call_deferred()

func _start() -> void:
	main = load("res://scenes/pilot/guardian_encounter.tscn").instantiate()
	root.add_child(main)
	swarm = main.get_node("Guardians")
	player = main.get_node("Player")
	swarm.enemy_died.connect(func(_at: Vector2, _xp: int): guardian_kills += 1)
	swarm.sword_contact.connect(func(_id: int, _swing: int, applied: float):
		blade_contacts += 1
		contact_frames.append(frame)
		blade_damage += applied)

func _process(_delta: float) -> bool:
	if main == null or finishing: return false
	frame += 1
	# Take an initial real contact, then react to subsequent visible windups.
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("dash")
	for id: int in swarm.visuals:
		var actor: Node3D = swarm.visuals[id].actor
		var key := "%d:%d" % [id,actor.swing_id]
		if blade_contacts > 0 and actor.state == &"Attack" and actor.state_elapsed >= 0.18 and actor.state_elapsed < 0.35 and not dodged_swings.has(key):
			dodged_swings[key] = true
			dodge_attempts += 1
			dodge_frames = 30
			Input.action_press("dash")
	if dodge_frames > 0:
		Input.action_press("move_left")
		dodge_frames -= 1
	var hud: Hud = main.get_node("Hud")
	if hud._upgrade_root.visible: hud._choose(0)
	for id: int in swarm.visuals:
		seen_ids[id] = true
		var actor: Node3D = swarm.visuals[id].actor
		states[str(actor.state)] = true
		if actor.state == &"Hit": incoming_hits += 1
	for actor: Node3D in swarm.corpses: states[str(actor.state)] = true
	if output != "" and DisplayServer.get_name() != "headless" and frame in [90, 150, 175, 210, 270, 330, 700, 1000]:
		_save_frame.call_deferred(frame)
	max_visuals = maxi(max_visuals, swarm.visuals.size())
	max_deaths = maxi(max_deaths, swarm.corpses.size())
	if frame >= max_frames or main._game_over:
		finishing = true
		_finish.call_deferred()
	return false

func _finish() -> void:
	for action: String in ["move_left","move_right","dash"]: Input.action_release(action)
	var result := {"frames": frame, "seconds": main.elapsed, "guardian_kills": guardian_kills, "distinct_guardian_ids": seen_ids.size(), "blade_contacts": blade_contacts, "blade_damage": blade_damage, "dodge_attempts": dodge_attempts, "contact_frames": contact_frames, "hit_pose_frames": incoming_hits, "states": states.keys(), "max_live_visuals": max_visuals, "max_death_visuals": max_deaths, "main_kills": main.kills, "hero_hp": player.stats.hp, "hero_level": player.stats.level, "hero_dead": player.dead, "camera": str(main.get_node("CameraRig/Camera3D").get_path()), "asset_sha256": FileAccess.get_sha256("res://assets/meshy_pilot/guardian_one_hand.glb")}
	var passed: bool = guardian_kills >= 1 and seen_ids.size() >= 2 and blade_contacts >= 1 and incoming_hits > 0 and states.has("Walk") and states.has("Attack") and states.has("Death") and max_visuals <= 1 and max_deaths <= 3 and dodge_attempts > 0 and not player.dead
	result.passed = passed
	print("GUARDIAN MAIN SMOKE: ", JSON.stringify(result))
	if output != "":
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("guardian_main_smoke.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("guardian_main_camera.png"))
	main.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _save_frame(index: int) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % index))
