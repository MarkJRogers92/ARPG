class_name GraveyardExpeditionScenery
extends RefCounted
## Authored, non-colliding landmarks for the first Graveyard branch. Objective
## sites remain owned by ExpeditionDirector; this class only frames them.

const STONE := Color(0.3, 0.34, 0.4)
const ASH_STONE := Color(0.24, 0.25, 0.27)
const BRASS := Color(0.61, 0.43, 0.24)
const SOUL := Color(0.34, 0.86, 1.0)
const MOSS := Color(0.17, 0.25, 0.16)


static func build(parent: Node3D, mission: Dictionary, sites: Array[Vector2], occupied_props: Dictionary = {}) -> void:
	var node_id := str(mission.get("node_id", ""))
	if int(mission.get("biome_index", 0)) != 0 or not node_id.begins_with("0:1:") or bool(mission.get("final_boss", false)):
		return
	_build_entry_gate(parent)
	_build_processional_causeway(parent, sites)
	_build_objective_clearings(parent, sites)
	var chapel_at := select_chapel_site(int(mission.get("mission_seed", 1)), sites, occupied_props)
	if chapel_at != Vector2.INF:
		_build_ruined_chapel(parent, chapel_at)


## Selects a stable secondary landmark far enough from the hero and all
## interaction sites to keep open approach space around gameplay targets.
static func select_chapel_site(mission_seed: int, sites: Array[Vector2], occupied_props: Dictionary = {}) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed
	var phase := rng.randf_range(0.0, TAU)
	var base_radius := rng.randf_range(18.0, 22.0)
	for attempt in 48:
		var angle := phase + float(attempt) * 2.39996323
		var radius := base_radius + float(attempt % 4) * 1.35
		var candidate := Vector2(cos(angle), sin(angle)) * radius
		if _chapel_clear(candidate, sites, occupied_props):
			return candidate
	return Vector2.INF


static func _chapel_clear(candidate: Vector2, sites: Array[Vector2], occupied_props: Dictionary) -> bool:
	if candidate.length() < 16.0 or Obstacles.blocked(candidate, 4.2):
		return false
	for site: Vector2 in sites:
		if candidate.distance_to(site) < 9.0:
			return false
	if _near_tall_prop(candidate, occupied_props, 4.5):
		return false
	return true


