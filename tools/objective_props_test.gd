extends SceneTree
## Standalone presentation fixture; never opens a controller or save/profile.
## godot --headless --path . -s tools/objective_props_test.gd
## godot --path . -s tools/objective_props_test.gd -- /tmp
## Display mode writes objective-props-overview.png and objective-props-combat.png.

const IDS := ["seal_1", "cache", "elite"]
const COLORS := [Color(0.35, 0.92, 1.0), Color(0.8, 0.55, 1.0), Color(1.0, 0.55, 0.22)]
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	MetaProgress.disabled = true
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.7)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_color = Color(1.0, 0.9, 0.76)
	light.light_energy = 1.25
	light.shadow_enabled = true
	world.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = Models.material("ground")
	world.add_child(ground)
	var props: Array[MeshInstance3D] = []
	for i in IDS.size():
		var holder := _marker(world, IDS[i], COLORS[i], Vector3(float(i - 1) * 4.2, 0, 0))
		var label := holder.get_child(2)
		var prop := ObjectiveProps.attach(holder, IDS[i], COLORS[i])
		props.append(prop)
		_check(holder.get_child(2) == label and label is Label3D, "Existing label index must remain 2")
		_check(holder.get_child_count() == 4 and prop.get_child_count() == 0, "Each marker adds exactly one leaf instance")
		_check(prop.mesh.get_surface_count() == 1, "One surface per objective prop")
		var vertices: int = prop.mesh.surface_get_array_len(0)
		_check(vertices <= 9000, "Geometry must stay below 3000 triangles per prop")
		var bounds := prop.mesh.get_aabb()
		_check(bounds.position.x >= -1.0 and bounds.end.x <= 1.0 and bounds.position.z >= -1.0 and bounds.end.z <= 1.0, "Prop must remain inside its navigation ring")
		_check(bounds.position.y >= 0.0 and bounds.end.y < 2.95, "Props must not intersect navigation labels")
		_check(not prop.is_processing() and not prop.is_physics_processing(), "Props have no per-frame work")
		if IDS[i] == "elite":
			_check(bounds.position.y > 2.0, "Elite decoration must float above the target")
		print(IDS[i], ": vertices=", vertices, " triangles=", vertices / 3, " surfaces=", prop.mesh.get_surface_count(), " bounds=", bounds)
		# Lifecycle is inherited from the holder; no detached animation or nodes.
		holder.visible = false
		_check(not prop.is_visible_in_tree(), "Claiming/hiding the holder must hide its prop")
		holder.visible = true
	var extra := Node3D.new()
	world.add_child(extra)
	var shared := ObjectiveProps.attach(extra, "seal_3", COLORS[0])
	_check(shared.mesh == props[0].mesh, "All seal instances reuse cached geometry")
	_check(ObjectiveProps.attach(extra, "unknown", Color.WHITE) == null, "Unknown objective adds no art")
	_check(ObjectiveProps._meshes.size() == 3, "Normal contracts produce only three cached meshes")
	extra.free()
	# Exercise the production attachment path, not only the fixture marker.
	var director := ExpeditionDirector.new()
	world.add_child(director)
	for i in IDS.size():
		director._add_site(IDS[i], COLORS[i], IDS[i])
		var holder: Node3D = director._visuals[i]
		_check(holder.get_child_count() == 4 and holder.get_child(2) is Label3D, "Production marker preserves label index and adds one prop")
		_check(holder.get_child(3) is MeshInstance3D and holder.get_child(3).name == "ObjectiveProp", "Production director attaches the new prop")
	director.free()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.7
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(1.6, 9.4, 13.0)
	camera.look_at(Vector3(0, 0.95, 0))
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "/tmp"
	var capture := DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(out)
	await _capture(out.path_join("objective-props-overview.png"), capture)
	# Match the game's camera distance, angle and field of view. Existing
	# models supply size/context without running gameplay or creating a profile.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(0, 24.57, 17.21)
	camera.look_at(Vector3.ZERO)
	camera.fov = 32.0
	for i in 9:
		var enemy := MeshInstance3D.new()
		enemy.mesh = Models.enemy("grunt", Color(0.52, 0.64, 0.42), 1.45)
		enemy.material_override = Models.material("kit")
		enemy.position = Vector3(-6.0 + i * 1.5, 0, -3.7 - float(i % 2))
		world.add_child(enemy)
	var elite := MeshInstance3D.new()
	elite.mesh = Models.enemy("lancer", Color(0.63, 0.39, 0.27), 1.8)
	elite.material_override = Models.material("kit")
	elite.position = Vector3(4.2, 0, 0)
	world.add_child(elite)
	await _capture(out.path_join("objective-props-combat.png"), capture)
	print("OBJECTIVE PROPS FIXTURE ", "FAILED" if _failed else "PASSED", "; cached meshes=", ObjectiveProps._meshes.size())
	quit(1 if _failed else 0)


func _marker(world: Node3D, id: String, color: Color, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = id
	holder.position = at
	world.add_child(holder)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.1
	ring_mesh.outer_radius = 1.35
	ring.mesh = ring_mesh
	ring.position.y = 0.08
	ring.material_override = _emissive(color, 0.95)
	holder.add_child(ring)
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.22
	cylinder.height = 2.8
	beam.mesh = cylinder
	beam.position.y = 1.45
	beam.material_override = _emissive(color, 0.34)
	holder.add_child(beam)
	var label := Label3D.new()
	label.text = {"seal_1": "SEAL 1 / 3", "cache": "CURSED CACHE", "elite": "MARKED ELITE"}[id]
	label.position.y = 3.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.modulate = color
	holder.add_child(label)
	return holder


func _emissive(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _capture(path: String, enabled: bool) -> void:
	await process_frame
	await process_frame
	if enabled:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.get_size() == Vector2i(1280, 720), "Preview must render at the requested size")
		_check(image.save_png(path) == OK, "Could not save rendered preview")
		print("Saved ", path)
