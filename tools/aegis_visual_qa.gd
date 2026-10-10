extends SceneTree
## Native inspection of the integrated HeroModel; no gameplay or save writes.
var hero: HeroModel
var camera: Camera3D
var output := ""
var failures := 0
var viewport: SubViewport
var hero_class := "battlemage"

func _initialize() -> void:
	output = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1:
		hero_class = OS.get_cmdline_user_args()[1]
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(720, 720)
	root.content_scale_size = Vector2i(720, 720)
	root.msaa_3d = Viewport.MSAA_4X
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var display := TextureRect.new()
	display.size = Vector2(720, 720)
	display.texture = viewport.get_texture()
	root.add_child(display)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.12, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.9, 1.0)
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.17, 0.22)
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	viewport.add_child(ground)
	hero = HeroModel.new()
	hero.set_body(HeroClass.data(hero_class)["look"])
	viewport.add_child(hero)
	hero.set_process(false)
	hero.set_weapon(HeroClass.data(hero_class)["weapon"], HeroClass.data(hero_class)["accent"])
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	viewport.add_child(camera)
	camera.current = true
	for spec in [["front", Vector3(0, 2.6, -7)], ["three-quarter", Vector3(4.5, 3.2, -6)], ["back", Vector3(0, 2.8, 7)]]:
		camera.position = spec[1]
		camera.look_at(Vector3(0, 1.35, 0))
		await capture(spec[0])
	camera.position = Vector3(4.5, 3.2, -6)
	camera.look_at(Vector3(0, 1.35, 0))
	for base in ["Staff", "Wand", "Orb", "Scythe"]:
		hero.set_weapon(base, HeroClass.data(hero_class)["accent"])
		await capture("weapon-" + base.to_lower())
	hero.set_weapon(HeroClass.data(hero_class)["weapon"], HeroClass.data(hero_class)["accent"])
	hero.cast()
	for step in 5:
		hero._process(1.0 / 60.0)
	await capture("action")
	hero._neutral()
	var directions := [Vector2(0, -6), Vector2(0, 6), Vector2(6, 0), Vector2(-6, 0)]
	var names := ["forward", "backward", "right", "left"]
	for frame in 180:
		var phase := frame / 45
		for step in 2:
			hero.set_motion(directions[phase], 1.0 / 60.0)
			if frame % 45 == 10 and step == 0:
				hero.cast()
			hero._process(1.0 / 60.0)
		await capture("frames/%03d" % frame)
		if frame % 45 == 22:
			await capture("walking-" + names[phase])
	for step in 180:
		hero.set_motion(Vector2.ZERO, 1.0 / 60.0)
		hero._process(1.0 / 60.0)
	hero.set_body(HeroClass.data("necromancer" if hero_class == "pyromancer" else "pyromancer")["look"])
	await capture("class-switched")
	hero.set_body(HeroClass.data(hero_class)["look"])
	hero.set_weapon(HeroClass.data(hero_class)["weapon"], HeroClass.data(hero_class)["accent"])
	await capture("class-restored")
	print("HERO_NATIVE_QA: %s, 180 motion frames, 14 inspection views, %d capture failures" % [hero_class, failures])
	hero.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.get_size() != Vector2i(720, 720) or image.save_png(output.path_join(label + ".png")) != OK:
		failures += 1
		push_error("Capture failed: " + label)
