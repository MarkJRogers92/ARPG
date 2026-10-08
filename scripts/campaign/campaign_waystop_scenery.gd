class_name CampaignWaystopScenery
extends RefCounted
## Small authored settlements shared by the walk town and its inset. The
## seven service interactions remain owned by CampaignWalkTown; this helper
## only builds a destination's ground, road, and recognizable silhouette.

const SOUL := Color(0.34, 0.86, 1.0)
const GOLD := Color(0.95, 0.72, 0.36)
const STONE := Color(0.29, 0.32, 0.36)
const IRON := Color(0.12, 0.15, 0.19)


static func build(parent: Node3D, place: Dictionary, scale_factor := 1.0) -> Node3D:
	var biome := clampi(int(place.get("biome_index", 0)), 0, 2)
	var kind := str(place.get("kind", "camp"))
	var stage := clampi(int(place.get("stage", 0)), 0, 4)
	var root := Node3D.new()
	root.name = "Waystop_" + str(place.get("id", "unknown")).replace(":", "_")
	root.scale = Vector3.ONE * scale_factor
	root.set_meta("walk_blockers", [])
	parent.add_child(root)
	_ground(root, biome, kind)
	_road(root, biome, stage)
	match kind:
		"camp": _camp(root, biome, stage, false)
		"caravan": _camp(root, biome, stage, true)
		"village": _village(root, biome, stage)
		"monastery": _monastery(root, biome, stage)
		"refuge": _refuge(root, biome)
		"watchtower": _watchtower(root, biome, stage)
		"ice_chapel": _ice_chapel(root, stage)
		"forge": _forge(root, stage)
		"siege": _siege(root, stage)
		"dawn": _dawn(root)
		_: _camp(root, biome, stage, false)
	_arrival_markers(root, biome, kind)
	_nameboard(root, str(place.get("name", "Waystop")), biome)
	if kind != "lantern" and stage > 0:
		_local_honor(root, biome, stage)
	return root


static func walk_blockers(root: Node3D) -> Array:
	var blockers: Array = root.get_meta("walk_blockers", [])
	var scaled: Array = []
	var factor := root.scale.x
	for entry: Array in blockers:
		scaled.append([entry[0], float(entry[1]) * factor])
	return scaled


static func _palette(biome: int) -> Dictionary:
	match biome:
		1:
			return {"earth": Color(0.34, 0.43, 0.53), "road": Color(0.48, 0.57, 0.65),
				"stone": Color(0.49, 0.58, 0.66), "trim": Color(0.63, 0.82, 0.88), "warm": Color(1.0, 0.71, 0.35), "glow": SOUL}
		2:
			return {"earth": Color(0.23, 0.12, 0.095), "road": Color(0.4, 0.25, 0.19),
				"stone": Color(0.3, 0.24, 0.22), "trim": Color(0.58, 0.3, 0.18), "warm": Color(1.0, 0.43, 0.16), "glow": Color(1.0, 0.43, 0.16)}
		_:
			return {"earth": Color(0.13, 0.16, 0.13), "road": Color(0.34, 0.33, 0.31),
				"stone": STONE, "trim": Color(0.43, 0.35, 0.27), "warm": GOLD, "glow": SOUL}


