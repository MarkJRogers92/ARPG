extends SceneTree
## Focused fixture for the polished Title, Pause and Inventory menus.
##
## Screenshots (run without --headless so a real GPU viewport renders; the
## window is minimized so it cannot steal focus or paint a stuck frame):
##   godot --path . -s tools/menu_polish_ui_test.gd -- \
##     --screen=title-valid --width=1280 --height=720 \
##     --output=res://build/menu-polish-evidence/title-valid-1280x720.png --minimized
##
## Contract checks (headless; asserts focus, wording, comparison rows and that
## each menu fits its viewport):
##   godot --headless --path . -s tools/menu_polish_ui_test.gd -- --screen=behavior
##
## Screens: title-none, title-locked, title-valid, title-damaged, title-abandoned, pause,
## pause-campaign, inventory, inventory-full, behavior.
## Every fixture writes only to a unique user:// name; the real save slots are
## never opened, read or written.

const SAVE_SUFFIXES := ["", ".bak", ".previous", ".rollback", ".tmp"]

var _failures: Array[String] = []
var _tag := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var width := 1280
	var height := 720
	var screen := "behavior"
	var output := ""
	var minimized := false
	for arg: String in args:
		if arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--screen="):
			screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--minimized":
			minimized = true
	_tag = "user://menu-polish-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	MetaProgress.disabled = true
	MetaProgress.save_path = _tag + "-meta.save"
	CampaignSave.path = _tag + "-campaign.save"
	CampaignSave.fail_stage = ""
	RunSave.path = _tag + "-run.save"
	_clear_slots()
	if screen == "behavior":
		await _run_behavior(width, height)
	else:
		await _run_screenshot(screen, width, height, output, minimized)
	_clear_slots()
	quit(1 if not _failures.is_empty() else 0)


# --- fixtures ---------------------------------------------------------------

func _clear_slots() -> void:
	for base: String in [CampaignSave.path, RunSave.path, MetaProgress.save_path]:
		for suffix: String in SAVE_SUFFIXES:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))


func _write_campaign(hero: String, seed_value: int, phase: String, biome: int, gold: int) -> void:
	var controller := CampaignController.new()
	root.add_child(controller)
	var created: Dictionary = controller.create(hero, seed_value)
	if not created.get("ok", false):
		_check(false, "fixture campaign created (%s)" % str(created.get("error", "")))
	var state: Dictionary = controller.state
	state["biome_index"] = biome
	state["phase"] = phase
	state["gold"] = gold
	if not CampaignSave.write(state):
		_check(false, "fixture campaign persisted (%s)" % CampaignSave.last_error)
	root.remove_child(controller)
	controller.free()


func _write_damaged_campaign() -> void:
	var file := FileAccess.open(CampaignSave.path, FileAccess.WRITE)
	if file == null:
		_check(false, "damaged fixture opened for writing")
		return
	file.store_string("this is not a campaign save, only a damaged file for the recovery path")
	file.close()


func _mount_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	return main


## A worn weapon beside a carried weapon that rolls ADD / INCREASED / MORE, a
## negative (cursed) affix and a legendary power, so the comparison is exercised
## across every operation the item system can roll.
func _build_inventory_fixture(main: Node) -> InventoryScreen:
	var director := main.get_node("WaveDirector")
	director.base_rate = 0.0
	director.rate_growth = 0.0
	var player := main.get_node("Player") as Player
	var screen := main.get_node("InventoryScreen") as InventoryScreen
	var worn := ItemGenerator.generate_with(5, ItemData.Rarity.RARE, "weapon")
	worn.implicit.assign([{"stat": "bolt_damage", "op": PlayerStats.Op.ADD, "value": 6.0}])
	worn.affixes.assign([{"stat": "crit_chance", "op": PlayerStats.Op.ADD, "value": 0.02}])
	player.inventory.pickup(worn)
	var offered := ItemGenerator.generate_with(5, ItemData.Rarity.RARE, "weapon")
	offered.power = _longest_power("weapon")
	offered.affixes.assign([
		{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.20},
		{"stat": "bolt_damage", "op": PlayerStats.Op.MORE, "value": 0.15},
		{"stat": "max_hp", "op": PlayerStats.Op.ADD, "value": -12.0},
	])
	player.inventory.pickup(offered)
	return screen


func _fill_backpack(player: Player) -> void:
	var index := 0
	while player.inventory.backpack.size() < Inventory.BACKPACK_SIZE:
		var filler := ItemGenerator.generate_with(5 + index % 4, ItemData.Rarity.MAGIC, ItemData.SLOTS[index % ItemData.SLOTS.size()])
		player.inventory.pickup(filler)
		index += 1
		if index > Inventory.BACKPACK_SIZE * 2:
			break


