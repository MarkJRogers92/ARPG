class_name CampaignCampDressing
extends RefCounted
## Lived-in texture for the roadside camps: ground scatter, a garland strung
## over each road gate, outer-ring silhouettes, and small story vignettes that
## say who camps here. Everything sits outside the service approach circles
## and the central road; anything inside the walk radius registers a blocker.

const IRON := Color(0.12, 0.15, 0.19)
const BONE := Color(0.74, 0.7, 0.6)
const SNOW := Color(0.82, 0.88, 0.93)
const ICE := Color(0.56, 0.78, 0.9)
const ASH := Color(0.27, 0.24, 0.23)
const LAVA := Color(1.0, 0.42, 0.1)
# Service rings and their props, the hero's arrival spot, and Mara's seat.
const KEEP_CLEAR := [
	[Vector2(0, -7.4), 2.9], [Vector2(-8.0, -4.0), 2.8], [Vector2(-8.5, 3.5), 2.9],
	[Vector2(8.0, -4.0), 2.6], [Vector2(8.5, 3.5), 2.9], [Vector2(-3.5, 8.0), 2.8],
	[Vector2(3.5, 8.0), 2.8], [Vector2(0, 2.5), 2.0], [Vector2(-4.35, -1.05), 1.0],
	[Vector2(-6.3, 4.3), 1.3], [Vector2(6.3, 1.3), 1.3],
]


