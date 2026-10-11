extends SceneTree
## Real-scene pause/guide/upgrade hooks and optional native Compatibility gallery.
## Run only in a disposable QA project; all profile writes are disabled.
var checks := 0
var failures := 0
var capture_dir := ""
var main: Node
var target_size := Vector2i(1280, 720)

func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--width="): target_size.x = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): target_size.y = int(arg.trim_prefix("--height="))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _cancel() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = target_size
	Realm.in_title = false
	MetaProgress.forced_class = "battlemage"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main._unhandled_input(_cancel())
	var pause: PauseMenu = main._pause
	var stats: PlayerStats = main._player.stats
	check(paused and pause._root.visible and pause.build_stats == stats, "real Escape hook supplies live stats before opening paused UI")
	check(pause._page_scroll.follow_focus and pause._page_scroll.custom_minimum_size.y <= target_size.y - 80, "pause settings remain keyboard-scrollable within 720p")
	check(not pause._goal_label.visible, "no mystery goal is shown before pinning")
	await _capture("pause-settings")
	pause._guide_button.pressed.emit()
	await process_frame
	check(paused and pause._guide_panel.visible and not pause._main_box.visible, "real Build Guide button opens checklist without unpausing")
	check(pause._guide_panel._rows.size() == BuildGuide.rows(stats).size(), "guide receives actual hero eligibility")
	var pin: CheckButton = pause._guide_panel._pin_by_id["soul_lance"]
	pin.button_pressed = true
	check(pause.pinned_evolution == "soul_lance", "real checkbox updates parent current-run goal")
	var other: CheckButton = pause._guide_panel._pin_by_id["absolute_zero"]
	other.button_pressed = true
	check(pause.pinned_evolution == "absolute_zero" and not pin.button_pressed, "switching goal cannot recursively clear the new pin")
	other.button_pressed = false
	check(pause.pinned_evolution == "", "real checkbox unpins goal")
	pin.button_pressed = true
	await _capture("build-guide")
	check(pause._page_scroll.get_global_rect().encloses(pause._guide_panel._back.get_global_rect()), "guide Back stays visible inside pause scroll at tested window size")
	pause._input(_cancel())
	await process_frame
	check(paused and pause._main_box.visible and not pause._guide_panel.visible, "Escape from guide returns to settings, not live combat")
	check(pause._goal_label.text.contains("Soul Lance"), "pause labels the pinned recipe by name")
	Upgrades.apply("bolt_damage", stats)
	pause._guide_button.pressed.emit()
	await process_frame
	var row: Dictionary = pause._guide_panel._rows.filter(func(value: Dictionary) -> bool: return value["id"] == "soul_lance")[0]
	check(row["weapon"]["rank"] == 1 and pause.pinned_evolution == "soul_lance", "reopening guide refreshes ranks but retains this scene's goal")
	pause._guide_panel._back.pressed.emit()
	await process_frame
	var opacity := pause.find_child("Setting_friendly_opacity", true, false) as HSlider
	check(opacity != null and is_equal_approx(opacity.min_value, 0.15), "real slider never hides friendly spells completely")
	opacity.value = 0.35
	check(is_equal_approx(Juice.friendly_opacity, 0.35), "saved setting signal is wired to live main.apply_settings")
	var aura: ShaderMaterial = main._player._aura_visual.material_override
	check(is_equal_approx(aura.get_shader_parameter("friendly_opacity"), 0.35), "setting signal applies to real scene aura")
	pause.close()
	check(not paused, "Resume returns to unpaused game")
	var fresh := PauseMenu.new()
	root.add_child(fresh)
	check(fresh.pinned_evolution == "", "new/resumed/retry scene has no persisted build pin")
	fresh.free()
	var hud: Hud = main._hud
	var choices: Array[Dictionary] = main._upgrade_choices()
	check(choices.all(func(card: Dictionary) -> bool: return card.has("affected")), "actual roll hook annotates every offered card")
	hud.show_upgrades(choices)
	paused = true
	await process_frame
	check(hud._upgrade_row.find_child("AffectedAbilities", true, false) != null, "actual level-up cards render affected ability previews")
	await _capture("upgrade-cards")
	var evolution: Dictionary = Evolutions.card("soul_lance")
	evolution["affected"] = BuildGuide.affected_text(evolution["id"], stats)
	hud.show_upgrades([evolution])
	await process_frame
	check(not evolution["affected"].is_empty(), "prefixed golden evolution card has its real preview")
	await _capture("evolution-card")
	hud._upgrade_root.hide()
	hud.title_card("Soul Lance", "EVOLUTION · " + str(Evolutions.DEFS["soul_lance"]["desc"]), UiStyle.GOLD)
	hud._title_card.modulate.a = 1.0
	await _capture("evolution-announcement")
	hud._title_card.hide()
	await _opacity_gallery()
	paused = false
	main.free()
	Elements.reset()
	Juice.reset()
	await process_frame
	print("REPORT_IMPROVEMENTS_UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _opacity_gallery() -> void:
	var player: Player = main._player
	player._aura_visual.visible = true
	player._aura_visual.scale = Vector3(3.5, 1, 3.5)
	player._aura_visual.material_override.set_shader_parameter("pulse", 0.6)
	var shots := EnemyShots.new()
	shots.capacity = 10
	main.add_child(shots)
	var bolts := ProjectileSwarm.new()
	bolts.capacity = 10
	main.add_child(bolts)
	for index in 6:
		shots.spawn(player.pos2 + Vector2(2.0 + index * 0.5, -1.2), Vector2.LEFT, 0, 1)
		bolts.spawn(player.pos2 + Vector2(-2.0 - index * 0.5, -1.2), Vector2.RIGHT, 0, 1, 0, 5)
	shots.step(0, player)
	bolts.step(0, [])
	var threats: ShaderMaterial = shots.multimesh.mesh.surface_get_material(0)
	var original_shader := threats.shader
	Juice.set_friendly_opacity(1)
	await _capture("friendly-opacity-100")
	Juice.set_friendly_opacity(0.15)
	await _capture("friendly-opacity-15")
	check(threats.shader == original_shader and threats.get_shader_parameter("friendly_opacity") == null, "native comparison never rewrites hostile shot material")
	check(shots.count == 6 and bolts.count == 6, "visual-only fixture keeps friendly/hostile shot counts unchanged")
	Juice.set_friendly_opacity(1)
	shots.free()
	bolts.free()

func _capture(label: String) -> void:
	# Let staggered card fade-in/scale tweens finish before judging readability.
	for frame in 30: await process_frame
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join("%s-%dx%d.png" % [label, target_size.x, target_size.y])
	check(root.get_texture().get_image().save_png(path) == OK, "native screenshot saves: " + label)
