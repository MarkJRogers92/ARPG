extends SceneTree
## Runs the real game with a fresh campaign and separate disposable save slots.
## godot --path . -s tools/menu_polish_preview.gd

func _initialize() -> void:
	call_deferred("_start_preview")

func _start_preview() -> void:
	var folder := "user://menu_polish_previews/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if error != OK:
		push_error("Could not create separate preview saves: %s" % error_string(error))
		quit(1)
		return
	MetaProgress.disabled = true
	MetaProgress.save_path = folder + "/meta.save"
	CampaignSave.path = folder + "/campaign.save"
	RunSave.path = folder + "/run.save"
	var controller := CampaignController.new()
	root.add_child(controller)
	var response := controller.create("battlemage", 7712)
	controller.free()
	if not response.get("ok", false):
		push_error("Could not prepare menu preview: %s" % str(response.get("error", "")))
		quit(1)
		return
	Realm.in_title = true
	root.title = "Soulbound — menu preview · separate saves"
	error = change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		push_error("Could not open menu preview: %s" % error_string(error))
		quit(1)
		return
	if "--self-test" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		var title := current_scene.get_node("TitleScreen") as TitleScreen
		if title == null or not title.is_open() or title._campaign_continue.disabled:
			push_error("Menu preview did not reach its resumable title screen")
			quit(1)
			return
		print("MENU_POLISH_PREVIEW_OK")
		quit(0)