static func build(root: Node3D, biome: int, kind: String) -> void:
	var p := CampaignWaystopScenery._palette(biome)
	var avoid: Array = KEEP_CLEAR.duplicate()
	for blocker: Array in root.get_meta("walk_blockers", []):
		avoid.append([blocker[0], float(blocker[1]) + 0.5])
	var scatter := _kit()
	var props := _kit()
	var glow := _kit()
	_scatter(scatter, biome, avoid)
	match kind:
		"camp":
			_open_grave(root, props, glow, Vector3(11.8, 0, 8.2), p)
			_grave_row(root, props, Vector3(7.1, 0, -12.3), p)
			_shroud_line(root, props, Vector3(-13.6, 0, 4.4), Vector3(-11.0, 0, 9.0), p)
			_coffin_trestle(root, props, Vector3(-12.1, 0, -7.6), p)
			_garland(props, glow, 0, p)
			_ring_assets(root, ["rune_gravestone", "iron_fence", "rune_gravestone", "iron_fence"], 0.82)
		"refuge":
			_firewood(root, props, Vector3(-12.2, 0, -6.8), p, true)
			_ski_rack(root, props, Vector3(11.8, 0, 6.8), p)
			_fur_frame(root, props, Vector3(-11.8, 0, 6.8), p)
			_gate_braziers(root, props, glow, p)
			_icicles(props, Vector3(0, 3.58, -14.85), 3.2)
			for side: float in [-1.0, 1.0]:
				_icicles(props, Vector3(side * 3.0, 2.13, -14.82), 3.2)
				_drift(scatter, Vector3(side * 4.2, 0, -14.6), 3.6, 0.55)
				_drift(scatter, Vector3(side * 12.4, 0, 1.4), 2.6, 0.38)
			_garland(props, glow, 1, p)
			_ring_assets(root, ["frosted_pine", "snow_boulder", "frosted_pine", "frosted_pine"], 0.9)
		"caravan":
			if biome == 1:
				_sled_repair(root, props, Vector3(11.8, 0, 7.4), p)
				_kennels(root, props, Vector3(-12.0, 0, 6.8), p)
				_firewood(root, props, Vector3(-12.4, 0, -7.6), p, true)
				_ice_cliffs(props)
				for side: float in [-1.0, 1.0]:
					_drift(scatter, Vector3(side * 13.6, 0, -4.8), 2.8, 0.42)
				_garland(props, glow, 1, p)
				_ring_assets(root, ["frosted_pine", "ice_stalagmites", "frosted_pine", "snow_boulder"], 0.86)
			else:
				_wheel_stack(root, props, Vector3(11.8, 0, 7.4), p)
				_water_awning(root, props, glow, Vector3(-12.0, 0, 6.8), p)
				_covered_wagon(root, props, Vector3(-12.6, 0, -8.0), p)
				_lava_fissures(glow)
				_garland(props, glow, 2, p)
				_ring_assets(root, ["obsidian_outcrop", "ashen_tree", "basalt_columns", "ashen_tree"], 0.8)
	for entry: Array in [["CampGroundScatter", scatter], ["CampStoryVignettes", props], ["CampLanternsAndGlow", glow]]:
		if (entry[1] as MeshKit).vertex_count() == 0:
			continue
		var mesh := CampaignWaystopScenery._mesh(root, str(entry[0]), entry[1])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _h(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


static func _open(at: Vector2, avoid: Array) -> bool:
	if absf(at.x) < 2.7 and at.y > -15.0:
		return false
	for entry: Array in avoid:
		if at.distance_to(entry[0]) < float(entry[1]):
			return false
	return true


static func _scatter(kit: MeshKit, biome: int, avoid: Array) -> void:
	var placed := 0
	for i in 260:
		if placed >= 120:
			break
		var angle := _h(i, 1.0) * TAU
		var radius := 3.2 + sqrt(_h(i, 2.0)) * 15.5
		var at := Vector2(cos(angle), sin(angle)) * radius
		if not _open(at, avoid):
			continue
		placed += 1
		var yaw := _h(i, 3.0) * 180.0
		var size := 0.6 + _h(i, 4.0) * 0.8
		var pos := Vector3(at.x, 0.03, at.y)
		var roll := int(_h(i, 5.0) * 10.0)
		match biome:
			0:
				if roll < 5:
					_tuft(kit, pos, size, Color(0.18, 0.27, 0.17).lerp(Color(0.32, 0.31, 0.2), _h(i, 6.0)))
				elif roll < 8:
					_pebbles(kit, pos, size, Color(0.27, 0.29, 0.3))
				elif roll < 9:
					kit.box(Vector3(0.36, 0.06, 0.08) * size, MeshKit.at(pos + Vector3(0, 0.03, 0), Vector3(0, yaw, 0)), BONE.darkened(0.2))
					kit.sphere(0.06 * size, MeshKit.at(pos + Vector3(0.17 * size, 0.05, 0)), BONE.darkened(0.15), 0, 5, 3)
				else:
					kit.box(Vector3(0.22, 0.02, 0.15) * size, MeshKit.at(pos, Vector3(0, yaw, 0)), Color(0.42, 0.27, 0.12))
			1:
				if roll < 5:
					kit.sphere(0.32 * size, MeshKit.at(pos, Vector3(0, yaw, 0), Vector3(1.4, 0.24, 0.9)), SNOW.darkened(0.06 + _h(i, 6.0) * 0.08), 0, 8, 4)
				elif roll < 7:
					_pebbles(kit, pos, size, Color(0.4, 0.46, 0.52))
				elif roll < 9:
					kit.box(Vector3(0.1, 0.42, 0.1) * size, MeshKit.at(pos + Vector3(0, 0.15 * size, 0), Vector3(14, yaw, -18)), ICE, 0.12)
				else:
					_tuft(kit, pos, size * 0.8, Color(0.5, 0.55, 0.5))
			_:
				if roll < 4:
					kit.sphere(0.42 * size, MeshKit.at(pos, Vector3(0, yaw, 0), Vector3(1.5, 0.2, 0.9)), ASH.lightened(_h(i, 6.0) * 0.08), 0, 8, 4)
				elif roll < 7:
					_pebbles(kit, pos, size, Color(0.1, 0.08, 0.08))
				elif roll < 9:
					kit.box(Vector3(0.12, 0.04, 0.12) * size, MeshKit.at(pos, Vector3(0, yaw, 0)), LAVA, 0.9)
				else:
					kit.box(Vector3(0.28, 0.32, 0.05) * size, MeshKit.at(pos + Vector3(0, 0.14, 0), Vector3(-12, yaw, 6)), Color(0.18, 0.1, 0.09))


static func _tuft(kit: MeshKit, at: Vector3, size: float, color: Color) -> void:
	for blade in 4:
		var lean := -24.0 + float(blade) * 16.0
		kit.box(Vector3(0.05, 0.34, 0.03) * size, MeshKit.at(at + Vector3(0, 0.15 * size, 0), Vector3(lean * 0.4, float(blade) * 47.0, lean)), color.lightened(float(blade % 2) * 0.06))


static func _pebbles(kit: MeshKit, at: Vector3, size: float, color: Color) -> void:
	for n in 3:
		var off := Vector3(cos(float(n) * 2.1) * 0.22, 0, sin(float(n) * 2.1) * 0.18) * size
		kit.sphere((0.1 + 0.04 * float(n)) * size, MeshKit.at(at + off, Vector3(0, float(n) * 40.0, 0), Vector3(1.2, 0.6, 1.0)), color.lightened(float(n) * 0.05), 0, 6, 3)


static func _drift(kit: MeshKit, at: Vector3, width: float, height: float) -> void:
	kit.sphere(width * 0.5, MeshKit.at(at, Vector3.ZERO, Vector3(1.0, height * 2.0 / width, 0.42)), SNOW, 0, 10, 5)
	kit.sphere(width * 0.3, MeshKit.at(at + Vector3(width * 0.28, 0, 0.25), Vector3.ZERO, Vector3(1.0, height * 1.6 / width, 0.5)), SNOW.lightened(0.05), 0, 8, 4)


static func _post(kit: MeshKit, at: Vector3, height: float, color: Color) -> void:
	CampaignWaystopScenery._segment(kit, at, at + Vector3(0, height, 0), 0.07, color)
	kit.box(Vector3(0.2, 0.08, 0.2), MeshKit.at(at + Vector3(0, height, 0)), IRON)


## A sagging line between two points; returns the points so callers can hang
## lanterns, flags, or shrouds off the rope.
static func _rope(kit: MeshKit, a: Vector3, b: Vector3, sag: float, color: Color, steps := 8) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		points.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	for i in steps:
		CampaignWaystopScenery._segment(kit, points[i], points[i + 1], 0.018, color)
	return points


## A strung welcome over both road gates: paper lanterns in the graveyard,
## prayer flags in the snow, ember lamps and pennants in the Rift.
static func _garland(kit: MeshKit, glow: MeshKit, biome: int, p: Dictionary) -> void:
	var flags := [Color(0.82, 0.3, 0.26), Color(0.95, 0.78, 0.36), Color(0.3, 0.56, 0.78), Color(0.88, 0.9, 0.86), Color(0.36, 0.62, 0.42)]
	for z: float in [14.3, -10.7]:
		var height := 3.3 if z > 0.0 else 3.6
		for side: float in [-1.0, 1.0]:
			_post(kit, Vector3(side * 4.95, 0, z), height, p.trim.darkened(0.2))
		var points := _rope(kit, Vector3(-4.95, height, z), Vector3(4.95, height, z), 0.75, p.trim.darkened(0.35), 10)
		for i in range(1, points.size() - 1):
			var at: Vector3 = points[i]
			match biome:
				1:
					var flag: Color = flags[i % flags.size()]
					kit.box(Vector3(0.42, 0.5, 0.025), MeshKit.at(at - Vector3(0, 0.27, 0), Vector3(0, 0, float(i % 3 - 1) * 5.0)), flag.darkened(0.12))
				2:
					if i % 2 == 0:
						CampaignWaystopScenery._segment(kit, at, at - Vector3(0, 0.2, 0), 0.012, IRON)
						glow.box(Vector3(0.18, 0.24, 0.18), MeshKit.at(at - Vector3(0, 0.34, 0)), LAVA, 1.1)
						kit.box(Vector3(0.24, 0.05, 0.24), MeshKit.at(at - Vector3(0, 0.2, 0)), IRON)
					else:
						kit.box(Vector3(0.3, 0.46, 0.025), MeshKit.at(at - Vector3(0, 0.25, 0), Vector3(0, 0, 4)), Color(0.55, 0.12, 0.08))
				_:
					if i % 2 == 0:
						glow.sphere(0.15, MeshKit.at(at - Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.0, 1.25, 1.0)), Color(1.0, 0.7, 0.34), 1.0, 7, 4)
						kit.box(Vector3(0.12, 0.05, 0.12), MeshKit.at(at - Vector3(0, 0.05, 0)), IRON)
					else:
						kit.box(Vector3(0.22, 0.32, 0.025), MeshKit.at(at - Vector3(0, 0.18, 0)), Color(0.62, 0.6, 0.52))