static func _ground(parent: Node3D, biome: int, kind: String) -> void:
	var p := _palette(biome)
	var kit := _kit()
	kit.cylinder(0.0, 23.0, 0.22, MeshKit.at(Vector3(0, -0.14, 0)), p.earth.darkened(0.1), 0, 40)
	kit.cylinder(0.0, 15.2, 0.13, MeshKit.at(Vector3(0, -0.01, 0)), p.earth.lightened(0.05), 0, 32)
	# Unlike the circular Last Lantern plaza, later sites have irregular, broken
	# ground edges and an open lane leading in from the south.
	for side: float in [-1.0, 1.0]:
		for i in 7:
			var z := -15.0 + float(i) * 4.2
			var x := side * (13.8 + float(i % 3) * 1.1)
			kit.box(Vector3(2.1 + float(i % 2) * 0.7, 0.12, 3.5), MeshKit.at(Vector3(x, 0.02, z), Vector3(0, side * float(i % 3 - 1) * 8.0, 0)), p.earth.darkened(0.06 + float(i % 4) * 0.025))
		if kind == "village" or kind == "dawn":
			for i in 3:
				var x := side * (18.0 + float(i % 2) * 1.2)
				var z := -9.0 + float(i) * 8.0
				kit.box(Vector3(3.2, 0.14, 3.0), MeshKit.at(Vector3(x, 0.08, z)), p.road.darkened(0.08))
	var ground := _mesh(parent, "WaystopEarth", kit)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _road(parent: Node3D, biome: int, stage: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	var length := 29 if stage != 4 else 26
	for row in length:
		var z := 14.2 - float(row) * 1.0
		for col in 5:
			var x := float(col - 2) * 0.9 + (0.16 if row % 2 == 0 else -0.16)
			var shade := float(posmod(row * 5 + col * 3 + stage, 4)) * 0.035
			kit.box(Vector3(0.82, 0.1, 0.82), MeshKit.at(Vector3(x, 0.06, z), Vector3(0, float((row + col) % 3 - 1) * 3.0, 0)), p.road.darkened(0.05 + shade))
	# Short branching paths land at the familiar service ring, leaving each
	# station's walk-up circle unobstructed.
	for x: float in [-1.0, 1.0]:
		for row in 5:
			var z := 4.8 - float(row) * 2.0
			kit.box(Vector3(0.74, 0.07, 0.76), MeshKit.at(Vector3(x * (2.4 + float(row) * 0.82), 0.05, z)), p.road.darkened(0.1))
	var road := _mesh(parent, "ArrivalRoadSouthToRouteNorth", kit)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _camp(parent: Node3D, biome: int, stage: int, caravan: bool) -> void:
	var p := _palette(biome)
	var kit := _kit()
	for side: float in [-1.0, 1.0]:
		var x := side * 12.7
		var z := -4.5 if side < 0.0 else -5.4
		_tent(kit, Vector3(x, 0, z), p, side < 0.0)
		_register_blocker(parent, Vector2(x, z), 1.55)
		var rear_tent := Vector2(side * 15.0, -13.0)
		_tent(kit, Vector3(rear_tent.x, 0, rear_tent.y), p, side > 0.0)
		_register_blocker(parent, rear_tent, 1.55)
		kit.box(Vector3(0.2, 3.0, 0.2), MeshKit.at(Vector3(side * 7.3, 1.5, -14.7)), IRON)
		kit.box(Vector3(1.15, 1.0, 0.12), MeshKit.at(Vector3(side * 7.3, 2.2, -14.7)), p.trim)
		if stage >= 2:
			kit.box(Vector3(0.12, 2.6, 0.12), MeshKit.at(Vector3(side * 6.2, 1.3, -13.7)), IRON)
			kit.box(Vector3(0.8, 1.0, 0.07), MeshKit.at(Vector3(side * 6.2, 1.9, -13.7)), p.warm)
	if caravan:
		_asset(parent, "sled" if biome == 1 else "minecart", Vector3(-12.6, 0, 7.2), -8.0, 1.05)
		_asset(parent, "funeral_wagon", Vector3(12.0, 0, -8.2), 184.0, 0.92)
		_asset(parent, "supply_tripod" if biome == 1 else "crate_stack", Vector3(11.7, 0, -9.6), -24.0, 0.95)
	else:
		_asset(parent, "funeral_wagon" if biome == 0 else ("sled" if biome == 1 else "minecart"), Vector3(-12.8, 0, 8.0), 26.0, 0.95)
		kit.cylinder(0.84, 1.0, 0.26, MeshKit.at(Vector3(0, 0.14, -3.8)), IRON, 0, 12)
		for angle_index in 9:
			var angle := TAU * float(angle_index) / 9.0
			var x := cos(angle) * 0.88
			var z := -3.8 + sin(angle) * 0.88
			kit.box(Vector3(0.62, 0.2, 0.22), MeshKit.at(Vector3(x, 0.2, z), Vector3(0, -rad_to_deg(angle), 0)), p.trim)
		kit.box(Vector3(1.1, 0.18, 0.2), MeshKit.at(Vector3(0, 0.32, -3.8), Vector3(0, 34, 0)), IRON)
		kit.box(Vector3(1.1, 0.18, 0.2), MeshKit.at(Vector3(0, 0.36, -3.8), Vector3(0, -34, 0)), p.trim)
		kit.sphere(0.43, MeshKit.at(Vector3(0, 0.69, -3.8)), p.warm, 1.25, 8, 5)
		kit.sphere(0.25, MeshKit.at(Vector3(-0.14, 1.05, -3.76)), p.glow, 1.6, 8, 5)
		kit.sphere(0.22, MeshKit.at(Vector3(0.18, 0.96, -3.82)), p.warm, 1.35, 8, 5)
		_register_blocker(parent, Vector2(0, -3.8), 0.78)
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(1.2, 0.12, 0.12), MeshKit.at(Vector3(side * 0.85, 0.3, -2.0)), p.trim)
	var marker := _mesh(parent, "CaravanEncampment" if caravan else "GravediggersCamp", kit)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not caravan:
		var fire_light := OmniLight3D.new()
		fire_light.name = "CampfireWarmth"
		fire_light.position = Vector3(0, 1.15, -3.8)
		fire_light.light_color = p.warm
		fire_light.light_energy = 3.4
		fire_light.omni_range = 8.2
		parent.add_child(fire_light)