static func _build_entry_gate(parent: Node3D) -> void:
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 20
	# Layered piers, a split lintel and an asymmetric broken wing frame the
	# arrival lane without closing it or growing into enemy-warning silhouettes.
	for side: float in [-1.0, 1.0]:
		var x := side * 4.55
		var z := -3.9
		var shade := 0.07 if side < 0.0 else 0.0
		kit.box(Vector3(1.12, 0.18, 1.25), MeshKit.at(Vector3(x, 0.09, z)), ASH_STONE.lightened(shade))
		kit.box(Vector3(0.94, 0.18, 1.08), MeshKit.at(Vector3(x, 0.27, z)), STONE.darkened(0.17))
		kit.box(Vector3(0.7, 0.22, 0.83), MeshKit.at(Vector3(x, 0.47, z)), STONE.darkened(0.04))
		kit.box(Vector3(0.61, 1.72, 0.72), MeshKit.at(Vector3(x, 1.42, z)), STONE.darkened(0.06 + shade))
		for edge: float in [-1.0, 1.0]:
			kit.box(Vector3(0.08, 1.68, 0.08), MeshKit.at(Vector3(x + edge * 0.3, 1.42, z - 0.38)), STONE.lightened(0.12))
		kit.box(Vector3(0.76, 0.13, 0.88), MeshKit.at(Vector3(x, 2.32, z)), STONE.darkened(0.02))
		kit.box(Vector3(1.0, 0.18, 1.12), MeshKit.at(Vector3(x, 2.49, z)), ASH_STONE.lightened(0.1))
		kit.box(Vector3(1.12, 0.16, 1.24), MeshKit.at(Vector3(x, 2.66, z)), STONE.lightened(0.12))
		kit.box(Vector3(0.07, 0.66, 0.035), MeshKit.at(Vector3(x, 1.36, z - 0.383), Vector3(0, 0, side * 5)), SOUL.darkened(0.1), 0.28)
		kit.box(Vector3(0.22, 0.055, 0.04), MeshKit.at(Vector3(x, 1.42, z - 0.39), Vector3(0, 0, 35)), BRASS, 0.05)
		var wall_x := side * 6.0
		if side < 0.0:
			kit.box(Vector3(2.18, 0.68, 0.78), MeshKit.at(Vector3(wall_x, 0.5, z + 0.25), Vector3(0, 0, 2)), STONE.darkened(0.16))
			kit.box(Vector3(2.25, 0.15, 0.84), MeshKit.at(Vector3(wall_x, 0.91, z + 0.25), Vector3(0, 0, 2)), STONE.lightened(0.06))
		else:
			kit.box(Vector3(1.15, 0.48, 0.76), MeshKit.at(Vector3(wall_x - 0.48, 0.39, z + 0.25), Vector3(0, 0, -4)), ASH_STONE)
			kit.box(Vector3(1.28, 0.63, 0.75), MeshKit.at(Vector3(wall_x + 0.45, 0.43, z + 0.27), Vector3(0, 0, 7)), STONE.darkened(0.15))
			kit.box(Vector3(0.8, 0.2, 0.8), MeshKit.at(Vector3(wall_x + 1.0, 0.13, z + 1.05), Vector3(0, 12, 7)), STONE.darkened(0.12))
			kit.sphere(0.32, MeshKit.at(Vector3(wall_x - 0.6, 0.79, z + 0.12), Vector3(0, 0, -18), Vector3(1.5, 0.18, 0.8)), MOSS, 0, 6, 3)
		var lantern_color := Color(1.0, 0.61, 0.3) if side < 0.0 else SOUL
		var arm := side * 0.42
		kit.box(Vector3(0.12, 0.1, 0.58), MeshKit.at(Vector3(x + arm, 3.03, z)), BRASS.lightened(0.08))
		kit.box(Vector3(0.42, 0.09, 0.09), MeshKit.at(Vector3(x + side * 0.61, 3.03, z)), BRASS)
		kit.box(Vector3(0.3, 0.5, 0.3), MeshKit.at(Vector3(x + side * 0.66, 2.73, z)), ASH_STONE)
		kit.box(Vector3(0.21, 0.31, 0.21), MeshKit.at(Vector3(x + side * 0.66, 2.74, z)), lantern_color, 0.65)
		kit.sphere(0.11, MeshKit.at(Vector3(x + side * 0.66, 3.04, z)), lantern_color, 0.42, 6, 4)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(2.25, 0.22, 0.82), MeshKit.at(Vector3(side * 3.12, 2.88, -3.9), Vector3(0, 0, side * -2)), STONE.lightened(0.05))
		kit.box(Vector3(1.92, 0.13, 0.88), MeshKit.at(Vector3(side * 3.02, 3.045, -3.9), Vector3(0, 0, side * -2)), ASH_STONE.lightened(0.15))
	var instance := _place_mesh(parent, "GraveyardArrivalGate", kit)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _build_processional_causeway(parent: Node3D, sites: Array[Vector2]) -> void:
	var kit := MeshKit.new()
	kit.flat = true
	for row in 8:
		var z := -0.5 - float(row) * 0.86
		for col in 3:
			var x := float(col - 1) * 0.92 + (0.16 if row % 2 == 0 else -0.16) + float((row + col * 3) % 3 - 1) * 0.035
			var stone_at := Vector2(x, z)
			var objective_clear := true
			for site: Vector2 in sites:
				if stone_at.distance_to(site) < 3.6:
					objective_clear = false
					break
			if not objective_clear:
				continue
			var width := 0.78 + float((row + col) % 3) * 0.035
			var depth := 0.7 + float((row * 2 + col) % 3) * 0.035
			var shade := float((row + col * 2) % 4) * 0.045
			kit.box(Vector3(width, 0.1, depth), MeshKit.at(Vector3(x, 0.045, z), Vector3(0, float((row + col) % 3 - 1) * 3.0, 0)), STONE.darkened(0.05 + shade))
		if row in [1, 4, 6]:
			var side := -1.0 if row % 2 == 0 else 1.0
			var moss_at := Vector3(side * 1.5, 0.06, z)
			var moss_clear := true
			for site: Vector2 in sites:
				if Vector2(moss_at.x, moss_at.z).distance_to(site) < 3.6:
					moss_clear = false
					break
			if moss_clear:
				kit.sphere(0.18, MeshKit.at(moss_at, Vector3.ZERO, Vector3(1.7, 0.16, 0.7)), MOSS.darkened(0.04), 0, 6, 3)
	_place_mesh(parent, "GraveyardProcessionalCauseway", kit)


