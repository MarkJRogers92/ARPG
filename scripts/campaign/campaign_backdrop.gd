class_name CampaignBackdrop
extends SubViewportContainer
## A miniature of the Last Lantern sanctuary, made with the same vertex-color
## kit and scenery as combat. Presentation only; it owns no campaign state.

const SOUL := Color(0.34, 0.86, 1.0)
const EMBER := Color(1.0, 0.57, 0.24)
const STONE := Color(0.3, 0.34, 0.4)
const IRON := Color(0.14, 0.18, 0.24)
const BRASS := Color(0.61, 0.43, 0.24)
const MOTE_COUNT := 12

var _motes: Array[MeshInstance3D] = []
var _origins: Array[Vector3] = []
var _clock := 0.0
var _camera: Camera3D
var _world: Node3D
var _lantern_scene: Node3D
var _waystop_scene: Node3D
var _waystop_id := ""
var _place: Dictionary = {}
var _environment_resource: Environment
var _moon: DirectionalLight3D
var _journey: Node3D
var _weather: Array[MeshInstance3D] = []
var _weather_origins: Array[Vector3] = []
var _biome_index := 0
var _completed := false
var _presented_key := ""


## Safe before or after _ready. Only the two presentation values are retained;
## no campaign data is mutated, and repeat refreshes do not rebuild geometry.
func present(state: Dictionary) -> void:
	_place = CampaignWaystops.resolve(state)
	_biome_index = clampi(int(_place.get("biome_index", 0)), 0, 2)
	_completed = bool(state.get("completed", false))
	if is_instance_valid(_world):
		_present_journey()
		_apply_waystop()


func set_progress(biome_index: int, completed := false) -> void:
	_biome_index = clampi(biome_index, 0, 2)
	_completed = completed
	_place = CampaignWaystops.resolve({"biome_index": _biome_index, "completed": completed, "cleared_nodes": []})
	if is_instance_valid(_world):
		_present_journey()
		_apply_waystop()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_world()
	resized.connect(_frame_sanctuary)
	_frame_sanctuary()


func _build_world() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 440)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	world.name = "LanternSanctuary"
	_world = world
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	_environment_resource = _environment()
	env.environment = _environment_resource
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	_moon = moon
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color(0.65, 0.76, 1.0)
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	world.add_child(moon)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.position = Vector3(11, 12, 18)
	world.add_child(_camera)
	_camera.look_at(Vector3(0, 1.1, -0.5), Vector3.UP)
	_camera.current = true
	_lantern_scene = Node3D.new()
	_lantern_scene.name = "LastLanternDiorama"
	world.add_child(_lantern_scene)
	_add_ground(_lantern_scene)
	_add_chapel(_lantern_scene)
	_add_lantern(_lantern_scene)
	_add_stations(_lantern_scene)
	_add_soul_motes(_lantern_scene)
	_present_journey()
	if _place.is_empty():
		_place = CampaignWaystops.resolve({"biome_index": _biome_index, "completed": _completed, "cleared_nodes": []})
	_apply_waystop()


func _frame_sanctuary() -> void:
	if is_instance_valid(_camera):
		# Keep the whole silhouette inside both the short 720p inset and taller
		# desktop layouts; a service panel should never crop the lantern roof.
		_camera.size = maxf(16.4, 8.6 * size.x / maxf(size.y, 1.0))


func _apply_waystop() -> void:
	if not is_instance_valid(_world):
		return
	var id := str(_place.get("id", ""))
	if id != _waystop_id:
		_waystop_id = id
		if is_instance_valid(_waystop_scene):
			_waystop_scene.free()
			_waystop_scene = null
		if str(_place.get("kind", "")) != "lantern":
			_waystop_scene = CampaignWaystopScenery.build(_world, _place, 0.39)
	var is_lantern := str(_place.get("kind", "")) == "lantern"
	if is_instance_valid(_lantern_scene):
		_lantern_scene.visible = is_lantern
	if is_instance_valid(_journey):
		_journey.visible = is_lantern


