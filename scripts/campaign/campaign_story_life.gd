class_name CampaignStoryLife
extends Node3D
## Walkable settlement cast and physical story payoffs. State remains in the controller.

signal story_used(story_id: String)

const CONFIG := {
	"whitepass_aid": {"name": "HESSA VALE", "title": "STRANDED TRAVELER", "at": Vector3(-4.6, 0, -1.2), "coat": Color(0.28, 0.42, 0.57), "trim": Color(0.78, 0.84, 0.86), "prop": "supply"},
	"sledwright_repair": {"name": "ELIAN RUSK", "title": "SLEDWRIGHT", "at": Vector3(-10.0, 0, -1.0), "coat": Color(0.42, 0.28, 0.19), "trim": Color(0.84, 0.58, 0.25), "prop": "runner"},
	"redwake_trade": {"name": "JUNO CALDER", "title": "REDWAKE FACTOR", "at": Vector3(5.6, 0, -3.0), "coat": Color(0.48, 0.21, 0.15), "trim": Color(0.96, 0.48, 0.18), "prop": "crate"},
}
const RANGE := 2.4

var _clock := 0.0
var _story_id := ""
var _actor: Node3D
var _memorial: Node3D
var _memorial_status := ""
var _prompt: Label3D
var _name_label: Label3D
var _prop_root: Node3D
var _payoff: Node3D
var _broken_runner: MeshInstance3D
var _iron_shoe: MeshInstance3D
var _canvas_splint: MeshInstance3D
var _signal_flame: MeshInstance3D
var _supply_bundle: MeshInstance3D
var _crate_lid: MeshInstance3D
var _coin_pile: Node3D
var _cargo_ash: MeshInstance3D
var _hammer: Node3D
var _base_position := Vector3.ZERO
var _resolved_choice := ""


func configure(place: Dictionary, stories: Dictionary) -> void:
	var id := _story_for_place(place)
	if id == "": return
	_story_id = id
	var data: Dictionary = CONFIG[id]
	_base_position = data["at"]
	_build_actor(data)
	_build_prop(str(data["prop"]))
	apply_stories(stories)


func _build_road_memorial(lantern_returned: bool) -> void:
	if is_instance_valid(_memorial): _memorial.queue_free()
	var memorial := Node3D.new()
	memorial.name = "MaraRoadLanternMemorial"
	memorial.position = Vector3(2.7, 0, -5.4)
	add_child(memorial)
	_memorial = memorial
	var brass := _material(Color(0.65, 0.48, 0.22))
	_add_mesh(memorial, _box(Vector3(0.42, 0.08, 0.42)), Vector3(0, 0.12, 0), brass)
	_add_mesh(memorial, _box(Vector3(0.07, 1.55, 0.07)), Vector3(0, 0.83, 0), brass)
	if lantern_returned:
		var glass := _material(Color(0.38, 0.82, 0.96), true)
		_add_mesh(memorial, _box(Vector3(0.36, 0.42, 0.30)), Vector3(0, 1.72, 0), glass)
		_add_mesh(memorial, _box(Vector3(0.46, 0.07, 0.40)), Vector3(0, 1.96, 0), brass)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 1.82, 0)
		light.light_color = Color(0.42, 0.82, 1.0)
		light.light_energy = 1.0
		light.omni_range = 4.8
		memorial.add_child(light)
	else:
		var hook := MeshInstance3D.new()
		var hook_mesh := TorusMesh.new()
		hook_mesh.inner_radius = 0.15
		hook_mesh.outer_radius = 0.2
		hook.mesh = hook_mesh
		hook.position = Vector3(0, 1.48, 0)
		hook.rotation.x = PI * 0.5
		hook.material_override = brass
		memorial.add_child(hook)
	var plaque := _label("MARA'S BLUE LANTERN  ·  CARRIED NORTH" if lantern_returned else "MARA'S EMPTY LANTERN HOOK")
	plaque.position = Vector3(0, 1.72, 0)
	plaque.font_size = 32
	memorial.add_child(plaque)


func _story_for_place(place: Dictionary) -> String:
	var id := str(place.get("id", ""))
	match id:
		"waystop:frozen_wastes:0": return "whitepass_aid"
		"waystop:frozen_wastes:1": return "sledwright_repair"
		"waystop:ember_rift:1": return "redwake_trade"
	return ""


func set_prompt(eligible: bool, hero_position: Vector2, walking: bool) -> void:
	var near := walking and eligible and Vector2(_base_position.x, _base_position.z).distance_to(hero_position) <= RANGE
	if is_instance_valid(_prompt):
		_prompt.visible = near
		_prompt.text = "%s  Speak with %s" % [Controls.tag("interact"), str(CONFIG[_story_id]["name"]).get_slice(" ", 0)]


