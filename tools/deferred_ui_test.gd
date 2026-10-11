extends SceneTree
## Real scene controls + optional native captures. No profile writes.
var checks := 0
var failures := 0
var capture_dir := ""
var size := Vector2i(1280, 720)
var main: Node

func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress._loaded = true
	MetaProgress.bestiary = {"Ghoul": 250}
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	RunSave.pending = {}
	Realm.in_title = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--width="): size.x = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): size.y = int(arg.trim_prefix("--height="))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	root.size = size
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var player: Player = main._player
	var hud: Hud = main._hud
	Upgrades.apply("lightning", player.stats)
	Upgrades.apply("aura", player.stats)
	Upgrades.apply("synergy_relay", player.stats)
	player.pending_levels = 1
	main._try_level_up()
	await process_frame
	check(paused and hud._upgrade_root.visible and main._banishes_left == 2, "real level-up opens two-ban attempt budget")
	await _capture("build-choices")
	var first: String = hud._upgrade_ids[0]
	var kept: Array = hud._upgrade_ids.slice(1)
	check(Upgrades.DEFS.has(first), "fixture first shown card regular")
	var banish := hud._banish_row.get_child(0) as Button
	await _activate(banish)
	check(main._banishes_left == 1 and first in main._banished and not first in hud._upgrade_ids, "actual banish control removes shown card; level unspent")
	check(kept.all(func(id: String) -> bool: return id in hud._upgrade_ids), "banish is not a free full reroll")
	var second: String = hud._upgrade_ids[0]
	await _activate(hud._banish_row.get_child(0))
	check(main._banishes_left == 0 and second in main._banished and player.pending_levels == 0 and main._choosing_upgrade, "second and final ban preserves this open level-up")
	main._on_banish(hud._upgrade_ids[0])
	check(main._banished.size() == 2 and not hud._banish_row.visible, "third ban impossible; budget hidden")
	hud._choose(0)
	check(not paused and player.pending_levels == 0, "upgrade selection closes after bans")
	player.empower_warding(30.0)
	Elements.metrics.tick(5.0, ["Chain Lightning"])
	Elements.metrics.record("Chain Lightning", 10.0, "fixture")
	Elements.damage_by = {"Chain Lightning": 10.0}
	var saved: Dictionary = main.capture()
	check(saved["banished"].size() == 2 and saved["banishes_left"] == 0 and saved["upgrades"].has("synergy_relay"), "Classic capture preserves bans and synergy cards")
	main._restore(saved)
	for swarm: EnemySwarm in main._swarms: swarm.step(0.0, player.pos2)
	check(main._banished.size() == 2 and main._banishes_left == 0 and BuildSynergies.live("synergy_relay", player.stats), "Classic resume reconstructs card predicates")
	check(player.warding_charge_left == 0.0 and player.build_synergies.drain().is_empty(), "Classic restore discards transient charge and pulses")
	check(Elements.metrics.report()["total"] == 10.0, "Classic capture/restore measured damage")
	# An actual dash press consumes one charge, while a cooldown press cannot.
	player._dash_cooldown = 0.0
	player.empower_warding(30.0)
	Input.action_press("dash")
	player.tick(1.0 / 60.0)
	Input.action_release("dash")
	check(player.dash_uses == 1 and player.warding_charge_left == 0.0, "successful dash spends shrine power even on a miss")
	player.empower_warding(30.0)
	Input.action_press("dash")
	player.tick(1.0 / 60.0)
	Input.action_release("dash")
	check(player.dash_uses == 1 and player.warding_charge_left > 0.0, "invalid cooldown input cannot spend charge")
	hud.refresh_extras(0, 0.0, "", -1.0)
	hud.set_dash_charge(player.warding_charge_left)
	check(hud._dash_label.text.contains("WARDING READY"), "HUD readiness agrees with charge")
	await _capture("warding-ready")
	hud.reveal_reward("SOUL LANCE", "EVOLUTION · piercing volleys now spear the horde\nBolt damage 10 → 18 · pierce 2 → 4", UiStyle.GOLD)
	hud._title_tween.pause() # Controlled screenshot; input checks must not race a slow GPU's auto-dismiss.
	hud._title_card.modulate.a = 1.0
	await _capture("reward-reveal")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	hud._input(space)
	check(hud._reward_reveal_shown, "Space remains dash, not reward dismissal")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	hud._input(cancel)
	check(hud._reward_reveal_shown, "Escape remains pause, not reward dismissal")
	var dismiss := InputEventKey.new()
	dismiss.keycode = KEY_ENTER
	dismiss.pressed = true
	paused = true
	hud._input(dismiss)
	check(hud._reward_reveal_shown, "reveal cannot consume menu Enter while paused")
	paused = false
	hud._input(dismiss)
	check(not hud._reward_reveal_shown and not hud._dismiss_reward.visible, "input dismisses presentation without changing reward owner")
	hud.set_report(Elements.damage_by, main.kills, 0, main.omen, "", Elements.metrics.report())
	hud.show_game_over(main.elapsed, main.kills, player.stats.level)
	check(hud._report.text.contains("available combat seconds") and hud.find_child("RecapScroll", true, false) != null, "recap labels denominator and scrolls")
	await _capture("measured-recap")
	hud.hide_end()
	# Exercise the scheduled shrine through its real once-only removal path.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7819
	var offering := ItemGenerator.generate_with(3, ItemData.Rarity.MAGIC, "amulet", rng, "elemental")
	main._events.configure_opportunity(offering.to_dict(), "fixture-attempt")
	check(main._events.start_opportunity() and not main._events.start_opportunity(), "one scheduled opportunity only")
	var event: Dictionary = main._events._events[-1]
	player.global_position = Vector3(event["at"].x, 0.0, event["at"].y)
	var drops: int = main._loot.drops.size()
	main._events._update_events(main._events.shrine_charge_time)
	check(main._events._events.is_empty() and main._loot.drops.size() == drops + 1, "charging offers once and removes the event immediately")
	var dropped: Item = main._loot.drops[-1]["item"]
	check(dropped.name == offering.name and dropped.affixes == offering.affixes and dropped.campaign_id == "fixture-attempt:drop:opportunity", "live shrine uses exact committed thematic roll and attempt identity")
	main._events._update_events(main._events.shrine_charge_time)
	check(main._loot.drops.size() == drops + 1 and player.warding_charge_left > 0.0, "no duplicate offering; empowered charge ready")
	player.challenge_id = "trial_dash"
	main._events.bless_for("Warding", 30.0)
	check(player.warding_charge_left == 0.0, "trial kit cannot gain an out-of-kit Warding pulse")
	player.challenge_id = ""
	player._dash_time = 0.0
	player.shield_left = 0.0
	player.recovery_charge = true
	player.stats.hp = 10.0
	player.take_damage(1000.0)
	check(not player.dead and not player.recovery_charge and is_equal_approx(player.stats.hp, player.stats.max_hp * 0.35), "recovery kit activates once, including a lethal crossing of its threshold")
	await _town_gallery()
	main.free()
	Elements.reset()
	Juice.reset()
	await process_frame
	print("DEFERRED UI %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)

func _town_gallery() -> void:
	MetaProgress.bestiary = {"Ghoul": 1000}
	main.hide()
	main._hud.hide()
	CampaignSave.path = "user://deferred-ui-%d-%d.save" % [OS.get_process_id(), Time.get_ticks_usec()]
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 58103)["ok"], "native town fixture")
	var next := controller.snapshot()
	next["gold"] = 350
	next["fatigue_enabled"] = true
	var veteran := controller._veteran_record({"name": "Orin", "swarm": "Grunts", "label": "Ghoul", "role": "brawler", "rank": 2, "deeds": 24, "nights": 1}, "orin")
	veteran["fatigue"] = 1
	next["roster"] = [veteran]
	next["deployed_veteran"] = "orin"
	check(controller._commit(next)["ok"], "veteran planning fixture")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame
	town._open_station("roster")
	await _capture("preparation-veterans")
	check(town._content.find_child("*", false, false) != null, "real preparation service renders")
	await _scroll_to_bottom(town._content.get_parent())
	await _capture("veteran-fatigue")
	town._open_station("trainer")
	await _capture_top("mastery-goals", town._content.get_parent())
	await _scroll_to_bottom(town._content.get_parent())
	await _capture("mastery-goals-detail")
	var trial_id := ""
	for node: Dictionary in controller.available_routes():
		if TacticTrials.DEFS.has(node["contract"]): trial_id = node["id"]
	check(trial_id != "", "owned trial is on new campaign opening roads")
	check(controller.choose_route(trial_id)["ok"], "trial committed from owned snapshot")
	if controller.state["phase"] == "EVENT_PENDING":
		var choice: String = controller.state["event"]["choices"][0]["id"]
		check(controller.resolve_event(choice)["ok"], "trial route event resolved")
	town._open_station("route")
	await _capture_top("trial-contract", town._content.get_parent())
	await _scroll_to_bottom(town._content.get_parent())
	await _capture("trial-kit-detail")
	check(CampaignLoadout.preview(controller.state)["trial"] != "", "preview includes real granted kit")
	town.free()
	controller.free()
	for suffix in ["", ".bak", ".previous", ".rollback", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignSave.path + suffix))
	main._title.open()
	main._title._relic_overlay.show()
	main._title._fill_reliquary()
	var reliquary_copy := ""
	for label: Label in main._title._relic_box.find_children("*", "Label", true, false): reliquary_copy += label.text + "\n"
	check(reliquary_copy.contains("Requires owned relic (stars or trial clear)") and reliquary_copy.contains(Relics.price_text("blade_compass")), "package and relic copy includes trial receipt as an alternative to stars")
	await _capture("reliquary-packages")
	await _scroll_to_bottom(main._title.find_child("ReliquaryScroll", true, false))
	await _capture("reliquary-packages-detail")
	check(main._title.find_child("ReliquaryScroll", true, false) != null and not MetaProgress.pick_package("relay"), "long Reliquary is scrollable and package cannot bypass ownership")

func _scroll_to_bottom(scroll: ScrollContainer) -> void:
	for i in 3: await process_frame
	var point := scroll.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for i in 45:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.position = point
		wheel.global_position = point
		wheel.pressed = true
		root.push_input(wheel, true)
		await process_frame
	check(scroll.scroll_vertical > 0, "real wheel input reaches overflowing service content")

func _activate(button: Button) -> void:
	for i in 30: await process_frame # Finish card dealing/layout before clicking.
	button.grab_focus()
	for i in 3: await process_frame
	var scroll := main._hud.find_child("UpgradeScroll", true, false) as ScrollContainer
	if scroll: scroll.ensure_control_visible(button)
	for i in 3: await process_frame
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	for i in 3: await process_frame

func _capture_top(label: String, scroll: ScrollContainer) -> void:
	# A shared service scroller retains its previous offset; show the new panel's
	# heading before exercising wheel input to its details. This is fixture state.
	for i in 3: await process_frame
	scroll.scroll_vertical = 0
	await _capture(label)

func _capture(label: String) -> void:
	for i in 30: await process_frame
	if capture_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join("%s-%dx%d.png" % [label, size.x, size.y])
	check(root.get_texture().get_image().save_png(path) == OK, "capture: " + label)