## Biome silhouettes in the dark band beyond the walkable edge.
static func _ring_assets(root: Node3D, kinds: Array, size: float) -> void:
	var spots := [Vector3(-16.6, 0, -9.5), Vector3(16.8, 0, -11.5), Vector3(-17.2, 0, 11.5), Vector3(16.9, 0, 12.8),
		Vector3(-9.5, 0, -17.2), Vector3(10.2, 0, -16.9), Vector3(-18.4, 0, 1.8), Vector3(18.2, 0, 3.2)]
	for i in spots.size():
		CampaignWaystopScenery._asset(root, str(kinds[i % kinds.size()]), spots[i], float(i) * 47.0, size * (0.85 + 0.1 * float(i % 3)))


# --- Gravediggers' Camp --------------------------------------------------------

static func _open_grave(root: Node3D, kit: MeshKit, glow: MeshKit, at: Vector3, p: Dictionary) -> void:
	var dirt := Color(0.24, 0.18, 0.12)
	var turn := Basis(Vector3.UP, deg_to_rad(-24.0))
	kit.box(Vector3(1.25, 0.04, 2.3), MeshKit.at(at + Vector3(0, 0.04, 0), Vector3(0, -24, 0)), Color(0.04, 0.04, 0.04))
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.14, 0.12, 2.5), MeshKit.at(at + turn * Vector3(side * 0.7, 0.07, 0), Vector3(0, -24, 0)), dirt.darkened(0.2))
	# Spoil heap with planted tools.
	var heap := at + turn * Vector3(1.55, 0, 0.1)
	kit.sphere(1.0, MeshKit.at(heap, Vector3(0, -24, 0), Vector3(0.85, 0.48, 1.3)), dirt, 0, 10, 5)
	kit.sphere(0.6, MeshKit.at(heap + Vector3(0.2, 0.25, -0.3)), dirt.lightened(0.06), 0, 8, 4)
	for tool in 2:
		var base := heap + turn * Vector3(-0.15 + float(tool) * 0.42, 0.35, -0.2 + float(tool) * 0.5)
		var tip := base + Vector3(0.12 - float(tool) * 0.3, 1.25, 0.08)
		CampaignWaystopScenery._segment(kit, base, tip, 0.035, p.trim.darkened(0.1))
		kit.box(Vector3(0.26, 0.34, 0.04), MeshKit.at(base - Vector3(0, 0.12, 0), Vector3(0, -24 + float(tool) * 30.0, 0)), IRON.lightened(0.15))
		kit.box(Vector3(0.22, 0.05, 0.05), MeshKit.at(tip, Vector3(0, -24, 0)), p.trim.darkened(0.25))
	# Pick-axe laid on the far lip, a fresh marker waiting at the head.
	var pick := at + turn * Vector3(-1.1, 0.12, -0.4)
	CampaignWaystopScenery._segment(kit, pick, pick + turn * Vector3(0, 0, 1.0), 0.03, p.trim.darkened(0.15))
	kit.box(Vector3(0.7, 0.07, 0.07), MeshKit.at(pick + turn * Vector3(0, 0.02, 1.0), Vector3(0, -24, 0)), IRON)
	var head := at + turn * Vector3(0, 0, -1.55)
	_marker(kit, head, -24.0, p.trim.lightened(0.1), true)
	var lamp := at + turn * Vector3(-0.95, 0, 1.25)
	CampaignWaystopScenery._segment(kit, lamp, lamp + Vector3(0, 1.35, 0), 0.03, IRON)
	CampaignWaystopScenery._segment(kit, lamp + Vector3(0, 1.35, 0), lamp + Vector3(0.35, 1.35, 0), 0.02, IRON)
	glow.sphere(0.12, MeshKit.at(lamp + Vector3(0.35, 1.13, 0), Vector3.ZERO, Vector3(1, 1.3, 1)), p.warm, 1.0, 7, 4)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.7)
	_light(root, lamp + Vector3(0.35, 1.3, 0), p.warm, 1.6, 4.2)


static func _marker(kit: MeshKit, at: Vector3, yaw: float, wood: Color, cross: bool) -> void:
	if cross:
		kit.box(Vector3(0.11, 1.05, 0.09), MeshKit.at(at + Vector3(0, 0.5, 0), Vector3(0, yaw, 4)), wood)
		kit.box(Vector3(0.56, 0.1, 0.09), MeshKit.at(at + Vector3(0, 0.75, 0), Vector3(0, yaw, 4)), wood)
	else:
		kit.box(Vector3(0.5, 0.68, 0.08), MeshKit.at(at + Vector3(0, 0.34, 0), Vector3(-5, yaw, -3)), wood)
		kit.box(Vector3(0.56, 0.08, 0.1), MeshKit.at(at + Vector3(0, 0.7, 0), Vector3(-5, yaw, -3)), wood.darkened(0.2))
	kit.sphere(0.32, MeshKit.at(at + Vector3(0, 0.02, 0.55), Vector3(0, yaw, 0), Vector3(0.9, 0.22, 1.7)), Color(0.22, 0.17, 0.12), 0, 7, 3)