static func _build_objective_clearings(parent: Node3D, sites: Array[Vector2]) -> void:
	for site_index in sites.size():
		var center := sites[site_index]
		var kit := MeshKit.new()
		kit.flat = true
		# Broken flagstones make a wide, low memorial court around the existing
		# objective. The inner 3.4 m remain entirely open for its ring and player.
		for i in 16:
			if i % 4 == 0:
				continue
			var angle := TAU * float(i) / 16.0 + (0.07 if site_index % 2 == 0 else -0.05)
			var radius := 4.15 + float((i + site_index) % 3) * 0.18
			var point := center + Vector2(cos(angle), sin(angle)) * radius
			if Obstacles.blocked(point, 0.65):
				continue
			var separated := true
			for other_index in sites.size():
				if other_index != site_index and point.distance_to(sites[other_index]) < 2.1:
					separated = false
					break
			if not separated:
				continue
			var at := Vector3(point.x - center.x, 0.06, point.y - center.y)
			var shade := float((i + site_index) % 4) * 0.035
			kit.box(Vector3(0.8, 0.12, 0.68), MeshKit.at(at, Vector3(0, rad_to_deg(angle) + 90, 0)), STONE.darkened(0.09 + shade))
		# Four low, broken markers lie outside the pathing radius and never rise
		# above the hero's waist; there is no collision or gameplay effect.
		for i in 4:
			var angle := TAU * float(i) / 4.0 + PI / 4.0
			var point := center + Vector2(cos(angle), sin(angle)) * 4.8
			if Obstacles.blocked(point, 0.7):
				continue
			var height := [0.7, 0.95, 0.58, 0.82][i] as float
			var local_at := Vector3(cos(angle) * 4.8, height * 0.5, sin(angle) * 4.8)
			kit.box(Vector3(0.4, height, 0.34), MeshKit.at(local_at, Vector3(0, rad_to_deg(angle), float(i - 2) * 3)), STONE.darkened(float(i) * 0.035))
			kit.box(Vector3(0.46, 0.09, 0.39), MeshKit.at(local_at + Vector3(0, height * 0.5, 0), Vector3(0, rad_to_deg(angle), float(i - 2) * 3)), BRASS.darkened(0.1))
		var clearing := _place_mesh(parent, "MemorialClearing_%d" % (site_index + 1), kit)
		clearing.position = Vector3(center.x, 0, center.y)


