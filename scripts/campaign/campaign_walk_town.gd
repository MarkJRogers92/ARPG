class_name CampaignWalkTown
extends Node3D
## The Last Lantern as a place: the hero walks the plaza and uses each service
## at its station. Presentation only; it emits station_used and CampaignTown
## opens the matching existing service panel. It owns no campaign state.

signal station_used(service_id: String)

const SOUL := Color(0.34, 0.86, 1.0)
const EMBER := Color(1.0, 0.57, 0.24)
const GOLD := Color(0.95, 0.79, 0.4)
const SPEED := 6.0
const PLAZA_RADIUS := 13.0
const USE_RANGE := 2.4
const CAMERA_OFFSET := Vector3(0, 11.5, 9.5)

## One station per CampaignTown service. `props` are AssetProps kinds placed
## around `at`; `person` adds a standing figure (Ferryman model or a robed
## keeper) so services read as people as well as places.
const STATIONS := [
	{"id": "route", "label": "Route Board  ·  depart", "at": Vector3(0, 0, -7.4), "color": GOLD,
		"props": [["lantern_post", Vector3(-1.5, 0, -0.3), 0.0], ["lantern_post", Vector3(1.5, 0, -0.3), 0.0]]},
	{"id": "pack", "label": "Armory  ·  equipment", "at": Vector3(-8.0, 0, -4.0), "color": EMBER,
		"props": [["weapon_rack", Vector3(0, 0, -0.6), 25.0], ["crate_stack", Vector3(-1.3, 0, 0.4), 10.0]]},
	{"id": "market", "label": "Market  ·  buy, sell, reforge", "at": Vector3(-8.5, 0, 3.5), "color": EMBER,
		"props": [["forge", Vector3(0, 0, -0.4), 30.0], ["barrel", Vector3(1.2, 0, 0.6), 0.0]], "person": "keeper"},
	{"id": "trainer", "label": "Trainer  ·  talents", "at": Vector3(8.0, 0, -4.0), "color": SOUL,
		"props": [["tome_pedestal", Vector3(0, 0, -0.4), -20.0]], "person": "keeper"},
	{"id": "roster", "label": "Crypt  ·  veterans", "at": Vector3(8.5, 0, 3.5), "color": SOUL,
		"props": [["gravedigger_bench", Vector3(0, 0, -0.5), -30.0], ["sarcophagus", Vector3(1.4, 0, 0.5), -60.0]]},
	{"id": "ferryman", "label": "The Ferryman  ·  wagers", "at": Vector3(-3.5, 0, 8.0), "color": Color(0.7, 0.75, 1.0),
		"props": [["stone_well", Vector3(-1.4, 0, 0.2), 0.0]], "person": "ferryman"},
	{"id": "ledger", "label": "The Ledger  ·  bargains", "at": Vector3(3.5, 0, 8.0), "color": Color(0.85, 0.55, 1.0),
		"props": [["offering_bowl", Vector3(0, 0, -0.4), 0.0], ["soul_obelisk", Vector3(1.3, 0, -0.2), 0.0]]},
]

## While false (a service panel is open) the hero ignores movement and E.
var walking := true:
	set(value):
		walking = value
		if not walking and is_instance_valid(_hero):
			_hero.set_motion(Vector2.ZERO, 1.0)

var _hero: HeroModel
var _camera: Camera3D
var _hero_pos := Vector2(0, 2.5)
var _blockers: Array = [] # [Vector2 center, float radius]
var _labels: Dictionary = {} # service id -> Label3D
var _rings: Dictionary = {} # service id -> MeshInstance3D
var _near := ""
var _clock := 0.0
var _env: Environment
var _ground_material: StandardMaterial3D
var _scatter: Node3D
var _biome := -1
var _motes: Array[MeshInstance3D] = []
var _mote_origins: Array[Vector3] = []
var _keepers: Array[Node3D] = []

## Per-biome ground, ambient, fog, and the scenery kinds scattered beyond
## the plaza (Models.prop kinds, the same ones combat decor uses).
const BIOMES := [
	{"ground": Color(0.1, 0.13, 0.085), "ambient": Color(0.53, 0.63, 0.79), "fog": Color(0.08, 0.1, 0.16),
		"props": [["grass", 70], ["bush", 14], ["tree", 12], ["grave", 12], ["rock", 10], ["mushroom", 10], ["bones", 6]]},
	{"ground": Color(0.62, 0.68, 0.76), "ambient": Color(0.62, 0.72, 0.9), "fog": Color(0.42, 0.5, 0.62),
		"props": [["pine", 22], ["snowrock", 16], ["ice", 12], ["rock", 8], ["grave", 6]]},
	{"ground": Color(0.16, 0.08, 0.06), "ambient": Color(0.82, 0.5, 0.36), "fog": Color(0.22, 0.08, 0.04),
		"props": [["ashtree", 18], ["obsidian", 16], ["brimstone", 12], ["rock", 10], ["bones", 8]]},
]


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_lantern()
	for station: Dictionary in STATIONS:
		_build_station(station)
	_hero = HeroModel.new()
	add_child(_hero)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.current = true
	_place_hero(0.0)


