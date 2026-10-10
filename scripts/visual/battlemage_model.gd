extends Node3D
## The Battlemage's articulated look, built entirely from MeshKit primitives.
## HeroModel preloads this script (no global class_name, so a headless suite can
## run without a fresh class cache, matching combat_visuals.gd). An empty
## HeroClass `look` selects this model; every other hero keeps the original
## single-mesh Models.hero_body, so they are not reskinned.
##
## The rig has three layers:
##   - hip pivots hold the legs at ground level, so the stride never floats;
##   - a torso node bobs and leans over them (it carries the head, arms and
##     cape, and HeroModel's weapon mount, so the staff rides the same motion);
##   - shoulder/head/cape pivots sit above the torso and swing with the gait.
## Every value comes from the delta HeroModel passes in, never the wall clock,
## and reset_pose() snaps everything back for a clean class switch.

const HIP_Y := 0.92
const SHOULDER_Y := 1.46
const HEAD_Y := 1.6
const RIGHT_HAND := Vector3(0.08, -0.34, -0.37)

var _mat: ShaderMaterial
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _cape: Array[Node3D] = []
var _cape_rest := PackedFloat32Array([-0.08, -0.12, -0.09])
var _built := false
var _leg_bounds: AABB


func build(look: Dictionary, material: ShaderMaterial) -> void:
	if _built:
		return
	_built = true
	_mat = material
	var robe: Color = look.get("robe", Color(0.2, 0.33, 0.78))
	var robe_dark: Color = look.get("robe_dark", Color(0.12, 0.18, 0.45))
	var trim: Color = look.get("trim", Color(0.95, 0.75, 0.3))
	var cape: Color = look.get("cape", Color(0.55, 0.1, 0.14))
	var eye: Color = look.get("eye", Color(0.5, 0.9, 1.0))
	var skin := Color(0.92, 0.74, 0.6)
	var leather := Color(0.33, 0.2, 0.12)

	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	_torso.add_child(_mi(_torso_mesh(robe, robe_dark, trim, leather, eye)))

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, HEAD_Y, 0)
	_torso.add_child(_head)
	_head.add_child(_mi(_head_mesh(robe_dark, trim, skin, eye)))

	# The left arm hangs and counter-swings; the right arm rests on the weapon.
	# Both are single pivots at the shoulder with the limb baked along the arm.
	_arm_l = Node3D.new()
	_arm_l.name = "ArmLeft"
	_arm_l.position = Vector3(-0.4, SHOULDER_Y, 0.0)
	_torso.add_child(_arm_l)
	_arm_l.add_child(_mi(_arm_mesh(false, robe, trim, skin)))

	_arm_r = Node3D.new()
	_arm_r.name = "ArmRight"
	_arm_r.position = Vector3(0.36, SHOULDER_Y, -0.08)
	_torso.add_child(_arm_r)
	# The baked hand lands exactly on Models.HERO_HAND, so the staff is in-hand.
	_arm_r.add_child(_mi(_arm_mesh(true, robe, trim, skin)))

	# A three-segment cape that trails and sways behind the shoulders.
	_cape.clear()
	var cape0 := Node3D.new()
	cape0.name = "Cape0"
	cape0.position = Vector3(0, 1.5, 0.42)
	_torso.add_child(cape0)
	cape0.add_child(_mi(_cape_seg(0.6, 0.34, cape, trim, false)))
	var cape1 := Node3D.new()
	cape1.name = "Cape1"
	cape1.position = Vector3(0, -0.34, 0)
	cape0.add_child(cape1)
	cape1.add_child(_mi(_cape_seg(0.54, 0.32, cape, trim, false)))
	var cape2 := Node3D.new()
	cape2.name = "Cape2"
	cape2.position = Vector3(0, -0.32, 0)
	cape1.add_child(cape2)
	cape2.add_child(_mi(_cape_seg(0.48, 0.3, cape, trim, true)))
	_cape = [cape0, cape1, cape2]

	_leg_l = Node3D.new()
	_leg_l.name = "LegLeft"
	_leg_l.position = Vector3(-0.17, HIP_Y, 0)
	add_child(_leg_l)
	var leg_mesh := _leg_mesh(robe_dark, leather)
	_leg_bounds = leg_mesh.get_aabb()
	_leg_l.add_child(_mi(leg_mesh))

	_leg_r = Node3D.new()
	_leg_r.name = "LegRight"
	_leg_r.position = Vector3(0.17, HIP_Y, 0)
	add_child(_leg_r)
	_leg_r.add_child(_mi(leg_mesh))

	reset_pose()