static func _tent(kit: MeshKit, at: Vector3, p: Dictionary, turned: bool) -> void:
	var yaw := -10.0 if turned else 10.0
	kit.box(Vector3(3.0, 0.12, 2.75), MeshKit.at(at + Vector3(0, 0.06, 0), Vector3(0, yaw, 0)), p.trim.darkened(0.16))
	# Two sloped canvas planes form a ridge tent. The south face stays open as
	# an obvious mouth, while the rear flaps, ridge pole, ropes, and stakes give
	# the shelter a field-built silhouette instead of a cottage roof.
	for side: float in [-1.0, 1.0]:
		var roof_angle := -48.0 * side
		kit.box(Vector3(2.35, 0.14, 2.72), MeshKit.at(at + Vector3(side * 0.78, 1.28, 0), Vector3(0, yaw, roof_angle)), p.trim.darkened(0.04))
		kit.box(Vector3(2.42, 0.055, 0.08), MeshKit.at(at + Vector3(side * 0.76, 1.32, -0.08), Vector3(0, yaw, roof_angle)), p.warm.lightened(0.04))
		kit.cylinder(0.045, 0.065, 2.65, MeshKit.at(at + Vector3(side * 1.28, 1.32, -0.03), Vector3(0, 0, yaw)), IRON)
		var rope_end := Vector3(side * 2.55, 0.06, 2.0)
		var rope_delta := rope_end - Vector3(side * 0.76, 1.28, 0)
		var rope_angle := rad_to_deg(atan2(-rope_delta.x, rope_delta.y))
		kit.cylinder(0.018, 0.028, rope_delta.length(), MeshKit.at(at + Vector3(side * 0.76, 1.28, 0) + rope_delta * 0.5, Vector3(0, 0, rope_angle)), p.trim.lightened(0.22))
	# Closed rear end flaps leave a dark, walk-in opening facing the arrival road.
	kit.box(Vector3(1.02, 1.52, 0.08), MeshKit.at(at + Vector3(-0.55, 0.78, -1.29), Vector3(0, yaw, 0)), p.trim.darkened(0.12))
	kit.box(Vector3(1.02, 1.52, 0.08), MeshKit.at(at + Vector3(0.55, 0.78, -1.29), Vector3(0, yaw, 0)), p.trim.darkened(0.12))
	kit.cylinder(0.05, 0.07, 2.9, MeshKit.at(at + Vector3(0, 1.75, 0), Vector3(90, 0, yaw)), IRON)