## Dress the hero in the campaign's class colors and equipped weapon.
func present(state: Dictionary) -> void:
	if not is_instance_valid(_hero):
		return
	var biome := clampi(int(state.get("biome_index", 0)), 0, BIOMES.size() - 1)
	if biome != _biome:
		_biome = biome
		var look: Dictionary = BIOMES[biome]
		_ground_material.albedo_color = look["ground"]
		_env.ambient_light_color = look["ambient"]
		_env.fog_light_color = look["fog"]
		_build_scatter(biome)
	var info: Dictionary = HeroClass.data(str(state.get("hero_class", "")))
	if info.has("look"):
		_hero.set_body(info["look"])
	var weapon := str(info.get("weapon", HeroModel.DEFAULT_WEAPON))
	var inventory: Dictionary = state.get("inventory", {})
	var worn_id = inventory.get("equipped", {}).get("weapon", "")
	var record = inventory.get("items", {}).get(worn_id, {})
	if record is Dictionary and record.get("data") is Dictionary:
		weapon = str(record["data"].get("base_name", weapon))
	_hero.set_weapon(weapon, info.get("accent", HeroModel.DEFAULT_ACCENT))


func nearest_station() -> String:
	return _near


func _process(delta: float) -> void:
	_clock += delta
	for id: String in _rings:
		var ring: MeshInstance3D = _rings[id]
		ring.scale = Vector3.ONE * ((1.12 + 0.06 * sin(_clock * 3.0)) if id == _near else 1.0)
	for i in _motes.size():
		var phase := float(i) * 0.71
		_motes[i].position = _mote_origins[i] + Vector3(cos(_clock * 0.3 + phase) * 0.4, sin(_clock * 0.8 + phase) * 0.3, sin(_clock * 0.25 + phase) * 0.4)
	for i in _keepers.size():
		_keepers[i].position.y = sin(_clock * 1.6 + i) * 0.03
		_keepers[i].scale.y = 1.0 + sin(_clock * 1.6 + i) * 0.015
	if not walking or not is_instance_valid(_hero):
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_place_hero(delta, input * SPEED)
	_update_near()
	if _near != "" and Input.is_action_just_pressed("interact"):
		station_used.emit(_near)


func _place_hero(delta: float, velocity := Vector2.ZERO) -> void:
	var next := _hero_pos + velocity * delta
	for blocker: Array in _blockers:
		var center: Vector2 = blocker[0]
		var radius: float = blocker[1]
		var away := next - center
		if away.length() < radius:
			next = center + (away.normalized() if away.length() > 0.001 else Vector2.DOWN) * radius
	if next.length() > PLAZA_RADIUS:
		next = next.normalized() * PLAZA_RADIUS
	_hero_pos = next
	_hero.position = Vector3(_hero_pos.x, 0.12, _hero_pos.y) # stand on the flagstones
	if velocity.length() > 0.1:
		_hero.rotation.y = atan2(-velocity.x, -velocity.y)
	_hero.set_motion(velocity, maxf(delta, 0.001))
	var target := _hero.position + Vector3(0, 1.0, 0)
	_camera.position = _camera.position.lerp(target + CAMERA_OFFSET, 1.0 - exp(-6.0 * delta)) if delta > 0.0 else target + CAMERA_OFFSET
	_camera.look_at(target, Vector3.UP)


func _update_near() -> void:
	var best := ""
	var best_distance := USE_RANGE
	for station: Dictionary in STATIONS:
		var at: Vector3 = station["at"]
		var distance := _hero_pos.distance_to(Vector2(at.x, at.z))
		if distance <= best_distance:
			best = station["id"]
			best_distance = distance
	if best == _near:
		return
	_near = best
	for station: Dictionary in STATIONS:
		var label: Label3D = _labels[station["id"]]
		var active: bool = station["id"] == _near
		label.text = ("[%s]  %s" % [Controls.tag("interact"), station["label"]]) if active else str(station["label"]).get_slice("  ·  ", 0)
		label.modulate = Color.WHITE if active else Color(1, 1, 1, 0.72)
		label.font_size = 64 if active else 48


# --- building the plaza ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.026, 0.044, 0.064)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.53, 0.63, 0.79)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.16)
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -30, 0)
	moon.light_color = Color(0.65, 0.76, 1.0)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	add_child(moon)