func can_talk_from(position: Vector2) -> bool:
	return not _story_id.is_empty() and Vector2(_base_position.x, _base_position.z).distance_to(position) <= RANGE


func talk() -> void:
	if not _story_id.is_empty(): story_used.emit(_story_id)


func apply_stories(stories: Dictionary) -> void:
	var lantern_status := str(stories.get("lantern_recovery", {}).get("status", ""))
	if lantern_status != _memorial_status:
		_memorial_status = lantern_status
		if lantern_status in ["complete", "missed"]:
			_build_road_memorial(lantern_status == "complete")
		elif is_instance_valid(_memorial):
			_memorial.queue_free()
			_memorial = null
	if not is_instance_valid(_actor): return
	var record: Dictionary = stories.get(_story_id, {})
	_resolved_choice = str(record.get("choice", ""))
	if _story_id == "redwake_trade":
		_resolved_choice = str(record.get("status", "open"))
	match _story_id:
		"whitepass_aid":
			if _resolved_choice == "donate":
				_actor.rotation.y = PI
				_prop_root.scale = Vector3(1.1, 1.15, 1.1)
				if is_instance_valid(_supply_bundle): _supply_bundle.visible = true
			elif _resolved_choice == "signal":
				_actor.rotation.y = 0.0
				_prop_root.scale = Vector3(0.72, 0.82, 0.72)
				if is_instance_valid(_signal_flame): _signal_flame.visible = true
		"sledwright_repair":
			if _resolved_choice == "iron":
				_actor.rotation.y = 0.35
				if is_instance_valid(_broken_runner): _broken_runner.visible = false
				if is_instance_valid(_iron_shoe): _iron_shoe.visible = true
			elif _resolved_choice == "canvas":
				_actor.rotation.y = -0.35
				if is_instance_valid(_broken_runner): _broken_runner.visible = false
				if is_instance_valid(_canvas_splint): _canvas_splint.visible = true
		"redwake_trade":
			var won := bool(record.get("won", false))
			if _resolved_choice == "played":
				_actor.rotation.y = -0.7 if won else 0.7
				if is_instance_valid(_crate_lid):
					_crate_lid.visible = true
					_crate_lid.rotation.x = -0.72 if won else 0.48
				if is_instance_valid(_coin_pile): _coin_pile.visible = won
				if is_instance_valid(_cargo_ash): _cargo_ash.visible = not won


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_actor):
		_actor.position.y = 0.025 * sin(_clock * 1.7)
	if is_instance_valid(_hammer): _hammer.rotation.z = -0.22 + 0.18 * sin(_clock * 1.3)
	if is_instance_valid(_signal_flame): _signal_flame.scale = Vector3.ONE * (0.9 + 0.1 * sin(_clock * 5.0))


func _build_actor(data: Dictionary) -> void:
	_actor = Node3D.new()
	_actor.name = str(data["name"]).replace(" ", "")
	_actor.position = _base_position
	add_child(_actor)
	var coat := _material(data["coat"])
	var trim := _material(data["trim"])
	var dark := _material(Color(0.11, 0.12, 0.14))
	var skin := _material(Color(0.55, 0.38, 0.29))
	_add_mesh(_actor, _capsule(0.29, 0.88), Vector3(0, 0.83, 0), coat)
	_add_mesh(_actor, _sphere(0.215), Vector3(0, 1.51, 0), skin)
	_add_mesh(_actor, _sphere(0.25), Vector3(0, 1.67, -0.025), trim)
	_add_mesh(_actor, _box(Vector3(0.47, 0.1, 0.37)), Vector3(0, 1.52, 0), dark)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.26, 1.22, 0.03)
		_actor.add_child(arm)
		_add_mesh(arm, _capsule(0.075, 0.44), Vector3(0, -0.2, 0), trim)
		if side < 0.0 and _story_id == "sledwright_repair":
			_hammer = Node3D.new()
			_hammer.position = Vector3(-0.06, -0.4, -0.1)
			arm.add_child(_hammer)
			_add_mesh(_hammer, _box(Vector3(0.07, 0.42, 0.07)), Vector3.ZERO, dark)
			_add_mesh(_hammer, _box(Vector3(0.24, 0.08, 0.11)), Vector3(0, -0.2, 0), trim)
	if _story_id == "redwake_trade":
		_add_mesh(_actor, _box(Vector3(0.5, 0.12, 0.32)), Vector3(0, 1.72, -0.04), _material(Color(0.26, 0.09, 0.06)))
		_add_mesh(_actor, _box(Vector3(0.18, 0.18, 0.07)), Vector3(0.29, 1.23, 0.04), _material(Color(0.85, 0.52, 0.12)))
	elif _story_id == "whitepass_aid":
		_add_mesh(_actor, _sphere(0.12), Vector3(-0.31, 1.22, -0.05), _material(Color(0.42, 0.83, 1.0), true))
	_name_label = _label(str(data["name"]))
	_name_label.position = Vector3(0, 2.02, 0)
	_actor.add_child(_name_label)
	var role := _label(str(data["title"]))
	role.position = Vector3(0, 2.32, 0)
	role.font_size = 31
	role.modulate = Color(0.83, 0.88, 0.94)
	_actor.add_child(role)
	_prompt = _label("%s  Speak" % Controls.tag("interact"))
	_prompt.position = Vector3(0, 2.65, 0)
	_prompt.modulate = Color(1.0, 0.84, 0.49)
	_prompt.visible = false
	_actor.add_child(_prompt)


