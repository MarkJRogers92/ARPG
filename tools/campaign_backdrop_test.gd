extends SceneTree
## Standalone art fixture: no controller, account, scene or save is opened.
## godot --path . -s tools/campaign_backdrop_test.gd -- /absolute/output/folder
## Headless invocation checks state changes without producing images.

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "res://work/backdrop-captures"
	var capture := DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var backdrop := CampaignBackdrop.new()
	# Exercise the public API before the node has built its 3D world.
	var state := {"biome_index": 1, "completed": false, "untouched": [1, 2]}
	var before := state.duplicate(true)
	backdrop.present(state)
	root.add_child(backdrop)
	var viewport := backdrop.get_child(0) as SubViewport
	viewport.transparent_bg = false
	_check(state == before, "Backdrop must never mutate campaign state")
	_check(backdrop._journey.has_node("LichKingCrown"), "Pre-ready progress must display the first guardian trophy")
	var journey := backdrop._journey
	backdrop.present(state)
	_check(backdrop._journey == journey, "Repeated presentation must not rebuild the scene")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		backdrop.size = resolution
		for stage in 4:
			backdrop.set_progress(mini(stage, 2), stage == 3)
			backdrop._clock = 3.0
			backdrop.set_process(false)
			backdrop._process(0.0)
			_check(backdrop._journey.has_node("LichKingCrown") == (stage >= 1), "Lich trophy timing")
			_check(backdrop._journey.has_node("FrostColossusHeart") == (stage >= 2), "Frost trophy timing")
			_check(backdrop._journey.has_node("RestoredLanternArch") == (stage == 3), "Restoration must appear only at victory")
			_check(backdrop._weather.size() == 18 and backdrop._motes.size() == 12, "Particles must remain bounded across region changes")
			var layers := 0
			for child in backdrop._world.get_children():
				if child is Node3D and child.name == "JourneyDressings":
					layers += 1
			_check(layers == 1, "Only the active scenery layer may remain in the world")
			await process_frame
			await process_frame
			if capture:
				await RenderingServer.frame_post_draw
				var filename := "overnight-sanctuary-%s-%d.png" % [["grave", "frozen", "ember", "victory"][stage], resolution.y]
				var rendered := viewport.get_texture().get_image()
				_check(rendered.get_size() == resolution, "Capture must match the requested resolution")
				var err := rendered.save_png(out.path_join(filename))
				_check(err == OK, "Could not save " + filename)
				print("Saved ", filename)
	backdrop.set_progress(-9)
	_check(backdrop._biome_index == 0 and not backdrop._journey.has_node("LichKingCrown"), "Fresh/reset campaigns must clear trophies")
	backdrop.set_progress(99)
	_check(backdrop._biome_index == 2, "Out-of-range presentation values must be clamped")
	print("BACKDROP FIXTURE ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