static func _grave_row(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	for i in 4:
		var spot := at + Vector3(-2.1 + float(i) * 1.4, 0, float(i % 2) * 0.35)
		_marker(kit, spot, float(i * 7 - 10), p.trim.darkened(0.05 + float(i % 2) * 0.12), i % 2 == 0)
		if i == 1:
			kit.sphere(0.07, MeshKit.at(spot + Vector3(0.05, 0.12, 0.5)), Color(0.75, 0.28, 0.3), 0, 5, 3)
			kit.box(Vector3(0.02, 0.18, 0.02), MeshKit.at(spot + Vector3(0.05, 0.04, 0.5)), Color(0.2, 0.35, 0.18))
	# Crow perch: a leaning post with a black bird watching the road.
	var perch := at + Vector3(-3.6, 0, -0.4)
	CampaignWaystopScenery._segment(kit, perch, perch + Vector3(0.2, 2.3, 0), 0.06, p.trim.darkened(0.3))
	CampaignWaystopScenery._segment(kit, perch + Vector3(0.18, 2.1, 0), perch + Vector3(0.8, 2.25, 0), 0.035, p.trim.darkened(0.3))
	var bird := perch + Vector3(0.62, 2.42, 0)
	kit.sphere(0.13, MeshKit.at(bird, Vector3.ZERO, Vector3(1.0, 0.9, 1.5)), Color(0.05, 0.05, 0.07), 0, 7, 4)
	kit.sphere(0.08, MeshKit.at(bird + Vector3(0, 0.12, 0.14)), Color(0.05, 0.05, 0.07), 0, 6, 3)
	kit.box(Vector3(0.03, 0.03, 0.1), MeshKit.at(bird + Vector3(0, 0.11, 0.25)), Color(0.4, 0.33, 0.2))
	kit.box(Vector3(0.12, 0.03, 0.22), MeshKit.at(bird + Vector3(0, 0.0, -0.22), Vector3(-20, 0, 0)), Color(0.05, 0.05, 0.07))
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z + 0.2), 2.6)
	_light(root, at + Vector3(0, 1.6, 0.9), Color(0.45, 0.8, 1.0), 0.9, 4.0)


static func _shroud_line(root: Node3D, kit: MeshKit, a: Vector3, b: Vector3, p: Dictionary) -> void:
	_post(kit, a, 2.2, p.trim.darkened(0.2))
	_post(kit, b, 2.2, p.trim.darkened(0.2))
	var points := _rope(kit, a + Vector3(0, 2.15, 0), b + Vector3(0, 2.15, 0), 0.32, Color(0.5, 0.45, 0.36), 6)
	var yaw := rad_to_deg(atan2(b.x - a.x, b.z - a.z)) + 90.0
	for i in [1, 2, 4, 5]:
		var at: Vector3 = points[i]
		var cloth := Color(0.72, 0.69, 0.6).darkened(float(i % 2) * 0.12)
		kit.box(Vector3(0.62, 1.05, 0.03), MeshKit.at(at - Vector3(0, 0.54, 0), Vector3(0, yaw, float(i % 3 - 1) * 3.0)), cloth)
		kit.box(Vector3(0.64, 0.05, 0.05), MeshKit.at(at - Vector3(0, 0.02, 0), Vector3(0, yaw, 0)), cloth.darkened(0.2))
	# Basket of folded shrouds at the foot of the line.
	var basket := a.lerp(b, 0.5) + Vector3(0.55, 0, 0.1)
	kit.cylinder(0.36, 0.3, 0.38, MeshKit.at(basket + Vector3(0, 0.19, 0)), Color(0.45, 0.33, 0.18), 0, 9)
	kit.box(Vector3(0.48, 0.12, 0.42), MeshKit.at(basket + Vector3(0, 0.42, 0), Vector3(0, 15, 0)), Color(0.75, 0.72, 0.64))
	for point: Vector3 in [a, b]:
		CampaignWaystopScenery._register_blocker(root, Vector2(point.x, point.z), 0.35)
	CampaignWaystopScenery._register_blocker(root, Vector2(basket.x, basket.z), 0.45)


static func _coffin_trestle(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	var yaw := 22.0
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var wood: Color = p.trim.darkened(0.1)
	for z: float in [-0.75, 0.75]:
		for side: float in [-1.0, 1.0]:
			CampaignWaystopScenery._segment(kit, at + turn * Vector3(side * 0.42, 0.02, z), at + turn * Vector3(0, 0.66, z), 0.04, IRON)
		kit.box(Vector3(0.9, 0.08, 0.12), MeshKit.at(at + turn * Vector3(0, 0.66, z), Vector3(0, yaw, 0)), wood.darkened(0.2))
	kit.box(Vector3(0.7, 0.42, 2.0), MeshKit.at(at + turn * Vector3(0, 0.92, 0), Vector3(0, yaw, 0)), Color(0.3, 0.2, 0.13))
	kit.box(Vector3(0.78, 0.07, 2.08), MeshKit.at(at + turn * Vector3(0.12, 1.17, 0.04), Vector3(0, yaw + 6.0, 3)), Color(0.36, 0.25, 0.16))
	kit.box(Vector3(0.08, 0.02, 0.6), MeshKit.at(at + turn * Vector3(0.12, 1.22, -0.2), Vector3(0, yaw, 0)), BONE.darkened(0.3))
	kit.box(Vector3(0.36, 0.02, 0.08), MeshKit.at(at + turn * Vector3(0.12, 1.22, -0.35), Vector3(0, yaw, 0)), BONE.darkened(0.3))
	# Loose planks and a saw left mid-job.
	for i in 3:
		kit.box(Vector3(0.22, 0.05, 1.7), MeshKit.at(at + turn * Vector3(1.0 + float(i) * 0.08, 0.05 + float(i) * 0.05, 0.1), Vector3(0, yaw + float(i) * 4.0, 0)), wood.lightened(float(i) * 0.05))
	kit.box(Vector3(0.05, 0.18, 0.62), MeshKit.at(at + turn * Vector3(1.05, 0.25, -0.3), Vector3(0, yaw, 0)), IRON.lightened(0.25))
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.35)
	_light(root, at + Vector3(0.8, 1.8, 0.6), Color(1.0, 0.66, 0.34), 1.0, 3.6)


