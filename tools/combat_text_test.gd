extends SceneTree
## Cosmetic budgets must not change values, RNG consumption or combat telemetry.
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func active(n: DamageNumbers, priority := -1) -> Array[int]:
	var out: Array[int] = []
	for i in n.pool_size:
		if n._age[i] < n.LIFE and (priority < 0 or n._priority[i] == priority): out.append(i)
	return out

func clear(n: DamageNumbers) -> void:
	n._process(n.LIFE + 0.01)

func _run() -> void:
	var n := DamageNumbers.new()
	root.add_child(n)
	n.set_process(false)
	Juice.calm = false
	check(n.get_child_count() == n.pool_size, "fixed label pool created once")
	for i in 4: n.show_number(Vector2.ZERO, 2.0, false, Color.WHITE)
	check(active(n).is_empty(), "ordinary hits retain original every-fifth sampling")
	n.show_number(Vector2.ZERO, 2.4, false, Color.WHITE)
	check(active(n).size() == 1 and n._labels[active(n)[0]].text == "2", "one exact rounded hit value, not a sum")
	n.show_number(Vector2.ZERO, 33.6, true, Color.WHITE)
	check(active(n).size() == 1 and n._labels[active(n)[0]].text == "34", "crit takes priority over nearby ordinary hit")
	check(n._labels[active(n)[0]].font_size == 46 and n._labels[active(n)[0]].scale.x <= 1.18, "critical emphasis is restrained")
	for i in 10: n.show_number(Vector2.ZERO, 99.0, false, Color.WHITE)
	check(n._labels[active(n)[0]].text == "34", "ordinary spam cannot overwrite a crit")
	n.show_number(Vector2.ZERO, 88.0, true, Color.WHITE)
	check(n._labels[active(n)[0]].text == "34", "rapid hits retain a minimum reading window")
	n._process(n.MIN_READ_TIME + 0.01)
	n.show_number(Vector2.ZERO, 88.0, true, Color.WHITE)
	check(active(n).size() == 1 and n._labels[active(n)[0]].text == "88", "later nearby hit replaces rather than stacks or totals")
	n.show_text(Vector2.ZERO, "SHATTER", Color.CYAN)
	check(active(n).size() == 1 and n._labels[active(n)[0]].text == "SHATTER", "reaction replaces nearby number")
	n.show_number(Vector2.ZERO, 100.0, true, Color.WHITE)
	check(n._labels[active(n)[0]].text == "SHATTER", "numbers cannot erase a reaction")
	clear(n)
	for i in 100: n.show_number(Vector2(i * 3.0, 0), float(i), true, Color.WHITE)
	check(active(n).size() == n.NUMBER_LIMIT, "numeric labels have a hard concurrent budget")
	for i in 12: n.show_text(Vector2(i * 3.0, 20), "REACTION " + str(i), Color.CYAN)
	check(active(n, 2).size() == n.REACTION_LIMIT and active(n).size() == n.NUMBER_LIMIT + n.REACTION_LIMIT, "reaction labels have a separate bounded budget")
	check(n.get_child_count() == n.pool_size, "bursts never allocate more labels")
	Juice.calm = true
	n._process(0.0)
	check(active(n).size() == n.CALM_NUMBER_LIMIT + n.REACTION_LIMIT, "live Calm toggle immediately trims cosmetic density")
	for i: int in active(n): check(n._labels[i].scale == Vector3.ONE, "Calm removes label scale animation")
	for i in 20: n.show_number(Vector2(i * 3.0, 40), float(i), true, Color.WHITE)
	check(active(n).size() <= n.CALM_NUMBER_LIMIT + n.REACTION_LIMIT, "ongoing Calm bursts respect the lower budget")
	clear(n)
	check(active(n).is_empty(), "all labels expire normally")
	for label: Label3D in n._labels: check(not label.visible, "expired pooled label hidden")
	Juice.calm = false
	n._normal_count = 0
	seed(49122)
	for i in 80:
		n.show_number(Vector2.ZERO, float(i), i % 3 == 0, Color.WHITE)
	var actual_rng := randf()
	seed(49122)
	var ordinary := 0
	for i in 80:
		if i % 3 != 0:
			ordinary += 1
			if ordinary % n.normal_every != 0: continue
		randf_range(-0.3, 0.3); randf_range(-0.2, 0.2); randf_range(-0.6, 0.6)
	check(actual_rng == randf(), "suppressed labels preserve the original gameplay RNG stream")
	var recorded := Elements.damage_by.duplicate(true)
	Juice.numbers = null
	clear(n)
	Juice.number(Vector2.ZERO, 100.0, true)
	check(active(n).is_empty(), "damage-numbers-off bypass remains effective")
	check(Elements.damage_by == recorded, "cosmetic labels never modify damage telemetry")
	var tiny := DamageNumbers.new()
	tiny.pool_size = 1
	root.add_child(tiny); tiny.set_process(false)
	tiny.show_number(Vector2.ZERO, 3, true, Color.WHITE)
	tiny.show_text(Vector2(20,20), "SHATTER", Color.CYAN)
	check(tiny._labels[0].text == "SHATTER", "tiny pools preserve reaction priority safely")
	tiny.free(); n.free(); Elements.reset(); Juice.reset()
	await _main_settings_flow()
	print("COMBAT TEXT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _main_settings_flow() -> void:
	Realm.in_title = false; Realm.current = "graveyard"; Realm.daily = false
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	root.size = Vector2i(1280, 720)
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main); current_scene = main
	await process_frame
	main.set_process(false)
	var numbers: DamageNumbers = main.get_node("DamageNumbers")
	numbers.set_process(false)
	var pause: PauseMenu = main._pause
	var toggles: Dictionary = {}
	for child: CheckButton in pause.find_children("*", "CheckButton", true, false): toggles[child.text] = child
	var stats_before: Array = main._player.stats._mods.duplicate(true)
	var hp_before: float = main._player.stats.hp
	for repeat in 3:
		pause.open(); paused = true
		(toggles["Calm effects"] as CheckButton).button_pressed = true
		check(Juice.calm and MetaProgress.setting("calm"), "real Pause Calm toggle applies " + str(repeat))
		pause.close(); paused = false
		for i in 30: Juice.number(Vector2(i * 3.0, 0), float(i), true)
		numbers._process(0.0)
		check(active(numbers).size() <= numbers.CALM_NUMBER_LIMIT, "Main uses Calm numeric budget")
		pause.open(); paused = true
		(toggles["Damage numbers"] as CheckButton).button_pressed = false
		check(Juice.numbers == null and not MetaProgress.setting("numbers"), "real Pause numbers-off applies")
		pause.close(); paused = false
		clear(numbers); Juice.number(Vector2.ZERO, 100, true)
		check(active(numbers).is_empty(), "Main no new label while numbers disabled")
		pause.open(); paused = true
		(toggles["Damage numbers"] as CheckButton).button_pressed = true
		(toggles["Calm effects"] as CheckButton).button_pressed = false
		pause.close(); paused = false
		check(Juice.numbers == numbers and not Juice.calm, "repeated settings return to normal")
	check(main._player.stats._mods == stats_before and main._player.stats.hp == hp_before, "presentation settings preserve actual Main player stats")
	var target := EnemySwarm.new()
	target.capacity = 1; target.max_hp = 100000.0; target.move_speed = 0.0; target.contact_dps = 0.0
	root.add_child(target); target.spawn(Vector2(30,30)); target.step(0.0, Vector2.ZERO)
	var expected_damage := -1.0
	# Render a controlled fixed cluster in the real camera for all settings.
	for mode: String in ["Normal", "Calm", "Numbers_off"]:
		clear(numbers)
		MetaProgress.settings["calm"] = mode == "Calm"
		MetaProgress.settings["numbers"] = mode != "Numbers_off"
		main.apply_settings()
		target.hp[0] = 100000.0
		Elements.source = "Text visibility check"
		var ledger_before := float(Elements.damage_by.get(Elements.source, 0.0))
		for i in 80: Elements.hit(target, 0, 12.0, Elements.NONE, true)
		var dealt := 100000.0 - target.hp[0]
		if expected_damage < 0.0: expected_damage = dealt
		check(is_equal_approx(dealt, expected_damage) and dealt > 0.0, "same actual enemy damage in " + mode)
		check(is_equal_approx(float(Elements.damage_by[Elements.source]) - ledger_before, dealt), "every hit remains in damage telemetry in " + mode)
		clear(numbers)
		for i in 80:
			var at := Vector2(-6.0 + (i % 8) * 1.5, -4.0 + (i / 8) * 1.0)
			Juice.number(at, float(5 + i), i % 3 == 0)
		numbers._process(0.0)
		if mode == "Numbers_off": check(active(numbers).is_empty(), "off render has no cosmetic labels")
		if output != "" and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(mode + ".png")) == OK, "render " + mode)
	target.free(); main.free(); current_scene = null; Elements.reset(); Juice.reset()
	await process_frame