func _longest_power(slot: String) -> String:
	var best := ""
	var best_len := -1
	for id: String in ItemData.powers_for(slot):
		var desc := str(ItemData.POWERS[id].get("desc", ""))
		if desc.length() > best_len:
			best_len = desc.length()
			best = id
	return best


# --- rendering --------------------------------------------------------------

func _run_screenshot(screen: String, width: int, height: int, output: String, minimized: bool) -> void:
	if output.is_empty():
		_check(false, "a screenshot needs --output=<path>")
		return
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_position(Vector2i(40, 40))
		DisplayServer.window_set_size(Vector2i(width, height))
		if minimized:
			root.mode = Window.MODE_MINIMIZED
	root.size = Vector2i(width, height)
	var container := SubViewportContainer.new()
	container.position = Vector2.ZERO
	container.size = Vector2(width, height)
	container.stretch = false
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var main: Node = null
	match screen:
		"title-locked":
			_clear_slots()
			MetaProgress.disabled = false
			MetaProgress.load_save()
			Realm.in_title = true
			main = await _mount_into(viewport)
		"title-none":
			_clear_slots()
			Realm.in_title = true
			main = await _mount_into(viewport)
		"title-valid":
			_clear_slots()
			_write_campaign("reaper", 7712, "DEPARTURE_READY", 1, 185)
			Realm.in_title = true
			main = await _mount_into(viewport)
		"title-damaged":
			_clear_slots()
			_write_damaged_campaign()
			Realm.in_title = true
			main = await _mount_into(viewport)
		"title-abandoned":
			_clear_slots()
			_write_campaign("battlemage", 7713, "ABANDONED", 0, 64)
			Realm.in_title = true
			main = await _mount_into(viewport)
		"pause", "pause-campaign":
			Realm.in_title = false
			main = await _mount_into(viewport)
			var pause := main._pause as PauseMenu
			pause.campaign_mode = screen == "pause-campaign"
			pause.open()
		"inventory", "inventory-full":
			Realm.in_title = false
			main = await _mount_into(viewport)
			var menu := _build_inventory_fixture(main)
			if screen == "inventory-full":
				_fill_backpack(main.get_node("Player") as Player)
			menu.open()
			await process_frame
			if menu._backpack_list.item_count > 0:
				menu._backpack_list.select(0)
				menu._backpack_list.item_selected.emit(0)
		_:
			_check(false, "unknown screenshot screen '%s'" % screen)
			return
	if main != null:
		main.process_mode = Node.PROCESS_MODE_DISABLED
	await _settle(viewport)
	var image := viewport.get_texture().get_image()
	if image.is_empty():
		_check(false, "viewport captured an empty image for %s" % screen)
		return
	if image.get_width() != width or image.get_height() != height or viewport.size != Vector2i(width, height):
		_check(false, "viewport kept requested %dx%d (got %dx%d)" % [width, height, image.get_width(), image.get_height()])
		return
	var save_error := image.save_png(output)
	if save_error != OK:
		_check(false, "image saved to %s (%s)" % [output, error_string(save_error)])
		return
	print("MENU_POLISH_SCREENSHOT_OK %s %dx%d" % [output, image.get_width(), image.get_height()])


func _mount_into(viewport: SubViewport) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	return main


func _settle(viewport: SubViewport) -> void:
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless" and viewport.get_texture() != null:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw


# --- behaviour contract -----------------------------------------------------

func _run_behavior(width: int, height: int) -> void:
	root.size = Vector2i(width, height)
	await _behavior_locked_realms(height)
	await _behavior_title(height)
	await _behavior_pause()
	await _behavior_inventory(height)
	for message: String in _failures:
		push_error("MENU_POLISH_BEHAVIOR_FAIL: " + message)
	print("MENU_POLISH_BEHAVIOR %s" % ["FAILED" if not _failures.is_empty() else "PASSED"])


func _behavior_locked_realms(height: int) -> void:
	_clear_slots()
	MetaProgress.disabled = false
	MetaProgress.load_save()
	Realm.in_title = true
	var main: Node = await _mount_main()
	var title := main.get_node("TitleScreen") as TitleScreen
	title.open()
	for i in 4:
		await process_frame
	_check(_content_min_height(title._root) <= float(height), "locked title fits viewport")
	for i in range(1, Realm.ORDER.size()):
		var label := _find_label_containing(title, "Locked · Conquer Night %d first" % i)
		_check(label != null, "locked realm identifies prerequisite Night %d" % i)
		if label != null:
			var card := label.get_parent().get_parent() as Button
			_check(card.disabled, "locked realm remains unavailable")
			_check(card.get_global_rect().encloses(label.get_global_rect()), "locked status stays inside its card")
			_check(label.get_line_count() == 1, "locked status fits on one line")
	main.free()
	MetaProgress.disabled = true


