extends SceneTree
## Headless checks for the hero visual polish. No display, no save, no source
## project mutation: it only builds HeroModel / BattlemageModel nodes in the
## test process and steps them with an explicit delta (the engine's own
## _process is disabled on every fixture, so the numbers are deterministic).
##
## Covers:
##   - Battlemage (empty look) vs every other class (non-empty palette);
##   - the original Models.hero_body is kept, not silently reskinned;
##   - weapon mesh parity and the fixed Models.HERO_HAND mount;
##   - a grounded, ~2 m articulated rig and no extra lights/particles/marker;
##   - motion/cast determinism, cast retriggering and settling to neutral;
##   - neutral reset on a class switch;
##   - deferred-free cleanup with no stale references.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	ProjectSettings.set_setting("visuals/imported_roster", false)
	# Keep regression coverage for the prior selectable/fallback rig.
	ProjectSettings.set_setting("visuals/aegis_battlemage", false)
	call_deferred("_run")


func _run() -> void:
	var hero := _spawn()
	check(hero.uses_battlemage(), "the default (empty) look selects the Battlemage model")
	check(not hero._body.visible and hero._battlemage.visible, "the generic body hides and the Battlemage rig shows")
	check(hero._weapon_pivot.get_parent() == hero._battlemage.hand_mount(), "the weapon mount rides the Battlemage rig")
	check(hero._weapon_pivot.position.is_equal_approx(Models.HERO_HAND), "the Battlemage mount stays at Models.HERO_HAND")

	# Every other hero keeps the original body: no silent reskin.
	for id: String in ["necromancer", "pyromancer", "stormcaller", "reaper"]:
		var look: Dictionary = HeroClass.data(id)["look"]
		check(not look.is_empty(), "%s has a non-empty palette" % id)
		hero.set_body(look)
		check(not hero.uses_battlemage(), "%s keeps the original hero body" % id)
		check(hero._body.visible and not hero._battlemage.visible, "%s shows the original body, not the Battlemage" % id)
		check(hero._body.mesh == Models.hero_body(look), "%s body mesh matches Models.hero_body(look)" % id)
		check(hero._weapon_pivot.position.is_equal_approx(Models.HERO_HAND), "%s weapon mount stays at Models.HERO_HAND" % id)
		check(hero._weapon_pivot.get_parent() == hero._rig, "%s weapon mount returns to the shared rig" % id)

	# Articulated, grounded, and no extra lights/particles on the model.
	hero.set_body({})
	var aabb := _local_aabb(hero._battlemage)
	check(aabb.position.y > -0.15 and aabb.position.y < 0.15, "Battlemage feet stay near ground level (min y=%.3f)" % aabb.position.y)
	check(aabb.size.y > 1.6 and aabb.size.y < 2.4, "Battlemage stays about existing height (%.2f m)" % aabb.size.y)
	check(hero._rig.find_children("*", "GPUParticles3D", true, false).is_empty(), "no extra particles on the hero")
	var marker_count := 0
	for mesh_node: MeshInstance3D in hero.find_children("*", "MeshInstance3D", true, false):
		if mesh_node.mesh is PlaneMesh:
			marker_count += 1
	check(marker_count == 0, "HeroModel adds no duplicate ground marker (player.tscn owns it)")
	check(hero._battlemage._arm_l.rotation.z < 0.0, "left arm rests outside the robe")
	check(hero._battlemage._cape[0].position.z >= 0.4 and hero._battlemage._cape[0].rotation.x < 0.0, "cape hangs behind the robe")
	var lights := 0
	for child: Node in hero.get_children():
		if child is OmniLight3D:
			lights += 1
	check(lights == 1 and hero._light != null, "the only light is the single existing arcane light")

	# Weapon parity for every held base, on both bodies.
	var accent := Color(0.9, 0.3, 0.4)
	for base: String in ["Staff", "Wand", "Orb", "Scythe"]:
		hero.set_weapon(base, accent)
		check(hero._weapon.mesh == Models.item("weapon", base, accent), "%s weapon mesh matches Models.item" % base)
		check(hero._weapon.get_parent() == hero._weapon_pivot, "%s weapon is a child of the mount" % base)
	hero.set_body(HeroClass.data("reaper")["look"])
	for base: String in ["Staff", "Wand", "Orb", "Scythe"]:
		hero.set_weapon(base, accent)
		check(hero._weapon.mesh == Models.item("weapon", base, accent), "original body keeps %s weapon parity" % base)
	check(hero._weapon_pivot.position.is_equal_approx(Models.HERO_HAND), "weapon mount offset is identical on both bodies")

	_test_neutral_reset(hero)
	_test_determinism()
	_test_directional_gait()
	_test_material_isolation()
	await _test_cast_and_settle()
	await _test_cleanup()
	hero.free()
	_report()