static func _village(parent: Node3D, biome: int, stage: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	var tower_height := 6.4 if biome == 0 else (7.1 if biome == 1 else 8.0)
	# Bellwether's open timber bell-frame becomes a watch beacon in the snow
	# and a basalt signal stack in the Rift.
	kit.box(Vector3(3.6, 0.55, 3.3), MeshKit.at(Vector3(0, 0.28, -16.2)), p.stone.darkened(0.13))
	kit.box(Vector3(2.45, tower_height, 2.2), MeshKit.at(Vector3(0, tower_height * 0.5 + 0.55, -16.2)), p.stone.darkened(0.12))
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.24, tower_height + 0.4, 0.24), MeshKit.at(Vector3(side * 1.27, tower_height * 0.5 + 0.55, -17.37)), p.trim)
	kit.box(Vector3(3.25, 0.4, 2.9), MeshKit.at(Vector3(0, tower_height + 0.6, -16.2)), p.trim)
	kit.sphere(0.42, MeshKit.at(Vector3(0, tower_height * 0.74, -17.35)), p.warm, 0.8, 8, 5)
	for side: float in [-1.0, 1.0]:
		for i in 2:
			var house_at := Vector2(side * (13.8 + float(i) * 1.4), -2.0 + float(i) * 7.0)
			_house(kit, Vector3(house_at.x, 0, house_at.y), p, side < 0.0)
			_register_blocker(parent, house_at, 1.8)
		_asset(parent, "soul_brazier" if biome == 0 else ("wind_chime" if biome == 1 else "brimstone_vent"), Vector3(side * 9.5, 0, -13.0), 0.0, 1.0)
	var village := _mesh(parent, "BellwetherTower" if biome == 0 else ("RimewatchBeacon" if biome == 1 else "CoalhavenSignalTower"), kit)
	village.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if stage >= 2:
		_asset(parent, "broken_archway" if biome == 0 else ("ice_arch" if biome == 1 else "skull_gateway"), Vector3(0, 0, -11.8), 0.0, 0.82)


static func _house(kit: MeshKit, at: Vector3, p: Dictionary, mirror: bool) -> void:
	var side := -1.0 if mirror else 1.0
	kit.box(Vector3(3.4, 2.5, 2.9), MeshKit.at(at + Vector3(0, 1.25, 0)), p.stone.darkened(0.13))
	kit.box(Vector3(3.9, 0.22, 3.4), MeshKit.at(at + Vector3(0, 2.56, 0), Vector3(0, 0, side * 3)), p.trim)
	kit.box(Vector3(0.7, 1.2, 0.08), MeshKit.at(at + Vector3(0, 0.75, -1.5)), IRON)
	kit.box(Vector3(0.68, 0.52, 0.06), MeshKit.at(at + Vector3(side * 0.9, 1.55, -1.5)), p.warm, 0.8)
	kit.box(Vector3(0.14, 2.35, 0.14), MeshKit.at(at + Vector3(side * 1.55, 1.2, -1.38)), p.trim.lightened(0.12))