func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.026, 0.044, 0.064)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.53, 0.63, 0.79)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	return env


func _kit() -> MeshKit:
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 16
	return kit


func _place_kit(world: Node3D, kit: MeshKit, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	# MeshKit stores its color and emission in vertex data. A plain mesh has
	# no material, which would discard the palette and render grey geometry.
	instance.mesh = kit.commit(Models.material("kit"))
	world.add_child(instance)


func _add_ground(world: Node3D) -> void:
	var kit := _kit()
	# Faceted earth and foundation rather than a smooth floating grey disc.
	kit.cylinder(6.2, 5.6, 0.5, MeshKit.at(Vector3(0, -0.35, 0), Vector3.ZERO, Vector3(1, 1, 0.72)), Color(0.12, 0.16, 0.18), 0, 12)
	kit.cylinder(5.9, 6.2, 0.16, MeshKit.at(Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1, 1, 0.72)), Color(0.24, 0.28, 0.3), 0, 12)
	# Individually laid flagstones, deliberately broken at the outer edge.
	for row in range(-3, 4):
		for col in range(-5, 6):
			var x := float(col) * 0.92 + (0.22 if row % 2 == 0 else -0.22)
			var z := float(row) * 0.92
			if x * x / 30.0 + z * z / 13.0 > 1.0:
				continue
			var shade := float(posmod(row * 17 + col * 7, 5)) * 0.023
			kit.box(Vector3(0.87, 0.1, 0.86), MeshKit.at(Vector3(x, 0.09, z), Vector3(0, float(posmod(col * 3 + row, 5) - 2), 0)), STONE.darkened(0.16 + shade))
	# The road leaves the safe circle at the foot of the lantern.
	for i in 4:
		kit.box(Vector3(2.5 - i * 0.16, 0.16, 0.62), MeshKit.at(Vector3(0, -0.03 - i * 0.09, 3.6 + i * 0.48)), STONE.darkened(0.08 + i * 0.05))
	# Thin horizontal inlays use the torus' native XZ orientation.
	kit.torus(1.7, 1.76, MeshKit.at(Vector3(0, 0.16, 0.2)), BRASS, 0.12, 24)
	kit.torus(1.49, 1.53, MeshKit.at(Vector3(0, 0.17, 0.2)), SOUL.darkened(0.3), 0.35, 24)
	for i in 8:
		var angle := TAU * i / 8.0
		kit.box(Vector3(0.075, 0.018, 0.25), MeshKit.at(Vector3(sin(angle) * 1.98, 0.16, 0.2 + cos(angle) * 1.98), Vector3(0, rad_to_deg(angle), 0)), BRASS)
	_place_kit(world, kit, "WornFlagstoneCourt")


