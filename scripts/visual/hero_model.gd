class_name HeroModel
extends Node3D
## The hero's look. Player drives it with set_motion() every frame and cast()
## when a volley fires; everything else (bobbing, leaning, the stride and the
## weapon recoil) happens here, driven only by the delta it is handed -- never
## the wall clock -- so a replay or a test sees the same pose every time.
##
## Isolated preview flags select the supplied GLBs by existing class palette.
## Unknown palettes and flag-off appearances keep the original bodies. This
## class never changes class stats, collision, attack timing or save schemas.

const BattlemageModelScript := preload("res://scripts/visual/battlemage_model.gd")
const AegisModelScript := preload("res://scripts/visual/aegis_battlemage_model.gd")

const DEFAULT_WEAPON := "Staff"
const DEFAULT_ACCENT := Color(0.5, 0.85, 1.0)

var _body: MeshInstance3D
var _rig: Node3D
var _battlemage: BattlemageModelScript
var _aegis: AegisModelScript
var _imported: AegisModelScript
var _imported_models: Dictionary = {}
var _weapon_base := DEFAULT_WEAPON
var _weapon_accent := DEFAULT_ACCENT
var _weapon_pivot: Node3D
var _weapon: MeshInstance3D
var _light: OmniLight3D
var _speed := 0.0
## Ground velocity in the model's own frame: x = forward, y = to its right.
var _local := Vector2.ZERO
var _walk := 0.0
var _cast := 0.0
var _clock := 0.0
var _body_look: Dictionary = {}
var _ready_done := false
var _locator: Label3D
var _locator_target := 3.7


func _ready() -> void:
	_locator = get_node_or_null("Locator") as Label3D
	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * 1.12
	add_child(_rig)
	_body = MeshInstance3D.new()
	_body.mesh = Models.hero_body()
	_rig.add_child(_body)

	# A per-hero material copy: tweaking one hero's rim never mutates the shared
	# Models cache that every other hero and prop also reads.
	_battlemage = BattlemageModelScript.new()
	_battlemage.name = "Battlemage"
	_battlemage.build({}, _mutable_hero_material())
	_battlemage.visible = false
	_rig.add_child(_battlemage)
	if bool(ProjectSettings.get_setting("visuals/aegis_battlemage", false)) or bool(ProjectSettings.get_setting("visuals/imported_roster", false)):
		_aegis = AegisModelScript.new()
		_aegis.name = "Aegis"
		_aegis.build()
		_aegis.visible = false
		add_child(_aegis) # authored metres; do not apply the legacy 1.12 scale
		_imported_models["battlemage"] = _aegis

	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponMount"
	_rig.add_child(_weapon_pivot)
	_weapon = MeshInstance3D.new()
	_weapon_pivot.add_child(_weapon)
	set_weapon(DEFAULT_WEAPON, DEFAULT_ACCENT)

	# A small arcane light that travels with the hero and lights the ground
	# and scenery around them (the horde is on another layer, see EnemySwarm).
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.75, 1.0)
	_light.light_energy = 2.4
	_light.omni_range = 9.0
	_light.omni_attenuation = 1.2
	_light.light_cull_mask = 1
	_light.position = Vector3(0.3, 2.2, -0.4)
	add_child(_light)

	_ready_done = true
	_apply_body(_body_look)


func _mutable_hero_material() -> ShaderMaterial:
	# A fresh material per hero: copy the shader but set the uniforms directly,
	# so nothing here shares (or can mutate) the cached Models material.
	var source := Models.material("kit", {"rim_strength": 0.6, "rim_color": Color(0.6, 0.8, 1.0)}, "hero")
	var mat := ShaderMaterial.new()
	mat.shader = source.shader
	mat.set_shader_parameter("rim_strength", 0.6)
	mat.set_shader_parameter("rim_color", Color(0.6, 0.8, 1.0))
	return mat