## The node the staff mount should ride, so the weapon moves with the torso.
func hand_mount() -> Node3D:
	return _torso


func hand_position() -> Vector3:
	return _arm_r.transform * RIGHT_HAND


func hand_rotation() -> Vector3:
	return _arm_r.rotation


func animate(delta: float, local: Vector2, speed: float, walk: float, cast: float, clock: float) -> void:
	if not _built:
		return
	var move := clampf(speed / 6.0, 0.0, 1.0)
	var swing := sin(walk)
	var fwd := clampf(local.x / 6.0, -1.0, 1.0)
	var side := clampf(local.y / 6.0, -1.0, 1.0)
	var breathe := sin(clock * 1.6) * 0.015 * (1.0 - minf(move, 1.0))

	# Legs stride with the motion, lift the swinging foot, and scissor on a
	# strafe so the hero reads as walking, not sliding, in any direction.
	_leg_l.rotation.x = swing * 0.62 * fwd
	_leg_r.rotation.x = -swing * 0.62 * fwd
	_leg_l.rotation.z = -swing * side * 0.45
	_leg_r.rotation.z = swing * side * 0.45
	_ground_foot(_leg_l, maxf(0.0, cos(walk)) * 0.08 * move)
	_ground_foot(_leg_r, maxf(0.0, -cos(walk)) * 0.08 * move)

	# Torso over the planted feet: forward lean on the move, roll into a strafe,
	# a small forward dip on the cast.
	_torso.position.y = absf(swing) * 0.04 * move + breathe
	_torso.rotation.x = -0.16 * fwd * move - cast * 0.08
	_torso.rotation.z = -0.1 * side * move + swing * 0.03 * move

	_head.rotation.x = -0.05 * fwd * move + sin(clock * 1.1) * 0.02 * (1.0 - move)
	_head.rotation.y = sin(clock * 0.6) * 0.03 * (1.0 - move)

	# Arms: the left counter-swings, the right steadies the weapon and only
	# lifts a little on the cast (the mount thrust handles the recoil).
	_arm_l.rotation.x = -swing * 0.6 * move - cast * 0.15 + breathe * 3.0
	_arm_l.rotation.z = -0.14 - side * 0.1 * move
	_arm_r.rotation.x = swing * 0.12 * move - cast * 0.25
	_arm_r.rotation.z = -0.03 * move

	# Cape: damped follow, so it trails the torso and sways behind the stride.
	var follow := 1.0 - exp(-9.0 * delta)
	var trail := 0.45 * move + 0.4 * maxf(fwd, 0.0) * move
	for i in _cape.size():
		var seg := _cape[i]
		var target_x := (_cape_rest[i] - trail * (0.22 + 0.22 * i)
			+ sin(walk * 0.5 - i * 0.8) * 0.07 * move)
		var target_z := (-side * 0.12 * move * (0.5 + 0.3 * i)
			+ sin(walk * 0.5 - i * 0.8 + 1.0) * 0.05 * move)
		seg.rotation.x = lerpf(seg.rotation.x, target_x, follow)
		seg.rotation.z = lerpf(seg.rotation.z, target_z, follow)