static func _monastery(parent: Node3D, biome: int, stage: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	var height := 4.5 if biome == 0 else (5.2 if biome == 1 else 4.2)
	# The guardian approach has an open nave; the doorway and processional line
	# point north toward the route board instead of closing the playable center.
	for side: float in [-1.0, 1.0]:
		var x := side * 5.6
		kit.box(Vector3(1.15, 0.3, 1.25), MeshKit.at(Vector3(x, 0.15, -15.6)), p.stone.darkened(0.18))
		kit.box(Vector3(0.78, height, 0.78), MeshKit.at(Vector3(x, height * 0.5 + 0.3, -15.6)), p.stone)
		kit.box(Vector3(1.28, 0.25, 1.35), MeshKit.at(Vector3(x, height + 0.3, -15.6)), p.trim)
		kit.box(Vector3(4.9, 0.3, 0.8), MeshKit.at(Vector3(side * 2.85, height + 0.2, -15.7), Vector3(0, 0, -side * 9)), p.stone.lightened(0.08))
	for x: float in [-8.8, -7.3, -5.8, 5.8, 7.3, 8.8]:
		var h := 1.4 + float(posmod(roundi(x * 10), 3)) * 0.42
		kit.box(Vector3(1.25, h, 0.55), MeshKit.at(Vector3(x, h * 0.5, -15.3)), p.stone.darkened(0.12))
		kit.box(Vector3(1.38, 0.16, 0.64), MeshKit.at(Vector3(x, h + 0.05, -15.3)), p.trim)
	kit.cylinder(0.12, 0.23, 1.0, MeshKit.at(Vector3(0, 0.5, -14.4)), p.glow, 0.8, 8)
	kit.box(Vector3(0.18, 1.5, 0.2), MeshKit.at(Vector3(0, 1.75, -14.4)), p.trim)
	kit.box(Vector3(1.15, 0.16, 0.18), MeshKit.at(Vector3(0, 2.15, -14.4)), p.trim)
	if stage >= 2:
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0.16, 3.2, 0.16), MeshKit.at(Vector3(side * 7.8, 1.6, -10.5)), p.trim)
			kit.box(Vector3(1.4, 0.14, 0.14), MeshKit.at(Vector3(side * 7.8, 2.7, -10.5)), p.glow)
	var nave := _mesh(parent, "VigilGuardianNave", kit)
	nave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if biome == 0:
		_asset(parent, "mausoleum", Vector3(0, 0, -20.0), 0.0, 0.86)
	elif biome == 1:
		_asset(parent, "ice_arch", Vector3(0, 0, -20.0), 0.0, 0.88)
	else:
		_asset(parent, "skull_gateway", Vector3(0, 0, -20.0), 0.0, 0.86)


static func _refuge(parent: Node3D, biome: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	for side: float in [-1.0, 1.0]:
		var x := side * 6.0
		kit.box(Vector3(1.0, 4.0, 1.2), MeshKit.at(Vector3(x, 2.0, -15.4)), p.stone.darkened(0.1))
		kit.box(Vector3(1.32, 0.32, 1.55), MeshKit.at(Vector3(x, 4.08, -15.4)), p.trim)
		kit.box(Vector3(4.9, 0.65, 1.0), MeshKit.at(Vector3(side * 3.5, 1.0, -15.4)), p.stone)
		kit.box(Vector3(3.5, 0.72, 1.1), MeshKit.at(Vector3(side * 3.0, 1.82, -15.4)), p.trim.darkened(0.1))
	kit.box(Vector3(0.3, 4.2, 0.3), MeshKit.at(Vector3(0, 2.1, -15.0)), IRON)
	kit.box(Vector3(3.4, 0.24, 0.3), MeshKit.at(Vector3(0, 3.7, -15.0)), p.trim)
	kit.box(Vector3(0.86, 1.35, 0.12), MeshKit.at(Vector3(0, 1.25, -15.0)), p.glow, 0.7)
	var gate := _mesh(parent, "WhitepassShelterGate", kit)
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		_tent(kit, Vector3(side * 11.5, 0, -1.0), p, side > 0.0)
		_register_blocker(parent, Vector2(side * 11.5, -1.0), 1.55)
	var awnings := _mesh(parent, "WhitepassSupplyAwnings", kit)
	awnings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "ribcage", Vector3(13.5, 0, -13.5), 20.0, 0.78)


