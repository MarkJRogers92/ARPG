extends "res://tools/menu_polish_ui_test.gd"
## Native physical-resolution views, unique fixture slots, offscreen/no-focus.
func _run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_tag = "user://quiet-menu-preview-%d" % OS.get_process_id()
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true
	MetaProgress.save_path = _tag + "-meta.save"
	CampaignSave.path = _tag + "-campaign.save"
	RunSave.path = _tag + "-run.save"
	_clear_slots()
	_write_campaign("reaper", 7712, "DEPARTURE_READY", 1, 185)
	Realm.in_title = true; Realm.current = "graveyard"; Realm.daily = false
	root.mode = Window.MODE_WINDOWED; root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.position = Vector2i(-30000,-30000); root.size = Vector2i(1280,720)
	seed(41391)
	var main: Node = await _mount_main()
	main.set_process(false)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.get_size() == root.size, "native dimensions")
	_check(image.save_png(output) == OK, "saved native Quiet Fantasy view")
	main.queue_free(); for i in 5: await process_frame
	_clear_slots()
	quit(0 if _failures.is_empty() else 1)