## True while either Battlemage presentation is the visible body.
func uses_battlemage() -> bool:
	return _body_look.is_empty() and (uses_imported() or (_battlemage != null and _battlemage.visible))


func uses_aegis() -> bool:
	return _aegis != null and _aegis.visible

func uses_imported() -> bool:
	return _imported != null and _imported.visible

func imported_class() -> String:
	return _imported.class_id if uses_imported() else ""

func _class_for_look(look: Dictionary) -> String:
	for id: String in HeroClass.ORDER:
		if HeroClass.data(id)["look"] == look:
			return id
	return "" # preserve unknown/custom palettes as legacy appearances


## Swaps the body for the class palette. An empty palette ({}) is the
## Battlemage's; known palettes select their enabled imported presentation.
## Other palettes keep Models.hero_body. A changed class returns to a neutral
## pose; presenting the same palette again must not interrupt town walking.
func set_body(look: Dictionary) -> void:
	if _ready_done and _body_look == look:
		return
	_body_look = look.duplicate()
	if _ready_done:
		_apply_body(look)


func _apply_body(look: Dictionary) -> void:
	var battlemage := look.is_empty()
	var id := _class_for_look(look)
	var imported := (not id.is_empty() and bool(ProjectSettings.get_setting("visuals/imported_roster", false))) or (battlemage and _aegis != null)
	for model: AegisModelScript in _imported_models.values():
		model.visible = false
	_imported = null
	if imported:
		if not _imported_models.has(id):
			var model := AegisModelScript.new()
			model.name = "Imported_" + id
			model.build(id)
			add_child(model)
			_imported_models[id] = model
		_imported = _imported_models[id]
		_imported.visible = true
	_rig.visible = not imported
	if _body:
		_body.visible = not battlemage and not imported
		if not battlemage and not imported:
			_body.mesh = Models.hero_body(look)
	if _battlemage:
		_battlemage.visible = battlemage and not imported
	_attach_weapon(battlemage)
	set_weapon(_weapon_base, _weapon_accent)
	if _light:
		_light.light_color = (look["eye"] as Color).lerp(Color.WHITE, 0.3) if look.has("eye") else Color(0.55, 0.75, 1.0)
	_neutral()


## Aegis uses its authored hand socket; legacy bodies retain Models.HERO_HAND.
func _attach_weapon(battlemage: bool) -> void:
	if _weapon_pivot == null:
		return
	var parent: Node3D = _imported.hand_mount() if uses_imported() else (_battlemage.hand_mount() if battlemage else _rig)
	if _weapon_pivot.get_parent() != parent:
		if _weapon_pivot.get_parent() != null:
			_weapon_pivot.get_parent().remove_child(_weapon_pivot)
		parent.add_child(_weapon_pivot)
	_weapon_pivot.position = Vector3.ZERO if uses_imported() else Models.HERO_HAND
	_weapon_pivot.rotation = Vector3.ZERO


## Shows the weapon base `base_name` (see ItemData.BASES) with an `accent` gem.
func set_weapon(base_name: String, accent: Color) -> void:
	_weapon_base = base_name
	_weapon_accent = accent
	if _weapon == null:
		return
	if uses_imported() and base_name == _imported.native_weapon_base():
		_weapon.mesh = _imported.native_weapon_mesh(accent)
		_weapon.position = Vector3.ZERO # exported origin already sits at its grip
		_weapon.rotation = Vector3.ZERO
		return
	_weapon.mesh = Models.item("weapon", base_name, accent)
	# Staffs (and the Reaper's scythe) are planted like a walking stick; wands
	# and orbs are held up.
	match base_name:
		"Staff":
			_weapon.position = Vector3(0, 0.15, 0)
			_weapon.rotation_degrees = Vector3(-10, 0, 0)
		"Orb":
			_weapon.position = Vector3(0, 0.18, -0.05)
			_weapon.rotation_degrees = Vector3.ZERO
		"Scythe":
			_weapon.position = Vector3(0, 0.2, 0)
			_weapon.rotation_degrees = Vector3(-8, 90, 0)
		_:
			_weapon.position = Vector3(0, 0.25, -0.05)
			_weapon.rotation_degrees = Vector3(-35, 0, 0)
	if uses_imported():
		# Align the actual legacy handle, not its arbitrary mesh origin, with
		# the authored socket; a rotated wand must not float beside the fingers.
		_weapon.position = -(_weapon.basis * AegisModelScript.weapon_grip(base_name))


