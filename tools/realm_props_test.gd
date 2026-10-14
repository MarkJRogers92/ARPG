extends SceneTree
## The textured scenery models (RealmProps) that replace the code-built props.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	for kind: String in RealmProps.KINDS:
		var d: Dictionary = RealmProps.KINDS[kind]
		check(kind in Models.PROPS, "%s is a WorldDecor prop kind" % kind)
		var mesh := Models.prop(kind)
		check(mesh != null and mesh == RealmProps.mesh(kind), "%s: Models.prop serves the Meshy mesh (one cached mesh)" % kind)
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		var native: bool = d.get("native", false)
		check(absf(box.position.y) < (0.15 if native else 0.01), "%s: base sits on y = 0" % kind)
		check(not native or (mesh.get_surface_count() >= 1 and d.has("file")), "%s: filler model has surfaces" % kind)
		if native:
			check(maxf(box.size.x, box.size.z) < 3.0 and box.size.y < 3.2, "%s: no giant outlier" % kind)
			continue
		check(absf(box.position.x + box.size.x * 0.5) < 0.01 and absf(box.position.z + box.size.z * 0.5) < 0.01, "%s: centered on its footprint" % kind)
		var extent := box.size.y if d["fit"] == "height" else maxf(box.size.x, box.size.z)
		check(absf(extent - d["size"]) < 0.02, "%s: normalized to %.2f m (%.2f)" % [kind, d["size"], extent])
		check(maxf(box.size.x, box.size.z) < 3.0 and box.size.y < 3.2, "%s: no giant outlier" % kind)
		var mat := mesh.surface_get_material(0) as ShaderMaterial
		check(mat != null and mat.get_shader_parameter("albedo_tex") != null, "%s: albedo texture is wired" % kind)
	# Variants exist in the realms that use them.
	check(Realm.REALMS["graveyard"]["props"].has("celtic_cross"), "graveyard places the celtic cross")
	check(Realm.REALMS["frozen"]["props"].has("frozen_deadtree"), "frozen places the dead tree variant")
	check(Realm.REALMS["ember"]["props"].has("magma_rock"), "ember places magma rocks")
	for realm: String in Realm.REALMS:
		for kind: String in Realm.REALMS[realm]["props"]:
			check(kind in Models.PROPS, "%s: density kind %s exists" % [realm, kind])
	# The old code-built meshes remain reachable (falling ice shards use one) and the switch works.
	check(Models.code_prop("ice").get_surface_count() > 0, "code-built ice shard still builds")
	RealmProps.enabled = false
	check(Models.prop("pine") == Models.code_prop("pine"), "disabled: the old pine comes back")
	RealmProps.enabled = true
	# The see-through window gets the hero position.
	RealmProps.set_hero(Vector3(3.0, 0.0, 4.0))
	var tree_mat := RealmProps.mesh("tree").surface_get_material(0) as ShaderMaterial
	check((tree_mat.get_shader_parameter("hero_position") as Vector3).is_equal_approx(Vector3(3.0, 0.9, 4.0)), "hero position reaches the props' dither window")
	print("REALM PROPS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)