func _flat_material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	ground.mesh = plane
	_ground_material = _flat_material(BIOMES[0]["ground"])
	ground.material_override = _ground_material
	add_child(ground)
	var plaza := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS + 1.2
	disc.bottom_radius = PLAZA_RADIUS + 1.4
	disc.height = 0.08
	disc.radial_segments = 48
	plaza.mesh = disc
	plaza.position.y = 0.04
	plaza.material_override = _flat_material(Color(0.12, 0.13, 0.15))
	add_child(plaza)
	# A ring of graves and pillars marks the sanctuary's edge.
	for i in 18:
		var angle := TAU * i / 18.0
		var kind := "rune_gravestone" if i % 3 else "ruined_pillar"
		if sin(angle) > 0.0 and absf(cos(angle)) * (PLAZA_RADIUS + 2.2) < 4.0:
			continue # the road and its statues
		_prop(kind, Vector3(cos(angle), 0, sin(angle)) * (PLAZA_RADIUS + 2.2), rad_to_deg(-angle) + 90.0, 1.0, false)


## Reuses the sanctuary art from CampaignBackdrop (the Last Lantern and the
## ruined apse) at walking scale, so the town is the place players already know.
func _build_lantern() -> void:
	var art := CampaignBackdrop.new()
	var lantern := Node3D.new()
	lantern.name = "LastLantern"
	# The backdrop draws the lantern at (0, 0, -1.72); recenter it on the plaza.
	lantern.scale = Vector3.ONE * 1.6
	lantern.position = Vector3(0, 0, 1.72 * 1.6)
	add_child(lantern)
	art._add_lantern(lantern)
	var apse := Node3D.new()
	apse.name = "RuinedApse"
	apse.scale = Vector3.ONE * 1.9
	apse.position = Vector3(0, 0, -4.0)
	add_child(apse)
	art._add_chapel(apse)
	art.free()
	_blockers.append([Vector2.ZERO, 1.45])
	for i in 15:
		_blockers.append([Vector2(-8.4 + i * 1.2, -10.0), 0.8])
	for x in [-8.74, 8.74]:
		_blockers.append([Vector2(x, -8.75), 1.0])
	_light(Vector3(0, 5.0, 0), SOUL, 3.0, 14.0)
	_build_flagstones()
	_build_buildings()
	_build_motes()


## Individually laid stones in rings, plus a road leaving south.
func _build_flagstones() -> void:
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 16
	var stone := Color(0.3, 0.34, 0.4)
	var ring := 0
	var radius := 2.2
	while radius < PLAZA_RADIUS + 1.0:
		var count := int(TAU * radius / 0.95)
		for i in count:
			var angle := TAU * (i + 0.5 * (ring % 2)) / count
			var shade := float(posmod(i * 7 + ring * 13, 5)) * 0.025
			kit.box(Vector3(0.86, 0.1, 0.8), MeshKit.at(Vector3(cos(angle) * radius, 0.1, sin(angle) * radius), Vector3(0, rad_to_deg(-angle) + float(posmod(i * 3, 5) - 2), 0)), stone.darkened(0.12 + shade))
		radius += 0.92
		ring += 1
	for i in 12:
		var z := PLAZA_RADIUS + 0.6 + i * 0.9
		for x in [-0.9, 0.0, 0.9]:
			kit.box(Vector3(0.82, 0.1, 0.8), MeshKit.at(Vector3(x + (0.2 if i % 2 else -0.2), 0.08 - i * 0.004, z), Vector3(0, float(posmod(i * 5, 7) - 3), 0)), stone.darkened(0.18 + i * 0.015))
	# Brass inlay rings around the lantern, as in the vignette.
	kit.torus(1.85, 1.95, MeshKit.at(Vector3(0, 0.16, 0)), Color(0.61, 0.43, 0.24), 0.12, 32)
	kit.torus(1.6, 1.66, MeshKit.at(Vector3(0, 0.17, 0)), SOUL.darkened(0.3), 0.35, 32)
	var instance := MeshInstance3D.new()
	instance.name = "Flagstones"
	instance.mesh = kit.commit(Models.material("kit"))
	add_child(instance)


## Larger structures behind the service ring give the plaza a skyline.
func _build_buildings() -> void:
	_prop("mausoleum", Vector3(-14.5, 0, 0.0), 90.0, 1.3, false)
	_prop("mausoleum", Vector3(14.5, 0, 0.0), -90.0, 1.3, false)
	_prop("guardian_statue", Vector3(-2.2, 0, PLAZA_RADIUS + 1.6), 180.0, 1.1, false)
	_prop("guardian_statue", Vector3(2.2, 0, PLAZA_RADIUS + 1.6), 180.0, 1.1, false)
	_prop("funeral_wagon", Vector3(-11.8, 0, 7.5), 40.0, 1.0, false)
	_prop("winged_memorial", Vector3(11.8, 0, 7.5), -40.0, 1.0, false)
	_prop("soul_brazier", Vector3(-6.0, 0, -9.2), 0.0, 1.0, true)
	_prop("soul_brazier", Vector3(6.0, 0, -9.2), 0.0, 1.0, true)
	_light(Vector3(-6.0, 1.8, -9.2), EMBER, 2.0, 5.0)
	_light(Vector3(6.0, 1.8, -9.2), EMBER, 2.0, 5.0)


