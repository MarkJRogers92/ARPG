extends Node3D
## Presentation-only adapter for the five supplied common-rig hero GLBs.
## All motion is driven by HeroModel's delta/velocity/cast envelope. No animation
## changes gameplay timing, collisions, projectile origin, class stats or saves.
const BODY := preload("res://assets/heroes/aegis/battlemage_rigged.glb")
const STAFF := preload("res://assets/heroes/aegis/astrolabe_staff.glb")
const ROSTER := {
	"necromancer": [preload("res://assets/heroes/roster/necromancer/necromancer_rigged.glb"), preload("res://assets/heroes/roster/necromancer/necromancer_weapon.glb")],
	"pyromancer": [preload("res://assets/heroes/roster/pyromancer/pyromancer_rigged.glb"), preload("res://assets/heroes/roster/pyromancer/pyromancer_weapon.glb")],
	"stormcaller": [preload("res://assets/heroes/roster/stormcaller/stormcaller_rigged.glb"), preload("res://assets/heroes/roster/stormcaller/stormcaller_weapon.glb")],
	"reaper": [preload("res://assets/heroes/roster/reaper/reaper_rigged.glb"), preload("res://assets/heroes/roster/reaper/reaper_weapon.glb")],
}
const GRIP := Vector3(0.642, 1.2, -0.379)
static var _mesh_cache := {}

var _model: Node3D
var _skeleton: Skeleton3D
var _socket: Node3D
var _socket_rest: Transform3D
var _skeleton_frame := Transform3D.IDENTITY
var _bones := {}
var _rest: Array[Transform3D] = []
var _global_rest: Array[Transform3D] = []
var _bone_bounds := {}
var _cape_angle := -0.035
var _cape_roll := 0.0
var _built := false
var class_id := "battlemage"
var _weapon_scene: PackedScene = STAFF
var _emission := Color(0.18, 0.55, 0.85)
var _native_weapon: ArrayMesh
var _native_accent := Color.TRANSPARENT

func build(id := "battlemage") -> void:
	if _built:
		return
	_built = true
	class_id = id
	var body_scene: PackedScene = BODY
	if ROSTER.has(id):
		body_scene = ROSTER[id][0]
		_weapon_scene = ROSTER[id][1]
		_emission = HeroClass.data(id)["look"]["eye"] * 0.75
	_model = body_scene.instantiate()
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for player: AnimationPlayer in _model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
		player.active = false # never race procedural poses against imported clips
	for b in _skeleton.get_bone_count():
		_bones[_skeleton.get_bone_name(b)] = b
		_rest.append(_skeleton.get_bone_rest(b))
		_global_rest.append(_skeleton.get_bone_global_rest(b))
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Astrolabe_Staff" or str(mesh.name).ends_with("_Weapon"):
			mesh.visible = false # equipped staff/weapon is shown through the socket
			continue
		_record_bounds(mesh)
		mesh.mesh = _compatibility_mesh(mesh.mesh)
		mesh.custom_aabb = mesh.mesh.get_aabb().grow(0.6)
		for s in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(s, _material(mesh.mesh.surface_get_material(s), _emission))
	add_child(_model)
	# Include the imported ancestor transforms, not only Skeleton3D's parent-
	# local transform. This also works while build() is still outside the tree.
	var ancestor: Node = _skeleton
	while ancestor != self:
		if ancestor is Node3D:
			_skeleton_frame = (ancestor as Node3D).transform * _skeleton_frame
		ancestor = ancestor.get_parent()
	_socket = Node3D.new()
	_socket.name = "RightHandSocket"
	add_child(_socket)
	_socket_rest = _global_rest[_bones["hand.R"]].affine_inverse() * Transform3D(Basis.IDENTITY, GRIP)
	reset_pose()

