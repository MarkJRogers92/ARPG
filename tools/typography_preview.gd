extends "res://tools/menu_polish_ui_test.gd"
## Deterministic actual-window typography review, with separate fixture saves.
## Use an isolated project/profile, windowed + no_focus, never the installed app.
## -- --capture-dir=/absolute/path  (omit for headless layout checks)

var capture_dir := ""
var measurements: Array[Dictionary] = []

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	_tag = "user://typography-%d" % OS.get_process_id()
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"] = true
	MetaProgress.save_path = _tag + "-meta.save"
	CampaignSave.path = _tag + "-campaign.save"
	RunSave.path = _tag + "-run.save"
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.position = Vector2i(-30000, -30000)
	for physical: Vector2i in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = physical
		await settle()
		seed(41391)
		_clear_slots()
		_write_campaign("reaper", 7712, "DEPARTURE_READY", 1, 185)
		Elements.player = null; Elements.swarms.clear()
		Realm.current = "graveyard"; Realm.daily = false; Realm.in_title = true
		var main: Node = await _mount_main()
		main.set_process(false)
		var title := main.get_node("TitleScreen") as TitleScreen
		title.open()
		if title.has_method("_show_class_details"):
			for id: String in HeroClass.ORDER:
				title._show_class_details(id); await settle()
				var quit_button := _find_button_containing(title, "Quit")
				_check(root.get_visible_rect().grow(1).encloses(quit_button.get_global_rect()), "all class details preserve the footer: " + id)
			title._show_class_details(MetaProgress.hero_class)
		await shot("title", physical, [title._campaign_new, title._campaign_continue, title._first_realm, _find_button_containing(title, "Quit")])
		title.close(); paused = false; main.queue_free()
		for i in 5: await process_frame
		Elements.player = null; Elements.swarms.clear()
		Realm.in_title = false; seed(41391)
		main = await _mount_main(); main.set_process(false)
		var player := main.get_node("Player") as Player
		var hud := main.get_node("Hud") as Hud
		hud._run_root.show()
		hud.refresh(player.stats, 271.0, 1197, 20, 3)
		hud.set_clock("Dawn in 10:29")
		hud.refresh(player.stats, 271.0, 1197, 20, 3)
		hud.set_blessing("Warding", 29.1, RunUi.SOUL)
		hud.set_prompt("[E] Field forge · inspect your equipped weapon")
		await shot("hud", physical, [hud._time_label, hud._hp_text, hud._prompt_label])
		var pause := main._pause as PauseMenu
		pause.build_stats = player.stats
		pause.open(); paused = true
		await shot("pause", physical, [pause._page_scroll, pause._resume])
		pause._show_controls(true)
		await shot("controls", physical, [pause._page_scroll])
		pause._show_build_guide(true)
		await shot("build-guide", physical, [pause._page_scroll, pause._guide_panel._back])
		pause.close()
		var screen := _build_inventory_fixture(main)
		main._open_screen(screen); screen._on_backpack_selected(0)
		await shot("equipment", physical, [screen._equip_button, screen._impact, screen._upgrades_button])
		var item := ItemGenerator.generate_with(12, ItemData.Rarity.LEGENDARY, "weapon")
		item.name = "Stormcaller's Scepter of the Restless Dead"
		main._loot.drop(item, player.pos2)
		screen._source_tabs.current_tab = 1; screen._refresh()
		screen._on_nearby_selected(0)
		await shot("nearby", physical, [screen._equip_button, screen._nearby_list])
		item.name = "A Very Long Relic Name ".repeat(12)
		screen._refresh(); screen._on_nearby_selected(0)
		await shot("long-item", physical, [screen._equip_button, screen._selection_name])
		screen.close()
		hud.show_upgrades(Upgrades.roll(player.stats), 2, "LEVEL UP", "Choose a power · 1 / 2 / 3 or click", 1); paused = true
		await shot("upgrades", physical, [hud._upgrade_row, hud._reroll_button])
		hud._upgrade_root.hide(); paused = false
		Obstacles.clear()
		main._events._start_chest(player.pos2, true)
		Input.action_press("interact"); main._events.offer_chest(); Input.action_release("interact")
		var chest: WagerPanel = main._events._chest_panel
		await shot("chest", physical, [chest.action_button("hunt"), chest.action_button("seal"), chest.action_button("leave")])
		main._events._choose_chest("leave")
		var forge := FieldForgePanel.new(); main.add_child(forge)
		forge.inspect_weapon(item, 12); paused = true
		await shot("forge-inspect", physical, [forge.action_button("leave"), forge.action_button("roll")])
		var worn: Item = player.inventory.equipped.weapon
		item.name = "Stormcaller's Scepter of the Restless Dead"
		forge.compare_weapon(player.inventory, player.stats, worn, item)
		await shot("forge-compare", physical, [forge.action_button("keep"), forge.action_button("take")])
		forge.close(); paused = false
		main._events._start_crossroads(Vector2(0,-7))
		if not main._events._events.is_empty():
			main._events._refresh_discovery_prompt(player.pos2)
		hud.set_prompt("Crossroads shrine · choose a blessing · hold its circle for 2.5 s")
		await shot("shrine", physical, [hud._prompt_label])
		hud.set_recap("Slain by: Plague Bloater blast · Hurt most by: Ghoul 45% · Meteors 20%", [], {"takeaway":"Step clear of the marked circle before the blast.", "trail":"Last hits · Ghoul 18 · Plague Bloater blast 42"})
		hud.show_game_over(271.0, 1197, 17, 23)
		await shot("game-over", physical, [hud._restart_button, hud._recap_scroll])
		paused = false; main.queue_free()
		for i in 5: await process_frame
	_clear_slots()
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("layouts.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(measurements, "\t"))
	print("TYPOGRAPHY PREVIEW: %d layouts, %d failures" % [measurements.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func settle() -> void:
	for i in 6: await process_frame

func shot(screen: String, physical: Vector2i, controls: Array) -> void:
	await settle()
	var bounds := root.get_visible_rect()
	var record := {"screen":screen, "window":str(root.size), "logical":str(bounds.size), "controls":[]}
	_check(root.size == physical, "actual window size " + str(physical))
	for control: Control in controls:
		_check(control != null and control.is_visible_in_tree(), "visible " + screen)
		if control == null: continue
		var rect := control.get_global_rect()
		var fits := bounds.grow(1).encloses(rect)
		_check(fits, "%s %s inside %s: %s" % [screen, control.name, bounds, rect])
		record.controls.append({"name":str(control.name), "rect":str(rect), "fits":fits})
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.get_size() == physical, "actual rendered size " + str(physical))
		_check(image.save_png(capture_dir.path_join("%s-%dx%d.png" % [screen,physical.x,physical.y])) == OK, "saved " + screen)
	measurements.append(record)