# --- Frozen camps ---------------------------------------------------------------

static func _firewood(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary, snowy: bool) -> void:
	var wood := Color(0.38, 0.26, 0.16)
	for row in 3:
		for i in 4 - row:
			var x := -0.66 + float(i) * 0.44 + float(row) * 0.22
			CampaignWaystopScenery._segment(kit, at + Vector3(x, 0.17 + float(row) * 0.3, -0.55), at + Vector3(x, 0.17 + float(row) * 0.3, 0.55), 0.15, wood.lightened(float((i + row) % 2) * 0.08))
			kit.cylinder(0.11, 0.11, 0.02, MeshKit.at(at + Vector3(x, 0.17 + float(row) * 0.3, 0.56), Vector3(90, 0, 0)), Color(0.66, 0.52, 0.34), 0, 7)
	for side: float in [-1.0, 1.0]:
		CampaignWaystopScenery._segment(kit, at + Vector3(side * 0.95, 0, 0), at + Vector3(side * 0.95, 1.1, 0), 0.05, IRON)
	if snowy:
		kit.sphere(0.8, MeshKit.at(at + Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1.25, 0.2, 0.85)), SNOW, 0, 9, 4)
	kit.box(Vector3(0.05, 0.6, 0.05), MeshKit.at(at + Vector3(0.6, 0.48, 0.75), Vector3(0, 0, 25)), p.trim.darkened(0.2))
	kit.box(Vector3(0.24, 0.14, 0.04), MeshKit.at(at + Vector3(0.78, 0.78, 0.75), Vector3(0, 0, 25)), IRON.lightened(0.2))
	kit.cylinder(0.24, 0.26, 0.42, MeshKit.at(at + Vector3(-0.2, 0.21, 0.95)), wood.lightened(0.05), 0, 9)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.2)


static func _ski_rack(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	kit.box(Vector3(2.2, 0.1, 0.12), MeshKit.at(at + Vector3(0, 1.25, -0.3)), p.trim.darkened(0.1))
	for side: float in [-1.0, 1.0]:
		CampaignWaystopScenery._segment(kit, at + Vector3(side * 1.05, 0, -0.3), at + Vector3(side * 1.05, 1.32, -0.3), 0.05, p.trim.darkened(0.2))
	for i in 4:
		var x := -0.75 + float(i) * 0.36
		kit.box(Vector3(0.1, 1.75, 0.03), MeshKit.at(at + Vector3(x, 0.86, -0.12), Vector3(-12, 0, float(i % 2) * 4.0 - 2.0)), Color(0.55, 0.36, 0.2).darkened(float(i % 2) * 0.12))
		kit.box(Vector3(0.1, 0.05, 0.12), MeshKit.at(at + Vector3(x, 1.72, 0.06), Vector3(30, 0, 0)), Color(0.55, 0.36, 0.2))
	for i in 2:
		var shoe := at + Vector3(0.75 + float(i) * 0.15, 0.62, 0.1 + float(i) * 0.08)
		kit.torus(0.2, 0.25, MeshKit.at(shoe, Vector3(75, 0, 0), Vector3(1.0, 1.0, 1.6)), Color(0.44, 0.3, 0.18), 0, 10)
		kit.box(Vector3(0.3, 0.02, 0.5), MeshKit.at(shoe, Vector3(-15, 0, 0)), Color(0.3, 0.22, 0.15))
	_drift(kit, at + Vector3(0, 0, -0.55), 2.6, 0.32)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.25)
	_light(root, at + Vector3(-0.4, 1.7, 1.2), Color(1.0, 0.72, 0.42), 1.7, 4.4)


static func _fur_frame(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		CampaignWaystopScenery._segment(kit, at + Vector3(side * 0.85, 0, 0), at + Vector3(side * 0.85, 2.1, 0), 0.06, p.trim.darkened(0.2))
	CampaignWaystopScenery._segment(kit, at + Vector3(-1.0, 2.0, 0), at + Vector3(1.0, 2.0, 0), 0.05, p.trim.darkened(0.15))
	CampaignWaystopScenery._segment(kit, at + Vector3(-0.85, 0.35, 0), at + Vector3(0.85, 0.35, 0), 0.04, p.trim.darkened(0.15))
	var furs := [Color(0.48, 0.38, 0.28), Color(0.72, 0.7, 0.66), Color(0.32, 0.26, 0.22)]
	for i in 3:
		var x := -0.5 + float(i) * 0.5
		kit.box(Vector3(0.44, 1.3, 0.07), MeshKit.at(at + Vector3(x, 1.28, 0.02 * float(i)), Vector3(0, float(i - 1) * 6.0, float(i - 1) * 3.0)), furs[i])
		kit.box(Vector3(0.5, 0.12, 0.1), MeshKit.at(at + Vector3(x, 1.94, 0)), Color(furs[i]).darkened(0.25))
	# Scraping block and a pelt bundle.
	kit.cylinder(0.3, 0.34, 0.5, MeshKit.at(at + Vector3(0.4, 0.25, 0.9)), Color(0.38, 0.27, 0.17), 0, 9)
	kit.box(Vector3(0.3, 0.03, 0.08), MeshKit.at(at + Vector3(0.42, 0.52, 0.9), Vector3(0, 30, 0)), IRON.lightened(0.25))
	kit.sphere(0.32, MeshKit.at(at + Vector3(-0.55, 0.18, 0.75), Vector3.ZERO, Vector3(1.3, 0.6, 0.9)), Color(0.55, 0.45, 0.33), 0, 8, 4)
	_drift(kit, at + Vector3(0.2, 0, -0.5), 2.4, 0.3)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z + 0.3), 1.25)
	_light(root, at + Vector3(0.6, 1.7, 1.2), Color(1.0, 0.72, 0.42), 1.7, 4.4)


