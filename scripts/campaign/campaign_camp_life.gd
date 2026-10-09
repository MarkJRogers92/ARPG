class_name CampaignCampLife
extends Node3D
## Small, presentation-only life layer for Gravediggers' Camp.
## It is mounted below that waystop's destination root, so travel/teardown owns
## every worker, ember, and label without introducing campaign state.

signal mara_used

const MARA_AT := Vector2(-4.35, -1.05)
const TALK_RANGE := 2.1

var _clock := 0.0
var _workers: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _fire_light: OmniLight3D
var _fire_audio: AudioStreamPlayer
var _prompt: Label3D
var _mara_label: Label3D
var _talk_enabled := false


func _ready() -> void:
	name = "GravediggersCampLife"
	_build_workers()
	_build_fire_motes()
	_fire_light = get_parent().get_node_or_null("CampfireWarmth") as OmniLight3D
	_fire_audio = AudioStreamPlayer.new()
	_fire_audio.name = "CampfireCrackle"
	_fire_audio.bus = "SFX"
	_fire_audio.volume_db = -21.0
	_fire_audio.autoplay = true
	var crackle := load("res://audio/sfx/campfire_loop.wav") as AudioStreamWAV
	if crackle != null:
		crackle.loop_mode = AudioStreamWAV.LOOP_FORWARD
		crackle.loop_begin = 0
		crackle.loop_end = int(crackle.data.size() / 2)
		_fire_audio.stream = crackle
		add_child(_fire_audio)


func set_talk_prompt(eligible: bool, hero_position: Vector2, walking: bool) -> void:
	_talk_enabled = eligible and walking and hero_position.distance_to(MARA_AT) <= TALK_RANGE
	if is_instance_valid(_prompt):
		_prompt.text = "%s  Speak with Mara" % Controls.tag("interact")
		_prompt.visible = _talk_enabled
	if is_instance_valid(_mara_label):
		_mara_label.visible = true


func can_talk_from(position: Vector2) -> bool:
	return _talk_enabled and position.distance_to(MARA_AT) <= TALK_RANGE


func talk() -> void:
	if _talk_enabled:
		mara_used.emit()


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_fire_light):
		_fire_light.light_energy = 3.1 + 0.17 * sin(_clock * 8.2) + 0.08 * sin(_clock * 13.7)
	for worker: Dictionary in _workers:
		var root: Node3D = worker["root"]
		var role := str(worker["role"])
		var phase := float(worker["phase"])
		root.position.y = float(worker["base_y"]) + 0.025 * sin(_clock * (1.8 if role == "mara" else 2.4) + phase)
		if role == "firekeeper":
			var arms: Array = worker["arms"]
			arms[0].rotation.z = -0.28 + 0.2 * sin(_clock * 1.5 + phase)
			arms[1].rotation.z = 0.28 - 0.2 * sin(_clock * 1.5 + phase)
		elif role == "repairer":
			var arm: Node3D = worker["arms"][0]
			arm.rotation.z = -0.15 - 0.52 * maxf(0.0, sin(_clock * 2.0 + phase))
		elif role == "mara":
			var arm: Node3D = worker["arms"][0]
			arm.rotation.z = -0.12 + 0.07 * sin(_clock * 0.8 + phase)
	for mote: Dictionary in _smoke:
		var age := fposmod(_clock + float(mote["phase"]), float(mote["duration"]))
		var t := age / float(mote["duration"])
		var node: MeshInstance3D = mote["node"]
		node.position = mote["origin"] + Vector3(0.18 * sin(age * 1.1 + float(mote["phase"])), age * 0.44, 0.12 * cos(age * 0.8 + float(mote["phase"])))
		node.scale = Vector3.ONE * (0.28 + t * 0.62)
		var material: StandardMaterial3D = node.material_override
		material.albedo_color.a = (1.0 - t) * 0.32
	for mote: Dictionary in _embers:
		var phase := _clock * float(mote["speed"]) + float(mote["phase"])
		var node: MeshInstance3D = mote["node"]
		node.position = mote["origin"] + Vector3(cos(phase) * float(mote["reach"]), 0.12 + fposmod(_clock * float(mote["rise"]) + float(mote["phase"]), 1.0) * 0.88, sin(phase) * float(mote["reach"]) * 0.55)
		node.visible = sin(phase * 1.4) > -0.35