func _build_prop(kind: String) -> void:
	_prop_root = Node3D.new()
	_prop_root.name = "SettlementStoryProps"
	_prop_root.position = _base_position + Vector3(0.8, 0, -0.8)
	add_child(_prop_root)
	var wood := _material(Color(0.32, 0.22, 0.14))
	var fabric := _material(Color(0.57, 0.66, 0.72))
	match kind:
		"supply":
			_add_mesh(_prop_root, _box(Vector3(0.88, 0.48, 0.66)), Vector3(0, 0.26, 0), wood)
			_add_mesh(_prop_root, _box(Vector3(0.94, 0.09, 0.72)), Vector3(0, 0.53, 0), fabric)
			_supply_bundle = _add_mesh(_prop_root, _sphere(0.24), Vector3(0.05, 0.68, 0.08), _material(Color(0.72, 0.41, 0.16)))
			_supply_bundle.visible = false
			var brazier := _add_mesh(_prop_root, _box(Vector3(0.12, 1.2, 0.12)), Vector3(-0.84, 0.6, -0.35), wood)
			brazier.rotation.z = -0.12
			_signal_flame = _add_mesh(_prop_root, _sphere(0.13), Vector3(-0.84, 1.3, -0.35), _material(Color(1.0, 0.55, 0.19), true))
			_signal_flame.visible = false
		"runner":
			for side in [-1.0, 1.0]:
				_add_mesh(_prop_root, _box(Vector3(0.12, 0.16, 1.7)), Vector3(side * 0.42, 0.12, 0), wood)
			_broken_runner = _add_mesh(_prop_root, _box(Vector3(0.12, 0.12, 0.96)), Vector3(0.42, 0.3, 0.14), _material(Color(0.39, 0.24, 0.13)))
			_broken_runner.rotation.y = 0.18
			_iron_shoe = _add_mesh(_prop_root, _box(Vector3(0.16, 0.09, 1.55)), Vector3(0, 0.23, 0), _material(Color(0.6, 0.66, 0.7), true))
			_iron_shoe.visible = false
			_canvas_splint = _add_mesh(_prop_root, _box(Vector3(0.2, 0.23, 0.54)), Vector3(0.42, 0.31, 0.14), _material(Color(0.78, 0.62, 0.34)))
			_canvas_splint.visible = false
		"crate":
			for i in 3:
				_add_mesh(_prop_root, _box(Vector3(0.64, 0.56, 0.58)), Vector3(float(i % 2) * 0.58 - 0.28, 0.28 + float(i / 2) * 0.56, float(i % 2) * -0.28), wood)
			_crate_lid = _add_mesh(_prop_root, _box(Vector3(0.71, 0.09, 0.64)), Vector3(0.02, 1.15, 0.02), _material(Color(0.32, 0.22, 0.14).lightened(0.12)))
			_crate_lid.visible = false
			_coin_pile = Node3D.new()
			_coin_pile.position = Vector3(0.05, 0.89, 0.02)
			_prop_root.add_child(_coin_pile)
			for i in 5: _add_mesh(_coin_pile, _coin(), Vector3(float(i % 3) * 0.11 - 0.11, float(i / 3) * 0.05, float(i % 2) * 0.1 - 0.05), _material(Color(0.94, 0.72, 0.26), true))
			_coin_pile.visible = false
			_cargo_ash = _add_mesh(_prop_root, _sphere(0.28), Vector3(0.04, 0.86, 0.02), _material(Color(0.43, 0.18, 0.09)))
			_cargo_ash.visible = false


func _label(text_value: String) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 38
	label.pixel_size = 0.004
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.98, 0.86, 0.62)
	return label


func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.0
	return material


func _sphere(radius := 0.22) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
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


func _coin() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.09
	mesh.height = 0.035
	mesh.radial_segments = 8
	return mesh
