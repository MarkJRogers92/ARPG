extends SceneTree
## The new GLB path, independently of the existing procedural-rig regression.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("visuals/imported_roster", false)
	ProjectSettings.set_setting("visuals/aegis_battlemage", true)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func spawn() -> HeroModel:
	var hero := HeroModel.new()
	root.add_child(hero)
	hero.set_process(false)
	return hero

func _run() -> void:
	var hero := spawn()
	check(hero.uses_aegis() and hero.uses_battlemage(), "Aegis selected only for Battlemage")
	check(hero._aegis.scale == Vector3.ONE and not hero._rig.visible, "authored scale without old 1.12 multiplier")
	check(hero._aegis._skeleton.get_bone_count() == 18, "18-bone imported rig")
	check(hero._weapon_pivot.get_parent() == hero._aegis.hand_mount(), "equipped weapon rides right-hand socket")
	check(hero._weapon_pivot.position == Vector3.ZERO and hero._weapon.position == Vector3.ZERO, "authored staff uses its own grip origin")
	check(hero._aegis._socket.position.is_equal_approx(hero._aegis.GRIP), "neutral socket matches authored grip")
	var imported: MeshInstance3D = hero._aegis._model.find_child("Astrolabe_Staff", true, false)
	check(not imported.visible, "embedded staff hidden to prevent two held weapons")
	var body: MeshInstance3D = hero._aegis._model.find_child("Battlemage_Body", true, false)
	for s in body.mesh.get_surface_count():
		var material := body.get_surface_override_material(s) as StandardMaterial3D
		check(material != null and material.vertex_color_use_as_albedo, "cloth/metal/emissive vertex colors enabled")
		check(material != body.mesh.surface_get_material(s), "body materials are per-instance overrides")
		if s == 0:
			check(material.metallic == 0.0, "cloth stays non-metallic")
		if s == 1:
			check(material.metallic > 0.4, "metal material distinction preserved")
		if s == 2:
			check(material.emission_enabled and material.emission.b > material.emission.r, "arcane emission stays cyan")
	for direction in [Vector2(0, -6), Vector2(0, 6), Vector2(6, 0), Vector2(-6, 0), Vector2(4.24, -4.24)]:
		hero._neutral()
		for frame in 120:
			hero.set_motion(direction, 1.0 / 60.0)
			if frame % 30 == 0:
				hero.cast()
			hero._process(1.0 / 60.0)
			for foot in ["foot.L", "foot.R"]:
				check(hero._aegis.posed_bounds(foot).position.y >= -0.001, "posed boot stays above ground in all travel/cast directions")
			check(hero._weapon_pivot.position == Vector3.ZERO and hero._weapon_pivot.rotation == Vector3.ZERO, "no double-applied weapon recoil/offset")
			var expected := hero._aegis._skeleton_frame * hero._aegis._skeleton.get_bone_global_pose(hero._aegis._bones["hand.R"]) * hero._aegis._socket_rest
			check(hero._aegis._socket.transform.is_equal_approx(expected), "socket follows actual skeleton in same frame")
			check(hero._aegis.posed_bounds("cape").position.z > -0.15, "moving cape remains behind front robe panels")
			check(hero._aegis._socket.transform.origin.is_finite(), "pose is finite")
		var moving := hero._aegis.pose_signature()
		var cast_before := hero._cast
		hero.set_body({})
		check(moving == hero._aegis.pose_signature() and cast_before == hero._cast, "unchanged town class presentation doesn't reset motion")
	var accent := Color(0.9, 0.3, 0.4)
	for base in ["Staff", "Wand", "Orb", "Scythe"]:
		hero.set_weapon(base, accent)
		check(hero._weapon_pivot.get_parent() == hero._aegis.hand_mount(), "every weapon stays socket-attached")
		check((hero._weapon.transform * hero._aegis.weapon_grip(base)).is_equal_approx(Vector3.ZERO), "actual handle lies in the fingers for every weapon")
		if base == "Staff":
			check(hero._weapon.mesh.get_surface_count() == 3 and hero._weapon.position == Vector3.ZERO, "supplied staff is equipped at authored origin")
		else:
			check(hero._weapon.mesh == Models.item("weapon", base, accent), "non-staff equipment uses its existing mesh")
	for id in ["necromancer", "pyromancer", "stormcaller", "reaper"]:
		hero.set_body(HeroClass.data(id)["look"])
		check(not hero.uses_aegis() and not hero.uses_battlemage() and hero._body.visible and hero._rig.visible, "other class retains original body")
		check(hero._weapon_pivot.get_parent() == hero._rig and hero._weapon_pivot.position == Models.HERO_HAND, "other class restores legacy socket")
		check(hero._weapon.mesh == Models.item("weapon", "Scythe", accent), "class switch preserves equipped weapon")
		hero.set_body({})
		check(hero.uses_aegis() and hero._local == Vector2.ZERO and hero._cast == 0.0, "Aegis class switch resets motion")
	var a := spawn()
	var b := spawn()
	for frame in 90:
		for h in [a, b]:
			h.set_motion(Vector2(3, -2), 1.0 / 60.0)
			if frame in [15, 45]:
				h.cast()
			h._process(1.0 / 60.0)
	check(a._aegis.pose_signature() == b._aegis.pose_signature(), "skeletal gait is deterministic")
	var a_body: MeshInstance3D = a._aegis._model.find_child("Battlemage_Body", true, false)
	var b_body: MeshInstance3D = b._aegis._model.find_child("Battlemage_Body", true, false)
	(a_body.get_surface_override_material(0) as StandardMaterial3D).albedo_color = Color.RED
	check((b_body.get_surface_override_material(0) as StandardMaterial3D).albedo_color == Color.WHITE, "body material changes cannot affect another hero")
	for frame in 180:
		hero.set_motion(Vector2.ZERO, 1.0 / 60.0)
		hero._process(1.0 / 60.0)
	check(hero._speed < 0.001 and hero._cast == 0.0, "motion and cast settle at rest")
	check(absf(hero._aegis.posed_bounds("foot.L").position.y) < 0.001, "resting foot settles on ground")
	var weak: WeakRef = weakref(hero._aegis)
	hero.queue_free()
	a.queue_free()
	b.queue_free()
	hero = null
	await process_frame
	await process_frame
	check(weak.get_ref() == null, "deferred free releases Aegis without stale references")
	print("AEGIS_VISUAL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