func _build_motes() -> void:
	var kit := MeshKit.new()
	kit.sphere(0.05, Transform3D.IDENTITY, SOUL, 1.0, 6, 3)
	var mesh := kit.commit(Models.material("kit"))
	for i in 28:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		var angle := TAU * i / 28.0 + float(i % 3)
		var distance := 2.0 + float((i * 37) % 100) * 0.1
		mote.position = Vector3(cos(angle) * distance, 0.8 + float(i % 6) * 0.45, sin(angle) * distance)
		add_child(mote)
		_motes.append(mote)
		_mote_origins.append(mote.position)


## Scenery beyond the plaza follows the current biome; rebuilt only on change.
func _build_scatter(biome: int) -> void:
	if is_instance_valid(_scatter):
		_scatter.free()
	_scatter = Node3D.new()
	_scatter.name = "Scatter"
	add_child(_scatter)
	var info: Dictionary = BIOMES[biome]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + biome
	for entry: Array in info["props"]:
		var mesh := Models.prop(entry[0])
		if mesh == null:
			continue
		for i in int(entry[1]):
			var angle := rng.randf() * TAU
			var distance := rng.randf_range(PLAZA_RADIUS + 3.0, 32.0)
			var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
			# Keep the southern road clear.
			if absf(at.x) < 2.5 and at.z > 0.0:
				at.x += 4.0 * signf(at.x + 0.01)
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.position = at
			instance.rotation.y = rng.randf() * TAU
			instance.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
			_scatter.add_child(instance)


func _build_station(station: Dictionary) -> void:
	var at: Vector3 = station["at"]
	var color: Color = station["color"]
	for entry: Array in station["props"]:
		_prop(entry[0], at + entry[1], entry[2], 1.0, true)
	match str(station.get("person", "")):
		"ferryman":
			_figure(Models.ferryman(), at + Vector3(0.9, 0, -0.6))
		"keeper":
			var keeper := MeshInstance3D.new()
			keeper.mesh = Models.hero_body({"robe": Color(0.3, 0.27, 0.22), "robe_dark": Color(0.15, 0.13, 0.11), "trim": color, "eye": color})
			keeper.position = at + Vector3(0.9, 0, -0.9)
			keeper.rotation.y = atan2(keeper.position.x, keeper.position.z) # face the plaza
			add_child(keeper)
			_keepers.append(keeper)
			_blockers.append([Vector2(keeper.position.x, keeper.position.z), 0.5])
	# A glowing ring on the ground marks where to stand; always present so a
	# missing prop never hides a service.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.25
	ring.mesh = torus
	ring.scale = Vector3.ONE
	ring.position = at + Vector3(0, 0.06, 0)
	ring.material_override = _flat_material(color, 2.0)
	add_child(ring)
	_rings[station["id"]] = ring
	_light(at + Vector3(0, 2.2, 0), color, 2.2, 5.0)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.006
	label.modulate = Color(1, 1, 1, 0.72)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.text = str(station["label"]).get_slice("  ·  ", 0)
	label.position = at + Vector3(0, 3.1, 0)
	add_child(label)
	_labels[station["id"]] = label


func _prop(kind: String, at: Vector3, yaw: float, scale_factor: float, solid: bool) -> void:
	var mesh := AssetProps.mesh(kind)
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = Vector3.ONE * scale_factor
	instance.position = at
	instance.rotation_degrees.y = yaw
	# Same swap CampaignBackdrop uses: town props skip the combat
	# hero-occlusion shader but keep their glowing surfaces.
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface) as ShaderMaterial
		var glowing := source != null and float(source.get_shader_parameter("flat_glow")) > 0.0
		instance.set_surface_override_material(surface, AssetProps.emissive_material() if glowing else AssetProps.opaque_material())
	add_child(instance)
	if solid:
		_blockers.append([Vector2(at.x, at.z), 0.55 * scale_factor])


func _figure(mesh: Mesh, at: Vector3) -> void:
	var figure := MeshInstance3D.new()
	figure.mesh = mesh
	figure.position = at
	figure.rotation.y = atan2(at.x, at.z) # face the plaza
	add_child(figure)
	_blockers.append([Vector2(at.x, at.z), 0.5])


func _light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	add_child(lamp)