static func _watchtower(parent: Node3D, biome: int, stage: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	kit.box(Vector3(4.0, 0.5, 4.0), MeshKit.at(Vector3(0, 0.25, -16.5)), p.stone.darkened(0.14))
	for side: float in [-1.0, 1.0]:
		var x := side * 1.55
		kit.box(Vector3(0.72, 7.4, 0.75), MeshKit.at(Vector3(x, 3.95, -16.5)), p.stone.darkened(0.1))
		for y: float in [1.0, 2.9, 4.8, 6.7]:
			kit.box(Vector3(0.95, 0.18, 1.0), MeshKit.at(Vector3(x, y, -16.5)), p.trim)
	kit.box(Vector3(4.0, 0.38, 3.8), MeshKit.at(Vector3(0, 7.9, -16.5)), p.trim)
	kit.box(Vector3(2.6, 0.16, 0.2), MeshKit.at(Vector3(0, 6.45, -14.8)), p.warm, 0.55)
	kit.box(Vector3(1.5, 0.24, 0.2), MeshKit.at(Vector3(0, 6.7, -14.8)), p.warm, 0.75)
	for step in 11:
		var x := -2.7 + float(step) * 0.48
		var y := 0.35 + float(step) * 0.43
		kit.box(Vector3(1.15, 0.11, 0.22), MeshKit.at(Vector3(x, y, -14.25)), p.road)
	var tower := _mesh(parent, "RimewatchSignalTower", kit)
	tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "wind_chime", Vector3(5.2, 0, -13.5), 0.0, 0.8)
	if stage >= 2:
		_asset(parent, "sled", Vector3(-8.5, 0, -12.0), 10.0, 0.82)


static func _ice_chapel(parent: Node3D, stage: int) -> void:
	var p := _palette(1)
	var kit := _kit()
	for side: float in [-1.0, 1.0]:
		var x := side * 4.8
		kit.box(Vector3(1.15, 0.28, 1.2), MeshKit.at(Vector3(x, 0.14, -16.0)), p.stone.darkened(0.1))
		kit.box(Vector3(0.82, 4.2, 0.82), MeshKit.at(Vector3(x, 2.38, -16.0)), p.stone)
		kit.box(Vector3(1.35, 0.3, 1.25), MeshKit.at(Vector3(x, 4.62, -16.0)), p.trim)
	kit.box(Vector3(4.5, 0.28, 0.75), MeshKit.at(Vector3(0, 4.4, -16.0)), p.trim.lightened(0.08))
	kit.torus(1.15, 1.45, MeshKit.at(Vector3(0, 2.25, -15.0)), p.glow, 0.22, 16)
	kit.sphere(0.52, MeshKit.at(Vector3(0, 2.1, -14.7), Vector3.ZERO, Vector3(0.8, 1.4, 0.8)), p.glow, 0.9, 8, 5)
	kit.box(Vector3(1.2, 0.2, 0.8), MeshKit.at(Vector3(0, 0.12, -14.4)), p.trim)
	kit.box(Vector3(0.12, 0.95, 0.12), MeshKit.at(Vector3(0, 0.68, -14.7)), p.warm)
	var chapel := _mesh(parent, "ChapelOfTheThawIceNave", kit)
	chapel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "ice_arch", Vector3(0, 0, -20.0), 0.0, 1.0)
	if stage >= 2:
		_asset(parent, "frozen_pond", Vector3(9.0, 0, -11.5), 0.0, 0.85)


static func _forge(parent: Node3D, stage: int) -> void:
	var p := _palette(2)
	var kit := _kit()
	kit.box(Vector3(5.6, 0.42, 3.6), MeshKit.at(Vector3(0, 0.21, -15.2)), IRON)
	kit.box(Vector3(4.4, 3.6, 2.8), MeshKit.at(Vector3(0, 2.1, -15.2)), p.stone.darkened(0.1))
	kit.box(Vector3(2.3, 2.4, 0.3), MeshKit.at(Vector3(0, 2.0, -13.72)), IRON)
	kit.box(Vector3(1.2, 1.5, 0.22), MeshKit.at(Vector3(0, 1.8, -13.5)), p.glow, 1.2)
	kit.box(Vector3(0.8, 2.6, 0.8), MeshKit.at(Vector3(-1.55, 4.7, -15.5)), p.trim.darkened(0.08))
	kit.box(Vector3(0.8, 3.7, 0.8), MeshKit.at(Vector3(1.55, 5.25, -15.5)), p.stone)
	kit.box(Vector3(1.0, 0.22, 1.0), MeshKit.at(Vector3(-1.55, 6.05, -15.5)), p.trim)
	var forge := _mesh(parent, "CinderwakeFurnaceBlock", kit)
	forge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "furnace", Vector3(-6.5, 0, -12.0), -12.0, 0.92)
	_asset(parent, "forge", Vector3(7.5, 0, -13.5), 20.0, 0.85)
	if stage >= 2:
		_asset(parent, "minecart", Vector3(11.5, 0, 3.5), -8.0, 0.8)


