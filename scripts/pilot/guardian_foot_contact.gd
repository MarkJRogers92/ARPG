extends RefCounted
## Bounded, flat-ground, leg-only transition correction for the isolated pilot.
## Runtime evaluates <=26 cached support markers per foot, never bakes a mesh.
## Offline tests must still measure the full rendered skin, including toes.
const CONTACT_TOLERANCE := 0.015
const MAX_ANKLE_CORRECTION := 0.12
const RESIDUAL_TOLERANCE := 0.001
var skeleton: Skeleton3D
var feet: Array[Dictionary] = []
var failures: Array[String] = []
var max_ankle_correction := 0.0
var active := false

func setup(source_skeleton: Skeleton3D, model: Node3D) -> bool:
	skeleton = source_skeleton
	skeleton.force_update_all_bone_transforms()
	for side: String in ["Left", "Right"]:
		var data := {"side": side, "hip": skeleton.find_bone(side + "UpLeg"), "knee": skeleton.find_bone(side + "Leg"), "ankle": skeleton.find_bone(side + "Foot"), "toe": skeleton.find_bone(side + "ToeBase"), "all_points": [], "markers": []}
		for key: String in ["hip", "knee", "ankle", "toe"]:
			if int(data[key]) < 0:
				failures.append("Missing leg bone " + side + key)
				return false
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null:
				continue
			var bind_bones: Array[int] = []
			for bind in mesh.skin.get_bind_count():
				bind_bones.append(skeleton.find_bone(str(mesh.skin.get_bind_name(bind))))
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var slots: int = joints.size() / vertices.size()
				for index in vertices.size():
					var foot_weight := 0.0
					for slot in slots:
						var bone := bind_bones[joints[index * slots + slot]]
						if bone == data.ankle or bone == data.toe:
							foot_weight += weights[index * slots + slot]
					if foot_weight < 0.5:
						continue
					var point := {"bones": [], "local": [], "weights": []}
					for slot in slots:
						var weight := weights[index * slots + slot]
						if weight <= 0.0:
							continue
						var bind := joints[index * slots + slot]
						point.bones.append(bind_bones[bind])
						point.local.append(mesh.skin.get_bind_pose(bind) * vertices[index])
						point.weights.append(weight)
					data.all_points.append(point)
		if data.all_points.is_empty():
			failures.append("No weighted foot support geometry for " + side)
			return false
		var marker_ids: Array[int] = []
		for x in [-1, 0, 1]:
			for y in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					if x == 0 and y == 0 and z == 0:
						continue
					var direction := Vector3(x, y, z)
					var best := -INF
					var best_id := -1
					for index in data.all_points.size():
						var score := point_position(data.all_points[index]).dot(direction)
						if score > best:
							best = score
							best_id = index
					if best_id not in marker_ids:
						marker_ids.append(best_id)
		for index in marker_ids:
			data.markers.append(data.all_points[index])
		data.baseline = floor_y(data, true)
		data.idle_ankle = skeleton.get_bone_global_pose(data.ankle)
		data.idle_toe = skeleton.get_bone_global_pose(data.toe)
		feet.append(data)
	return true

func point_position(point: Dictionary) -> Vector3:
	var p := Vector3.ZERO
	for i in point.bones.size():
		p += (skeleton.get_bone_global_pose(point.bones[i]) * point.local[i]) * float(point.weights[i])
	return p

func floor_y(data: Dictionary, full_geometry := false) -> float:
	var minimum := INF
	var points: Array = data.all_points if full_geometry else data.markers
	for point: Dictionary in points:
		minimum = minf(minimum, point_position(point).y)
	return minimum

func begin() -> void:
	active = true
	max_ankle_correction = 0.0
	skeleton.force_update_all_bone_transforms()
	for data: Dictionary in feet:
		data.start_height = floor_y(data)
		data.start_ankle = skeleton.get_bone_global_pose(data.ankle)
		data.start_toe = skeleton.get_bone_global_pose(data.toe)
		data.grounded = float(data.start_height) <= float(data.baseline) + CONTACT_TOLERANCE

