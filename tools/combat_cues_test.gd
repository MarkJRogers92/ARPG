extends SceneTree
## Normal Main HUD state and repeated pause/input flows, using an isolated profile.
var checks := 0
var failures := 0
var main: Node
var output := ""
func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.save_path = "user://combat-cues-test.profile"
	RunSave.path = "user://combat-cues-test.run"
	RunSave.pending = {}
	Realm.in_title = false
	Realm.daily = false
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func _action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new(); event.action = name; event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func _capture(name: String) -> void:
	if output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "rendered " + name)
func _run() -> void:
	seed(78133)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	await process_frame
	main.set_process(false)
	var p: Player = main._player
	var hud: Hud = main._hud
	p.invulnerable = true
	main._process(0.0)
	check(hud._dash_label.text.contains("DASH READY") and hud._dash_label.text.contains(Controls.tag("dash")), "ready shows current binding")
	check(hud._debug_label.text.contains("AIM: AUTO"), "normal Main exposes actual initial aim mode")
	p.stats.hp = 25.0
	p._dash_cooldown = 1.23
	main._process(0.0)
	check(hud._hp_text.text.contains("LOW HEALTH"), "low health has a non-color, non-motion text cue")
	check(hud._dash_label.text.contains("1.3 s"), "countdown rounds up to tenths from actual remaining time")
	p.stats.dash_cooldown = 0.8
	main._process(0.0)
	check(hud._dash_label.text.contains("1.3 s"), "changed cooldown stat cannot shorten displayed remaining timer")
	p._dash_cooldown = 0.001
	main._process(0.0)
	check(hud._dash_label.text.contains("0.1 s") and not hud._dash_label.text.contains("READY"), "positive remainder never falsely shows ready or zero seconds")
	p._dash_cooldown = 1.23
	MetaProgress.settings["calm"] = true
	main.apply_settings()
	main._process(0.0)
	hud.set_hurt(false, 1.0)
	var material := hud._vignette.material as ShaderMaterial
	var steady := float(material.get_shader_parameter("hurt"))
	for i in 5:
		await create_timer(0.08).timeout
		hud.set_hurt(false, 0.0)
		check(is_equal_approx(material.get_shader_parameter("hurt"), steady), "Calm low-HP warning is time-independent")
	check(steady > 0.0 and steady < 0.1, "Calm warning remains gentle but present")
	await _capture("calm_low_health")
	p.empower_warding(30.0)
	main._process(0.0)
	check(hud._dash_label.text.contains("WARDING 1.3 s") and hud._dash_label.tooltip_text.contains("30 s"), "charged ward retains actual cooldown and expiry")
	p._dash_cooldown = 0.0
	main._process(0.0)
	check(hud._dash_label.text.contains("WARDING READY"), "charge shows ready only at actual readiness")
	p.warding_charge_left = 0.0
	main._process(0.0)
	check(hud._dash_label.text.contains("DASH READY") and hud._dash_label.tooltip_text.is_empty(), "expired charge clears label and tooltip")
	Controls.rebind("dash", KEY_F)
	main._process(0.0)
	check(hud._dash_label.text.contains("[F]"), "dash hint refreshes after rebinding")
	Controls.reset()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(200,300); motion.relative = Vector2(10,0)
	Input.parse_input_event(motion)
	await process_frame
	main._process(0.0)
	check(p.aim_mode == Player.Aim.MOUSE and hud._debug_label.text.contains("AIM: MOUSE"), "real mouse event selects mouse label")
	await _action("toggle_aim")
	main._process(0.0)
	check(p.aim_mode == Player.Aim.AUTO and hud._debug_label.text.contains("AUTO (mouse off)"), "toggle explicitly reports mouse takeover disabled")
	Input.action_press("aim_down",1.0)
	main._process(0.0)
	check(p.aim_mode == Player.Aim.STICK and hud._debug_label.text.contains("AIM: STICK"), "stick aim label follows actual player state")
	Input.action_release("aim_down")
	main._process(0.0)
	check(p.aim_mode == Player.Aim.AUTO and hud._debug_label.text.contains("AUTO (mouse off)"), "releasing stick restores actual auto state")
	for cycle in 3:
		await _action("ui_cancel")
		check(paused and main._pause.is_open(), "repeated pause opens")
		var before: float = p.dash_cooldown_remaining()
		MetaProgress.settings["calm"] = cycle % 2 == 0
		main._pause.settings_changed.emit()
		await process_frame
		check(is_equal_approx(p.dash_cooldown_remaining(), before), "pause/settings cannot consume cooldown")
		check(Juice.calm == bool(MetaProgress.settings["calm"]), "Calm applies through real settings signal")
		await _action("ui_cancel")
		check(not paused and not main._pause.is_open(), "repeated cancel resumes")
	main._process(0.0)
	await process_frame
	check(hud._debug_label.get_global_rect().end.x <= root.get_visible_rect().size.x - 8, "longest aim hint fits the visible viewport without clipping")
	p.stats.hp = p.stats.max_hp / 3.0
	main._process(0.0)
	check(not hud._hp_text.text.contains("LOW HEALTH"), "warning clears at original one-third threshold")
	p.stats.hp = 0.0
	hud.refresh(p.stats, 0.0,0,0)
	check(not hud._hp_text.text.contains("LOW HEALTH"), "dead HP label does not suggest a live low-health state")
	p.stats.hp = p.stats.max_hp
	main._process(0.0)
	hud.set_hurt(false, 1.0)
	check(is_zero_approx(float(material.get_shader_parameter("hurt"))), "healing clears calm warning")
	# Successful dash, blocked repeat, cooldown and recovery through Main.
	p._dash_cooldown = 0.0
	p.stats.dash_cooldown = 0.8
	Input.action_press("dash")
	main._process(1.0/60.0)
	Input.action_release("dash")
	var uses := p.dash_uses
	check(uses == 1 and hud._dash_label.text.contains("0.8 s"), "real successful dash starts countdown")
	await process_frame
	Input.action_press("dash")
	main._process(1.0/60.0)
	Input.action_release("dash")
	check(p.dash_uses == uses and not hud._dash_label.text.contains("READY"), "cooldown press cannot change dash count/readiness")
	for i in 60:
		await process_frame
		main._process(1.0/60.0)
	check(hud._dash_label.text.contains("DASH READY"), "actual combat ticking restores ready")
	await _capture("recovered_auto_aim")
	# Real Night Market entry/exit uses the alternate Main HUD path.
	p._dash_cooldown = 0.73
	p.empower_warding(5.0)
	main._rift.enter_market()
	var combat_clock: float = main.elapsed
	main._process(0.0)
	check(main._rift.in_market() and hud._dash_label.text.contains("WARDING 0.8 s"), "actual market frame shows charge and true remaining timer")
	check(main.elapsed == combat_clock and hud._debug_label.text.contains("AIM: AUTO"), "market keeps combat clock held and aim state fresh")
	hud._hurt = 1.0
	p.stats.hp = p.stats.max_hp
	for i in 15: main._process(0.05)
	check(is_zero_approx(float(material.get_shader_parameter("hurt"))), "safe market/healing clears stale hurt edges")
	main._rift.leave_market()
	main._process(0.0)
	check(not main._rift.in_market() and hud._dash_label.text.contains("WARDING READY"), "market exit retains real cooldown readiness")
	# Actual long blessing text used to extend past the left screen edge.
	for i in 6: hud.toast("Notice %d" % i)
	hud.toast("Blessing of Warding: +150 armor (about half the damage) for 30 s · next successful dash spends one 3m frost pulse (20 base damage), even on a miss")
	await process_frame
	await process_frame
	check(hud._toasts.get_child_count() == 3, "notification stack has a bounded visible count")
	var toast := hud._toasts.get_child(-1) as Label
	check(toast.get_global_rect().position.x >= 8 and toast.get_global_rect().end.x <= root.get_visible_rect().size.x - 8, "long reward notice wraps inside the viewport")
	check(toast.get_global_rect().end.y < hud._prompt_label.get_global_rect().position.y, "notice stack stays above interaction guidance")
	await _capture("wrapped_reward_notice")
	main.queue_free()
	for i in 4: await process_frame
	print("COMBAT CUES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