static func _siege(parent: Node3D, stage: int) -> void:
	var p := _palette(2)
	var kit := _kit()
	for side: float in [-1.0, 1.0]:
		var x := side * 5.0
		kit.box(Vector3(2.4, 0.45, 2.0), MeshKit.at(Vector3(x, 0.22, -16.0)), IRON)
		kit.box(Vector3(1.7, 5.6, 1.8), MeshKit.at(Vector3(x, 3.25, -16.0)), p.stone.darkened(0.12))
		kit.box(Vector3(2.2, 0.34, 2.3), MeshKit.at(Vector3(x, 6.1, -16.0)), p.trim)
		kit.box(Vector3(3.9, 0.42, 1.6), MeshKit.at(Vector3(side * 3.0, 4.6, -16.0), Vector3(0, 0, -side * 8)), p.stone)
	kit.box(Vector3(1.2, 5.0, 0.32), MeshKit.at(Vector3(0, 2.5, -15.4)), IRON)
	for i in 5:
		var x := -1.8 + float(i) * 0.9
		kit.box(Vector3(0.62, 5.2, 0.18), MeshKit.at(Vector3(x, 2.6, -14.9)), p.trim.darkened(0.1))
	kit.box(Vector3(3.1, 0.35, 1.25), MeshKit.at(Vector3(0, 7.1, -16.0)), p.trim)
	var gate := _mesh(parent, "GateOfEmbersSiegehouse", kit)
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "skull_gateway", Vector3(0, 0, -20.0), 0.0, 0.9)
	_asset(parent, "siege_barricade", Vector3(-9.5, 0, 2.0), 0.0, 0.86)
	if stage >= 2:
		_asset(parent, "scorched_banner", Vector3(9.2, 0, 1.0), 0.0, 0.9)


static func _dawn(parent: Node3D) -> void:
	var kit := _kit()
	var stone := Color(0.58, 0.51, 0.35)
	var gold := Color(1.0, 0.7, 0.25)
	for side: float in [-1.0, 1.0]:
		var x := side * 5.0
		kit.box(Vector3(1.15, 4.1, 1.05), MeshKit.at(Vector3(x, 2.05, -15.5)), stone)
		kit.box(Vector3(1.55, 0.34, 1.45), MeshKit.at(Vector3(x, 4.2, -15.5)), gold)
		kit.box(Vector3(4.0, 0.28, 0.9), MeshKit.at(Vector3(side * 3.0, 4.1, -15.5), Vector3(0, 0, -side * 8)), stone.lightened(0.1))
	kit.sphere(0.58, MeshKit.at(Vector3(0, 3.65, -15.0)), gold, 0.55, 10, 6)
	var arch := _mesh(parent, "DawnsRestSunriseArch", kit)
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		var house_at := Vector2(side * 13.0, -1.0)
		_house(kit, Vector3(house_at.x, 0, house_at.y), {"stone": Color(0.45, 0.4, 0.32), "trim": stone, "warm": gold}, side < 0.0)
		_register_blocker(parent, house_at, 1.8)
	var cabins := _mesh(parent, "DawnsRestGuestHouses", kit)
	cabins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 7:
		var x := -8.0 + float(i) * 2.6
		kit.sphere(0.28, MeshKit.at(Vector3(x, 0.3, 12.0 + float(i % 2) * 1.2), Vector3.ZERO, Vector3(1.3, 0.6, 1.1)), Color(0.3, 0.53, 0.34), 0, 7, 4)
	var gardens := _mesh(parent, "DawnsRestGardens", kit)
	gardens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset(parent, "lantern_post", Vector3(-7.2, 0, -12.0), 0.0, 0.85)
	_asset(parent, "lantern_post", Vector3(7.2, 0, -12.0), 0.0, 0.85)


