class_name ObjectiveProps
extends RefCounted
## Cosmetic companions to the campaign's existing rings, beams and labels.
## One cached surface per kind; no animation, collision, lights or game state.

const STONE := Color(0.3, 0.34, 0.4)
const IRON := Color(0.14, 0.18, 0.24)
const BRASS := Color(0.61, 0.43, 0.24)
static var _meshes: Dictionary = {}


## Append after the existing label: ExpeditionDirector retains child index 2.
static func attach(holder: Node3D, site_id: String, color: Color) -> MeshInstance3D:
	var kind := "seal" if site_id.begins_with("seal_") else site_id
	if kind not in ["seal", "cache", "elite", "lantern_recovery"]:
		return null
	var key := kind + ":" + color.to_html()
	if not _meshes.has(key):
		var kit := MeshKit.new()
		kit.flat = true
		kit.max_segments = 12
		match kind:
			"seal": _seal(kit, color)
			"cache": _cache(kit, color)
			"elite": _elite(kit, color)
			"lantern_recovery": _lantern(kit, color)
		_meshes[key] = kit.commit(Models.material("kit"))
	var prop := MeshInstance3D.new()
	prop.name = "ObjectiveProp"
	prop.mesh = _meshes[key] as ArrayMesh
	# The floating mark should not cast an unexplained shadow over its target.
	if kind == "elite":
		prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(prop)
	return prop


static func _seal(kit: MeshKit, soul: Color) -> void:
	kit.cylinder(0.91, 0.98, 0.13, MeshKit.at(Vector3(0, 0.08, 0)), STONE.darkened(0.2), 0, 8)
	kit.cylinder(0.68, 0.76, 0.12, MeshKit.at(Vector3(0, 0.2, 0)), STONE, 0, 8)
	kit.torus(0.46, 0.49, MeshKit.at(Vector3(0, 0.27, 0)), BRASS, 0, 12)
	# Three separate broken uprights echo the three seals without closing the
	# central silhouette. Their inner rune cuts remain visible from above.
	for i in 3:
		var angle := TAU * float(i) / 3.0
		var at := Vector3(sin(angle) * 0.64, 0, cos(angle) * 0.64)
		var yaw := rad_to_deg(angle)
		var height := [0.82, 1.04, 0.7][i] as float
		kit.box(Vector3(0.34, height, 0.29), MeshKit.at(at + Vector3(0, 0.24 + height * 0.5, 0), Vector3(0, yaw, 0)), STONE.lightened(float(i) * 0.035))
		kit.box(Vector3(0.38, 0.12, 0.33), MeshKit.at(at + Vector3(0, 0.26 + height, 0), Vector3(0, yaw, 8 - i * 7)), STONE.darkened(0.07))
		kit.box(Vector3(0.39, 0.07, 0.34), MeshKit.at(at + Vector3(0, 0.45, 0), Vector3(0, yaw, 0)), BRASS)
		var rune_at := at * 0.78 + Vector3(0, 0.43 + height * 0.36, 0)
		kit.box(Vector3(0.055, height * 0.44, 0.028), MeshKit.at(rune_at, Vector3(0, yaw, 0)), soul, 0.75)
		kit.box(Vector3(0.19, 0.055, 0.029), MeshKit.at(rune_at, Vector3(0, yaw, 0)), soul, 0.75)
	# A contained soul over the central socket, well below the navigation label.
	kit.cylinder(0.2, 0.29, 0.18, MeshKit.at(Vector3(0, 0.35, 0)), IRON, 0, 8)
	kit.sphere(0.18, MeshKit.at(Vector3(0, 0.67, 0), Vector3.ZERO, Vector3(0.75, 1.6, 0.75)), soul, 0.85, 8, 4)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + PI / 3.0
		kit.box(Vector3(0.055, 0.025, 0.3), MeshKit.at(Vector3(sin(angle) * 0.6, 0.27, cos(angle) * 0.6), Vector3(0, rad_to_deg(angle), 0)), soul.darkened(0.2), 0.5)


