extends SceneTree
## Presentation-only contracts through the real Main encounter. No damage mocks.
var checks := 0
var failures := 0
var main: Node3D
var swarm: GuardianSwarm
var player: Player
var hud: Hud

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func fresh(hp_multiplier := 1.0, elite := false) -> Dictionary:
	swarm.despawn_all()
	swarm.step(0.0, player.pos2)
	check(swarm.spawn(Vector2.ZERO, hp_multiplier, elite), "guardian fixture spawns")
	var entry: Dictionary = swarm.visuals[swarm.ids[0]]
	entry.cooldown = 0.0
	swarm.step(0.0, player.pos2)
	return entry

func _run() -> void:
	var saved_calm := Juice.calm
	var saved_bold := Juice.bold_telegraphs
	seed(381974)
	main = load("res://scenes/pilot/guardian_encounter.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	swarm = main.get_node("Guardians")
	player = main.get_node("Player")
	hud = main.get_node("Hud")
	player.position = Vector3(0, 0, 3.0)
	player.invulnerable = true
	Juice.calm = false
	Juice.bold_telegraphs = false
	var entry := fresh()
	var warning := entry.telegraph as MeshInstance3D
	var material := warning.material_override as ShaderMaterial
	check(warning.visible and not material.get_shader_parameter("active"), "steady warning starts with wind-up")
	check(is_zero_approx(float(material.get_shader_parameter("progress"))), "countdown starts empty")
	check(is_equal_approx(warning.mesh.size.x * GuardianSwarm.BODY_SCALE, 7.8), "warning plane covers unchanged 3.8 m sector")
	check(not material.shader.code.contains("TIME") and not material.shader.code.contains("depth_test_disabled"), "no strobing or through-wall ink")
	var previous := 0.0
	for i in 13:
		swarm.step(0.05, player.pos2)
		var progress: float = material.get_shader_parameter("progress")
		check(progress >= previous and progress <= 1.0, "countdown is monotonic and bounded")
		previous = progress
	swarm.step(0.001, player.pos2)
	check(bool(material.get_shader_parameter("active")) and warning.visible, "active ink follows existing attack window")
	main._refresh_guardian_readout()
	check(hud._boss_label.text.ends_with("CUT") and hud._boss_box.visible, "HUD uses evaluated cut state")
	for i in 7: swarm.step(0.05, player.pos2)
	check(not warning.visible, "ink closes at recovery, never implies lingering damage")
	main._refresh_guardian_readout()
	check(hud._boss_label.text.ends_with("RECOVERING"), "HUD exposes punish/recovery period")
	entry = fresh()
	warning = entry.telegraph
	material = warning.material_override
	var original_progress: float = material.get_shader_parameter("progress")
	Juice.bold_telegraphs = true
	Juice.calm = true
	swarm._flash[0] = 0.8
	swarm.step(0.0, player.pos2)
	check(float(material.get_shader_parameter("stroke_width")) == 0.12, "Bold warnings widens the stroke live")
	check(material.get_shader_parameter("color") == Juice.warning_color(Color(1.0,0.48,0.12,0.78)), "Bold warnings uses shared color policy")
	check(material.get_shader_parameter("progress") == original_progress, "settings/zero-time refresh cannot advance combat")
	for body_material: ShaderMaterial in entry.actor._material_keepalive:
		check(body_material.get_shader_parameter("hit_strength") == 0.25 and is_equal_approx(body_material.get_shader_parameter("hit_flash"), 0.8), "Calm reduces cosmetic strength, preserves incoming damage signal")
	swarm.damage(0, 1.0)
	check(entry.actor.state == &"Hit" and not warning.visible, "hit interruption removes ink immediately")
	main._refresh_guardian_readout()
	check(hud._boss_label.text.ends_with("STAGGERED"), "stagger readout is explicit")
	entry = fresh(2.0, true)
	swarm.hp[0] = swarm._cap[0] * 0.35
	main._refresh_guardian_readout()
	check(is_equal_approx(hud._boss_bar.value, 0.35), "health uses spawn-time cap, including elites/multipliers")
	var real_boss: EnemySwarm = main.get_node("Bosses")
	real_boss.spawn(Vector2(10, 10))
	hud.refresh_extras(0, 0.0, "REAL BOSS", 0.5)
	main._refresh_guardian_readout()
	check(hud._boss_label.text == "REAL BOSS" and hud._boss_bar.value == 0.5, "real boss readout retains priority")
	real_boss.despawn_all()
	swarm.damage(0, 100000.0)
	main._refresh_guardian_readout()
	check(not hud._boss_box.visible and not entry.telegraph.visible, "dead guardian clears health and warning immediately")
	for i in 3:
		entry = fresh()
		main._refresh_guardian_readout()
		check(hud._boss_box.visible and is_equal_approx(hud._boss_bar.value, 1.0), "repeat spawn shows fresh health")
		swarm.despawn_all()
		main._refresh_guardian_readout()
		check(not hud._boss_box.visible, "despawn clears readout")
	entry = fresh()
	main._game_over = true
	main._refresh_guardian_readout()
	check(not hud._boss_box.visible, "game-over hides encounter readout")
	Juice.calm = saved_calm
	Juice.bold_telegraphs = saved_bold
	entry = {}
	material = null
	warning = null
	main.queue_free()
	for i in 4: await process_frame
	print("VISUAL POLISH: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