func _behavior_title(height: int) -> void:
	# No save at all: New Campaign is the primary action.
	_clear_slots()
	Realm.in_title = true
	var main: Node = await _mount_main()
	var title := main.get_node("TitleScreen") as TitleScreen
	title.open()
	await process_frame
	await process_frame
	_check(title._campaign_continue.disabled, "no save leaves Continue Campaign disabled")
	_check(title._default_focus() == title._campaign_new, "no save makes New Campaign the first keyboard focus")
	_check(title._campaign_summary.text.contains("Three realms"), "no save summarises the campaign premise")
	_check(_find_button_containing(title, "New Campaign") != null, "New Campaign is present")
	_check(_find_button_containing(title, "Continue Campaign") != null, "Continue Campaign is present")
	var hero_names := 0
	for id: String in HeroClass.ORDER:
		if _find_button_containing(title, str(HeroClass.CLASSES[id]["name"])) != null:
			hero_names += 1
	_check(hero_names == HeroClass.ORDER.size(), "every hero (%d) stays reachable on the title" % hero_names)
	var realms := 0
	for i in Realm.ORDER.size():
		if _find_label_containing(title, "NIGHT %d" % (i + 1)) != null:
			realms += 1
	_check(realms == Realm.ORDER.size(), "every Classic realm (%d) stays reachable on the title" % realms)
	for entry: String in ["Altar of Souls", "Bestiary", "The Crypt", "Daily Night", "Pact of Night"]:
		_check(_find_button_containing(title, entry) != null, "title still offers %s" % entry)
	_check(title._relic_button != null and _find_button_containing(title, "Reliquary") != null, "title still offers the Reliquary")
	_check(_content_min_height(title._root) <= float(height), "title content fits %dpx without clipping (needs %.0f)" % [height, _content_min_height(title._root)])
	main.free()

	# A valid save: Continue is primary, focus lands on it and the summary is true.
	_clear_slots()
	_write_campaign("reaper", 7712, "DEPARTURE_READY", 1, 185)
	var saved_hash := FileAccess.get_sha256(CampaignSave.path)
	Realm.in_title = true
	main = await _mount_main()
	title = main.get_node("TitleScreen") as TitleScreen
	title.open()
	await process_frame
	await process_frame
	_check(not title._campaign_continue.disabled, "a resumable save enables Continue Campaign")
	_check(title._default_focus() == title._campaign_continue, "a resumable save makes Continue Campaign the first keyboard focus")
	_check(title.get_viewport().gui_get_focus_owner() == title._campaign_continue, "keyboard focus actually lands on Continue Campaign")
	_check(title._campaign_summary.text.contains("Reaper"), "summary names the saved hero")
	_check(title._campaign_summary.text.contains(str(Realm.REALMS["frozen"]["name"])), "summary names the saved realm")
	_check(title._campaign_summary.text.contains("departure is prepared"), "summary names the saved phase")
	_check(title._campaign_summary.text.contains("185 G"), "summary reports the saved gold")
	_check(FileAccess.get_sha256(CampaignSave.path) == saved_hash, "opening the title never rewrites the campaign save")
	main.free()

	# A damaged save keeps recovery reachable.
	_clear_slots()
	_write_damaged_campaign()
	var damaged_hash := FileAccess.get_sha256(CampaignSave.path)
	Realm.in_title = true
	main = await _mount_main()
	title = main.get_node("TitleScreen") as TitleScreen
	title.open()
	await process_frame
	await process_frame
	_check(CampaignSave.resumable(), "a damaged save still counts as resumable")
	_check(CampaignSave.read().is_empty(), "a damaged save cannot be read as campaign data")
	_check(not title._campaign_continue.disabled, "a damaged save leaves Continue reachable for recovery")
	_check(title._campaign_summary.text.contains("recovery"), "summary explains that the damaged save needs recovery")
	_check(FileAccess.get_sha256(CampaignSave.path) == damaged_hash, "the damaged file is left byte-for-byte intact")
	main.free()

	# An abandoned run is not offered as Continue.
	_clear_slots()
	_write_campaign("battlemage", 7713, "ABANDONED", 0, 64)
	Realm.in_title = true
	main = await _mount_main()
	title = main.get_node("TitleScreen") as TitleScreen
	title.open()
	await process_frame
	await process_frame
	_check(not CampaignSave.resumable(), "an abandoned run is not resumable")
	_check(title._campaign_continue.disabled, "an abandoned run disables Continue Campaign")
	_check(title._campaign_summary.text.contains("set aside"), "summary explains the abandoned run instead of implying a live town")
	_check(title._default_focus() == title._campaign_new, "an abandoned run falls back to New Campaign")
	main.free()
	Realm.in_title = false


