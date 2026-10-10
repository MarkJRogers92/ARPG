extends SceneTree
## Deterministic imported-roster regression, with saves disabled.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	MetaProgress.disabled = true
	ProjectSettings.set_setting("visuals/imported_roster", true)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func spawn(id := "battlemage") -> HeroModel:
	var hero := HeroModel.new()
	hero.set_body(HeroClass.data(id)["look"])
	root.add_child(hero)
	hero.set_process(false)
	hero.set_weapon(HeroClass.data(id)["weapon"], HeroClass.data(id)["accent"])
	return hero

func _run() -> void:
	var hero := spawn()
	var weak_models: Array[WeakRef] = []
	for id: String in HeroClass.ORDER:
		var data := HeroClass.data(id)
		hero.set_body(data["look"])
		hero.set_weapon(data["weapon"], data["accent"])
		var rig := hero._imported
		check(hero.imported_class() == id, "matching class palette selects " + id)
		check(hero.uses_battlemage() == (id == "battlemage"), "Battlemage API does not misidentify other classes")
		check(not hero._rig.visible and not hero._body.visible and rig.scale == Vector3.ONE, "only authored-scale GLB visible")
		check(rig._skeleton.get_bone_count() == 18, "complete 18-bone rig: " + id)
		check(hero._weapon_pivot.get_parent() == rig.hand_mount(), "equipped weapon attached to correct hand")
		check(rig._socket.position.is_equal_approx(rig._skeleton_frame * rig.GRIP), "shared authored grip contract")
		var body: MeshInstance3D
		var embedded: MeshInstance3D
		for mesh: MeshInstance3D in rig._model.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).ends_with("_Weapon") or mesh.name == "Astrolabe_Staff":
				embedded = mesh
			else:
				body = mesh
		check(body != null and body.visible and embedded != null and not embedded.visible, "one body and one independently equipped weapon")
		for s in body.mesh.get_surface_count():
			var mat := body.get_surface_override_material(s) as StandardMaterial3D
			check(mat.vertex_color_use_as_albedo and mat != body.mesh.surface_get_material(s), "per-instance vertex colors: " + id)
			if mat.emission_enabled:
				check(mat.emission.is_equal_approx(rig._emission), "class-specific glow preserved")
		for animator: AnimationPlayer in rig._model.find_children("*", "AnimationPlayer", true, false):
			check(not animator.active and not animator.is_playing(), "imported demo clips cannot race procedural poses")
		var rest := rig.pose_signature()
		for velocity in [Vector2.ZERO, Vector2(0, -6), Vector2(0, 6), Vector2(6, 0), Vector2(-6, 0), Vector2(4.2, -4.2)]:
			hero._neutral()
			for frame in 90:
				hero.set_motion(velocity, 1.0 / 60.0)
				if frame % 30 == 0:
					hero.cast()
					hero._process(1.0 / 60.0)
				check(rig.posed_bounds("foot.L").position.y >= -0.001 and rig.posed_bounds("foot.R").position.y >= -0.001, "boots remain above ground: " + id)
				check(hero._weapon_pivot.position == Vector3.ZERO and hero._weapon_pivot.rotation == Vector3.ZERO, "single hand/socket motion, not double recoil")
				var expected := rig._skeleton_frame * rig._skeleton.get_bone_global_pose(rig._bones["hand.R"]) * rig._socket_rest
				check(rig._socket.transform.is_equal_approx(expected), "same-frame socket tracks skeleton")
				check(rig.posed_bounds("cape").position.z > -0.2, "cape remains behind front robes")
				check(rig._socket.transform.origin.is_finite(), "finite skeletal pose")
			check(rig.pose_signature() != rest, "gait/idle updates bones: " + id)
		var before := rig.pose_signature()
		var nodes_before := hero.get_child_count()
		for repeated in 120:
			hero.set_body(data["look"])
		check(rig.pose_signature() == before and hero.get_child_count() == nodes_before, "repeated town presentation does not reset/build models")
		var weapon_before := hero._weapon.mesh
		var cached_meshes: int = rig._mesh_cache.size()
		for repeated in 120:
			hero.set_weapon(data["weapon"], data["accent"])
		check(hero._weapon.mesh == weapon_before and rig._mesh_cache.size() == cached_meshes, "repeated equipment presentation avoids native mesh churn")
		for base in ["Staff", "Wand", "Orb", "Scythe"]:
			hero.set_weapon(base, data["accent"])
			var native: bool = base == data["weapon"]
			var grip := Vector3.ZERO if native else rig.weapon_grip(base)
			check((hero._weapon.transform * grip).is_equal_approx(Vector3.ZERO), "actual equipped grip in fingers: " + id + "/" + base)
			check(hero._weapon.mesh.get_surface_count() == 3 if native else hero._weapon.mesh == Models.item("weapon", base, data["accent"]), "native/legacy equipment selection")
			check(not embedded.visible, "embedded weapon remains hidden on every equipment swap")
		for frame in 180:
			hero.set_motion(Vector2.ZERO, 1.0 / 60.0)
			hero._process(1.0 / 60.0)
		check(hero._cast == 0.0 and hero._speed < 0.001, "cast and movement settle")
		check(absf(rig.posed_bounds("foot.L").position.y) < 0.001, "resting boot grounds exactly")
		var a := spawn(id)
		var b := spawn(id)
		for frame in 60:
			for h in [a, b]:
				h.set_motion(Vector2(3, -2), 1.0 / 60.0)
				if frame == 25:
					h.cast()
				h._process(1.0 / 60.0)
		check(a._imported.pose_signature() == b._imported.pose_signature(), "same deltas give deterministic motion")
		var a_body: MeshInstance3D
		var b_body: MeshInstance3D
		for mesh: MeshInstance3D in a._imported._model.find_children("*", "MeshInstance3D", true, false):
			if mesh.visible:
				a_body = mesh
		for mesh: MeshInstance3D in b._imported._model.find_children("*", "MeshInstance3D", true, false):
			if mesh.visible:
				b_body = mesh
		(a_body.get_surface_override_material(0) as StandardMaterial3D).albedo_color = Color.RED
		check((b_body.get_surface_override_material(0) as StandardMaterial3D).albedo_color == Color.WHITE, "no cross-hero material mutation")
		weak_models.append(weakref(a._imported))
		a.queue_free()
		b.queue_free()
	# Every ordered class-switch pair, while preserving the equipped item.
	for from_id: String in HeroClass.ORDER:
		for to_id: String in HeroClass.ORDER:
			hero.set_body(HeroClass.data(from_id)["look"])
			hero.set_motion(Vector2(3, -2), 0.1)
			hero.cast()
			hero._process(0.1)
			hero.set_weapon("Wand", Color(0.2, 0.9, 0.7))
			hero.set_body(HeroClass.data(to_id)["look"])
			check(hero.imported_class() == to_id and hero._weapon_base == "Wand", "class switch keeps equipped base and picks correct body")
			if from_id != to_id:
				check(hero._cast == 0 and hero._local == Vector2.ZERO, "changed class returns to neutral")
			var visible := 0
			for model in hero._imported_models.values():
				visible += int(model.visible)
			check(visible == 1, "one imported body visible after switch")
	check(hero._imported_models.size() == 5, "bounded five-model cache after repeated switches")
	# Custom palettes must not accidentally select a class.
	hero.set_body({"robe": Color.BLUE, "eye": Color.YELLOW})
	check(not hero.uses_imported() and hero._rig.visible and hero._body.visible, "unknown custom palette preserves fallback")
	check(hero._weapon_pivot.get_parent() == hero._rig, "fallback weapon mount restored")
	# Integration through real Player/HeroClass, preserving class stats and attacks.
	MetaProgress.forced_class = "battlemage"
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.setup([], null)
	for id: String in HeroClass.ORDER:
		HeroClass.apply(player, id)
		check(player._visual.imported_class() == id, "Player class presentation selects imported rig")
		check(player._visual._weapon_base == HeroClass.data(id)["weapon"], "Player class starts with correct weapon category")
		check(player.stats.powers.has("reaping") == (id == "reaper"), "Reaper attack authority stays in class gameplay")
		var collision := player.get_node("Collision").shape as CapsuleShape3D
		check(collision.radius == 0.5 and is_equal_approx(collision.height, 2.2), "crowns and scythe never change player collision")
		if id == "reaper":
			player._visual._cast = 0
			player._scythe.update(1.0)
			check(player._visual._cast == 1.0 and player._scythe._blades.size() == 1, "actual timed scythe throw triggers pose, not a new attack event")
	# Fresh visual represents respawn, not leftover cast on the previous instance.
	var respawn := spawn("reaper")
	check(respawn._cast == 0.0 and respawn._local == Vector2.ZERO and respawn.imported_class() == "reaper", "fresh respawn starts neutral in selected class")
	weak_models.append(weakref(hero._imported_models["reaper"]))
	player.queue_free()
	respawn.queue_free()
	hero.queue_free()
	hero = null
	Elements.reset()
	Juice.reset()
	MetaProgress.forced_class = ""
	await process_frame
	await process_frame
	for weak in weak_models:
		check(weak.get_ref() == null, "deferred free releases cached rigs without stale references")
	print("HERO_ROSTER: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
