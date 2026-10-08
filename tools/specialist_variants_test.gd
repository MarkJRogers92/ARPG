extends SceneTree
## Regression checks for the six imported cosmetic alternatives.
var _failures := 0
var _checks := 0
var _adapter: Script
const CASES := {
	"graveyard": {"shieldbearer": "bone_shieldbearer", "mender": "grave_mender"},
	"frozen": {"mender": "hoarfrost_shaman", "bloater": "frost_bloater"},
	"ember": {"shieldbearer": "obsidian_guard", "bloater": "magma_bloater"},
}

func _initialize() -> void:
	MetaProgress.disabled = true
	if not ResourceLoader.exists("res://scripts/visual/specialist_models.gd"):
		_check(false, "six-model mesh adapter is available")
		quit(1)
		return
	_adapter = load("res://scripts/visual/specialist_models.gd")
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", message)

func _run() -> void:
	_test_meshes()
	_test_realm_selection()
	_test_surface_effects()
	_test_mixed_swarm()
	_test_locomotion()
	_test_signatures()
	print("SPECIALIST VARIANTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _test_meshes() -> void:
	for realm: String in CASES:
		for role: String in CASES[realm]:
			var kind: String = CASES[realm][role]
			_check(_adapter.kind_for(realm, role) == kind, "exact realm/role mapping " + kind)
			var height := 1.3 if role == "bloater" else 1.6
			var mesh: ArrayMesh = _adapter.mesh(kind, height)
			_check(mesh != null, "loads " + kind)
			if mesh == null: continue
			_check(mesh.get_surface_count() == 2, "both surfaces retained " + kind)
			var body := 1.35 if role == "bloater" else 1.8
			var total := 2.3 if role == "mender" else body
			_check(absf(mesh.get_aabb().end.y - total * height / body) < 0.001, "body scale preserves staff height " + kind)
			_check(absf(mesh.get_aabb().position.y) < 0.001, "feet stay at zero " + kind)
			var scene: PackedScene = load("res://assets/enemies/specialists/%s.glb" % kind)
			var source := scene.instantiate()
			var imported := source.find_children("*", "MeshInstance3D", true, false)[0].mesh as Mesh
			for s in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(s)
				var original := imported.surface_get_arrays(s)
				_check(a[Mesh.ARRAY_COLOR] == original[Mesh.ARRAY_COLOR], "authored colors retained " + kind)
				_check(a[Mesh.ARRAY_TEX_UV] == original[Mesh.ARRAY_TEX_UV], "glow tags retained " + kind)
				_check(a[Mesh.ARRAY_INDEX] == original[Mesh.ARRAY_INDEX], "topology retained " + kind)
			source.free()
	for pair in [["graveyard", "bloater"], ["frozen", "shieldbearer"], ["ember", "mender"], ["graveyard", "grunt"], ["unknown", "shieldbearer"]]:
		_check(_adapter.kind_for(pair[0], pair[1]).is_empty(), "unapproved combinations stay procedural")
	_check(_adapter.mesh("missing_model", 1.6) == null, "invalid descriptor falls back")

func _test_realm_selection() -> void:
	for realm: String in CASES:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		Realm.apply_gameplay(main, realm)
		for name: String in ["Shieldbearers", "Menders", "Bloaters", "Grunts"]:
			var swarm := main.get_node(name) as EnemySwarm
			var expected: String = CASES[realm].get(swarm.model, "")
			_check(swarm.get("specialist_model") == expected, "only approved swarms gain variants " + realm + "/" + name)
		main.free()

func _test_mixed_swarm() -> void:
	var old := EnemySwarm.new()
	old.model = "shieldbearer"
	old.capacity = 8
	old.body_height = 1.6
	root.add_child(old)
	var mixed := EnemySwarm.new()
	mixed.model = old.model
	mixed.body_height = old.body_height
	mixed.capacity = old.capacity
	mixed.set("specialist_model", "bone_shieldbearer")
	root.add_child(mixed)
	var layer := mixed.get("_variant_layer") as MultiMeshInstance3D
	_check(layer != null, "one extra shared body batch is available")
	if layer == null:
		old.free()
		mixed.free()
		return
	seed(9419)
	for i in 8: old.spawn(Vector2(i + 4, 2), 1.2, i == 3)
	var next_old := randf()
	seed(9419)
	for i in 8: mixed.spawn(Vector2(i + 4, 2), 1.2, i == 3)
	_check(randf() == next_old, "variant allocation consumes no gameplay RNG")
	_check(mixed.count == old.count and mixed.hp == old.hp, "identical counts and health")
	_check(not mixed.spawn(Vector2.ZERO), "capacity remains enforced")
	_check(mixed._fire == old._fire, "attack/heal timer randomness is unchanged")
	old.step(0.0, Vector2.ZERO)
	mixed.step(0.0, Vector2.ZERO)
	_check(mixed.multimesh.visible_instance_count == 4 and layer.multimesh.visible_instance_count == 4, "both appearances rendered exactly once")
	_check(mixed.get_child_count() == 2, "only one shared variant layer plus original shadow, no enemy nodes")
	for s in layer.multimesh.mesh.get_surface_count():
		var material := layer.multimesh.mesh.surface_get_material(s) as ShaderMaterial
		_check(material != null and material.shader == mixed.multimesh.mesh.surface_get_material(0).shader, "every new surface uses the enemy shader")
		_check(material.get_shader_parameter("spectral") == mixed.spectral, "spectral behavior retained on every surface")
		_check(material.get_shader_parameter("rigid_accessories") == true, "imported shield and staff gait is protected")
	mixed.chill[3] = 2.0
	mixed.shock[3] = 2.0
	mixed.burn[3] = 2.0
	mixed.burn_dps[3] = 0.0
	mixed.mark_afflicted(3)
	mixed.damage(3, 0.5)
	mixed.step(0.016, Vector2.ZERO)
	_check_render_buffers(mixed, layer)
	var assignments := {}
	var appearance: PackedByteArray = mixed.get("_appearance")
	for i in mixed.count: assignments[mixed.ids[i]] = appearance[i]
	mixed.damage(0, 1.0e6)
	mixed.damage(2, 1.0e6)
	mixed.step(0.0, Vector2.ZERO)
	appearance = mixed.get("_appearance")
	for i in mixed.count:
		_check(appearance[i] == assignments[mixed.ids[i]], "appearance follows enemy through swap removal")
	_check_render_buffers(mixed, layer)
	mixed.pos[0] = Vector2(10000, 10000)
	mixed.step(0.0, Vector2.ZERO)
	appearance = mixed.get("_appearance")
	_check(appearance[0] == assignments[mixed.ids[0]], "recycling preserves appearance")
	mixed.despawn_all()
	mixed.step(0.0, Vector2.ZERO)
	_check(mixed.count == 0 and mixed.multimesh.visible_instance_count == 0 and layer.multimesh.visible_instance_count == 0, "both body batches clear on despawn")
	for i in 4: mixed.spawn(Vector2(i, 2))
	mixed.step(0.0, Vector2.ZERO)
	for i in mixed.count:
		_check(mixed._buffer[i * 20 + MultiMeshUtil.OFFSET_CUSTOM + 3] == 0.0, "reused rows never inherit a dead enemy's burn glow")
	var fallback := EnemySwarm.new()
	fallback.capacity = 2
	fallback.set("specialist_model", "invalid_optional_model")
	root.add_child(fallback)
	fallback.spawn(Vector2.ONE)
	fallback.step(0.0, Vector2.ZERO)
	_check(fallback.get("_variant_layer") == null and fallback.multimesh.visible_instance_count == 1, "invalid optional model uses the old body batch")
	fallback.free()
	old.free()
	mixed.free()

func _test_surface_effects() -> void:
	for realm: String in CASES:
		for role: String in CASES[realm]:
			var swarm := EnemySwarm.new()
			swarm.model = role
			swarm.capacity = 2
			swarm.body_height = 1.3 if role == "bloater" else 1.6
			swarm.set("specialist_model", CASES[realm][role])
			swarm.spectral = true
			root.add_child(swarm)
			var layer := swarm.get("_variant_layer") as MultiMeshInstance3D
			_check(layer != null, "all six variants have a body batch")
			if layer != null:
				for s in layer.multimesh.mesh.get_surface_count():
					var mat := layer.multimesh.mesh.surface_get_material(s) as ShaderMaterial
					_check(mat.get_shader_parameter("spectral") == true, "spectral effect applies to both surfaces for " + CASES[realm][role])
					_check(mat.get_shader_parameter("rigid_accessories") == true, "accessory deformation protected on all six")
					if realm == "ember":
						_check(mat.get_shader_parameter("rim_strength") == 0.65, "only new Ember silhouettes receive the bounded cool rim")
					else:
						_check(mat.get_shader_parameter("rim_strength") == null, "other authored models retain the stock rim")
			swarm.free()

func _check_render_buffers(swarm: EnemySwarm, layer: MultiMeshInstance3D) -> void:
	var appearance: PackedByteArray = swarm.get("_appearance")
	var canonical: PackedFloat32Array = swarm.get("_buffer")
	var body: PackedFloat32Array = swarm.multimesh.buffer
	var variant: PackedFloat32Array = layer.multimesh.buffer
	var rows := [0, 0]
	for i in swarm.count:
		var kind := int(appearance[i])
		var rendered := body if kind == 0 else variant
		for k in MultiMeshUtil.FLOATS_PER_INSTANCE:
			_check(absf(rendered[rows[kind] * 20 + k] - canonical[i * 20 + k]) < 0.0001, "transform, hit, phase, elite, tint and burn copied to selected body")
		rows[kind] += 1
	_check(rows[0] == swarm.multimesh.visible_instance_count and rows[1] == layer.multimesh.visible_instance_count, "rendered counts match living simulation rows")

# Cosmetic gait must follow actual displacement while AI/stats stay unchanged.
func _test_locomotion() -> void:
	for realm: String in CASES:
		for role: String in CASES[realm]:
			var swarm := EnemySwarm.new()
			swarm.model = role
			swarm.capacity = 2
			swarm.body_height = 1.3 if role == "bloater" else 1.6
			swarm.separation_strength = 0.0
			swarm.specialist_model = CASES[realm][role]
			root.add_child(swarm)
			swarm.spawn(Vector2(8, 0))
			swarm.spawn(Vector2(0, 8))
			var before := swarm.pos[1]
			for i in 4: swarm.step(1.0 / 60.0, Vector2.ZERO)
			_check(swarm.pos[1].distance_to(Vector2.ZERO) < before.length(), "authored enemy advances toward hero " + swarm.specialist_model)
			var o := 20
			var forward := Vector2(-swarm._buffer[o + 2], -swarm._buffer[o + 10]).normalized()
			_check(forward.dot(-swarm.pos[1].normalized()) > 0.999, "authored -Z front faces travel direction")
			_check(swarm._buffer[o + MultiMeshUtil.OFFSET_COLOR + 3] > 0.99, "moving gait active")
			swarm.hold_range = 30.0
			swarm.step(1.0 / 60.0, Vector2.ZERO)
			_check(swarm._buffer[o + MultiMeshUtil.OFFSET_COLOR + 3] == 0.0, "stopped authored enemy no longer walks in place")
			_check(swarm._buffer[MultiMeshUtil.OFFSET_COLOR + 3] == 1.0, "procedural gait unchanged")
			swarm.hold_range = 0.0
			swarm.chill[1] = 2.0
			swarm.mark_afflicted(1)
			swarm.step(1.0 / 60.0, Vector2.ZERO)
			_check(absf(swarm._buffer[o + MultiMeshUtil.OFFSET_COLOR + 3] - 0.5) < 0.001, "chilled stride follows slower travel")
			var layer := swarm._variant_layer
			for surface in layer.multimesh.mesh.get_surface_count():
				var mat := layer.multimesh.mesh.surface_get_material(surface) as ShaderMaterial
				_check(mat.get_shader_parameter("travel_gait") == true, "authored surfaces use forward step cycle")
			swarm.free()

func _test_signatures() -> void:
	for record in [["ferryman", 2.86, 2.86, 2159], ["debt_collector", 2.2, 2.655, 2494]]:
		var mesh: ArrayMesh = _adapter.mesh(record[0], record[1])
		_check(mesh != null, "signature mesh loads " + record[0])
		if mesh == null: continue
		_check(mesh.get_surface_count() == 2, "signature has both surfaces")
		_check(absf(mesh.get_aabb().end.y - record[2]) < 0.001, "signature preserves its approved native proportion")
		_check(absf(mesh.get_aabb().position.y) < 0.001, "signature ground pivot unchanged")
		var triangles := 0
		for i in mesh.get_surface_count(): triangles += mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3
		_check(triangles == record[3], "signature topology retained")
	for realm: String in CASES:
		_check(_adapter.kind_for(realm, "collector") == "debt_collector", "Collector descriptor available in existing realms")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	Realm.current = "graveyard"
	Realm.in_title = false
	root.add_child(main)
	var collectors := main.get_node("Collectors") as EnemySwarm
	collectors.spawn(Vector2(8, 0))
	collectors.spawn(Vector2(0, 8))
	collectors.step(1.0 / 60.0, Vector2.ZERO)
	_check(collectors._variant_layer != null, "Collector stays in shared swarm batching")
	_check(not collectors._appearance.is_empty() and collectors._appearance[0] == 1 and collectors._appearance[1] == 0, "first debt uses new art and later debts retain old appearance")
	if collectors._variant_layer != null:
		var mesh := collectors._variant_layer.multimesh.mesh
		var mat := mesh.surface_get_material(0) as ShaderMaterial
		var width: float = mat.get_shader_parameter("leg_width") if mat.get_shader_parameter("leg_width") != null else 0.2
		var chain_vertices := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for i in vertices.size():
				if tags[i].x > 0.0 and vertices[i].y < collectors.body_height * 0.3:
					chain_vertices += 1
					_check(absf(vertices[i].x) >= collectors.body_height * width or vertices[i].z <= -collectors.body_height * 0.1, "entire low chain stays outside the leg mask")
		_check(chain_vertices > 0, "chain protection exercises actual emissive geometry")
	_check(collectors.captor and collectors.body_height == 2.2 and collectors.capacity == 2, "Collector mechanics and collision sizing retained")
	var ferry := main._ferryman as Ferryman
	ferry._schedule.clear()
	_check(ferry._arrive(), "actual Ferryman encounter arrives")
	if not ferry._visit.is_empty():
		var visit: Node3D = ferry._visit.node
		var model := visit.get_child(0) as MeshInstance3D
		_check(model.mesh.get_surface_count() == 2, "actual encounter uses both authored Ferryman surfaces")
		_check((model.basis * Vector3.FORWARD).dot(Vector3.BACK) > 0.9999, "Ferryman still faces encounter camera")
		_check(visit.find_children("*", "OmniLight3D", true, false).size() == 1, "existing encounter light retained")
		for surface in model.mesh.get_surface_count():
			var mat := model.mesh.surface_get_material(surface) as ShaderMaterial
			_check(mat != null and mat.shader.resource_path == "res://shaders/kit.gdshader", "Ferryman surfaces share actual kit effects without imported double emission")
		ferry._depart()
	ferry.set("authored_model", false)
	_check(ferry._arrive(), "procedural Ferryman remains selectable")
	if not ferry._visit.is_empty():
		var model := (ferry._visit.node as Node3D).get_child(0) as MeshInstance3D
		_check(model.mesh == Models.ferryman(), "explicit fallback retains original Ferryman")
		ferry._depart()
	main.free()