static func _cache(kit: MeshKit, soul: Color) -> void:
	kit.box(Vector3(1.6, 0.12, 1.0), MeshKit.at(Vector3(0, 0.09, 0)), STONE.darkened(0.12))
	kit.box(Vector3(1.4, 0.48, 0.8), MeshKit.at(Vector3(0, 0.39, 0)), IRON.lightened(0.12))
	# A faceted barrel lid makes the coffer read as treasure even at combat zoom.
	kit.cylinder(0.4, 0.4, 1.41, MeshKit.at(Vector3(0, 0.61, 0), Vector3(0, 0, 90)), IRON.lightened(0.2), 0, 8)
	for x in [-0.49, 0.49]:
		kit.box(Vector3(0.105, 0.5, 0.86), MeshKit.at(Vector3(x, 0.4, 0)), BRASS)
		kit.torus(0.395, 0.435, MeshKit.at(Vector3(x, 0.61, 0), Vector3(0, 0, 90)), BRASS, 0, 12)
	for z in [-0.415, 0.415]:
		kit.box(Vector3(1.4, 0.065, 0.05), MeshKit.at(Vector3(0, 0.63, z)), soul, 0.75)
		kit.box(Vector3(1.43, 0.075, 0.07), MeshKit.at(Vector3(0, 0.19, z)), BRASS.darkened(0.15))
		kit.box(Vector3(0.23, 0.31, 0.075), MeshKit.at(Vector3(0, 0.56, z * 1.08)), BRASS.lightened(0.12))
		kit.box(Vector3(0.09, 0.14, 0.08), MeshKit.at(Vector3(0, 0.57, z * 1.18), Vector3(0, 0, 45)), soul, 0.85)
	# Small trapped soul visible on the lid, connected to the retained beam.
	kit.sphere(0.115, MeshKit.at(Vector3(0, 1.08, 0), Vector3.ZERO, Vector3(0.8, 1.6, 0.8)), soul, 0.85, 8, 4)


static func _elite(kit: MeshKit, ember: Color) -> void:
	# The holder tracks a living enemy: a suspended coronet avoids creating a
	# moving ground monument or masking the enemy's feet and attack telegraphs.
	kit.torus(0.39, 0.45, MeshKit.at(Vector3(0, 2.42, 0)), BRASS.lightened(0.18), 0.15, 12)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI / 4.0
		var at := Vector3(sin(angle) * 0.42, 2.57, cos(angle) * 0.42)
		kit.cylinder(0, 0.115, 0.33, MeshKit.at(at), BRASS.lightened(0.25), 0.12, 4)
		kit.sphere(0.065, MeshKit.at(at + Vector3(0, 0.2, 0)), ember, 0.8, 6, 3)
	for z in [-0.44, 0.44]:
		kit.box(Vector3(0.15, 0.19, 0.055), MeshKit.at(Vector3(0, 2.42, z), Vector3(0, 0, 45)), ember, 0.85)


static func _lantern(kit: MeshKit, soul: Color) -> void:
	# A small brass field lamp, visibly different from campaign seals and caches.
	kit.box(Vector3(0.56, 0.1, 0.48), MeshKit.at(Vector3(0, 0.1, 0)), BRASS)
	kit.box(Vector3(0.38, 0.62, 0.32), MeshKit.at(Vector3(0, 0.48, 0)), Color(0.14, 0.22, 0.27))
	for x in [-0.2, 0.2]:
		for z in [-0.16, 0.16]:
			kit.box(Vector3(0.045, 0.62, 0.045), MeshKit.at(Vector3(x, 0.48, z)), BRASS.lightened(0.18))
	kit.box(Vector3(0.5, 0.08, 0.44), MeshKit.at(Vector3(0, 0.83, 0)), BRASS)
	kit.torus(0.19, 0.24, MeshKit.at(Vector3(0, 1.06, 0), Vector3(90, 0, 0)), BRASS.lightened(0.24), 0.0, 10)
	kit.sphere(0.14, MeshKit.at(Vector3(0, 0.49, 0), Vector3.ZERO, Vector3(0.75, 1.5, 0.75)), soul, 1.1, 8, 5)