## In the Compatibility renderer vertex colors are supplied in display space,
## unlike glTF's linear COLOR_0. Adapt a cached mesh copy, not the source GLBs.
static func _compatibility_mesh(source: Mesh) -> ArrayMesh:
	if _mesh_cache.has(source):
		return _mesh_cache[source]
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colors.size():
			colors[i] = colors[i].linear_to_srgb()
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(s, source.surface_get_material(s))
	_mesh_cache[source] = mesh
	return mesh

static func _material(source: Material, emission := Color(0.18, 0.55, 0.85)) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	if material.emission_enabled:
		# Godot's separate emission color isn't multiplied by COLOR_0. Preserve
		# the authored cyan rather than turning arcane inlays featureless white.
		material.emission = emission
		material.emission_energy_multiplier = 0.7
	return material

func staff_mesh(accent: Color) -> ArrayMesh:
	return native_weapon_mesh(accent)

func native_weapon_base() -> String:
	return HeroClass.data(class_id)["weapon"]

func native_weapon_mesh(accent: Color) -> ArrayMesh:
	# Town re-presents equipment regularly. Reuse the last per-instance mesh;
	# keep this cache bounded rather than retaining every loot accent forever.
	if _native_weapon != null and _native_accent == accent:
		return _native_weapon
	var instance := _weapon_scene.instantiate()
	var source: Mesh = instance.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var mesh := _compatibility_mesh(source).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var material := _material(mesh.surface_get_material(s), _emission)
		if material.emission_enabled:
			material.albedo_color = accent
			material.emission = accent * 0.65
		mesh.surface_set_material(s, material)
	instance.free()
	_native_weapon = mesh
	_native_accent = accent
	return mesh

func hand_mount() -> Node3D:
	return _socket

static func weapon_grip(base: String) -> Vector3:
	match base:
		"Orb": return Vector3(0, -0.25, 0)
		"Scythe", "Staff": return Vector3.ZERO
		_: return Vector3(0, -0.22, 0)

func _rotate(name: String, euler: Vector3) -> void:
	var bone: int = _bones[name]
	var global_basis := _global_rest[bone].basis.orthonormalized()
	var delta := global_basis.inverse() * Basis.from_euler(euler) * global_basis
	_skeleton.set_bone_pose_rotation(bone, (_rest[bone].basis * delta).get_rotation_quaternion())

