extends SceneTree
## Presentation contracts and real army combat parity with the optional allied
## mesh on/off. Run under a disposable user-data directory, as with other tests.
const VISUALS = preload("res://scripts/visual/combat_visuals.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	MetaProgress.disabled = true
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_warnings()
	_test_shots()
	var detailed := _army_trial(true)
	var fallback := _army_trial(false)
	check(detailed == fallback, "detail/legacy rendering has identical combat, saves and RNG")
	await _test_capacity_cleanup()
	Elements.reset()
	Juice.reset()
	CreatureModels.enabled = true
	Juice.bold_telegraphs = false
	print("COMBAT READABILITY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_warnings() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var c := Color(0.55, 0.85, 1.0, 0.45)
	Juice.bold_telegraphs = false
	var outline := HazardDirector.make_warning(host, Vector2(3, 4), c, 1.0, 4.8)
	var fill := HazardDirector.make_warning(host, Vector2(3, 4), c, 0.0, 4.8)
	var loot := HazardDirector.make_decal(host, Vector2.ZERO, c, 1.0, 2.0)
	var mat := outline.material_override as ShaderMaterial
	check(mat.shader.resource_path.ends_with("danger_warning.gdshader"), "danger has dedicated contrast shader")
	check((loot.material_override as ShaderMaterial).shader.resource_path.ends_with("ground_glow.gdshader"), "non-danger scenery glows remain unchanged")
	check(mat.get_shader_parameter("color") == c, "default element hue and opacity preserved")
	check((outline.mesh as PlaneMesh).size == Vector2(4.8, 4.8), "warning diameter preserved")
	check(outline.position == Vector3(3, 0.08, 4), "warning transform preserved")
	check(mat.render_priority > (fill.material_override as ShaderMaterial).render_priority, "countdown fill cannot cover outline")
	Juice.bold_telegraphs = true
	var bold := VISUALS.warning_material(c, 1.0, true)
	check(bold.get_shader_parameter("color") == Juice.warning_color(c), "bold warnings still work")
	check(bold.get_shader_parameter("strip") == true, "charge lines share danger language")
	Juice.bold_telegraphs = false
	var s := EnemySwarm.new()
	s.charger = true
	s.capacity = 2
	root.add_child(s)
	var line := (s._telegraph.multimesh.mesh as PlaneMesh).material as ShaderMaterial
	check(line.get_shader_parameter("strip") == true, "real charger uses contrast line")
	Juice.bold_telegraphs = true
	s.refresh_warnings()
	check(line.get_shader_parameter("color") == Juice.warning_color(EnemySwarm.CHARGE_LINE), "live charge warning settings refresh")
	Juice.bold_telegraphs = false
	s.free()
	host.free()


func _test_shots() -> void:
	var shots := EnemyShots.new()
	shots.capacity = 4
	root.add_child(shots)
	var player := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(player)
	var locator := player.get_node("Visual/Locator") as Label3D
	check(locator != null and not locator.no_depth_test, "hero locator respects scenery occlusion")
	check(locator.render_priority > 5 and locator.position.y > 3.5, "hero locator clears ordinary actors and combat-number ordering")
	player._visual.set_process(false)
	player._visual.set_crowd_count(800)
	for frame in 120:
		player._visual._process(1.0 / 60.0)
	check(locator.position.y > 5.9 and not locator.no_depth_test, "dense-crowd locator rises without x-ray rendering")
	player._visual.set_crowd_count(0)
	for frame in 120:
		player._visual._process(1.0 / 60.0)
	check(locator.position.y < 3.71, "locator settles back in quiet scenes")
	check((shots.multimesh.mesh.surface_get_material(0) as ShaderMaterial).shader.resource_path.ends_with("hostile_shot.gdshader"), "real enemy projectiles use solid threat shader")
	check((Models.bolt().surface_get_material(0) as ShaderMaterial).shader.resource_path.ends_with("glow.gdshader"), "hero bolts retain their trail shader")
	var hp := player.stats.hp
	shots.spawn(Vector2(6, 0), Vector2.LEFT, 3.0, 7.0, Elements.FROST, "Test witch")
	check(shots._element[0] == Elements.FROST and shots._damage[0] == 7.0, "element and damage unchanged")
	check(shots._vel[0] == Vector2(-3, 0), "shot velocity unchanged")
	shots.step(1.0, player)
	check(shots._pos[0] == Vector2(3, 0) and player.stats.hp == hp, "real shot flight unchanged")
	shots.step(1.0, player)
	check(shots.count == 0 and player.stats.hp < hp and player.chilled > 0, "shot collision, damage and chill preserved")
	shots.clear()
	check(shots.multimesh.visible_instance_count == 0, "shot clearing removes rendered instances")
	shots.free()
	player.free()


func _army_trial(detail: bool) -> Dictionary:
	Elements.reset()
	Juice.reset()
	EnemySwarm._next_id = 1
	EnemySwarm.deaths = 0
	CreatureModels.enabled = detail
	var host := Node3D.new()
	root.add_child(host)
	var player := load("res://scenes/player.tscn").instantiate() as Player
	host.add_child(player)
	var s := EnemySwarm.new()
	s.capacity = 32
	s.model = "grunt"
	s.creature_model = "coffin_crawler"
	s.max_hp = 20.0
	s.contact_dps = 0.0
	s.move_speed = 0.0
	host.add_child(s)
	var army := Army.new()
	host.add_child(army)
	army.setup(player, [s])
	Elements.player = player
	Elements.swarms = [s]
	check(army._types[0]["detailed"] == detail, "authored ally present or safe fallback")
	var mesh: Mesh = army._types[0]["mmi"].multimesh.mesh
	if detail:
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as ShaderMaterial
			check(mat.get_shader_parameter("spectral") == true and mat.get_shader_parameter("allied_attack") == true, "all imported ally surfaces animate spectrally")
		var enemy_mat := s._variant_layer.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		check(enemy_mat.get_shader_parameter("allied_attack") != true, "enemy material not mutated by ally")
	seed(81314)
	player.stats.minion_max = 4
	for i in 4:
		army._raise(0, false, false)
		army._pos[i] = Vector2(i * 1.8, 0)
	for i in 4:
		s.spawn(Vector2(i * 1.8, -0.7))
		s.hp[i] = 100000.0
	s.step(0.0, Vector2.ZERO)
	army.step(1.0 / 60.0)
	check(army._visual_attack[0] == 1.0, "real attack starts cosmetic swing")
	check(army._markers.multimesh.visible_instance_count == 4, "all living allies have bounded markers")
	for frame in 60:
		s.step(1.0 / 60.0, player.pos2)
		army.step(1.0 / 60.0)
	check(s.hp[0] < 100000.0 and float(Elements.damage_by.get("Soul Army", 0.0)) > 0.0, "parity trial actually deals army damage")
	var result := {"pos": army._pos.duplicate(), "hp": army._hp.duplicate(), "attack": army._attack.duplicate(),
		"slam": army._slam.duplicate(), "targets": army._target_id.duplicate(), "enemy_hp": s.hp.duplicate(),
		"snapshot": army.snapshot(), "damage": Elements.damage_by.duplicate(), "next_rng": randf()}
	Elements.reset()
	host.free()
	CreatureModels.enabled = true
	return result


func _test_capacity_cleanup() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var player := load("res://scenes/player.tscn").instantiate() as Player
	host.add_child(player)
	var s := EnemySwarm.new()
	s.capacity = 2
	s.creature_model = "coffin_crawler"
	host.add_child(s)
	var army := Army.new()
	host.add_child(army)
	army.setup(player, [s])
	player.stats.minion_max = Army.CAPACITY
	for i in Army.CAPACITY:
		check(army._raise(0, false, false), "raise up to existing army capacity")
	check(not army._raise(0, false, false), "army gameplay cap unchanged")
	army._draw()
	check(army._markers.multimesh.instance_count == Army.CAPACITY and army._markers.multimesh.visible_instance_count == Army.CAPACITY, "marker draw is capped at existing army capacity")
	army._visual_attack[39] = 0.75
	army._visual_motion[39] = 0.6
	army._remove(0, false, false)
	check(army._visual_attack[0] == 0.75 and is_equal_approx(army._visual_motion[0], 0.6), "cosmetic state follows swap removal")
	while army.count > 0:
		army._remove(army.count - 1, false, false)
	army._draw()
	check(army._markers.multimesh.visible_instance_count == 0, "no stale markers after removal")
	army._raise(0, false, false)
	check(army._visual_attack[0] == 0.0 and army._visual_motion[0] == 0.0, "reused row has no stale attack or travel")
	var weak: WeakRef = weakref(army._markers)
	Elements.reset()
	host.queue_free()
	await process_frame
	await process_frame
	check(weak.get_ref() == null, "deferred army exit releases marker owner")