func apply(progress: float) -> void:
	if not active:
		return
	var t := clampf(progress, 0.0, 1.0)
	var smooth := t * t * (3.0 - 2.0 * t)
	skeleton.force_update_all_bone_transforms()
	for data: Dictionary in feet:
		var raw: Array[Transform3D] = []
		for name: String in ["hip", "knee", "ankle", "toe"]:
			raw.append(skeleton.get_bone_global_pose(data[name]))
		var start_ankle: Transform3D = data.start_ankle
		var idle_ankle: Transform3D = data.idle_ankle
		var start_toe: Transform3D = data.start_toe
		var idle_toe: Transform3D = data.idle_toe
		var ankle_basis := start_ankle.basis.orthonormalized().slerp(idle_ankle.basis.orthonormalized(), smooth)
		var toe_basis := start_toe.basis.orthonormalized().slerp(idle_toe.basis.orthonormalized(), smooth)
		var target_height := lerpf(float(data.start_height), float(data.baseline), smooth)
		# Move between measured source and authored stance with zero endpoint
		# target velocity. Raw local-pose blends can move the knee34mm on
		# their first4ms tick. This is still not a world-XZ foot lock.
		var target := start_ankle.origin.lerp(idle_ankle.origin, smooth)
		target.y = raw[2].origin.y
		_set_foot_basis(data, ankle_basis, toe_basis)
		var success := true
		for iteration in 3:
			var error := target_height - floor_y(data)
			if absf(error) <= 0.0001 and iteration > 0:
				break
			target.y += error
			var correction := target.distance_to(raw[2].origin)
			max_ankle_correction = maxf(max_ankle_correction, correction)
			if correction > MAX_ANKLE_CORRECTION:
				_fail(data, "ankle correction exceeds 120 mm")
				success = false
				break
			if not _solve(data, raw, target, ankle_basis, toe_basis):
				success = false
				break
		if success and absf(target_height - floor_y(data)) > RESIDUAL_TOLERANCE:
			_fail(data, "support marker residual exceeds 1 mm")
			success = false
		if not success:
			_restore(data, raw)
	if t >= 1.0:
		active = false

func _set_foot_basis(data: Dictionary, ankle_basis: Basis, toe_basis: Basis) -> void:
	var ankle := skeleton.get_bone_global_pose(data.ankle)
	ankle.basis = ankle_basis
	skeleton.set_bone_global_pose(data.ankle, ankle)
	skeleton.force_update_all_bone_transforms()
	var toe := skeleton.get_bone_global_pose(data.toe)
	toe.basis = toe_basis
	skeleton.set_bone_global_pose(data.toe, toe)
	skeleton.force_update_all_bone_transforms()

func _solve(data: Dictionary, raw: Array[Transform3D], target: Vector3, ankle_basis: Basis, toe_basis: Basis) -> bool:
	var hip := raw[0].origin
	var knee := raw[1].origin
	var ankle := raw[2].origin
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	var vector := target - hip
	var distance := vector.length()
	if distance <= 0.00001 or distance > upper + lower - 0.00001 or distance < absf(upper - lower) + 0.00001:
		_fail(data, "unreachable target: %.6fm, allowed %.6f..%.6f" % [distance, absf(upper-lower), upper+lower])
		return false
	var axis := vector / distance
	var pole := knee - hip - axis * (knee - hip).dot(axis)
	if pole.length_squared() < 0.00000001:
		_fail(data, "degenerate knee pole")
		return false
	pole = pole.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(0.0, upper * upper - along * along))
	var solved_knee := hip + axis * along + pole * bend
	var hip_rotation := Basis(Quaternion((knee-hip).normalized(), (solved_knee-hip).normalized()))
	skeleton.set_bone_global_pose(data.hip, Transform3D(hip_rotation * raw[0].basis, hip))
	skeleton.force_update_all_bone_transforms()
	var current_knee := skeleton.get_bone_global_pose(data.knee)
	var current_ankle := skeleton.get_bone_global_pose(data.ankle)
	var knee_rotation := Basis(Quaternion((current_ankle.origin-current_knee.origin).normalized(), (target-solved_knee).normalized()))
	skeleton.set_bone_global_pose(data.knee, Transform3D(knee_rotation * current_knee.basis, solved_knee))
	skeleton.force_update_all_bone_transforms()
	var solved_ankle := skeleton.get_bone_global_pose(data.ankle)
	if solved_ankle.origin.distance_to(target) > 0.001:
		_fail(data, "two-bone endpoint residual exceeds 1 mm")
		return false
	skeleton.set_bone_global_pose(data.ankle, Transform3D(ankle_basis, solved_ankle.origin))
	skeleton.force_update_all_bone_transforms()
	var toe := skeleton.get_bone_global_pose(data.toe)
	toe.basis = toe_basis
	skeleton.set_bone_global_pose(data.toe, toe)
	skeleton.force_update_all_bone_transforms()
	return true

func _restore(data: Dictionary, raw: Array[Transform3D]) -> void:
	var names := ["hip", "knee", "ankle", "toe"]
	for i in names.size():
		skeleton.set_bone_global_pose(data[names[i]], raw[i])
		skeleton.force_update_all_bone_transforms()

func _fail(data: Dictionary, reason: String) -> void:
	var message := str(data.side) + ": " + reason
	if message not in failures:
		failures.append(message)
		push_warning("GUARDIAN_CONTACT_FAILED " + message)