static func _build_ruined_chapel(parent: Node3D, center: Vector2) -> void:
	var pocket := Node3D.new()
	pocket.name = "ProcessionalChapel"
	pocket.position = Vector3(center.x, 0, center.y)
	parent.add_child(pocket)
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 16
	# A shallow, irregular forecourt leads into a roofless chapel. Its center
	# stays open; the walls are low enough to preserve horde and warning reads.
	for row in 3:
		for col in 5:
			var x := (float(col) - 2.0) * 0.86 + (0.16 if row % 2 == 0 else -0.12)
			var z := 2.25 + float(row) * 0.76
			var shade := float((row * 3 + col) % 4) * 0.04
			kit.box(Vector3(0.77, 0.1, 0.68), MeshKit.at(Vector3(x, 0.045, z), Vector3(0, float((row + col) % 3 - 1) * 4.0, 0)), STONE.darkened(0.08 + shade))
	# Broken rear apse with two differently weathered piers and a split cap.
	for side: float in [-1.0, 1.0]:
		var x := side * 2.65
		var h := 2.0 if side < 0.0 else 1.55
		kit.box(Vector3(0.88, 0.2, 0.94), MeshKit.at(Vector3(x, 0.1, -1.15)), ASH_STONE)
		kit.box(Vector3(0.62, h, 0.66), MeshKit.at(Vector3(x, 0.2 + h * 0.5, -1.15)), STONE.darkened(0.06 + (0.04 if side > 0 else 0.0)))
		kit.box(Vector3(0.93, 0.17, 0.88), MeshKit.at(Vector3(x, h + 0.31, -1.15)), STONE.lightened(0.08))
		kit.box(Vector3(1.6, 0.15, 0.72), MeshKit.at(Vector3(side * 1.75, 2.22 if side < 0 else 1.78, -1.15), Vector3(0, 0, side * -8)), STONE.darkened(0.06))
	# A small copper-edged memorial niche is set behind the open court.
	kit.box(Vector3(1.6, 0.16, 0.95), MeshKit.at(Vector3(0, 0.12, -0.38)), ASH_STONE)
	kit.box(Vector3(0.09, 0.5, 0.09), MeshKit.at(Vector3(0, 0.48, -0.55)), BRASS)
	kit.box(Vector3(0.48, 0.08, 0.09), MeshKit.at(Vector3(0, 0.48, -0.55)), BRASS)
	kit.sphere(0.15, MeshKit.at(Vector3(0, 0.78, -0.55)), SOUL, 0.45, 6, 4)
	# A short broken wing and creeping moss lend asymmetry without a solid wall.
	kit.box(Vector3(1.3, 0.42, 0.35), MeshKit.at(Vector3(-3.55, 0.24, -0.45), Vector3(0, 0, -3)), STONE.darkened(0.16))
	kit.box(Vector3(0.84, 0.21, 0.51), MeshKit.at(Vector3(3.35, 0.12, 0.0), Vector3(0, 12, 4)), ASH_STONE)
	kit.sphere(0.28, MeshKit.at(Vector3(-3.5, 0.45, -0.4), Vector3.ZERO, Vector3(1.5, 0.18, 0.9)), MOSS, 0, 6, 3)
	var instance := _place_mesh(pocket, "RooflessChapel", kit)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var memorial_mesh := AssetProps.mesh("rune_gravestone")
	if memorial_mesh != null:
		var memorial := MeshInstance3D.new()
		memorial.name = "ChapelMemorial"
		memorial.mesh = memorial_mesh
		memorial.scale = Vector3.ONE * 0.72
		memorial.position = Vector3(0, 0, -0.62)
		pocket.add_child(memorial)


static func _place_mesh(parent: Node3D, node_name: String, kit: MeshKit) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = kit.commit(Models.material("kit"))
	parent.add_child(instance)
	return instance


static func _near_tall_prop(point: Vector2, props: Dictionary, clearance: float) -> bool:
	for kind: String in props:
		if kind == "grass" or kind == "mushroom":
			continue
		var footprint := float(AssetProps.data(kind).get("footprint", 0.8)) if AssetProps.has(kind) else 0.8
		var margin := clearance + footprint if AssetProps.has(kind) else clearance
		for transform: Transform3D in props[kind]:
			var at := Vector2(transform.origin.x, transform.origin.z)
			if point.distance_to(at) < margin:
				return true
	return false
