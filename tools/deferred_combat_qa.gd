extends SceneTree
## Controlled crowded snapshots of all three live interactions. Not a balance
## or performance benchmark; runtime dash/input checks live in deferred_ui_test.
var capture_dir := ""
var viewport_size := Vector2i(1280, 720)
var failures := 0

func _initialize() -> void:
	MetaProgress.disabled = true
	Realm.in_title = false
	RunSave.pending = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--width="): viewport_size.x = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): viewport_size.y = int(arg.trim_prefix("--height="))
	_run.call_deferred()

func _run() -> void:
	root.size = viewport_size
	seed(58103)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var player: Player = main._player
	var swarm := main.get_node("Grunts") as EnemySwarm
	for other: EnemySwarm in main._swarms:
		other.despawn_all()
		other.step(0.0, player.pos2) # Reset stale spatial grids before area/army queries.
	for i in 160:
		var at := Vector2.from_angle(float(i) * 2.399963) * (2.0 + sqrt(float(i) / 160.0) * 7.0)
		swarm.spawn(at, 3.0)
	# Put visible targets inside each of the three Blade Wake pulses too.
	for i in 3: swarm.pos[i] = Vector2(2.0 + i * 2.0, 0.0)
	swarm.step(0.0, player.pos2)
	for card: String in ["lightning", "aura", "orbit", "ignite", "legion", "synergy_relay", "synergy_escort", "synergy_wake"]: Upgrades.apply(card, player.stats)
	player.stats.crit_chance = 0.0
	for i in 2: main._army._raise(main._army.type_index(swarm), false, false)
	main._army.step(0.0)
	swarm.chill[0] = 2.0
	swarm.burn[1] = 2.0
	Elements.metrics.tick(1.0 / 60.0, CombatLedger.available(player.stats, main._army.count))
	Elements.source = "Chain Lightning"
	Elements.hit(swarm, 0, 4.0, Elements.LIGHTNING)
	Elements.source = "Soul Army"
	Elements.hit(swarm, 1, 4.0, Elements.NONE)
	player.build_synergies.on_dash(player, Vector2.RIGHT)
	main._flush_build_synergies()
	Elements.flush()
	main._fx.step(0.06)
	player._update_aura(1.0 / 60.0)
	main._hud.refresh(player.stats, 120.0, main.kills, swarm.alive_count())
	main._hud.toast("LIVE · Frost Relay + Ashen Escort + Blade Wake · controlled 160-enemy crowd", UiStyle.GOLD)
	for source: String in ["Frost Relay", "Ashen Escort", "Blade Wake"]:
		if float(Elements.damage_by.get(source, 0.0)) <= 0.0:
			failures += 1
			push_error("Missing integrated synergy damage: " + source)
	for opacity: float in [1.0, 0.35]:
		Juice.set_friendly_opacity(opacity)
		for i in 15: await process_frame
		if capture_dir != "" and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(capture_dir)
			await RenderingServer.frame_post_draw
			var path := capture_dir.path_join("live-synergies-%s-%dx%d.png" % [str(opacity), viewport_size.x, viewport_size.y])
			if root.get_texture().get_image().save_png(path) != OK: failures += 1
	print("DEFERRED COMBAT QA %s · actual synergy damage %s" % ["PASSED" if failures == 0 else "FAILED", str(Elements.damage_by)])
	main.free()
	Elements.reset()
	Juice.reset()
	await process_frame
	quit(0 if failures == 0 else 1)