func _ground_foot(leg: Node3D, lift: float) -> void:
	leg.position.y = HIP_Y
	var bounds: AABB = leg.transform * _leg_bounds
	leg.position.y -= bounds.position.y
	leg.position.y += lift


## Neutral rest, used at start-up and on every class switch.
func reset_pose() -> void:
	if not _built:
		return
	_torso.position = Vector3.ZERO
	_torso.rotation = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	_arm_l.rotation = Vector3(0, 0, -0.14)
	_arm_r.rotation = Vector3.ZERO
	_leg_l.rotation = Vector3.ZERO
	_leg_r.rotation = Vector3.ZERO
	_leg_l.position = Vector3(-0.17, HIP_Y, 0)
	_leg_r.position = Vector3(0.17, HIP_Y, 0)
	for i in _cape.size():
		_cape[i].rotation = Vector3(_cape_rest[i], 0, 0)


## Flat snapshot of every posed part, for deterministic pose comparisons.
func pose_signature() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n: Node3D in [_torso, _head, _arm_l, _arm_r, _leg_l, _leg_r]:
		out.push_back(n.position.x)
		out.push_back(n.position.y)
		out.push_back(n.position.z)
		out.push_back(n.rotation.x)
		out.push_back(n.rotation.y)
		out.push_back(n.rotation.z)
	for c: Node3D in _cape:
		out.push_back(c.rotation.x)
		out.push_back(c.rotation.y)
		out.push_back(c.rotation.z)
	return out


# --- meshes -------------------------------------------------------------------