func _add_chapel(world: Node3D) -> void:
	var kit := _kit()
	# A ruined apse cradles the beacon without competing with its silhouette.
	for i in 7:
		var x := -4.2 + float(i) * 1.4
		var h := 0.72 + float(posmod(i * 5, 3)) * 0.22
		kit.box(Vector3(1.29, h, 0.48), MeshKit.at(Vector3(x, h * 0.5 + 0.13, -3.15)), STONE.darkened(0.12))
		kit.box(Vector3(1.38, 0.12, 0.6), MeshKit.at(Vector3(x, h + 0.16, -3.15)), STONE.lightened(0.08))
	for x in [-4.6, 4.6]:
		kit.box(Vector3(0.88, 0.22, 0.88), MeshKit.at(Vector3(x, 0.2, -2.5)), STONE)
		kit.box(Vector3(0.54, 2.9, 0.56), MeshKit.at(Vector3(x, 1.7, -2.5)), STONE.darkened(0.05))
		kit.box(Vector3(0.84, 0.21, 0.82), MeshKit.at(Vector3(x, 3.2, -2.5)), STONE.lightened(0.1))
		kit.box(Vector3(0.19, 2.15, 0.12), MeshKit.at(Vector3(x, 1.9, -2.17)), BRASS.darkened(0.3))
		# Short inward broken ribs suggest a lost vault.
		kit.box(Vector3(1.1, 0.34, 0.53), MeshKit.at(Vector3(x * 0.87, 3.48, -2.5), Vector3(0, 0, -signf(x) * 28)), STONE)
	# Two indigo standards make this feel inhabited and give the banner a
	# deliberately split hem, using opaque low-poly cloth without textures.
	for x in [-2.85, 2.85]:
		kit.cylinder(0.055, 0.065, 2.65, MeshKit.at(Vector3(x, 1.45, -2.92)), IRON)
		kit.box(Vector3(1.06, 0.08, 0.08), MeshKit.at(Vector3(x, 2.69, -2.92)), BRASS)
		kit.box(Vector3(0.89, 1.12, 0.045), MeshKit.at(Vector3(x, 2.04, -2.88)), Color(0.13, 0.24, 0.37))
		for dx in [-0.27, 0.27]:
			kit.box(Vector3(0.33, 0.25, 0.05), MeshKit.at(Vector3(x + dx, 1.4, -2.88)), Color(0.13, 0.24, 0.37))
		kit.box(Vector3(0.18, 0.39, 0.055), MeshKit.at(Vector3(x, 2.07, -2.84), Vector3(0, 0, 45)), BRASS.lightened(0.14), 0.15)
	_place_kit(world, kit, "BrokenApseAndStandards")


func _add_lantern(world: Node3D) -> void:
	var kit := _kit()
	var center := Vector3(0, 0, -1.72)
	for i in 3:
		kit.cylinder(0.84 - i * 0.13, 0.84 - i * 0.13, 0.18, MeshKit.at(center + Vector3(0, 0.2 + i * 0.17, 0)), STONE.lightened(i * 0.04), 0, 8)
	kit.cylinder(0.18, 0.28, 1.95, MeshKit.at(center + Vector3(0, 1.49, 0)), IRON.lightened(0.12), 0, 8)
	for y in [0.66, 2.32]:
		kit.cylinder(0.29, 0.29, 0.12, MeshKit.at(center + Vector3(0, y, 0)), BRASS, 0, 8)
	kit.box(Vector3(1.02, 0.14, 1.02), MeshKit.at(center + Vector3(0, 2.56, 0)), BRASS)
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			kit.box(Vector3(0.07, 1.18, 0.07), MeshKit.at(center + Vector3(x, 3.14, z)), IRON.lightened(0.2))
	kit.box(Vector3(1.14, 0.14, 1.14), MeshKit.at(center + Vector3(0, 3.75, 0)), BRASS)
	kit.cylinder(0.05, 0.87, 0.72, MeshKit.at(center + Vector3(0, 4.15, 0), Vector3(0, 45, 0)), Color(0.16, 0.28, 0.35), 0, 4)
	kit.sphere(0.1, MeshKit.at(center + Vector3(0, 4.57, 0)), BRASS, 0.2)
	kit.sphere(0.29, MeshKit.at(center + Vector3(0, 3.15, 0), Vector3.ZERO, Vector3(0.8, 1.62, 0.8)), SOUL, 1.0, 8, 5)
	kit.torus(0.33, 0.365, MeshKit.at(center + Vector3(0, 3.07, 0)), BRASS, 0.15)
	_place_kit(world, kit, "TheLastLantern")
	_light(world, center + Vector3(0, 3.06, 0), SOUL, 4.0, 6.3)