static func _gate_braziers(root: Node3D, kit: MeshKit, glow: MeshKit, p: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 3.2, 0, -13.4)
		for leg in 3:
			var angle := TAU * float(leg) / 3.0
			CampaignWaystopScenery._segment(kit, at + Vector3(cos(angle) * 0.35, 0, sin(angle) * 0.35), at + Vector3(0, 0.95, 0), 0.04, IRON)
		kit.cylinder(0.42, 0.24, 0.3, MeshKit.at(at + Vector3(0, 1.05, 0)), IRON.lightened(0.1), 0, 10)
		glow.sphere(0.3, MeshKit.at(at + Vector3(0, 1.22, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0)), p.warm, 1.0, 8, 4)
		glow.cylinder(0.02, 0.18, 0.45, MeshKit.at(at + Vector3(0, 1.48, 0)), p.warm.lightened(0.2), 0.9, 6)
	_light(root, Vector3(0, 1.9, -13.2), p.warm, 2.2, 6.5)


static func _icicles(kit: MeshKit, at: Vector3, width: float) -> void:
	var count := int(width / 0.24)
	for i in count:
		var length := 0.16 + _h(i, at.x + 3.0) * 0.36
		var x := -width * 0.5 + (float(i) + 0.5) * width / float(count)
		kit.cylinder(0.05, 0.0, length, MeshKit.at(at + Vector3(x, -length * 0.5, 0)), ICE.lightened(0.15), 0.15, 5)


static func _sled_repair(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	var wood := Color(0.5, 0.33, 0.19)
	# Two sawhorses carry an upturned sled bed with one runner off.
	for z: float in [-0.9, 0.9]:
		kit.box(Vector3(1.4, 0.1, 0.12), MeshKit.at(at + Vector3(0, 0.78, z)), wood.darkened(0.2))
		for side: float in [-1.0, 1.0]:
			CampaignWaystopScenery._segment(kit, at + Vector3(side * 0.62, 0.0, z - 0.18), at + Vector3(side * 0.5, 0.76, z), 0.04, wood.darkened(0.3))
			CampaignWaystopScenery._segment(kit, at + Vector3(side * 0.62, 0.0, z + 0.18), at + Vector3(side * 0.5, 0.76, z), 0.04, wood.darkened(0.3))
	for i in 5:
		kit.box(Vector3(1.05, 0.06, 0.32), MeshKit.at(at + Vector3(0, 0.88, -1.0 + float(i) * 0.5), Vector3(0, float(i % 2) * 2.0, 0)), wood.lightened(float(i % 2) * 0.06))
	CampaignWaystopScenery._segment(kit, at + Vector3(-0.55, 0.98, -1.3), at + Vector3(-0.55, 0.98, 1.2), 0.05, IRON.lightened(0.2))
	CampaignWaystopScenery._segment(kit, at + Vector3(-0.55, 0.98, 1.2), at + Vector3(-0.55, 1.28, 1.55), 0.05, IRON.lightened(0.2))
	# The loose runner leans against the trestle; tools lie on a stump.
	CampaignWaystopScenery._segment(kit, at + Vector3(0.95, 0.02, -1.25), at + Vector3(0.78, 1.15, 0.55), 0.05, IRON.lightened(0.2))
	var stump := at + Vector3(-1.35, 0, 0.9)
	kit.cylinder(0.32, 0.36, 0.55, MeshKit.at(stump + Vector3(0, 0.27, 0)), Color(0.36, 0.25, 0.16), 0, 9)
	kit.cylinder(0.25, 0.25, 0.02, MeshKit.at(stump + Vector3(0, 0.55, 0)), Color(0.62, 0.48, 0.32), 0, 9)
	kit.box(Vector3(0.06, 0.06, 0.4), MeshKit.at(stump + Vector3(0.05, 0.6, 0), Vector3(0, 20, 0)), wood.darkened(0.2))
	kit.box(Vector3(0.2, 0.1, 0.1), MeshKit.at(stump + Vector3(0.12, 0.6, 0.2), Vector3(0, 20, 0)), IRON)
	kit.box(Vector3(0.3, 0.02, 0.08), MeshKit.at(stump + Vector3(-0.1, 0.57, -0.12), Vector3(0, -30, 0)), IRON.lightened(0.3))
	for i in 4:
		kit.box(Vector3(0.12, 0.02, 0.05), MeshKit.at(at + Vector3(-0.7 + _h(i, 9.0) * 1.6, 0.04, 1.3 + _h(i, 8.0) * 0.6), Vector3(0, _h(i, 7.0) * 180.0, 0)), Color(0.75, 0.6, 0.38))
	_drift(kit, at + Vector3(0.3, 0, -1.8), 2.8, 0.36)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.7)
	_light(root, at + Vector3(-0.6, 1.9, 1.2), Color(1.0, 0.72, 0.42), 2.0, 4.6)


