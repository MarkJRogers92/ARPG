extends SceneTree
## Isolated acceptance tests for the 24 approved static environment GLBs.
## Does not instantiate the main game or touch user saves.

const CATALOG_PATH := "res://assets/environment/arpg_pack/06_approved_collection/ASSET_CATALOG.json"
const PREFIX := "res://assets/environment/arpg_pack/"
const NEW_COUNT := 24
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(f != null, "catalog opens")
	if f == null:
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var valid_catalog: bool = parsed is Dictionary and parsed.get("assets") is Array
	_check(valid_catalog, "catalog contains an assets array")
	if not valid_catalog:
		quit(1)
		return
	var entries: Array = parsed["assets"]
	_check(entries.size() == NEW_COUNT, "catalog contains exactly 24 entries")
	if entries.size() != NEW_COUNT:
		quit(1)
		return
	_check(AssetProps.KINDS.size() == NEW_COUNT + 52, "approved kinds appended after original 52")
	var kinds := AssetProps.KINDS.keys()
	var new_kinds: Array[String] = []
	for i in entries.size():
		var item: Dictionary = entries[i]
		var kind: String = item["kind"]
		var appended: bool = kinds.size() >= NEW_COUNT + 52 and kinds[kinds.size() - NEW_COUNT + i] == kind
		_check(appended, "%s appended in catalog order" % kind)
		_check(not Landmarks.USES.has(kind), "%s is scenery, not a new gameplay interaction" % kind)
		if not AssetProps.has(kind):
			continue
		new_kinds.append(kind)
		var path: String = PREFIX + str(item["path"]) + ".glb"
		_check(FileAccess.file_exists(path), "%s GLB exists" % kind)
		if not FileAccess.file_exists(path):
			continue
		_check(FileAccess.get_sha256(path) == item["sha256"], "%s exact catalog SHA256" % kind)
		var packed := load(path) as PackedScene
		_check(packed != null, "%s imports as scene" % kind)
		if packed == null:
			continue
		var source_root := packed.instantiate()
		var meshes := source_root.find_children("*", "MeshInstance3D", true, false)
		if source_root is MeshInstance3D:
			meshes.push_front(source_root)
		_check(meshes.size() == 1, "%s has exactly one MeshInstance3D" % kind)
		if meshes.size() == 1:
			var raw := meshes[0] as MeshInstance3D
			_check(raw.mesh.get_surface_count() == item["surfaces"], "%s raw surface count" % kind)
			var raw_glow_count := 0
			for s in raw.mesh.get_surface_count():
				var mat := raw.mesh.surface_get_material(s) as BaseMaterial3D
				_check(mat != null and mat.cull_mode == BaseMaterial3D.CULL_BACK, "%s raw material backface culls" % kind)
				if mat != null:
					if mat.emission_enabled:
						raw_glow_count += 1
			_check(raw_glow_count == item["glow_surfaces"], "%s raw emissive surface count" % kind)
		var mesh := AssetProps.mesh(kind)
		_check(mesh != null and mesh == AssetProps.mesh(kind), "%s cached mesh exists" % kind)
		if mesh != null:
			_check(mesh.get_surface_count() == item["surfaces"], "%s cached surface count" % kind)
			var bounds := mesh.get_aabb()
			var expected := Vector3(item["bounds_godot_m"][0], item["bounds_godot_m"][1], item["bounds_godot_m"][2])
			_check((bounds.size - expected).abs().length() < 0.03, "%s imported bounds match catalog" % kind)
			var glow_count := 0
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				_check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), "%s retains vertex colours" % kind)
				_check(arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size(), "%s retains normals" % kind)
				var mat := mesh.surface_get_material(s) as ShaderMaterial
				_check(mat != null, "%s cached material is kit shader" % kind)
				if mat != null and mat.get_shader_parameter("flat_glow") > 0.0:
					glow_count += 1
			_check(glow_count == item["glow_surfaces"], "%s preserves emissive surfaces" % kind)
			var data := AssetProps.data(kind)
			var radius := 0.0
			for s in mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					radius = maxf(radius, Vector2(vertex.x, vertex.z).length() * float(data["scale"][1]))
			_check(radius <= data["footprint"] + 0.02, "%s scaled radial bounds fit footprint" % kind)
			_check((data["fx"] != null) == (item["glow_surfaces"] > 0), "%s glow FX matches authored glow" % kind)
		source_root.free()
	# Realm assignment is exclusive and every asset has positive placement weight.
	for item: Dictionary in entries:
		var kind: String = item["kind"]
		if not AssetProps.has(kind):
			continue
		var data := AssetProps.data(kind)
		_check(data["realm"] in Realm.ORDER, "%s realm exists" % kind)
		for realm: String in Realm.ORDER:
			var density: Dictionary = Realm.data(realm)["props"]
			if realm == data["realm"]:
				_check(float(density.get(kind, 0.0)) > 0.0, "%s has positive density in its biome" % kind)
			else:
				_check(not density.has(kind), "%s excluded from %s" % [kind, realm])
	# Art-only density tuning must not reduce existing interaction opportunities.
	var interaction_weights := {"bell_gibbet": 0.02, "wind_chime": 0.05, "chained_gong": 0.04,
		"soul_altar": 0.03, "stone_well": 0.03, "frozen_pond": 0.06, "forge": 0.05,
		"cauldron": 0.05, "fishing_hut": 0.05, "tome_pedestal": 0.03, "ritual_door": 0.02}
	for kind: String in Landmarks.USES:
		var realm: String = AssetProps.data(kind)["realm"]
		_check(is_equal_approx(float(Realm.data(realm)["props"][kind]), float(interaction_weights[kind])),
			"%s retains its original gameplay placement weight" % kind)
	# Bad/missing imports must fail quickly, not crash the later placement probes.
	if failures > 0:
		print("APPROVED COLLECTION: FAILED (%d catalog/import failures)" % failures)
		quit(1)
		return
	_test_fixed_extras(new_kinds)
	_test_sampling(new_kinds)
	await _test_frame_lifecycle(new_kinds)
	print("APPROVED COLLECTION: %s (%d checks; %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(1 if failures else 0)


func _test_fixed_extras(kinds: Array[String]) -> void:
	print("approved collection fixed-placement extras")
	var decor := WorldDecor.new()
	decor.view_chunks = 0
	decor.density = {}
	for i in kinds.size():
		var kind := kinds[i]
		var at := Vector2(3.25 + i * 0.015, -4.5 + i * 0.011)
		var yaw := 0.13 + float(i) * 0.021
		var scale := 0.72 + float(i % 7) * 0.09
		decor.fixed = [{"kind": kind, "at": at, "yaw": yaw, "scale": scale}]
		var result: Array = decor.compute(Vector2i(floori(at.x / decor.chunk_size), floori(at.y / decor.chunk_size)))
		var transforms: Array = result[0][kind]
		_check(transforms.size() == 1, "%s fixed placement appears once" % kind)
		if transforms.is_empty():
			continue
		var xf: Transform3D = transforms[0]
		_check(xf.origin.is_equal_approx(Vector3(at.x, 0.0, at.y)), "%s fixed placement non-origin centre" % kind)
		_check(absf(xf.basis.get_euler().y - yaw) < 0.0001, "%s fixed placement yaw" % kind)
		_check(absf(xf.basis.get_scale().x - scale) < 0.0001, "%s fixed placement scale" % kind)
		var d := AssetProps.data(kind)
		var circles: Array = result[2]
		_check(circles.size() == d["solid"].size(), "%s fixed collision circle count" % kind)
		for j in d["solid"].size():
			var local: Array = d["solid"][j]
			var world := xf * Vector3(local[0], 0.0, local[1])
			var expected_center := Vector2(world.x, world.z)
			var matched := false
			for circle in circles:
				if circle[0].distance_to(expected_center) < 0.0001 and absf(circle[1] - local[2] * scale) < 0.0001:
					matched = true
			_check(matched, "%s transformed circle %d centre/radius" % [kind, j])
		_check((result[3].size() == 1) == (d["fx"] != null), "%s fixed glow emitter presence" % kind)
		if d["fx"] != null and result[3].size() == 1:
			var expected_height: float = AssetProps.mesh(kind).get_aabb().size.y * 0.6 * scale
			_check(result[3][0][0].distance_to(xf.origin + Vector3(0, expected_height, 0)) < 0.0001,
				"%s fixed glow emitter transform" % kind)
			_check(result[3][0][1] == d["fx"], "%s emitter retains biome colour" % kind)
	# Approved architecture-specific walkability and blockers.
	var arch: Array = AssetProps.data("rift_archway")["solid"]
	_check(arch.size() == 2, "rift arch has two pillars")
	for c: Array in arch:
		_check(is_equal_approx(float(c[2]), 0.31), "rift arch pillar radius is .31")
		_check(Vector2(c[0], c[1]).length() > float(c[2]) + 0.5, "rift arch opening passes a .5 body")
	decor.fixed = [{"kind": "rift_archway", "at": Vector2(15.0, -9.0), "yaw": 0.0, "scale": 1.0}]
	var arch_circles: Array = decor.compute(Vector2i(1, -1))[2]
	Obstacles.set_circles(arch_circles, Rect2(Vector2(-20, -30), Vector2(50, 50)))
	_check(not Obstacles.blocked(Vector2(15.0, -9.0), 0.5), "rift arch centre passes .5 body via Obstacles")
	for c: Array in arch_circles:
		_check(Obstacles.blocked(c[0], 0.5), "rift arch pillars block .5 body via Obstacles")
	var blocker_kinds := ["warden_iron_gate", "warden_grave_fence", "warden_bone_barricade", "wastes_ice_barricade", "rift_obsidian_barricade"]
	for kind in blocker_kinds:
		var any_block := false
		for c: Array in AssetProps.data(kind)["solid"]:
			if Vector2(c[0], c[1]).length() < float(c[2]) + 0.5:
				any_block = true
		_check(any_block, "%s blocks a .5 body at its centre" % kind)
	_check(AssetProps.data("warden_ritual_circle")["solid"].is_empty(), "ritual circle remains non-colliding")
	decor.fixed = [{"kind": "warden_ritual_circle", "at": Vector2(15.0, -9.0), "yaw": 0.2, "scale": 1.0}]
	_check(decor.compute(Vector2i(1, -1))[2].is_empty(), "ritual circle creates no obstacle circles")
	# Production obstacle path: test circles after applying the transformed fixed extras.
	for kind in blocker_kinds:
		decor.fixed = [{"kind": kind, "at": Vector2(15.0, -9.0), "yaw": 0.43, "scale": 1.0}]
		var circles: Array = decor.compute(Vector2i(1, -1))[2]
		Obstacles.set_circles(circles, Rect2(Vector2(-20, -30), Vector2(50, 50)))
		_check(Obstacles.blocked(Vector2(15.0, -9.0), 0.5), "%s blocks .5 body via Obstacles" % kind)
	Obstacles.clear()
	decor.free()


func _test_sampling(kinds: Array[String]) -> void:
	print("approved collection chunk sampling")
	var decor := WorldDecor.new()
	decor.view_chunks = 0
	for realm: String in Realm.ORDER:
		decor.density = Realm.data(realm)["props"]
		var seen := {}
		for n in 800:
			var center := Vector2i(n * 17 + 101, -n * 29 - 307)
			var result: Array = decor.compute(center)
			var primary_count: int = result[4].size()
			for kind: String in AssetProps.KINDS:
				if AssetProps.data(kind)["landmark"]:
					for xf: Transform3D in result[0][kind]:
						if not WorldDecor._inside_group(Vector2(xf.origin.x, xf.origin.z), result[4]):
							primary_count += 1
			for kind: String in kinds:
				if AssetProps.data(kind)["realm"] != realm:
					_check(result[0][kind].is_empty(), "%s absent from non-biome %s sample" % [kind, realm])
				for xf: Transform3D in result[0][kind]:
					seen[kind] = true
			_check(primary_count <= 1, "%s chunk sample has at most one primary landmark/compound" % realm)
		var sample_chunk := Vector2i(53, -71)
		var a: Array = decor.compute(sample_chunk)
		decor.compute(Vector2i(-73, 29))
		var b: Array = decor.compute(sample_chunk)
		_check(a == b, "%s deterministic revisit after travelling to another chunk" % realm)
		for kind: String in kinds:
			if AssetProps.data(kind)["realm"] == realm:
				_check(seen.has(kind), "%s appears across distant sampled chunks" % kind)
		Obstacles.clear()
	decor.free()


func _test_frame_lifecycle(kinds: Array[String]) -> void:
	print("approved collection frame-driven WorldDecor lifecycle")
	var decor := WorldDecor.new()
	decor.view_chunks = 0
	decor.density = Realm.data("graveyard")["props"]
	decor.fixed = [{"kind": "warden_iron_gate", "at": Vector2(96.0, 96.0), "yaw": 0.2, "scale": 1.0},
		{"kind": "warden_soul_brazier", "at": Vector2(98.0, 96.0), "yaw": 0.4, "scale": 1.0}]
	root.add_child(decor)
	decor.follow(Vector2(96.0, 96.0))
	await process_frame
	await process_frame
	var prior_emitters := decor.emitters.duplicate(true)
	var prior_circles := Obstacles.circles.duplicate(true)
	_check(not decor.placed.is_empty(), "graveyard builds placed state")
	_check(not prior_emitters.is_empty(), "graveyard has glow emitters")
	_check(not prior_circles.is_empty(), "graveyard has obstacle circles")
	var old_mm: MultiMesh = decor._layers["warden_iron_gate"].multimesh
	decor.density = Realm.data("frozen")["props"]
	decor.fixed = [{"kind": "wastes_ice_barricade", "at": Vector2(108.0, 96.0), "yaw": 0.2, "scale": 1.0},
		{"kind": "wastes_frost_shrine", "at": Vector2(110.0, 96.0), "yaw": 0.4, "scale": 1.0}]
	decor.follow(Vector2(108.0, 96.0))
	await process_frame
	await process_frame
	_check(old_mm.instance_count == 0, "old graveyard multimesh cleared on chunk rebuild")
	for kind: String in kinds:
		if AssetProps.data(kind)["realm"] != "frozen":
			_check(decor.placed[kind].is_empty(), "%s cleared after realm switch to frozen" % kind)
	_check(decor.emitters != prior_emitters, "emitter list rebuilt on realm switch")
	_check(Obstacles.circles == decor.compute(Vector2i(9, 8))[2], "frozen rebuild replaces old obstacle circles exactly")
	decor.density = Realm.data("ember")["props"]
	decor.fixed = [{"kind": "rift_obsidian_barricade", "at": Vector2(120.0, 96.0), "yaw": 0.2, "scale": 1.0},
		{"kind": "rift_scorched_waystone", "at": Vector2(122.0, 96.0), "yaw": 0.4, "scale": 1.0}]
	decor.follow(Vector2(120.0, 96.0))
	await process_frame
	await process_frame
	for kind: String in kinds:
		if AssetProps.data(kind)["realm"] != "ember":
			_check(decor.placed[kind].is_empty(), "%s cleared after realm switch to ember" % kind)
	_check(Obstacles.circles == decor.compute(Vector2i(10, 8))[2], "ember rebuild replaces frozen obstacle circles exactly")
	# Empty density is an explicit rebuild case, including all cached render and collision state.
	decor.density = {}
	decor.fixed = []
	decor.rebuild_now()
	await process_frame
	await process_frame
	for kind: String in Models.PROPS:
		_check(decor._layers[kind].multimesh.instance_count == 0, "%s multimesh clears with empty density" % kind)
	_check(decor.emitters.is_empty(), "empty density clears glow emitters")
	_check(Obstacles.circles.is_empty() and Obstacles.width == 0, "empty density clears obstacle grid")
	decor.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(decor), "WorldDecor freed after deferred cleanup")
	Obstacles.clear()