func _spawn() -> HeroModel:
	var hero := HeroModel.new()
	root.add_child(hero)
	# HeroModel._ready() has already run synchronously on add_child; take the
	# animation out of the engine loop so the test owns every delta.
	hero.set_process(false)
	return hero


func _test_neutral_reset(hero: HeroModel) -> void:
	hero.set_body({})
	var rest := hero._battlemage.pose_signature()
	hero.set_motion(Vector2(5.0, 2.0), 0.25)
	hero.cast()
	for _i in 6:
		hero._process(1.0 / 60.0)
	check(hero._cast > 0.0 and hero._speed > 0.0, "the hero is mid-motion and mid-cast before the switch")
	var moving_pose := hero._battlemage.pose_signature()
	var moving_cast := hero._cast
	hero.set_body({})
	check(hero._battlemage.pose_signature() == moving_pose and hero._cast == moving_cast, "presenting unchanged class does not interrupt walking/cast")
	# Switching class resets to neutral so the next look never inherits the old pose.
	hero.set_body(HeroClass.data("pyromancer")["look"])
	check(hero._local == Vector2.ZERO and hero._speed == 0.0 and hero._cast == 0.0, "class switch clears motion and cast")
	check(hero._rig.rotation.is_equal_approx(Vector3.ZERO), "class switch zeroes the shared rig rotation")
	check(hero._rig.position.is_equal_approx(Vector3.ZERO), "class switch zeroes the shared rig offset")
	hero.set_body({})
	check(hero._battlemage.pose_signature() == rest, "the Battlemage returns to its neutral pose")
	check(hero._light.light_color.is_equal_approx(Color(0.55, 0.75, 1.0)), "Battlemage restores its light colour after class switch")


func _test_determinism() -> void:
	var a := _spawn()
	var b := _spawn()
	for h: HeroModel in [a, b]:
		h.set_body({})
	# Identical inputs must produce identical poses; no wall-clock term.
	for _i in 90:
		for h: HeroModel in [a, b]:
			h.set_motion(Vector2(3.0, -1.5), 1.0 / 60.0)
			h._process(1.0 / 60.0)
	check(_near(a._local, b._local, 0.0), "motion integration is deterministic")
	check(a._battlemage.pose_signature() == b._battlemage.pose_signature(), "Battlemage gait is deterministic frame to frame")
	var ga := _spawn()
	var gb := _spawn()
	for h: HeroModel in [ga, gb]:
		h.set_body(HeroClass.data("stormcaller")["look"])
	for _i in 90:
		for h: HeroModel in [ga, gb]:
			h.set_motion(Vector2(-2.0, 4.0), 1.0 / 60.0)
			h._process(1.0 / 60.0)
	check(ga._rig.transform.is_equal_approx(gb._rig.transform), "original-body lean is deterministic")
	a.free()
	b.free()
	ga.free()
	gb.free()


