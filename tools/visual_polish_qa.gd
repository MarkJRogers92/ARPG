extends SceneTree
## Matched static Main-camera fixtures, not a gameplay/balance test.
## Args: output_dir realm [guardian|terrain]. Real combat capture uses guardian_encounter_smoke.gd.
var main: Node3D
var output := ""
var realm := "graveyard"
var stage := "guardian"
var comfort := false
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: -- output_dir [realm] [guardian|terrain] [comfort]")
		quit(1)
		return
	comfort = args.size() > 3 and args[3] == "comfort"
	output = args[0]; realm = args[1] if args.size() > 1 else "graveyard"; stage = args[2] if args.size() > 2 else "guardian"
	_run.call_deferred()
func _run() -> void:
	MetaProgress.disabled = true; Realm.current = realm; Realm.in_title = false
	seed(78133); root.size = Vector2i(1280,720)
	main = load("res://scenes/pilot/guardian_encounter.tscn" if stage == "guardian" else "res://scenes/main.tscn").instantiate()
	root.add_child(main); main._process(0.0); main.set_process(false)
	var player: Player = main.get_node("Player")
	player.position = Vector3.ZERO
	main.get_node("CameraRig").set_process(false)
	Juice.bold_telegraphs = comfort
	Juice.calm = comfort
	Sound.instance = null
	main._decor.follow(Vector2.ZERO)
	main._atmosphere.tick(10.0,0.0,false)
	if stage == "guardian":
		var swarm: GuardianSwarm = main.get_node("Guardians")
		swarm.despawn_all();swarm.step(0.0,player.pos2);swarm.spawn(Vector2(2.12132,-2.12132))
		var entry: Dictionary = swarm.visuals[swarm.ids[0]]; entry.cooldown = 0.0
		swarm.hp[0] = swarm.max_hp * 0.7
		for i in 10: swarm.step(0.05,player.pos2)
		swarm._flash[0] = 0.75; swarm.step(0.0,player.pos2)
		if main.has_method("_refresh_guardian_readout"):main._refresh_guardian_readout()
	else:
		main.get_node("Hud").hide()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var path := output.path_join(stage+"_"+realm+("_comfort" if comfort else "")+".png")
	var error := root.get_texture().get_image().save_png(path)
	print("MATCHED CAPTURE: ",path," error=",error," camera=",main.get_node("CameraRig/Camera3D").global_transform)
	main.queue_free()
	for i in 4: await process_frame
	quit(0 if error == OK else 1)