func _add_stations(world: Node3D) -> void:
	# Stable facing and separate working areas keep each station recognizable.
	_station(world, "forge", Vector3(-3.4, 0.14, 0.0), 0.67, 18)
	_station(world, "weapon_rack", Vector3(-4.1, 0.14, 1.45), 0.67, 30)
	_station(world, "crate_stack", Vector3(-4.45, 0.14, -1.05), 0.62, 15)
	_station(world, "tome_pedestal", Vector3(3.05, 0.14, -0.45), 0.9, -15)
	_station(world, "gravedigger_bench", Vector3(3.6, 0.14, 1.35), 0.62, -25)
	_station(world, "soul_altar", Vector3(0, 0.14, 0.8), 0.62, 0)
	_station(world, "lantern_post", Vector3(-2.4, 0.14, 2.5), 0.61, 0)
	_station(world, "soul_brazier", Vector3(2.4, 0.14, 2.5), 0.71, 0)
	_light(world, Vector3(-3.2, 1.5, 0.2), EMBER, 3.6, 4.6)
	_light(world, Vector3(3.1, 1.4, 0.2), SOUL, 2.3, 4.0)
	_light(world, Vector3(-2.4, 1.6, 2.5), EMBER, 1.9, 3.8)


func _station(world: Node3D, kind: String, at: Vector3, scale_factor: float, yaw: float) -> void:
	var mesh := AssetProps.mesh(kind)
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = "Station_" + kind
	instance.mesh = mesh
	instance.scale = Vector3.ONE * scale_factor
	instance.position = at
	instance.rotation_degrees.y = yaw
	# Combat landmarks use a hero-occlusion shader. The town has no hero;
	# use the matching ordinary kit surfaces without changing cached assets.
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface) as ShaderMaterial
		var glowing := source != null and float(source.get_shader_parameter("flat_glow")) > 0.0
		instance.set_surface_override_material(surface, AssetProps.emissive_material() if glowing else AssetProps.opaque_material())
	world.add_child(instance)