func animate(delta: float, local: Vector2, speed: float, walk: float, cast: float, clock: float) -> void:
	if not _built:
		return
	var move := clampf(speed / 6.0, 0.0, 1.0)
	var forward := clampf(local.x / 6.0, -1.0, 1.0)
	var side := clampf(local.y / 6.0, -1.0, 1.0)
	var swing := sin(walk)
	var breathe := sin(clock * 1.6) * 0.014 * (1.0 - move)
	_rotate("chest", Vector3(-0.10 * forward * move - cast * 0.035 + breathe, 0, -0.065 * side * move + swing * 0.018 * move))
	_rotate("head", Vector3(-breathe * 0.4, sin(clock * 0.6) * 0.025 * (1.0 - move), 0))
	_rotate("upper_arm.L", Vector3(-swing * 0.22 * move - cast * 0.55, 0, -side * 0.025 * move))
	_rotate("forearm.L", Vector3(-cast * 0.2, 0, 0))
	_rotate("hand.L", Vector3(cast * 0.18, 0, 0))
	_rotate("upper_arm.R", Vector3(swing * 0.06 * move - cast * 0.14, 0, 0))
	_rotate("forearm.R", Vector3(-cast * 0.10, 0, 0))
	if class_id == "reaper":
		# ReapingScythe already calls HeroModel.cast() on each actual throw.
		# This is a visual sweep only; no extra attack or damage event is added.
		# Deliberately replace the generic right-arm cast with the reap sweep.
		_rotate("upper_arm.R", Vector3(swing * 0.06 * move, -cast * 0.28, -cast * 0.08))
		_rotate("forearm.R", Vector3(cast * 0.22, 0, 0))
		_rotate("hand.R", Vector3(0, -cast * 0.08, 0))
	# The folded cape stays behind the body even when walking backward.
	var follow := 1.0 - exp(-8.0 * delta)
	_cape_angle = lerpf(_cape_angle, -0.035 - 0.18 * move - 0.08 * maxf(forward, 0.0) * move + sin(walk * 0.5) * 0.025 * move, follow)
	_cape_roll = lerpf(_cape_roll, -side * 0.05 * move + sin(walk * 0.5 + 0.8) * 0.025 * move, follow)
	_rotate("cape", Vector3(_cape_angle, 0, _cape_roll))
	for spec in [["L", 1.0], ["R", -1.0]]:
		var suffix: String = spec[0]
		var phase: float = swing * spec[1]
		var thigh: int = _bones["thigh." + suffix]
		_skeleton.set_bone_pose_position(thigh, _rest[thigh].origin)
		# The authored split robe panels are thigh-weighted, so they stride
		# with the legs instead of remaining fixed in the boots' travel path.
		_rotate("thigh." + suffix, Vector3(phase * 0.34 * forward, 0, -phase * 0.19 * side))
		_rotate("shin." + suffix, Vector3(-maxf(0.0, -phase * forward) * 0.22 * move, 0, 0))
		var foot: int = _bones["foot." + suffix]
		var parent := _skeleton.get_bone_parent(foot)
		var flat := _skeleton.get_bone_global_pose(parent).basis.inverse() * _global_rest[foot].basis
		_skeleton.set_bone_pose_rotation(foot, flat.get_rotation_quaternion())
		var lift := maxf(0.0, cos(walk) * spec[1]) * 0.06 * move
		_ground_leg(thigh, foot, lift)
	_update_socket()

func _record_bounds(mesh: MeshInstance3D) -> void:
	for s in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(s)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for v in positions.size():
			for influence in 4:
				if weights[v * 4 + influence] < 0.5:
					continue
				var bind := joints[v * 4 + influence]
				var bone := mesh.skin.get_bind_bone(bind)
				if bone < 0:
					bone = _skeleton.find_bone(mesh.skin.get_bind_name(bind))
				var point: Vector3 = mesh.skin.get_bind_pose(bind) * positions[v]
				_bone_bounds[bone] = (_bone_bounds[bone] as AABB).expand(point) if _bone_bounds.has(bone) else AABB(point, Vector3.ZERO)

func posed_bounds(name: String) -> AABB:
	var bone: int = _bones[name]
	return _skeleton_frame * _skeleton.get_bone_global_pose(bone) * (_bone_bounds[bone] as AABB)

func _ground_leg(thigh: int, foot: int, lift: float) -> void:
	var bounds: AABB = _skeleton.get_bone_global_pose(foot) * (_bone_bounds[foot] as AABB)
	var parent := _skeleton.get_bone_parent(thigh)
	var correction := _skeleton.get_bone_global_pose(parent).basis.inverse() * Vector3(0, -bounds.position.y + lift, 0)
	_skeleton.set_bone_pose_position(thigh, _rest[thigh].origin + correction)

func _update_socket() -> void:
	_socket.transform = _skeleton_frame * _skeleton.get_bone_global_pose(_bones["hand.R"]) * _socket_rest

func reset_pose() -> void:
	if not _built:
		return
	for b in _skeleton.get_bone_count():
		_skeleton.set_bone_pose(b, _rest[b])
	_cape_angle = -0.035
	_cape_roll = 0.0
	_rotate("cape", Vector3(_cape_angle, 0, 0))
	_update_socket()

func pose_signature() -> PackedFloat32Array:
	var signature := PackedFloat32Array()
	for b in _skeleton.get_bone_count():
		var pose := _skeleton.get_bone_pose(b)
		for column: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
			signature.append_array(PackedFloat32Array([column.x, column.y, column.z]))
	return signature