func _build_workers() -> void:
	# Mara stands just off the cooking circle. The two other workers have
	# deliberately different silhouettes and rhythms so the camp feels occupied
	# without drawing attention away from the service approaches.
	var mara := _worker("Mara", "mara", MARA_AT, Color(0.36, 0.43, 0.36), Color(0.72, 0.58, 0.37), 0.4)
	_mara_label = Label3D.new()
	_mara_label.name = "MaraName"
	_mara_label.text = "MARA"
	_mara_label.font_size = 46
	_mara_label.pixel_size = 0.004
	_mara_label.position = Vector3(0, 2.12, 0)
	_mara_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mara_label.no_depth_test = true
	_mara_label.modulate = Color(0.96, 0.86, 0.66)
	mara.add_child(_mara_label)
	_prompt = Label3D.new()
	_prompt.name = "MaraTalkPrompt"
	_prompt.text = "[%s]  Speak with Mara" % Controls.tag("interact")
	_prompt.font_size = 42
	_prompt.pixel_size = 0.004
	_prompt.position = Vector3(0, 2.62, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = Color(1.0, 0.88, 0.62)
	_prompt.visible = false
	mara.add_child(_prompt)
	var firekeeper := _worker("Firekeeper", "firekeeper", Vector2(-0.8, -5.0), Color(0.43, 0.29, 0.23), Color(0.73, 0.48, 0.23), 1.8)
	var repairer := _worker("Repairer", "repairer", Vector2(-10.0, -3.8), Color(0.27, 0.36, 0.35), Color(0.53, 0.49, 0.35), 3.1)
	firekeeper.rotation.y = atan2(2.0, -1.3)
	# Keep workers out of the seven station use circles. They are decoration,
	# without collision, and do not change the walk-town's blocker map.
	for person: Node3D in [mara, firekeeper, repairer]:
		add_child(person)


func _worker(label: String, role: String, at: Vector2, coat: Color, trim: Color, phase: float) -> Node3D:
	var root := Node3D.new()
	root.name = label.replace(" ", "")
	root.position = Vector3(at.x, 0.0, at.y)
	var body := _material(coat)
	var accent := _material(trim)
	var dark := _material(Color(0.105, 0.105, 0.11))
	var skin := _material(Color(0.57, 0.39, 0.27))
	_add_mesh(root, _capsule(0.31, 0.88), Vector3(0, 0.83, 0), body)
	_add_mesh(root, _sphere(0.22, 8, 5), Vector3(0, 1.52, 0), skin)
	_add_mesh(root, _sphere(0.255, 8, 5), Vector3(0, 1.66, -0.025), accent)
	# Hood brim and a thin dark face shadow make faces readable at town scale.
	_add_mesh(root, _box(Vector3(0.46, 0.1, 0.36)), Vector3(0, 1.53, 0.01), dark)
	var arm_nodes: Array[Node3D] = []
	var hammer: MeshInstance3D
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.24, 1.18, 0.015)
		root.add_child(pivot)
		_add_mesh(pivot, _capsule(0.085, 0.48), Vector3(side * 0.06, -0.22, 0), accent)
		arm_nodes.append(pivot)
	_add_mesh(root, _box(Vector3(0.43, 0.12, 0.29)), Vector3(0, 0.22, 0), dark)
	if role == "repairer":
		var tool_arm: Node3D = arm_nodes[0]
		hammer = _add_mesh(tool_arm, _box(Vector3(0.055, 0.62, 0.055)), Vector3(-0.08, -0.48, -0.12), dark)
		hammer.rotation.z = -0.36
		_add_mesh(tool_arm, _box(Vector3(0.22, 0.08, 0.1)), Vector3(-0.12, -0.79, -0.12), trim_material(trim))
	elif role == "firekeeper":
		_add_mesh(root, _sphere(0.105, 7, 4), Vector3(0, 1.0, -0.42), _material(Color(1.0, 0.48, 0.12), true))
	_workers.append({"root": root, "role": role, "arms": arm_nodes, "hammer": hammer, "phase": phase, "base_y": 0.0})
	return root


func _build_fire_motes() -> void:
	var smoke_material := _material(Color(0.37, 0.42, 0.39, 0.32), false, true)
	for i in 5:
		var node := MeshInstance3D.new()
		node.name = "HearthSmoke_%d" % i
		node.mesh = _sphere(0.24, 7, 4)
		node.material_override = smoke_material.duplicate()
		var origin := Vector3(-2.8, 0.62, -3.7)
		add_child(node)
		_smoke.append({"node": node, "origin": origin, "phase": float(i) * 0.71, "duration": 5.3})
	var ember_material := _material(Color(1.0, 0.39, 0.08), true)
	for i in 7:
		var node := MeshInstance3D.new()
		node.name = "HearthEmber_%d" % i
		node.mesh = _sphere(0.055 if i % 2 == 0 else 0.038, 6, 4)
		node.material_override = ember_material
		add_child(node)
		_embers.append({"node": node, "origin": Vector3(-2.8, 0.2, -3.7), "phase": float(i) * 1.17, "speed": 1.35 + float(i % 3) * 0.21, "reach": 0.22 + float(i % 4) * 0.07, "rise": 0.19 + float(i % 3) * 0.035})


func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _material(color: Color, glow := false, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.3
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func trim_material(color: Color) -> StandardMaterial3D:
	return _material(color)


func _sphere(radius: float, radial := 8, rings := 5) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 3
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