static func _kennels(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	var wood := Color(0.42, 0.29, 0.18)
	for i in 2:
		var hut := at + Vector3(-0.7 + float(i) * 1.45, 0, float(i) * 0.35)
		kit.box(Vector3(0.95, 0.62, 1.0), MeshKit.at(hut + Vector3(0, 0.31, 0)), wood.darkened(float(i) * 0.1))
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0.66, 0.06, 1.12), MeshKit.at(hut + Vector3(side * 0.26, 0.8, 0), Vector3(0, 0, -side * 38.0)), wood.darkened(0.25))
			kit.box(Vector3(0.6, 0.08, 1.1), MeshKit.at(hut + Vector3(side * 0.27, 0.86, 0), Vector3(0, 0, -side * 38.0)), SNOW)
		kit.box(Vector3(0.4, 0.42, 0.04), MeshKit.at(hut + Vector3(0, 0.25, 0.51)), Color(0.05, 0.05, 0.06))
		kit.box(Vector3(0.3, 0.06, 0.24), MeshKit.at(hut + Vector3(0.3, 0.04, 0.75)), Color(0.35, 0.37, 0.4))
	# A sleeping sled dog curled at the warmer hut's door.
	var dog := at + Vector3(-0.55, 0, 0.95)
	kit.sphere(0.32, MeshKit.at(dog + Vector3(0, 0.2, 0), Vector3(0, 30, 0), Vector3(1.3, 0.7, 1.0)), Color(0.62, 0.6, 0.58), 0, 8, 5)
	kit.sphere(0.16, MeshKit.at(dog + Vector3(0.3, 0.25, 0.12)), Color(0.3, 0.29, 0.3), 0, 7, 4)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.06, 0.1, 0.04), MeshKit.at(dog + Vector3(0.3 + side * 0.07, 0.42, 0.1), Vector3(0, 0, side * 12)), Color(0.3, 0.29, 0.3))
	# Harness post with hanging traces.
	var post := at + Vector3(1.75, 0, -0.75)
	CampaignWaystopScenery._segment(kit, post, post + Vector3(0, 1.7, 0), 0.07, wood.darkened(0.3))
	for i in 3:
		var hook := post + Vector3(0, 1.45 - float(i) * 0.08, 0.06)
		CampaignWaystopScenery._segment(kit, hook, hook + Vector3(-0.2 + float(i) * 0.2, -0.75, 0.08), 0.025, Color(0.48, 0.2, 0.14).darkened(float(i) * 0.12))
	kit.torus(0.14, 0.18, MeshKit.at(post + Vector3(0, 1.25, 0.1), Vector3(90, 0, 0)), Color(0.6, 0.45, 0.25), 0, 10)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x + 0.2, at.z), 1.8)
	_light(root, at + Vector3(0.4, 1.6, 1.3), Color(1.0, 0.7, 0.4), 1.7, 4.4)


static func _ice_cliffs(kit: MeshKit) -> void:
	for i in 9:
		var x := -17.0 + float(i) * 4.25
		if absf(x) < 3.0:
			continue
		var height := 3.2 + _h(i, 11.0) * 3.4
		var z := -18.5 - _h(i, 12.0) * 1.6
		kit.box(Vector3(3.3, height, 2.0), MeshKit.at(Vector3(x, height * 0.5 - 0.2, z), Vector3(4, _h(i, 13.0) * 30.0 - 15.0, _h(i, 14.0) * 10.0 - 5.0)), ICE.darkened(0.2 + _h(i, 15.0) * 0.12), 0.05)
		kit.box(Vector3(3.4, 0.28, 2.1), MeshKit.at(Vector3(x, height - 0.1, z), Vector3(4, _h(i, 13.0) * 30.0 - 15.0, _h(i, 14.0) * 10.0 - 5.0)), SNOW)
		kit.box(Vector3(1.0, height * 0.6, 0.9), MeshKit.at(Vector3(x + 1.3, height * 0.3, z + 1.1), Vector3(0, 25, -8)), ICE.lightened(0.05), 0.12)


# --- Redwake Caravan ------------------------------------------------------------

static func _wheel(kit: MeshKit, at: Vector3, rot: Vector3, radius: float, wood: Color) -> void:
	kit.torus(radius - 0.1, radius, MeshKit.at(at, rot), wood, 0, 16)
	kit.torus(radius - 0.02, radius + 0.025, MeshKit.at(at, rot), IRON, 0, 16)
	var basis := Basis.from_euler(rot * PI / 180.0)
	kit.cylinder(0.1, 0.1, 0.2, MeshKit.at(at, rot), wood.darkened(0.25), 0, 8)
	for spoke in 6:
		var angle := TAU * float(spoke) / 6.0
		var dir := basis * Vector3(cos(angle), 0, sin(angle))
		CampaignWaystopScenery._segment(kit, at + dir * 0.08, at + dir * (radius - 0.08), 0.025, wood.darkened(0.12))


static func _wheel_stack(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	var wood := Color(0.42, 0.26, 0.16)
	for i in 3:
		_wheel(kit, at + Vector3(-0.7 + float(i) * 0.3, 0.6, -0.4 + float(i) * 0.12), Vector3(90, 0, -12.0), 0.62, wood.lightened(float(i) * 0.04))
	_wheel(kit, at + Vector3(0.7, 0.12, 0.65), Vector3(0, 0, 0), 0.62, wood.darkened(0.08))
	_wheel(kit, at + Vector3(0.75, 0.26, 0.6), Vector3(4, 20, 0), 0.55, wood)
	# Spare axle and a grease pot.
	CampaignWaystopScenery._segment(kit, at + Vector3(-1.2, 0.1, 1.0), at + Vector3(0.2, 0.1, 1.45), 0.07, wood.darkened(0.2))
	kit.cylinder(0.16, 0.18, 0.28, MeshKit.at(at + Vector3(-1.25, 0.14, 0.4)), IRON, 0, 8)
	kit.cylinder(0.13, 0.13, 0.02, MeshKit.at(at + Vector3(-1.25, 0.29, 0.4)), Color(0.08, 0.06, 0.05), 0, 8)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.6)
	_light(root, at + Vector3(0, 1.6, 1.1), Color(1.0, 0.55, 0.25), 1.8, 4.4)