func _test_material_isolation() -> void:
	var a := _spawn()
	var b := _spawn()
	var base := Models.material("kit", {"rim_strength": 0.6, "rim_color": Color(0.6, 0.8, 1.0)}, "hero")
	var a_mat: ShaderMaterial = a._battlemage._mat
	a_mat.set_shader_parameter("rim_strength", 0.99)
	var b_mat: ShaderMaterial = b._battlemage._mat
	check(not is_equal_approx(float(b_mat.get_shader_parameter("rim_strength")), 0.99), "each hero owns its own material")
	check(is_equal_approx(float(base.get_shader_parameter("rim_strength")), 0.6), "mutating a hero never touches the shared Models cache")
	a.free()
	b.free()


func _test_directional_gait() -> void:
	var hero := _spawn()
	for dir in [Vector2(0, -6), Vector2(0, 6), Vector2(6, 0), Vector2(-6, 0)]:
		hero.set_body({})
		hero._neutral()
		for frame in 60:
			hero.set_motion(dir, 1.0 / 60.0)
			if frame == 15:
				hero.cast()
			hero._process(1.0 / 60.0)
			check(hero._weapon_pivot.position.is_equal_approx(hero._battlemage.hand_position()), "weapon grip follows hand during travel/cast")
			check(_local_aabb(hero._battlemage).position.y >= -0.001, "posed feet remain above ground")
			var tip := hero._battlemage._torso.to_local(hero._battlemage._cape[2].to_global(Vector3(0, -0.3, 0)))
			check(tip.z > 0.36, "moving cape trails behind the robe")
		if absf(dir.x) > 0.0:
			check(absf(hero._battlemage._leg_l.rotation.z) > 0.01, "strafe uses a lateral leg swing")
		else:
			check(hero._battlemage._leg_l.rotation.x * hero._local.x * sin(hero._walk) > 0.0, "forward/backward swing follows travel sign")
	hero.free()


func _test_cast_and_settle() -> void:
	var hero := _spawn()
	hero.set_body({})
	hero.set_motion(Vector2(4.0, 0.0), 1.0 / 60.0)
	for _i in 10:
		hero._process(1.0 / 60.0)
	hero.cast()
	check(hero._cast == 1.0, "cast() starts the thrust at full strength")
	for _i in 6:
		hero._process(1.0 / 60.0)
	var decaying := hero._cast
	check(decaying < 1.0 and decaying > 0.0, "the cast envelope decays over time")
	hero.cast()
	check(hero._cast == 1.0, "a second cast() retriggers the thrust")
	# Settle: stop moving, run past the cast decay, and confirm a neutral pose.
	for _i in 150:
		hero.set_motion(Vector2.ZERO, 1.0 / 60.0)
		hero._process(1.0 / 60.0)
	check(hero._cast == 0.0, "the cast settles back to zero")
	check(hero._speed < 0.001 and hero._local.length() < 0.001, "speed and lean settle at rest")
	check(absf(hero._weapon_pivot.rotation.x) < 0.05, "the weapon returns to its resting angle")
	check(absf(hero._battlemage._torso.rotation.x) < 0.05 and absf(hero._battlemage._leg_l.rotation.x) < 0.05,
		"the Battlemage stride settles to neutral")
	hero.free()
	await process_frame


func _test_cleanup() -> void:
	var hero := _spawn()
	hero.set_body({})
	var body_ref: WeakRef = weakref(hero)
	var battlemage_ref: WeakRef = weakref(hero._battlemage)
	hero.queue_free()
	hero = null # never keep a stale reference to a deferred free
	await process_frame
	await process_frame
	check(body_ref.get_ref() == null, "a freed HeroModel is released")
	check(battlemage_ref.get_ref() == null, "its Battlemage rig is released too")


func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != root and node is Node3D:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box: AABB = xf * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _near(a: Vector2, b: Vector2, tol: float) -> bool:
	return absf(a.x - b.x) <= tol and absf(a.y - b.y) <= tol


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	print("HERO VISUAL: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("HERO_VISUAL_OK")
		quit(0)
	else:
		print("HERO_VISUAL_FAILED %d" % failures.size())
		quit(1)