func _mi(mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _torso_mesh(robe: Color, robe_dark: Color, trim: Color, leather: Color, eye: Color) -> ArrayMesh:
	var k := MeshKit.new()
	# Skirt, chest and a mantle over trimmed pauldrons; a glowing chest rune
	# keeps the hero readable in a crowd.
	k.cylinder(0.3, 0.44, 0.44, MeshKit.at(Vector3(0, 0.72, 0)), robe)
	k.cylinder(0.05, 0.05, 0.44, MeshKit.at(Vector3(0, 0.72, -0.3)), trim, 0.25, 6)
	k.cylinder(0.34, 0.32, 0.5, MeshKit.at(Vector3(0, 1.18, 0)), robe)
	k.cylinder(0.3, 0.34, 0.1, MeshKit.at(Vector3(0, 1.45, 0)), robe_dark)
	k.sphere(0.34, MeshKit.at(Vector3(0, 1.5, 0.02), Vector3.ZERO, Vector3(1.35, 0.5, 1.05)), robe_dark)
	for side: float in [-1.0, 1.0]:
		k.sphere(0.15, MeshKit.at(Vector3(0.36 * side, 1.5, 0)), robe)
		k.torus(0.13, 0.17, MeshKit.at(Vector3(0.36 * side, 1.5, 0), Vector3(0, 0, 90)), trim, 0.25, 12)
	k.cylinder(0.32, 0.33, 0.08, MeshKit.at(Vector3(0, 0.98, 0)), leather)
	k.box(Vector3(0.14, 0.11, 0.05), MeshKit.at(Vector3(0, 0.98, -0.29)), trim, 0.3)
	k.sphere(0.05, MeshKit.at(Vector3(0, 1.2, -0.31)), eye, 1.8, 6, 3, true)
	k.cylinder(0.1, 0.11, 0.12, MeshKit.at(Vector3(0, 1.56, 0.01)), robe_dark)
	return k.commit(_mat)


func _head_mesh(robe_dark: Color, trim: Color, skin: Color, eye: Color) -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(0.16, MeshKit.at(Vector3(0, 0.2, -0.02)), skin)
	k.sphere(0.27, MeshKit.at(Vector3(0, 0.25, 0.03), Vector3.ZERO, Vector3(1.02, 1.02, 1.12)), robe_dark)
	k.cylinder(0.0, 0.15, 0.42, MeshKit.at(Vector3(0, 0.4, 0.2), Vector3(60, 0, 0)), robe_dark, 0.0, 8)
	# Place the dark opening and eyes in front of the hood shell, not inside it.
	k.sphere(0.14, MeshKit.at(Vector3(0, 0.2, -0.272), Vector3.ZERO, Vector3(1.0, 1.0, 0.45)), Color(0.05, 0.05, 0.08))
	k.sphere(0.03, MeshKit.at(Vector3(-0.055, 0.23, -0.35)), eye, 2.6, 6, 4)
	k.sphere(0.03, MeshKit.at(Vector3(0.055, 0.23, -0.35)), eye, 2.6, 6, 4)
	k.torus(0.16, 0.19, MeshKit.at(Vector3(0, 0.33, 0.0), Vector3(80, 0, 0)), trim, 0.3, 14)
	return k.commit(_mat)


func _arm_mesh(right: bool, robe: Color, trim: Color, skin: Color) -> ArrayMesh:
	var k := MeshKit.new()
	if right:
		# From the shoulder at the origin out to the hand at Models.HERO_HAND
		# (0.44, 1.12, -0.45) in hero space: (0.08, -0.34, -0.37) from the pivot.
		var hand := RIGHT_HAND
		k.sphere(0.1, MeshKit.at(Vector3.ZERO), robe, 0.0, 6, 4)
		k.capsule(0.075, 0.4, _limb_xf(Vector3.ZERO, hand * 0.8), robe)
		k.cylinder(0.09, 0.08, 0.07, _limb_xf(hand * 0.72, hand * 0.84), trim)
		k.sphere(0.07, MeshKit.at(hand), skin, 0.0, 6, 4)
	else:
		k.sphere(0.1, MeshKit.at(Vector3(0, 0.02, 0.0)), robe, 0.0, 6, 4)
		k.capsule(0.075, 0.42, MeshKit.at(Vector3(0, -0.2, 0.0)), robe)
		k.cylinder(0.085, 0.08, 0.07, MeshKit.at(Vector3(0, -0.4, 0.0)), trim)
		k.sphere(0.065, MeshKit.at(Vector3(0, -0.46, 0.0)), skin, 0.0, 6, 4)
	return k.commit(_mat)


func _cape_seg(width: float, height: float, color: Color, trim: Color, bottom_trim: bool) -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(width, height, 0.05), MeshKit.at(Vector3(0, -height * 0.5, 0)), color)
	if bottom_trim:
		k.box(Vector3(width + 0.02, 0.04, 0.06), MeshKit.at(Vector3(0, -height + 0.02, 0)), trim, 0.25)
	return k.commit(_mat)


func _leg_mesh(robe_dark: Color, leather: Color) -> ArrayMesh:
	var k := MeshKit.new()
	k.capsule(0.11, 0.44, MeshKit.at(Vector3(0, -0.22, 0.0)), robe_dark)
	k.sphere(0.09, MeshKit.at(Vector3(0, -0.44, 0.0)), robe_dark)
	k.capsule(0.085, 0.34, MeshKit.at(Vector3(0, -0.58, 0.02)), robe_dark)
	k.box(Vector3(0.17, 0.14, 0.32), MeshKit.at(Vector3(0, -0.85, -0.05)), leather)
	k.box(Vector3(0.15, 0.08, 0.1), MeshKit.at(Vector3(0, -0.86, -0.2)), leather.darkened(0.25))
	return k.commit(_mat)


## A basis whose local +Y points from `from` to `to` (MeshKit parts grow along Y).
static func _limb_xf(from: Vector3, to: Vector3) -> Transform3D:
	var dir := to - from
	var length := dir.length()
	if length < 0.0001:
		return Transform3D(Basis.IDENTITY, from)
	var y_axis := dir / length
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.000001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis)
	return Transform3D(Basis(x_axis, y_axis, z_axis), (from + to) * 0.5)