func _light(world: Node3D, at: Vector3, color: Color, energy: float, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	world.add_child(lamp)


func _add_soul_motes(world: Node3D) -> void:
	var kit := _kit()
	kit.sphere(0.043, Transform3D.IDENTITY, SOUL, 1.0, 6, 3)
	var mesh := kit.commit(Models.material("kit"))
	for i in MOTE_COUNT:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.position = Vector3(-3.4 + float((i * 31) % 68) * 0.1, 0.65 + float(i % 5) * 0.38, -2.2 + float((i * 17) % 48) * 0.1)
		world.add_child(mote)
		_motes.append(mote)
		_origins.append(mote.position)


func _process(delta: float) -> void:
	_clock += delta
	for i in _motes.size():
		var phase := float(i) * 0.71
		_motes[i].position = _origins[i] + Vector3(cos(_clock * 0.34 + phase) * 0.12, sin(_clock * 0.7 + phase) * 0.14, 0)
		_motes[i].scale = Vector3.ONE * (0.8 + 0.22 * (0.5 + 0.5 * sin(_clock * 1.2 + phase)))

	for i in _weather.size():
		var at := _weather_origins[i]
		var drift := _clock * (0.19 if _biome_index == 1 else -0.14)
		_weather[i].position = Vector3(at.x + sin(_clock * 0.25 + i) * 0.15, 0.45 + fposmod(at.y - drift, 3.0), at.z)


func _present_journey() -> void:
	var key := "%d:%s" % [_biome_index, _completed]
	if key == _presented_key:
		return
	_presented_key = key
	_weather.clear()
	_weather_origins.clear()
	if is_instance_valid(_journey):
		# Remove immediately so a same-frame change cannot show both climates.
		_world.remove_child(_journey)
		_journey.queue_free()
	_journey = Node3D.new()
	_journey.name = "JourneyDressings"
	_world.add_child(_journey)
	_journey.visible = str(_place.get("kind", "lantern")) == "lantern"
	var light_colors := [Color(0.65, 0.76, 1.0), Color(0.68, 0.86, 1.0), Color(1.0, 0.65, 0.48)]
	var ambient_colors := [Color(0.53, 0.63, 0.79), Color(0.53, 0.71, 0.86), Color(0.68, 0.52, 0.57)]
	_moon.light_color = Color(1.0, 0.86, 0.64) if _completed else light_colors[_biome_index]
	_moon.light_energy = 1.45 if _completed else 1.25
	_environment_resource.ambient_light_color = Color(0.64, 0.73, 0.78) if _completed else ambient_colors[_biome_index]
	# The sanctuary's forge and soul lamps remain the visual anchors in every
	# climate. Geometry at the edges gives the weather readable silhouettes.
	_add_border_dressings()
	if _biome_index >= 1 or _completed:
		_add_guardian_trophy(false)
	if _biome_index >= 2 or _completed:
		_add_guardian_trophy(true)
	if _completed:
		_add_victory_restoration()
	_add_weather()


func _add_border_dressings() -> void:
	var kit := _kit()
	for side in [-1.0, 1.0]:
		for i in 5:
			var at := Vector3(side * (5.25 - float(i % 2) * 0.18), 0.17, -2.2 + float(i) * 0.97)
			if _completed:
				# Returning life: small clumps of pale grass and brass-gold flowers.
				for j in 3:
					var stem := at + Vector3(float(j - 1) * 0.12, 0.14, float(j % 2) * 0.1)
					kit.box(Vector3(0.04, 0.32 + j * 0.05, 0.04), MeshKit.at(stem, Vector3(0, 0, float(j - 1) * 14)), Color(0.34, 0.48, 0.35))
					kit.sphere(0.085, MeshKit.at(stem + Vector3(0, 0.18, 0)), Color(0.95, 0.76, 0.4), 0.15, 5, 3)
			elif _biome_index == 1:
				kit.sphere(0.36, MeshKit.at(at, Vector3.ZERO, Vector3(1.6, 0.22, 0.85)), Color(0.7, 0.81, 0.9), 0, 7, 3)
				for j in 2:
					kit.cylinder(0, 0.13, 0.42 + j * 0.25, MeshKit.at(at + Vector3(j * 0.19, 0.24, 0), Vector3(0, j * 35, side * -14)), Color(0.4, 0.71, 0.84), 0.12, 5)
			elif _biome_index == 2:
				kit.cylinder(0.11, 0.28, 0.3 + float(i % 3) * 0.14, MeshKit.at(at + Vector3(0, 0.11, 0), Vector3(0, i * 37, side * 8)), Color(0.15, 0.13, 0.18), 0, 5)
				kit.box(Vector3(0.2, 0.025, 0.055), MeshKit.at(at + Vector3(-side * 0.25, 0.01, 0.16), Vector3(0, i * 41, 0)), EMBER, 0.7)
			else:
				kit.sphere(0.27, MeshKit.at(at, Vector3.ZERO, Vector3(1.25, 0.16, 0.8)), Color(0.2, 0.31, 0.28), 0, 6, 3)
	if not _completed and _biome_index == 1:
		# A little settled snow on the back wall; working surfaces stay clear.
		for i in [0, 1, 5, 6]:
			var x := -4.2 + float(i) * 1.4
			var wall_top := 0.72 + float(posmod(i * 5, 3)) * 0.22 + 0.22
			kit.sphere(0.42, MeshKit.at(Vector3(x, wall_top, -3.15), Vector3.ZERO, Vector3(1.25, 0.12, 0.6)), Color(0.72, 0.83, 0.92), 0, 7, 3)
	_place_kit(_journey, kit, "ReturningLife" if _completed else ["GraveyardMoss", "SettledSnowAndRime", "RiftCinders"][_biome_index])


func _add_guardian_trophy(frost: bool) -> void:
	var kit := _kit()
	var x := 1.62 if frost else -1.62
	var at := Vector3(x, 0.0, -2.53)
	var accent := Color(0.6, 0.84, 0.94) if frost else Color(0.77, 0.69, 0.47)
	kit.box(Vector3(0.94, 0.16, 0.82), MeshKit.at(at + Vector3(0, 0.27, 0)), STONE)
	kit.box(Vector3(0.57, 0.9, 0.56), MeshKit.at(at + Vector3(0, 0.78, 0)), IRON.lightened(0.08))
	kit.box(Vector3(0.81, 0.13, 0.73), MeshKit.at(at + Vector3(0, 1.29, 0)), BRASS)
	kit.box(Vector3(0.19, 0.27, 0.035), MeshKit.at(at + Vector3(0, 0.82, 0.3), Vector3(0, 0, 45)), accent, 0.2)
	if frost:
		# A broken, faceted heart of the Frost Colossus, held in an iron cradle.
		kit.sphere(0.34, MeshKit.at(at + Vector3(0, 1.73, 0), Vector3(0, 25, 12), Vector3(0.8, 1.35, 0.8)), accent, 0.28, 5, 3)
		for dx in [-0.28, 0.28]:
			kit.box(Vector3(0.07, 0.44, 0.08), MeshKit.at(at + Vector3(dx, 1.52, 0), Vector3(0, 0, -signf(dx) * 18)), BRASS)
		kit.cylinder(0, 0.12, 0.5, MeshKit.at(at + Vector3(0.17, 1.7, 0.12), Vector3(0, 0, -25)), SOUL, 0.25, 5)
	else:
		# The Lich King's empty crown: five prongs, dark interior, dead gem.
		kit.torus(0.25, 0.35, MeshKit.at(at + Vector3(0, 1.57, 0)), accent)
		for i in 5:
			var angle := TAU * float(i) / 5.0
			kit.cylinder(0, 0.075, 0.39, MeshKit.at(at + Vector3(sin(angle) * 0.29, 1.76, cos(angle) * 0.29)), accent, 0, 4)
		kit.sphere(0.08, MeshKit.at(at + Vector3(0, 1.59, 0.33)), Color(0.39, 0.3, 0.55), 0.18, 6, 3)
	# A victory tab beneath the existing standards persists across climates.
	var banner_x := 2.85 if frost else -2.85
	kit.box(Vector3(0.14, 0.81, 0.02), MeshKit.at(Vector3(banner_x - 0.32, 2.05, -2.84)), accent)
	kit.box(Vector3(0.14, 0.81, 0.02), MeshKit.at(Vector3(banner_x + 0.32, 2.05, -2.84)), accent)
	_place_kit(_journey, kit, "FrostColossusHeart" if frost else "LichKingCrown")


func _add_victory_restoration() -> void:
	var kit := _kit()
	# Join the once-broken ribs with a slender, gold-edged lintel. The beacon
	# remains the highest point and its familiar cyan flame is untouched.
	kit.box(Vector3(7.4, 0.13, 0.23), MeshKit.at(Vector3(0, 3.57, -2.5)), BRASS.lightened(0.18))
	for x in [-3.55, 3.55]:
		kit.box(Vector3(0.1, 0.57, 0.12), MeshKit.at(Vector3(x, 3.32, -2.5)), BRASS)
	for i in 7:
		var x := -2.7 + i * 0.9
		var y := 3.44 - (1.0 - absf(x) / 3.1) * 0.28
		kit.box(Vector3(0.27, 0.37, 0.045), MeshKit.at(Vector3(x, y, -2.46), Vector3(0, 0, 45)), BRASS.lightened(0.25), 0.22)
	kit.torus(1.86, 1.9, MeshKit.at(Vector3(0, 0.19, 0.2)), EMBER.lightened(0.28), 0.45, 24)
	_place_kit(_journey, kit, "RestoredLanternArch")


func _add_weather() -> void:
	var kit := _kit()
	var color: Color = Color(0.96, 0.77, 0.4) if _completed else [SOUL.darkened(0.2), Color(0.78, 0.89, 1.0), EMBER][_biome_index]
	kit.sphere(0.028 if _biome_index == 1 and not _completed else 0.035, Transform3D.IDENTITY, color, 0.4, 5, 3)
	var mesh := kit.commit(Models.material("kit"))
	for i in 18:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		var at := Vector3(-4.8 + float((i * 37) % 96) * 0.1, 0.5 + float((i * 13) % 31) * 0.1, -2.8 + float((i * 19) % 60) * 0.1)
		mote.position = at
		_journey.add_child(mote)
		_weather.append(mote)
		_weather_origins.append(at)
