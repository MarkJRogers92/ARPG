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
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = _environment()
	world.add_child(env)
	var moon := DirectionalLight3D.new()
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
	_add_ground(world)
	_add_chapel(world)
	_add_lantern(world)
	_add_stations(world)
	_add_soul_motes(world)


func _frame_sanctuary() -> void:
	if is_instance_valid(_camera):
		# Keep the whole silhouette inside both the short 720p inset and taller
		# desktop layouts; a service panel should never crop the lantern roof.
		_camera.size = maxf(16.4, 8.6 * size.x / maxf(size.y, 1.0))


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