## `velocity` is the hero's ground velocity as Vector2(x, z), in units per
## second. The model leans the way it moves, even when it faces elsewhere, and
## the gait follows the lean, so strafing and walking backward stay coherent.
func set_motion(velocity: Vector2, delta: float) -> void:
	var t := 1.0 - exp(-10.0 * delta)
	_speed = lerpf(_speed, velocity.length(), t)
	var yaw := rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	_local = _local.lerp(Vector2(velocity.dot(forward), velocity.dot(right)), t)


## A volley fired: restart the thrust even if one is already playing.
func cast() -> void:
	_cast = 1.0


## Lift the depth-tested locator above tall foreground actors in dense hordes.
## The count only affects presentation; no x-ray or per-enemy nodes are used.
func set_crowd_count(count: int) -> void:
	_locator_target = lerpf(3.7, 6.0, clampf(float(count - 60) / 300.0, 0.0, 1.0))


## Snaps back to rest: used on a class switch so the new look never inherits
## the old one's lean, stride or cast.
func _neutral() -> void:
	_speed = 0.0
	_local = Vector2.ZERO
	_walk = 0.0
	_cast = 0.0
	_clock = 0.0
	if _rig:
		_rig.position = Vector3.ZERO
		_rig.rotation = Vector3.ZERO
	if _weapon_pivot:
		_weapon_pivot.rotation = Vector3.ZERO
	if _battlemage:
		_battlemage.reset_pose()
	for model: AegisModelScript in _imported_models.values():
		model.reset_pose()


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_locator):
		_locator.position.y = lerpf(_locator.position.y, _locator_target, 1.0 - exp(-8.0 * delta))
	_cast = maxf(_cast - delta * 5.0, 0.0)
	var moving := clampf(_speed / 6.0, 0.0, 1.5)
	_walk += delta * (2.0 + _speed * 1.6)
	if uses_imported():
		_imported.animate(delta, _local, _speed, _walk, _cast, _clock)
		_weapon_pivot.position = Vector3.ZERO
		_weapon_pivot.rotation = Vector3.ZERO # the socket already follows the hand
	elif _battlemage and _battlemage.visible:
		# The articulated rig bobs and leans itself, over feet that stay put.
		_battlemage.animate(delta, _local, _speed, _walk, _cast, _clock)
		# Keep the grip attached to the articulated hand, not a fixed torso point.
		_weapon_pivot.position = _battlemage.hand_position()
		_rig.position.y = 0.0
		_rig.rotation.x = 0.0
		_rig.rotation.z = 0.0
	else:
		var idle := sin(_clock * 1.3) * 0.03
		_rig.position.y = absf(sin(_walk)) * 0.12 * moving + idle * (1.0 - minf(moving, 1.0))
		_rig.rotation.x = -0.14 * clampf(_local.x / 6.0, -1.0, 1.0)
		_rig.rotation.z = -0.1 * clampf(_local.y / 6.0, -1.0, 1.0) + sin(_walk) * 0.05 * moving
	# The weapon thrusts forward when a volley fires.
	if _weapon_pivot and not uses_imported():
		_weapon_pivot.rotation = _battlemage.hand_rotation() if uses_battlemage() else Vector3.ZERO
		_weapon_pivot.rotation.x += -0.7 * _cast + sin(_walk) * 0.1 * moving
	if _light:
		_light.light_energy = 2.4 + _cast * 1.6
