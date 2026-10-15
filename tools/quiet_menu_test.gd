extends "res://tools/menu_polish_ui_test.gd"
## Real pages, keyboard/joypad events and real campaign transitions. Unique saves.
var capture_dir := ""
var checks := 0

func frames(n := 4) -> void:
	for i in n: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1; _check(ok, message)

func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	Input.parse_input_event(event); await frames()
	event = InputEventKey.new(); event.keycode = code; event.pressed = false
	Input.parse_input_event(event); await frames()

func joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new(); event.button_index = code; event.pressed = true
	Input.parse_input_event(event); await frames()
	event = InputEventJoypadButton.new(); event.button_index = code; event.pressed = false
	Input.parse_input_event(event); await frames()

func inside(control: Control) -> bool:
	return control.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(control.get_global_rect())

func snap(name: String, physical: Vector2i) -> void:
	if capture_dir.is_empty(): return
	await frames(8); await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == physical, "actual native dimensions " + str(physical))
	check(image.save_png(capture_dir.path_join("%s-%dx%d.png" % [name,physical.x,physical.y])) == OK, "captured " + name)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	_tag = "user://quiet-menu-test-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	MetaProgress.save_path = _tag + "-meta.save"; CampaignSave.path = _tag + "-campaign.save"; RunSave.path = _tag + "-run.save"
	MetaProgress.disabled = false; MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true; MetaProgress.shards = 0; MetaProgress.hero_class = "battlemage"
	MetaProgress.classes = {}; MetaProgress.realms = {}; MetaProgress.ranks = {}; MetaProgress.pacts = []
	for id: String in HeroClass.ORDER: MetaProgress.classes[id] = true
	for id: String in Realm.ORDER: MetaProgress.realms[id] = {"won":true,"endless":0.0}
	MetaProgress.save()
	_clear_slots(); MetaProgress.save()
	_write_campaign("reaper",7712,"DEPARTURE_READY",1,185)
	Realm.in_title = true; Realm.daily = false; Realm.current = "graveyard"; RunSave.pending = {}
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED; root.set_flag(Window.FLAG_NO_FOCUS,true); root.position = Vector2i(-30000,-30000)
	seed(41391)
	var main: Node = await _mount_main(); current_scene = main; main.set_process(false)
	var title: TitleScreen = main._title
	var campaign_hash := FileAccess.get_sha256(CampaignSave.path)
	for physical: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = physical; title.open(); await frames()
		check(root.size == physical, "window size " + str(physical))
		check(title._home.visible and not title._selection_page.visible, "opening view owns only primary navigation")
		check(title._title_hero.visible and title._title_hero.get_parent() == title and not main._player.visible, "menu owns a visual-only hero without combat markers")
		for id: String in ["continue","new","classic","crypt","settings","quit"]:
			check(inside(title._home_buttons[id]), "primary navigation visible: " + id)
		check(inside(title._home_detail) and inside(title._home_wallet), "campaign card and real currency fit")
		check(title._campaign_continue.has_focus(), "saved campaign receives initial focus")
		check(title._home_detail_title.text == Realm.data("frozen")["name"], "resume detail names the real saved realm")
		await snap("home",physical)
		await key(KEY_DOWN)
		check(title._home_new.has_focus(), "keyboard down follows vertical navigation")
		await joy(JOY_BUTTON_A)
		check(title._selection_page.visible and title._selection_mode == "campaign" and not title._realm_row.visible, "controller A reaches hero/loadout preparation for New Campaign")
		check(inside(title._campaign_new) and inside(title._relic_button), "new-campaign actions fit")
		var old_new := title._home_new; old_new.pressed.emit(); old_new.pressed.emit()
		check(current_scene == main and title._selection_page.visible, "stale home activation cannot start or replace a campaign")
		await snap("new-campaign",physical)
		# Repeated confirmation opens one dialog; cancellation keeps the saved campaign.
		title._campaign_new.pressed.emit(); title._campaign_new.pressed.emit(); await frames()
		check(title.find_children("*","ConfirmationDialog",true,false).size() == 1, "one replacement confirmation")
		await snap("replacement-confirmation",physical)
		title._new_confirmation.canceled.emit(); title._new_confirmation = null; await frames()
		check(FileAccess.get_sha256(CampaignSave.path) == campaign_hash and current_scene == main, "replacement cancellation preserves the save")
		await joy(JOY_BUTTON_B)
		check(title._home.visible and title._home_new.has_focus(), "controller B returns to New Campaign without mutation")
		title._home_classic.grab_focus(); await key(KEY_ENTER)
		check(title._selection_page.visible and title._realm_row.visible and not title._campaign_panel.visible, "Classic owns hero, loadout and realm choices")
		for card: Button in title._realm_row.get_children(): check(inside(card), "realm choice fits")
		for id: String in HeroClass.ORDER:
			title._show_class_details(id); await frames()
			check(inside(title._selection_back), "long class details cannot displace Back: " + id)
		await snap("classic",physical)
		title._relic_button.grab_focus(); await key(KEY_ENTER)
		check(title._relic_overlay.visible and not title._selection_page.visible, "loadout page has sole navigation ownership")
		var back := title._find_back(title._relic_overlay)
		check(back.has_focus(), "loadout entry has a keyboard Back action")
		await key(KEY_TAB)
		check(title._relic_overlay.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays in the loadout page")
		await snap("loadout",physical)
		await key(KEY_ESCAPE)
		check(title._selection_page.visible and title._relic_button.has_focus(), "loadout Escape restores selection focus")
		await key(KEY_ESCAPE)
		check(title._home.visible and title._home_classic.has_focus(), "Classic Escape returns to its home action")
		title._home_settings.grab_focus(); await joy(JOY_BUTTON_A)
		check(main._pause.is_open() and not title._root.visible and paused, "Settings owns the screen")
		check(not main._pause._save_button.visible and not main._pause._quit_button.visible and not main._pause._guide_button.visible, "title settings offer no run-only actions")
		await snap("settings",physical)
		main._pause._show_controls(true); await frames(); await key(KEY_ESCAPE)
		check(main._pause._main_box.visible and paused, "Controls Back returns to Settings")
		await joy(JOY_BUTTON_B)
		check(title._home.visible and title._home_settings.has_focus() and not paused, "Settings Back restores its home focus")
		var sanctum: Button = title._home.find_child("OpenSanctum",true,false)
		sanctum.grab_focus(); await key(KEY_ENTER)
		check(title._progress_page.visible and not title._home.visible, "secondary progression page is reachable")
		await snap("sanctum",physical)
		for pair: Array in [["Altar of Souls",title._altar_overlay],["Pact of Night",title._pact_overlay],["Bestiary",title._bestiary_overlay],["The Crypt",title._crypt_overlay],["Daily Night",title._daily_overlay]]:
			var button := _find_button_containing(title._progress_page,pair[0])
			button.grab_focus(); await key(KEY_ENTER)
			check(pair[1].visible and not title._progress_page.visible, "facility opens with sole ownership: " + pair[0])
			await snap(str(pair[0]).to_lower().replace(" ","-"),physical)
			await key(KEY_ESCAPE)
			check(title._progress_page.visible and button.has_focus(), "facility Escape restores its owner: " + pair[0])
		await key(KEY_ESCAPE)
		check(title._home.visible and sanctum.has_focus(), "Sanctum Back returns to its secondary link")
		for i in 3:
			title._home_buttons["crypt"].grab_focus(); await key(KEY_ENTER); await key(KEY_ESCAPE)
		check(title._home.visible and title._home_buttons["crypt"].has_focus(), "repeated Crypt open/close stays coherent")
		check(FileAccess.get_sha256(CampaignSave.path) == campaign_hash, "view/navigation leaves campaign bytes intact")
		title.close()
		check(main._player.visible and not title._title_hero.visible and not title._title_dressing.visible and main.get_node("CameraRig/Camera3D").current, "close restores player and gameplay camera; title visuals hide")
		title.open(); await frames()
	# Actual continuation mounts the saved controller once, preserving its identity.
	var campaign_id: String = CampaignSave.read()["campaign_id"]
	title._campaign_continue.pressed.emit(); title._campaign_continue.pressed.emit(); await frames(8)
	var shell := current_scene as CampaignShell
	check(shell != null and shell.controller.state["campaign_id"] == campaign_id and shell.controller.state["gold"] == 185, "double Continue mounts the same saved campaign once")
	if shell:
		shell._return_title(); await frames(8)
		main = current_scene; title = main._title; main.set_process(false)
		# Class selection is a UI choice; it keeps this scene and starts the selected class on acceptance.
		title._show_selection("campaign"); await frames()
		for b: Button in title._heroes.get_children():
			if b.text.contains("Reaper"): b.pressed.emit(); break
		await frames()
		check(current_scene == main and MetaProgress.hero_class == "reaper", "hero selection stays in preparation")
		title._campaign_new.pressed.emit(); await frames()
		title._new_confirmation.confirmed.emit(); title._new_confirmation.confirmed.emit(); await frames(8)
		shell = current_scene as CampaignShell
		check(shell != null and shell.controller.state["hero_class"] == "reaper" and shell.controller.state["campaign_id"] != campaign_id, "confirmed replacement creates exactly the selected hero's campaign")
		if shell:
			shell._return_title(); await frames(8)
			main = current_scene; title = main._title; main.set_process(false)
			title._show_selection("classic"); await frames()
			title._first_realm.pressed.emit(); title._first_realm.pressed.emit(); await frames(8)
			main = current_scene; main.set_process(false)
			check(not main._in_title and not main._title.is_open() and main._hero_class == "reaper" and Realm.current == "graveyard", "double Classic starts one real night with the selected hero and realm")
			check(main._player.visible and main.get_node("CameraRig/Camera3D").current, "real Classic gameplay retains its player and camera")
			main.queue_free()
	await frames(5); _clear_slots()
	print("QUIET MENU: %d checks, %d failures" % [checks,_failures.size()])
	quit(0 if _failures.is_empty() else 1)