static func _arrival_markers(parent: Node3D, biome: int, kind: String) -> void:
	var p := _palette(biome)
	var kit := _kit()
	for side: float in [-1.0, 1.0]:
		var x := side * 4.3
		kit.box(Vector3(0.38, 1.75, 0.38), MeshKit.at(Vector3(x, 0.88, 14.3)), p.stone.darkened(0.12))
		kit.box(Vector3(0.64, 0.2, 0.64), MeshKit.at(Vector3(x, 1.82, 14.3)), p.trim)
		kit.sphere(0.12, MeshKit.at(Vector3(x, 2.0, 14.3)), p.glow, 0.65, 6, 4)
	for side: float in [-1.0, 1.0]:
		var x := side * 4.3
		kit.box(Vector3(0.38, 1.8, 0.38), MeshKit.at(Vector3(x, 0.9, -10.7)), p.stone.darkened(0.12))
		kit.box(Vector3(0.7, 0.22, 0.48), MeshKit.at(Vector3(x, 1.92, -10.7)), p.trim)
		if kind == "monastery" or kind == "ice_chapel" or kind == "siege":
			kit.box(Vector3(0.09, 0.86, 0.07), MeshKit.at(Vector3(x, 2.43, -10.7)), p.glow, 0.35)
	var roadposts := _mesh(parent, "ArrivalAndDepartureRoadMarkers", kit)
	roadposts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _nameboard(parent: Node3D, _place_name: String, biome: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	kit.box(Vector3(3.9, 1.25, 0.24), MeshKit.at(Vector3(-7.8, 2.5, -10.4)), p.stone.darkened(0.16))
	kit.box(Vector3(3.65, 0.14, 0.08), MeshKit.at(Vector3(-7.8, 3.12, -10.24)), p.trim)
	for x: float in [-1.72, 1.72]:
		kit.box(Vector3(0.12, 2.65, 0.14), MeshKit.at(Vector3(-7.8 + x, 1.58, -10.3)), p.trim.darkened(0.1))
	var board := _mesh(parent, "WaystopNameboard", kit)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _local_honor(parent: Node3D, biome: int, stage: int) -> void:
	var p := _palette(biome)
	var kit := _kit()
	var x := -6.3 if stage % 2 == 1 else 6.3
	var z := 4.3 if stage % 2 == 1 else 1.3
	kit.box(Vector3(1.35, 0.16, 1.0), MeshKit.at(Vector3(x, 0.08, z)), p.stone.darkened(0.1))
	kit.box(Vector3(0.94, 0.66, 0.68), MeshKit.at(Vector3(x, 0.48, z)), p.trim)
	kit.box(Vector3(1.1, 0.12, 0.84), MeshKit.at(Vector3(x, 0.87, z)), p.warm)
	kit.sphere(0.18, MeshKit.at(Vector3(x, 1.15, z)), p.glow, 0.55, 7, 4)
	var honor := _mesh(parent, "LocalRoadHonor", kit)
	honor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_register_blocker(parent, Vector2(x, z), 0.78)


static func _asset(parent: Node3D, kind: String, at: Vector3, yaw: float, size: float) -> void:
	var mesh := AssetProps.mesh(kind)
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = "WaystopProp_" + kind
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees.y = yaw
	instance.scale = Vector3.ONE * size
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface) as ShaderMaterial
		var glowing := source != null and float(source.get_shader_parameter("flat_glow")) > 0.0
		instance.set_surface_override_material(surface, AssetProps.emissive_material() if glowing else AssetProps.opaque_material())
	parent.add_child(instance)


static func _mesh(parent: Node3D, node_name: String, kit: MeshKit) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = kit.commit(Models.material("kit"))
	parent.add_child(instance)
	return instance


static func _register_blocker(parent: Node3D, at: Vector2, radius: float) -> void:
	var blockers: Array = parent.get_meta("walk_blockers", [])
	blockers.append([at, radius])
	parent.set_meta("walk_blockers", blockers)


static func _kit() -> MeshKit:
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 24
	return kit