func _behavior_pause() -> void:
	var pause := PauseMenu.new()
	root.add_child(pause)
	pause.can_save = true
	pause.campaign_mode = false
	pause.open()
	await process_frame
	await process_frame
	_check(_count_nodes(pause, "HSlider") == 4, "pause keeps volume/aim sliders and adds friendly opacity")
	for setting: String in ["music_volume", "sfx_volume", "aim_assist", "friendly_opacity"]:
		_check(pause.find_child("Setting_" + setting, true, false) is HSlider, "pause retains independent setting " + setting)
	_check(_count_nodes(pause, "CheckButton") == 4, "pause keeps shake, numbers, calm and bold toggles")
	_check(_find_button_containing(pause, "Controls") != null, "pause keeps the Controls rebinding entry")
	_check(_find_button_containing(pause, "Resume") != null, "pause keeps Resume")
	_check(_find_button_containing(pause, "Save and quit") != null, "pause keeps Save and quit")
	_check(_find_button_containing(pause, "Abandon run") != null, "pause keeps the Classic abandon wording")
	_check(pause.get_viewport().gui_get_focus_owner() == pause._resume, "pause opens focused on Resume")
	var classic_height := _content_min_height(pause._root)
	_check(classic_height <= 720.0, "Classic pause fits 720px without clipping (needs %.0f)" % classic_height)
	var controls := _find_button_containing(pause, "Controls")
	controls.pressed.emit()
	await process_frame
	_check(pause._controls_box.visible, "Controls opens the rebinding panel")
	var rows := 0
	for pair: Array in Controls.ACTIONS:
		if _find_label_containing(pause._controls_box, str(pair[1])) != null:
			rows += 1
	_check(rows == Controls.ACTIONS.size(), "Controls panel keeps every rebindable action (%d)" % rows)
	_check(_find_button_containing(pause._controls_box, "Reset to defaults") != null, "Controls panel keeps reset")
	pause.campaign_mode = true
	pause._show_controls(false)
	await process_frame
	_check(str(pause._save_button.text).contains("restart from departure"), "campaign pause explains the run restarts from departure")
	_check(str(pause._quit_button.text).contains("Retreat"), "campaign pause labels quitting as a retreat to town")
	_check(pause._campaign_notice.visible, "campaign pause shows the retreat notice")
	var campaign_height := _content_min_height(pause._root)
	_check(campaign_height <= 720.0, "campaign pause fits 720px without clipping (needs %.0f)" % campaign_height)
	pause.free()


func _behavior_inventory(height: int) -> void:
	Realm.in_title = false
	var main: Node = await _mount_main()
	var screen := _build_inventory_fixture(main)
	screen.open()
	await process_frame
	screen._backpack_list.select(0)
	screen._backpack_list.item_selected.emit(0)
	await process_frame
	var details := screen._details.text
	_check(details.contains("GEAR COMPARISON"), "inventory labels the carried-item comparison separately from character stats")
	_check(details.contains("Added · "), "comparison shows ADD rolls")
	_check(details.contains("Increased · "), "comparison shows INCREASED rolls")
	_check(details.contains("More · "), "comparison shows MORE rolls")
	_check(details.contains("-12 Max HP"), "comparison preserves the cursed negative roll")
	_check(details.contains("Carried power"), "comparison names the carried legendary power")
	_check(details.contains("Worn power"), "comparison names the worn legendary power side")
	_check(details.contains("Likely upgrade") and details.contains("Estimated fit"), "the upgrade hint stays an explicit estimate")
	_check(_content_min_height(screen._root) <= float(height), "inventory fits %dpx without clipping (needs %.0f)" % [height, _content_min_height(screen._root)])
	var focus := screen.get_viewport().gui_get_focus_owner()
	_check(focus != null and focus == screen._backpack_list, "inventory opens focused on the backpack list")
	main.free()


# --- helpers ----------------------------------------------------------------

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
	print("  %s  %s" % ["ok  " if ok else "FAIL", message])


func _find_button_containing(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.contains(text):
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button_containing(child, text)
		if found != null:
			return found
	return null


func _find_label_containing(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.contains(text):
		return node as Label
	for child: Node in node.get_children():
		var found := _find_label_containing(child, text)
		if found != null:
			return found
	return null


func _count_nodes(node: Node, type_name: String) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		total += _count_nodes(child, type_name)
	return total


## The tallest direct child of a screen root is its content stack; if it needs
## more than the viewport height the centred layout would clip.
func _content_min_height(control: Control) -> float:
	var tallest := 0.0
	for child: Node in control.get_children():
		if child is Control:
			tallest = maxf(tallest, (child as Control).get_combined_minimum_size().y)
	return tallest