static func _water_awning(root: Node3D, kit: MeshKit, glow: MeshKit, at: Vector3, p: Dictionary) -> void:
	var cloth := Color(0.62, 0.42, 0.27)
	for x: float in [-1.2, 1.2]:
		for z: float in [-0.9, 0.9]:
			CampaignWaystopScenery._segment(kit, at + Vector3(x, 0, z), at + Vector3(x, 1.9 + (0.25 if z < 0.0 else 0.0), z), 0.05, IRON)
	kit.box(Vector3(2.7, 0.06, 2.1), MeshKit.at(at + Vector3(0, 2.05, 0), Vector3(-7, 0, 0)), cloth)
	for x in 6:
		kit.box(Vector3(0.36, 0.22, 0.03), MeshKit.at(at + Vector3(-1.12 + float(x) * 0.45, 1.83, 1.07), Vector3(-7, 0, 0)), cloth.darkened(0.08 + float(x % 2) * 0.08))
	for i in 5:
		var barrel := at + Vector3(-0.8 + float(i % 3) * 0.75, 0, -0.35 + (0.75 if i >= 3 else 0.0))
		kit.cylinder(0.3, 0.3, 0.8, MeshKit.at(barrel + Vector3(0, 0.4, 0)), Color(0.4, 0.27, 0.17).darkened(float(i % 2) * 0.08), 0, 10)
		for y: float in [0.16, 0.64]:
			kit.cylinder(0.315, 0.315, 0.05, MeshKit.at(barrel + Vector3(0, y, 0)), IRON, 0, 10)
		# Precious water glints in the open casks.
		if i % 2 == 0:
			glow.cylinder(0.25, 0.25, 0.02, MeshKit.at(barrel + Vector3(0, 0.79, 0)), Color(0.32, 0.62, 0.78), 0.35, 10)
		else:
			kit.cylinder(0.3, 0.3, 0.04, MeshKit.at(barrel + Vector3(0, 0.81, 0)), Color(0.32, 0.22, 0.14), 0, 10)
	kit.box(Vector3(0.05, 0.42, 0.05), MeshKit.at(at + Vector3(1.05, 0.95, 0.15), Vector3(0, 0, 30)), Color(0.55, 0.42, 0.25))
	kit.sphere(0.1, MeshKit.at(at + Vector3(1.15, 0.75, 0.15), Vector3.ZERO, Vector3(1.2, 0.6, 1.2)), Color(0.55, 0.42, 0.25), 0, 6, 3)
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.6)
	_light(root, at + Vector3(0, 1.6, 1.2), Color(1.0, 0.62, 0.3), 2.0, 4.6)


static func _covered_wagon(root: Node3D, kit: MeshKit, at: Vector3, p: Dictionary) -> void:
	var yaw := 28.0
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var wood := Color(0.38, 0.24, 0.15)
	kit.box(Vector3(1.6, 0.55, 3.0), MeshKit.at(at + turn * Vector3(0, 0.9, 0), Vector3(0, yaw, 0)), wood)
	kit.box(Vector3(1.7, 0.08, 3.1), MeshKit.at(at + turn * Vector3(0, 1.2, 0), Vector3(0, yaw, 0)), wood.darkened(0.25))
	for i in 4:
		var z := -1.25 + float(i) * 0.83
		for seg in 6:
			var a0 := PI * float(seg) / 6.0
			var a1 := PI * float(seg + 1) / 6.0
			CampaignWaystopScenery._segment(kit, at + turn * Vector3(cos(a0) * 0.82, 1.2 + sin(a0) * 0.95, z), at + turn * Vector3(cos(a1) * 0.82, 1.2 + sin(a1) * 0.95, z), 0.03, IRON)
	for seg in 6:
		var a := PI * (float(seg) + 0.5) / 6.0
		kit.box(Vector3(0.48, 0.05, 2.7), MeshKit.at(at + turn * Vector3(cos(a) * 0.84, 1.2 + sin(a) * 0.97, 0), Vector3(0, yaw, rad_to_deg(a) - 90.0)), Color(0.68, 0.55, 0.4).darkened(float(seg % 2) * 0.08 + 0.1))
	for x: float in [-0.88, 0.88]:
		for z: float in [-1.05, 1.05]:
			_wheel(kit, at + turn * Vector3(x, 0.55, z), Vector3(0, yaw, 90), 0.52, wood.darkened(0.1))
	CampaignWaystopScenery._segment(kit, at + turn * Vector3(0, 0.62, 1.5), at + turn * Vector3(0.15, 0.12, 2.9), 0.05, wood.darkened(0.2))
	kit.box(Vector3(0.6, 0.28, 0.45), MeshKit.at(at + turn * Vector3(0.55, 1.36, -1.25), Vector3(0, yaw + 10.0, 0)), Color(0.32, 0.2, 0.12))
	CampaignWaystopScenery._register_blocker(root, Vector2(at.x, at.z), 1.9)
	_light(root, at + Vector3(0.6, 2.2, 0.4), Color(1.0, 0.55, 0.25), 1.8, 4.6)


static func _lava_fissures(glow: MeshKit) -> void:
	for i in 10:
		var angle := TAU * (float(i) + _h(i, 21.0) * 0.6) / 10.0
		if absf(cos(angle)) < 0.22:
			continue
		var start := Vector3(cos(angle), 0, sin(angle)) * (14.6 + _h(i, 22.0) * 1.2)
		var heading := angle + (_h(i, 23.0) - 0.5) * 0.9
		var point := start
		for seg in 4:
			var bend := heading + (_h(i * 7 + seg, 24.0) - 0.5) * 1.1
			var next := point + Vector3(cos(bend), 0, sin(bend)) * (0.9 + _h(i * 5 + seg, 25.0) * 0.8)
			var mid := (point + next) * 0.5
			var length := point.distance_to(next)
			var width := 0.16 - float(seg) * 0.03
			glow.box(Vector3(width, 0.03, length), MeshKit.at(mid + Vector3(0, 0.035, 0), Vector3(0, rad_to_deg(atan2(next.x - point.x, next.z - point.z)), 0)), LAVA.lerp(Color(1.0, 0.75, 0.3), float(seg) * 0.15), 1.0)
			point = next


static func _light(root: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "CampVignetteLight"
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	root.add_child(lamp)


static func _kit() -> MeshKit:
	return CampaignWaystopScenery._kit()
