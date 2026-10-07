class_name Models
extends RefCounted
## Every model in the game, built from primitives with MeshKit, plus the
## shader materials that draw them. Models face -Z with their feet at y = 0
## unless noted. Meshes and materials are cached, so asking twice is free.
##
## Colors here are the art direction: change them freely. Enemy skins take the
## swarm's `color` export so each type can still be retinted from the scene.

static var _meshes := {}
static var _materials := {}


## A ShaderMaterial for shaders/<shader>.gdshader with `params` set. Cached by
## shader name plus `key`, so pass a key when the params differ per use.
static func material(shader: String, params := {}, key := "") -> ShaderMaterial:
	var id := shader + "|" + key
	if not _materials.has(id):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/%s.gdshader" % shader)
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_materials[id] = m
	return _materials[id]


static func kit_material() -> ShaderMaterial:
	return material("kit")


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]


# --- enemies ----------------------------------------------------------------------
# Built at height ~1 and scaled to the swarm's body_height.

## The model for an EnemySwarm `kind`, `height` world units tall.
static func enemy(kind: String, skin: Color, height: float) -> ArrayMesh:
	# Drawn thousands of times, so round parts stay coarse (~300 triangles).
	var kit := MeshKit.new()
	kit.max_segments = 6
	kit.max_rings = 3
	match kind:
		"brute":
			_brute(kit, skin)
		"runner":
			_runner(kit, skin)
		"cultist":
			_cultist(kit, skin)
		"boss":
			_boss(kit, skin)
		"wraith":
			_wraith(kit, skin)
		"imp":
			_imp(kit, skin)
		"lich":
			_lich(kit, skin)
		"colossus":
			_colossus(kit, skin)
		"tyrant":
			_tyrant(kit, skin)
		"lancer":
			_lancer(kit, skin)
		"gravedigger":
			_gravedigger(kit, skin)
		"collector":
			_collector(kit, skin)
		"goblin":
			_goblin(kit, skin)
		_:
			_grunt(kit, skin)
	kit.transform_all(Transform3D(Basis.from_scale(Vector3.ONE * height), Vector3.ZERO))
	return kit.commit()


## A hunched ghoul shambling forward with its arms out.
static func _grunt(k: MeshKit, skin: Color) -> void:
	var rags := Color(0.25, 0.2, 0.17)
	var dark := skin.darkened(0.35)
	var eye := Color(1.0, 0.25, 0.1)
	k.capsule(0.075, 0.38, MeshKit.at(Vector3(-0.11, 0.19, 0.02)), dark)
	k.capsule(0.075, 0.38, MeshKit.at(Vector3(0.11, 0.19, 0.02)), dark)
	k.cylinder(0.2, 0.25, 0.2, MeshKit.at(Vector3(0, 0.36, 0.0)), rags, 0.0, 7, true)
	k.sphere(0.24, MeshKit.at(Vector3(0, 0.56, -0.02), Vector3(-25, 0, 0), Vector3(1.15, 1.05, 0.9)), skin)
	k.sphere(0.1, MeshKit.at(Vector3(0, 0.66, 0.12)), dark, 0.0, 5, 2) # hunch
	k.sphere(0.13, MeshKit.at(Vector3(0, 0.78, -0.13), Vector3.ZERO, Vector3(1.0, 1.05, 1.0)), skin)
	k.box(Vector3(0.14, 0.05, 0.08), MeshKit.at(Vector3(0, 0.69, -0.21)), dark)
	k.sphere(0.03, MeshKit.at(Vector3(-0.05, 0.8, -0.24)), eye, 1.0, 4, 2)
	k.sphere(0.03, MeshKit.at(Vector3(0.05, 0.8, -0.24)), eye, 1.0, 4, 2)
	for side: float in [-1.0, 1.0]:
		k.capsule(0.055, 0.42, MeshKit.at(Vector3(0.22 * side, 0.56, -0.2), Vector3(70, 0, -8 * side)), skin)
		k.sphere(0.06, MeshKit.at(Vector3(0.22 * side, 0.5, -0.4)), dark, 0.0, 5, 2)


## A horned ogre with spiked pauldrons and a club.
static func _brute(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.4)
	var belly := skin.lightened(0.18)
	var bone := Color(0.88, 0.84, 0.72)
	var iron := Color(0.24, 0.24, 0.27)
	var wood := Color(0.32, 0.21, 0.13)
	var eye := Color(1.0, 0.6, 0.1)
	k.cylinder(0.09, 0.11, 0.3, MeshKit.at(Vector3(-0.15, 0.15, 0.0)), dark)
	k.cylinder(0.09, 0.11, 0.3, MeshKit.at(Vector3(0.15, 0.15, 0.0)), dark)
	k.cylinder(0.24, 0.28, 0.16, MeshKit.at(Vector3(0, 0.32, 0)), Color(0.3, 0.2, 0.14), 0.0, 8, true)
	k.sphere(0.3, MeshKit.at(Vector3(0, 0.52, 0), Vector3(-10, 0, 0), Vector3(1.1, 1.0, 0.9)), skin)
	k.sphere(0.2, MeshKit.at(Vector3(0, 0.46, -0.13), Vector3.ZERO, Vector3(1.1, 1.0, 0.8)), belly)
	k.sphere(0.12, MeshKit.at(Vector3(0, 0.79, -0.13)), skin)
	k.box(Vector3(0.16, 0.06, 0.06), MeshKit.at(Vector3(0, 0.73, -0.24)), dark)
	k.cylinder(0.0, 0.02, 0.06, MeshKit.at(Vector3(-0.05, 0.78, -0.26)), bone, 0.0, 5) # tusks
	k.cylinder(0.0, 0.02, 0.06, MeshKit.at(Vector3(0.05, 0.78, -0.26)), bone, 0.0, 5)
	k.sphere(0.025, MeshKit.at(Vector3(-0.045, 0.82, -0.235)), eye, 1.2, 4, 2)
	k.sphere(0.025, MeshKit.at(Vector3(0.045, 0.82, -0.235)), eye, 1.2, 4, 2)
	for side: float in [-1.0, 1.0]:
		k.cylinder(0.0, 0.035, 0.18, MeshKit.at(Vector3(0.1 * side, 0.92, -0.1), Vector3(-15, 0, -35 * side)), bone, 0.0, 6)
		k.sphere(0.13, MeshKit.at(Vector3(0.3 * side, 0.68, 0.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), iron, 0.0, 8, 5, true)
		k.cylinder(0.0, 0.035, 0.12, MeshKit.at(Vector3(0.34 * side, 0.8, 0.0), Vector3(0, 0, -25 * side)), bone, 0.0, 5)
		k.capsule(0.08, 0.4, MeshKit.at(Vector3(0.36 * side, 0.45, -0.04), Vector3(10, 0, 8 * side)), skin)
		k.sphere(0.085, MeshKit.at(Vector3(0.38 * side, 0.25, -0.08)), dark, 0.0, 5, 2)
	# Club in the right hand, raised over the shoulder.
	k.cylinder(0.05, 0.03, 0.6, MeshKit.at(Vector3(0.4, 0.42, -0.2), Vector3(-55, 0, 0)), wood, 0.0, 7, true)
	k.sphere(0.09, MeshKit.at(Vector3(0.4, 0.6, -0.42)), wood, 0.0, 5, 2, true)
	for a in 4:
		var dir := Vector3(cos(a * PI / 2.0), 0.0, sin(a * PI / 2.0))
		k.cylinder(0.0, 0.02, 0.07, MeshKit.at(Vector3(0.4, 0.6, -0.42) + dir * 0.09, Vector3(0, -a * 90.0, 90)), iron, 0.0, 4)


## A lean, glowing hellhound: fast and low.
static func _runner(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.5)
	var ember := skin.lightened(0.2)
	var eye := Color(1.0, 1.0, 0.6)
	for x: float in [-0.09, 0.09]:
		for z: float in [-0.17, 0.17]:
			k.cylinder(0.045, 0.03, 0.3, MeshKit.at(Vector3(x * 1.2, 0.15, z)), dark, 0.0, 6)
	k.capsule(0.17, 0.56, MeshKit.at(Vector3(0, 0.4, 0.0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.85)), skin)
	k.sphere(0.15, MeshKit.at(Vector3(0, 0.5, -0.3)), skin)
	k.box(Vector3(0.12, 0.08, 0.16), MeshKit.at(Vector3(0, 0.45, -0.44)), dark)
	k.sphere(0.028, MeshKit.at(Vector3(-0.06, 0.54, -0.43)), eye, 1.5, 4, 2)
	k.sphere(0.028, MeshKit.at(Vector3(0.06, 0.54, -0.43)), eye, 1.5, 4, 2)
	for side: float in [-1.0, 1.0]:
		k.cylinder(0.0, 0.04, 0.16, MeshKit.at(Vector3(0.08 * side, 0.66, -0.26), Vector3(20, 0, -20 * side)), dark, 0.0, 5)
	# A burning mane along the back and a whip tail.
	for i in 4:
		k.cylinder(0.0, 0.05, 0.16, MeshKit.at(Vector3(0, 0.56, -0.15 + i * 0.1), Vector3(30, 0, 0)), ember, 0.6, 5)
	k.cylinder(0.01, 0.045, 0.32, MeshKit.at(Vector3(0, 0.48, 0.4), Vector3(-60, 0, 0)), ember, 0.6, 5)


## A robed fire cultist holding up a burning orb. `skin` is the robe color.
static func _cultist(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.45)
	var trim := Color(0.85, 0.3, 0.15)
	var flesh := Color(0.75, 0.68, 0.6)
	var fire := Color(1.0, 0.45, 0.2)
	k.cylinder(0.14, 0.3, 0.62, MeshKit.at(Vector3(0, 0.31, 0)), skin, 0.0, 8)
	k.cylinder(0.31, 0.32, 0.05, MeshKit.at(Vector3(0, 0.03, 0)), trim, 0.3, 8)
	k.cylinder(0.17, 0.14, 0.24, MeshKit.at(Vector3(0, 0.72, 0)), skin, 0.0, 8)
	k.sphere(0.2, MeshKit.at(Vector3(0, 0.84, 0.0), Vector3.ZERO, Vector3(1.3, 0.45, 1.0)), dark)
	# Pointed hood with a dark face and burning eyes.
	k.sphere(0.13, MeshKit.at(Vector3(0, 0.95, -0.02)), dark)
	k.cylinder(0.0, 0.12, 0.26, MeshKit.at(Vector3(0, 1.12, 0.02), Vector3(-10, 0, 0)), dark, 0.0, 6)
	k.sphere(0.09, MeshKit.at(Vector3(0, 0.93, -0.08), Vector3.ZERO, Vector3(1.0, 1.0, 0.6)), Color(0.04, 0.03, 0.04), 0.0, 5, 2)
	k.sphere(0.02, MeshKit.at(Vector3(-0.035, 0.95, -0.13)), fire, 2.0, 4, 2)
	k.sphere(0.02, MeshKit.at(Vector3(0.035, 0.95, -0.13)), fire, 2.0, 4, 2)
	# Arms raised forward around a floating fireball.
	for side: float in [-1.0, 1.0]:
		k.capsule(0.045, 0.34, MeshKit.at(Vector3(0.15 * side, 0.74, -0.14), Vector3(65, 0, 15 * side)), skin)
		k.sphere(0.04, MeshKit.at(Vector3(0.1 * side, 0.68, -0.28)), flesh, 0.0, 5, 2)
	k.sphere(0.08, MeshKit.at(Vector3(0, 0.74, -0.34)), fire, 2.2, 6, 3)
	k.sphere(0.12, MeshKit.at(Vector3(0, 0.74, -0.34)), Color(1.0, 0.3, 0.1), 0.8, 6, 3)


## The Lancer: a lean armored skeleton leaning into a long spear, a round
## shield on its back arm. Charges in straight lines (see EnemySwarm.charger).
static func _lancer(k: MeshKit, skin: Color) -> void:
	var bone := Color(0.85, 0.82, 0.72)
	var iron := skin.darkened(0.2)
	var steel := Color(0.72, 0.74, 0.78)
	var eye := Color(1.0, 0.35, 0.2)
	# Legs, a skirt of plates and a leaning torso.
	for side: float in [-1.0, 1.0]:
		k.capsule(0.05, 0.42, MeshKit.at(Vector3(0.09 * side, 0.22, 0.02)), bone, 0.0, 6)
		k.box(Vector3(0.1, 0.06, 0.16), MeshKit.at(Vector3(0.09 * side, 0.03, -0.03)), iron)
	k.cylinder(0.14, 0.2, 0.18, MeshKit.at(Vector3(0, 0.46, 0)), iron, 0.0, 8)
	k.cylinder(0.17, 0.13, 0.34, MeshKit.at(Vector3(0, 0.68, -0.05), Vector3(-18, 0, 0)), iron, 0.0, 8)
	k.box(Vector3(0.36, 0.06, 0.18), MeshKit.at(Vector3(0, 0.86, -0.1), Vector3(-18, 0, 0)), steel)
	# Skull in a crested helm.
	k.sphere(0.11, MeshKit.at(Vector3(0, 0.98, -0.16)), bone, 0.0, 7, 4)
	k.cylinder(0.12, 0.13, 0.1, MeshKit.at(Vector3(0, 1.03, -0.15)), iron, 0.0, 8)
	k.box(Vector3(0.03, 0.12, 0.2), MeshKit.at(Vector3(0, 1.12, -0.13)), Color(0.75, 0.15, 0.1))
	k.sphere(0.022, MeshKit.at(Vector3(-0.04, 0.98, -0.26)), eye, 2.2, 4, 2)
	k.sphere(0.022, MeshKit.at(Vector3(0.04, 0.98, -0.26)), eye, 2.2, 4, 2)
	# The lance, couched forward and low, and the shield.
	k.capsule(0.04, 0.3, MeshKit.at(Vector3(0.14, 0.72, -0.18), Vector3(70, 0, 0)), bone, 0.0, 5)
	k.cylinder(0.025, 0.03, 1.5, MeshKit.at(Vector3(0.15, 0.66, -0.55), Vector3(-82, 0, 0)), Color(0.35, 0.24, 0.16), 0.0, 5)
	k.cylinder(0.0, 0.06, 0.28, MeshKit.at(Vector3(0.15, 0.62, -1.38), Vector3(-82, 0, 0)), steel, 0.4, 6)
	k.cylinder(0.2, 0.2, 0.05, MeshKit.at(Vector3(-0.2, 0.68, -0.05), Vector3(0, 0, 90)), iron, 0.0, 10)
	k.sphere(0.04, MeshKit.at(Vector3(-0.23, 0.68, -0.05)), steel, 0.3, 5, 2)


## The Gravedigger: hunched in a long coat, a shovel over one shoulder and a
## lantern of stolen souls. Raises the dead (see EnemySwarm.raise_interval).
static func _gravedigger(k: MeshKit, skin: Color) -> void:
	var coat := skin
	var dark := skin.darkened(0.5)
	var flesh := Color(0.62, 0.66, 0.55)
	var wood := Color(0.38, 0.26, 0.16)
	var soul := Color(0.55, 0.9, 1.0)
	k.cylinder(0.16, 0.3, 0.6, MeshKit.at(Vector3(0, 0.3, 0.04)), coat, 0.0, 8)
	k.sphere(0.24, MeshKit.at(Vector3(0, 0.66, 0.06), Vector3(-25, 0, 0), Vector3(1.1, 0.9, 1.0)), coat, 0.0, 8, 4)
	# A hunched head under a wide-brimmed hat.
	k.sphere(0.11, MeshKit.at(Vector3(0, 0.78, -0.16)), flesh, 0.0, 7, 4)
	k.cylinder(0.24, 0.24, 0.025, MeshKit.at(Vector3(0, 0.88, -0.14)), dark, 0.0, 10)
	k.cylinder(0.1, 0.12, 0.14, MeshKit.at(Vector3(0, 0.96, -0.14)), dark, 0.0, 8)
	k.sphere(0.02, MeshKit.at(Vector3(-0.04, 0.79, -0.26)), soul, 2.0, 4, 2)
	k.sphere(0.02, MeshKit.at(Vector3(0.04, 0.79, -0.26)), soul, 2.0, 4, 2)
	# Shovel over the right shoulder.
	k.cylinder(0.02, 0.02, 1.0, MeshKit.at(Vector3(0.2, 0.78, 0.08), Vector3(-50, 0, -15)), wood, 0.0, 5)
	k.box(Vector3(0.16, 0.2, 0.03), MeshKit.at(Vector3(0.28, 1.12, 0.42), Vector3(-50, 0, -15)), Color(0.5, 0.5, 0.52))
	# A soul lantern held out in the left hand.
	k.capsule(0.04, 0.3, MeshKit.at(Vector3(-0.2, 0.6, -0.12), Vector3(50, 0, 20)), coat, 0.0, 5)
	k.box(Vector3(0.11, 0.15, 0.11), MeshKit.at(Vector3(-0.26, 0.42, -0.26)), Color(0.2, 0.2, 0.22))
	k.sphere(0.06, MeshKit.at(Vector3(-0.26, 0.42, -0.26)), soul, 2.4, 6, 3)


## The Debt Collector: a gaunt figure in a long coat and tall hat, a ledger
## in one hand and a glowing chain in the other.
static func _collector(k: MeshKit, skin: Color) -> void:
	var coat := skin
	var dark := skin.darkened(0.55)
	var pale := Color(0.8, 0.78, 0.72)
	var gold := Color(1.0, 0.8, 0.35)
	k.cylinder(0.12, 0.3, 0.72, MeshKit.at(Vector3(0, 0.36, 0)), coat, 0.0, 8)
	k.cylinder(0.15, 0.12, 0.3, MeshKit.at(Vector3(0, 0.84, 0)), coat, 0.0, 8)
	k.box(Vector3(0.36, 0.05, 0.16), MeshKit.at(Vector3(0, 0.98, 0)), dark)
	k.sphere(0.1, MeshKit.at(Vector3(0, 1.08, -0.02), Vector3.ZERO, Vector3(0.85, 1.1, 0.9)), pale, 0.0, 7, 4)
	k.cylinder(0.17, 0.17, 0.02, MeshKit.at(Vector3(0, 1.17, 0)), dark, 0.0, 10)
	k.cylinder(0.1, 0.1, 0.24, MeshKit.at(Vector3(0, 1.3, 0)), dark, 0.0, 8)
	k.cylinder(0.105, 0.105, 0.04, MeshKit.at(Vector3(0, 1.21, 0)), gold, 0.6, 8)
	k.sphere(0.02, MeshKit.at(Vector3(-0.035, 1.1, -0.09)), gold, 2.5, 4, 2)
	k.sphere(0.02, MeshKit.at(Vector3(0.035, 1.1, -0.09)), gold, 2.5, 4, 2)
	# The ledger, held open, and the chain hanging from the other hand.
	k.capsule(0.035, 0.38, MeshKit.at(Vector3(-0.2, 0.78, -0.12), Vector3(55, 0, 15)), coat, 0.0, 5)
	k.box(Vector3(0.22, 0.03, 0.16), MeshKit.at(Vector3(-0.24, 0.66, -0.3), Vector3(20, 0, 0)), Color(0.9, 0.86, 0.72))
	k.capsule(0.035, 0.38, MeshKit.at(Vector3(0.2, 0.7, -0.05), Vector3(15, 0, -12)), coat, 0.0, 5)
	for i in 6:
		k.sphere(0.035, MeshKit.at(Vector3(0.24 + 0.02 * sin(i), 0.5 - i * 0.07, -0.08)), gold, 1.4, 5, 2)


## The Ogre Warlord: a brute in a crown and iron plate with a great hammer.
static func _boss(k: MeshKit, skin: Color) -> void:
	_brute(k, skin)
	var gold := Color(1.0, 0.78, 0.3)
	var iron := Color(0.2, 0.2, 0.23)
	var rune := Color(1.0, 0.35, 0.15)
	# Crown
	k.cylinder(0.11, 0.12, 0.05, MeshKit.at(Vector3(0, 0.9, -0.13)), gold, 0.3, 8)
	for a in 6:
		var ang := a * TAU / 6.0
		k.cylinder(0.0, 0.03, 0.09, MeshKit.at(Vector3(cos(ang) * 0.1, 0.96, -0.13 + sin(ang) * 0.1)), gold, 0.4, 4)
	# Chest plate with a glowing rune, and a belt.
	k.box(Vector3(0.42, 0.3, 0.1), MeshKit.at(Vector3(0, 0.55, -0.24), Vector3(-12, 0, 0)), iron)
	k.box(Vector3(0.08, 0.16, 0.02), MeshKit.at(Vector3(0, 0.57, -0.3), Vector3(-12, 0, 0)), rune, 1.5)
	k.cylinder(0.3, 0.3, 0.06, MeshKit.at(Vector3(0, 0.38, 0)), Color(0.35, 0.22, 0.12), 0.0, 8)
	k.box(Vector3(0.1, 0.08, 0.04), MeshKit.at(Vector3(0, 0.38, -0.3)), gold, 0.3)
	# A great hammer in the left hand, resting on the ground.
	k.cylinder(0.025, 0.025, 0.75, MeshKit.at(Vector3(-0.42, 0.38, -0.12), Vector3(-15, 0, -8)), Color(0.3, 0.2, 0.12), 0.0, 6)
	k.box(Vector3(0.2, 0.14, 0.16), MeshKit.at(Vector3(-0.47, 0.06, -0.02)), iron)
	k.box(Vector3(0.05, 0.1, 0.17), MeshKit.at(Vector3(-0.47, 0.06, -0.02)), rune, 1.2)


## An ice wraith: a hooded, legless spirit trailing frost. Its "legs" are the
## tattered hem, so the walk cycle makes it ripple.
static func _wraith(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.5)
	var eye := Color(0.6, 0.95, 1.0)
	k.cylinder(0.12, 0.04, 0.45, MeshKit.at(Vector3(0, 0.3, 0.02)), skin.darkened(0.2), 0.2, 6)
	for a in 5:
		var ang := a * TAU / 5.0
		k.cylinder(0.0, 0.06, 0.3, MeshKit.at(Vector3(cos(ang) * 0.1, 0.12, sin(ang) * 0.1), Vector3(180, 0, 0)), skin.darkened(0.3), 0.3, 4)
	k.sphere(0.2, MeshKit.at(Vector3(0, 0.58, 0), Vector3(-15, 0, 0), Vector3(1.0, 1.2, 0.85)), skin)
	k.sphere(0.14, MeshKit.at(Vector3(0, 0.84, -0.06)), dark)
	k.cylinder(0.0, 0.12, 0.22, MeshKit.at(Vector3(0, 1.0, 0.03), Vector3(-20, 0, 0)), dark, 0.0, 6)
	k.sphere(0.09, MeshKit.at(Vector3(0, 0.83, -0.12), Vector3.ZERO, Vector3(1.0, 0.9, 0.6)), Color(0.02, 0.04, 0.06), 0.0, 5, 2)
	k.sphere(0.025, MeshKit.at(Vector3(-0.04, 0.85, -0.17)), eye, 2.0, 4, 2)
	k.sphere(0.025, MeshKit.at(Vector3(0.04, 0.85, -0.17)), eye, 2.0, 4, 2)
	for side: float in [-1.0, 1.0]:
		k.capsule(0.04, 0.4, MeshKit.at(Vector3(0.2 * side, 0.58, -0.16), Vector3(60, 0, 20 * side)), skin)
		k.cylinder(0.0, 0.03, 0.16, MeshKit.at(Vector3(0.22 * side, 0.46, -0.34), Vector3(110, 0, 0)), eye, 0.8, 4)


## A small winged imp with a forked tail.
static func _imp(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.45)
	var eye := Color(1.0, 0.9, 0.3)
	var horn := Color(0.15, 0.1, 0.1)
	k.capsule(0.05, 0.3, MeshKit.at(Vector3(-0.08, 0.15, 0.02)), dark)
	k.capsule(0.05, 0.3, MeshKit.at(Vector3(0.08, 0.15, 0.02)), dark)
	k.sphere(0.18, MeshKit.at(Vector3(0, 0.42, 0), Vector3(-15, 0, 0), Vector3(1.0, 1.1, 0.9)), skin)
	k.sphere(0.13, MeshKit.at(Vector3(0, 0.66, -0.05)), skin)
	k.sphere(0.025, MeshKit.at(Vector3(-0.05, 0.68, -0.16)), eye, 2.0, 4, 2)
	k.sphere(0.025, MeshKit.at(Vector3(0.05, 0.68, -0.16)), eye, 2.0, 4, 2)
	for side: float in [-1.0, 1.0]:
		k.cylinder(0.0, 0.03, 0.15, MeshKit.at(Vector3(0.07 * side, 0.8, -0.02), Vector3(-20, 0, -30 * side)), horn, 0.0, 4)
		# Bat wings: two thin flat triangles spread wide.
		k.box(Vector3(0.32, 0.18, 0.02), MeshKit.at(Vector3(0.24 * side, 0.55, 0.12), Vector3(0, 25 * side, -25 * side)), dark, 0.1)
		k.capsule(0.035, 0.22, MeshKit.at(Vector3(0.17 * side, 0.42, -0.1), Vector3(60, 0, 15 * side)), skin)
	k.cylinder(0.005, 0.03, 0.4, MeshKit.at(Vector3(0, 0.25, 0.26), Vector3(-55, 0, 0)), dark, 0.0, 4)
	k.cylinder(0.0, 0.05, 0.08, MeshKit.at(Vector3(0, 0.12, 0.42), Vector3(-120, 0, 0)), Color(1.0, 0.45, 0.1), 1.0, 4)


## The Lich King: a towering robed skeleton with a crown of soulfire and a staff.
static func _lich(k: MeshKit, skin: Color) -> void:
	var robe := skin.darkened(0.35)
	var bone := Color(0.88, 0.86, 0.78)
	var soul := Color(0.45, 0.85, 1.0)
	var gold := Color(0.95, 0.75, 0.3)
	k.cylinder(0.16, 0.38, 0.6, MeshKit.at(Vector3(0, 0.3, 0)), robe, 0.0, 8)
	k.cylinder(0.39, 0.4, 0.04, MeshKit.at(Vector3(0, 0.02, 0)), soul, 0.8, 8)
	k.cylinder(0.2, 0.16, 0.25, MeshKit.at(Vector3(0, 0.7, 0)), robe, 0.0, 8)
	k.sphere(0.28, MeshKit.at(Vector3(0, 0.82, 0.02), Vector3.ZERO, Vector3(1.35, 0.45, 1.0)), robe.darkened(0.3))
	k.box(Vector3(0.12, 0.22, 0.04), MeshKit.at(Vector3(0, 0.66, -0.2)), bone) # ribs
	k.sphere(0.12, MeshKit.at(Vector3(0, 0.95, -0.02), Vector3.ZERO, Vector3(0.9, 1.1, 1.0)), bone)
	k.sphere(0.03, MeshKit.at(Vector3(-0.04, 0.96, -0.12)), soul, 3.0, 4, 2)
	k.sphere(0.03, MeshKit.at(Vector3(0.04, 0.96, -0.12)), soul, 3.0, 4, 2)
	k.cylinder(0.11, 0.12, 0.04, MeshKit.at(Vector3(0, 1.06, -0.02)), gold, 0.3, 8)
	for a in 5:
		var ang := a * TAU / 5.0
		k.cylinder(0.0, 0.025, 0.12, MeshKit.at(Vector3(cos(ang) * 0.1, 1.13, -0.02 + sin(ang) * 0.1)), soul, 1.5, 4)
	for side: float in [-1.0, 1.0]:
		k.sphere(0.1, MeshKit.at(Vector3(0.27 * side, 0.83, 0.0)), bone, 0.0, 6, 3, true) # pauldron skulls
		k.capsule(0.035, 0.42, MeshKit.at(Vector3(0.28 * side, 0.62, -0.08), Vector3(30, 0, 10 * side)), bone)
	# Staff topped with a cage holding a burning soul.
	k.cylinder(0.02, 0.02, 1.0, MeshKit.at(Vector3(0.36, 0.55, -0.22)), Color(0.2, 0.15, 0.25), 0.0, 6)
	k.torus(0.06, 0.08, MeshKit.at(Vector3(0.36, 1.1, -0.22)), gold, 0.3, 10)
	k.sphere(0.07, MeshKit.at(Vector3(0.36, 1.1, -0.22)), soul, 3.0, 6, 3)
	for a in 4:
		var ang := a * TAU / 4.0
		k.sphere(0.05, MeshKit.at(Vector3(cos(ang) * 0.5, 0.75 + 0.1 * (a % 2), sin(ang) * 0.5)), soul, 2.5, 5, 3)


## The Frost Colossus: a giant of packed ice and stone, crowned with spikes.
static func _colossus(k: MeshKit, skin: Color) -> void:
	_brute(k, skin)
	var ice := Color(0.65, 0.9, 1.0)
	for i in 9:
		var ang := i * 0.7
		var at := Vector3(cos(ang) * 0.22, 0.6 + 0.1 * sin(i * 1.3), 0.08 + sin(ang) * 0.12)
		k.cylinder(0.0, 0.06, 0.3, MeshKit.at(at, Vector3(-40 + i * 9, i * 40, 20 - i * 6)), ice, 0.9, 5, true)
	for i in 5:
		k.cylinder(0.0, 0.035, 0.2, MeshKit.at(Vector3(-0.12 + i * 0.06, 0.95, -0.12), Vector3(0, 0, -20 + i * 10)), ice, 1.2, 4, true)
	k.box(Vector3(0.18, 0.2, 0.16), MeshKit.at(Vector3(0.4, 0.62, -0.42)), ice, 0.6)


## The Ashen Tyrant: a horned demon king with great wings and a molten core.
static func _tyrant(k: MeshKit, skin: Color) -> void:
	_brute(k, skin)
	var horn := Color(0.12, 0.08, 0.08)
	var magma := Color(1.0, 0.45, 0.1)
	for side: float in [-1.0, 1.0]:
		k.cylinder(0.0, 0.05, 0.35, MeshKit.at(Vector3(0.12 * side, 1.0, -0.05), Vector3(-30, 0, -45 * side)), horn, 0.0, 6)
		# Wings: a spar and two membranes each.
		k.capsule(0.03, 0.7, MeshKit.at(Vector3(0.45 * side, 0.95, 0.25), Vector3(-20, 0, -55 * side)), horn)
		k.box(Vector3(0.6, 0.5, 0.02), MeshKit.at(Vector3(0.5 * side, 0.8, 0.3), Vector3(20, 30 * side, -20 * side)), skin.darkened(0.55), 0.15)
	k.sphere(0.12, MeshKit.at(Vector3(0, 0.55, -0.24)), magma, 2.2, 6, 3)
	for i in 4:
		k.box(Vector3(0.03, 0.18, 0.02), MeshKit.at(Vector3(-0.12 + i * 0.08, 0.5, -0.27), Vector3(0, 0, 15 - i * 10)), magma, 1.6)


## A treasure goblin: a little hunched thief hauling an overstuffed sack.
static func _goblin(k: MeshKit, skin: Color) -> void:
	var dark := skin.darkened(0.4)
	var sack := Color(0.5, 0.36, 0.2)
	var gold := Color(1.0, 0.82, 0.3)
	k.capsule(0.05, 0.3, MeshKit.at(Vector3(-0.08, 0.15, 0)), dark)
	k.capsule(0.05, 0.3, MeshKit.at(Vector3(0.08, 0.15, 0)), dark)
	k.sphere(0.17, MeshKit.at(Vector3(0, 0.4, -0.04), Vector3(-30, 0, 0)), skin)
	k.sphere(0.13, MeshKit.at(Vector3(0, 0.58, -0.16)), skin)
	for side: float in [-1.0, 1.0]:
		k.cylinder(0.0, 0.05, 0.22, MeshKit.at(Vector3(0.14 * side, 0.62, -0.14), Vector3(0, 0, -75 * side)), skin, 0.0, 4) # ears
		k.sphere(0.022, MeshKit.at(Vector3(0.045 * side, 0.6, -0.27)), Color(1.0, 0.9, 0.3), 2.0, 4, 2)
	k.sphere(0.26, MeshKit.at(Vector3(0, 0.62, 0.2), Vector3.ZERO, Vector3(1.0, 1.1, 0.9)), sack)
	k.cylinder(0.05, 0.08, 0.08, MeshKit.at(Vector3(0, 0.9, 0.22)), sack.darkened(0.3), 0.0, 6)
	for i in 5:
		k.sphere(0.05, MeshKit.at(Vector3(-0.1 + i * 0.05, 0.92 + (i % 2) * 0.03, 0.2)), gold, 1.2, 5, 2)


# --- hero -------------------------------------------------------------------------

## The hero's body (everything but the weapon), about 2 units tall, in a hero
## class's colors (see HeroClass).
static func hero_body(look := {}) -> ArrayMesh:
	return _cached("hero|" + str(look), func() -> ArrayMesh:
		var k := MeshKit.new()
		var robe: Color = look.get("robe", Color(0.2, 0.33, 0.78))
		var robe_dark: Color = look.get("robe_dark", Color(0.12, 0.18, 0.45))
		var trim: Color = look.get("trim", Color(0.95, 0.75, 0.3))
		var skin := Color(0.92, 0.74, 0.6)
		var cape: Color = look.get("cape", Color(0.55, 0.1, 0.14))
		var leather := Color(0.33, 0.2, 0.12)
		var eye: Color = look.get("eye", Color(0.5, 0.9, 1.0))
		k.cylinder(0.3, 0.52, 1.0, MeshKit.at(Vector3(0, 0.55, 0)), robe, 0.0, 12)
		k.cylinder(0.53, 0.55, 0.08, MeshKit.at(Vector3(0, 0.08, 0)), trim, 0.15, 12)
		k.cylinder(0.12, 0.12, 0.98, MeshKit.at(Vector3(0, 0.56, -0.38), Vector3(-17, 0, 0)), trim, 0.1, 6) # front stripe
		k.cylinder(0.31, 0.31, 0.1, MeshKit.at(Vector3(0, 1.08, 0)), leather, 0.0, 12)
		k.box(Vector3(0.12, 0.12, 0.05), MeshKit.at(Vector3(0, 1.08, -0.31)), trim, 0.3)
		k.cylinder(0.34, 0.29, 0.45, MeshKit.at(Vector3(0, 1.33, 0)), robe, 0.0, 12)
		k.sphere(0.36, MeshKit.at(Vector3(0, 1.56, 0.02), Vector3.ZERO, Vector3(1.3, 0.5, 1.0)), robe_dark)
		k.box(Vector3(0.7, 1.25, 0.05), MeshKit.at(Vector3(0, 0.95, 0.3), Vector3(12, 0, 0)), cape)
		k.sphere(0.19, MeshKit.at(Vector3(0, 1.82, -0.02)), skin)
		# Hood with a pointed tip falling back, eyes glowing out of its shadow.
		k.sphere(0.25, MeshKit.at(Vector3(0, 1.88, 0.04), Vector3.ZERO, Vector3(1.0, 1.0, 1.05)), robe_dark)
		k.cylinder(0.0, 0.16, 0.42, MeshKit.at(Vector3(0, 2.02, 0.22), Vector3(60, 0, 0)), robe_dark, 0.0, 8)
		k.sphere(0.15, MeshKit.at(Vector3(0, 1.8, -0.1), Vector3.ZERO, Vector3(1.0, 1.0, 0.6)), Color(0.05, 0.05, 0.08))
		k.sphere(0.028, MeshKit.at(Vector3(-0.06, 1.83, -0.18)), eye, 2.0, 6, 4)
		k.sphere(0.028, MeshKit.at(Vector3(0.06, 1.83, -0.18)), eye, 2.0, 6, 4)
		# Arms: the left hangs, the right reaches forward to hold the weapon.
		k.capsule(0.09, 0.62, MeshKit.at(Vector3(-0.42, 1.25, 0.0), Vector3(0, 0, -12)), robe)
		k.sphere(0.08, MeshKit.at(Vector3(-0.48, 0.95, 0.0)), skin)
		k.capsule(0.09, 0.6, MeshKit.at(Vector3(0.4, 1.3, -0.18), Vector3(55, 0, 10)), robe)
		k.cylinder(0.11, 0.1, 0.1, MeshKit.at(Vector3(0.42, 1.18, -0.38), Vector3(55, 0, 10)), trim, 0.2, 8)
		k.sphere(0.08, MeshKit.at(Vector3(0.44, 1.12, -0.45)), skin)
		return k.commit(material("kit", {"rim_strength": 0.6, "rim_color": Color(0.6, 0.8, 1.0)}, "hero")))


## Where the weapon model is held, in the hero's local space.
const HERO_HAND := Vector3(0.44, 1.12, -0.45)


# --- items ------------------------------------------------------------------------
# Item models stand about 0.8 units tall, centered on their middle, so they
# can float over the ground or sit in a hand. `accent` is the gem color, which
# is the rarity color for loot.

static func item(slot: String, base_name: String, accent: Color) -> ArrayMesh:
	return _cached("item|%s|%s|%s" % [slot, base_name, accent.to_html()], func() -> ArrayMesh:
		var k := MeshKit.new()
		_item_parts(k, base_name, accent)
		return k.commit(kit_material()))


static func _item_parts(k: MeshKit, base_name: String, accent: Color) -> void:
	var gold := Color(0.95, 0.75, 0.3)
	var silver := Color(0.75, 0.78, 0.85)
	var iron := Color(0.4, 0.42, 0.47)
	var wood := Color(0.4, 0.26, 0.15)
	var leather := Color(0.42, 0.27, 0.16)
	var cloth := Color(0.2, 0.3, 0.6)
	match base_name:
		# Weapons: the hilt end is at the bottom, the business end up.
		"Wand":
			k.cylinder(0.025, 0.04, 0.7, MeshKit.at(Vector3(0, -0.05, 0)), wood, 0.0, 6)
			k.cylinder(0.05, 0.05, 0.05, MeshKit.at(Vector3(0, 0.3, 0)), gold, 0.1, 8)
			k.sphere(0.08, MeshKit.at(Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(0.8, 1.4, 0.8)), accent, 1.0, 5, 2, true)
		"Staff":
			k.cylinder(0.035, 0.045, 1.5, MeshKit.at(Vector3(0, -0.2, 0)), wood, 0.0, 7, true)
			k.torus(0.1, 0.14, MeshKit.at(Vector3(0, 0.66, 0), Vector3(90, 0, 0)), gold, 0.1, 12)
			for a in 3:
				k.cylinder(0.0, 0.025, 0.2, MeshKit.at(Vector3(0, 0.62, 0) + Vector3(cos(a * TAU / 3.0), 0, sin(a * TAU / 3.0)) * 0.07, Vector3(0, -a * 120.0, 18)), gold, 0.1, 4)
			k.sphere(0.1, MeshKit.at(Vector3(0, 0.68, 0), Vector3.ZERO, Vector3(0.9, 1.3, 0.9)), accent, 1.2, 6, 2, true)
		"Orb":
			k.cylinder(0.03, 0.05, 0.25, MeshKit.at(Vector3(0, -0.25, 0)), wood, 0.0, 6)
			k.cylinder(0.12, 0.05, 0.1, MeshKit.at(Vector3(0, -0.08, 0)), gold, 0.1, 8)
			k.sphere(0.17, MeshKit.at(Vector3(0, 0.1, 0)), accent, 1.0, 12, 8)
			k.torus(0.2, 0.23, MeshKit.at(Vector3(0, 0.1, 0), Vector3(70, 0, 20)), gold, 0.2, 14)
		# Helms
		"Cap":
			k.sphere(0.26, MeshKit.at(Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), leather)
			k.cylinder(0.28, 0.3, 0.06, MeshKit.at(Vector3(0, -0.1, 0)), leather.darkened(0.3), 0.0, 10)
			k.box(Vector3(0.08, 0.08, 0.03), MeshKit.at(Vector3(0, 0.0, -0.26)), accent, 0.8)
		"Circlet":
			k.torus(0.2, 0.25, MeshKit.at(Vector3(0, 0, 0)), gold, 0.15, 16)
			k.cylinder(0.0, 0.05, 0.12, MeshKit.at(Vector3(0, 0.07, -0.23)), gold, 0.15, 5)
			k.sphere(0.05, MeshKit.at(Vector3(0, 0.02, -0.25)), accent, 1.2, 6, 2, true)
		"Helm":
			k.sphere(0.26, MeshKit.at(Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.0, 1.05, 1.05)), iron, 0.0, 10, 6, true)
			k.box(Vector3(0.36, 0.06, 0.06), MeshKit.at(Vector3(0, -0.03, -0.25)), Color(0.08, 0.08, 0.1))
			k.box(Vector3(0.05, 0.3, 0.05), MeshKit.at(Vector3(0, 0.05, -0.26)), iron.lightened(0.2))
			for side: float in [-1.0, 1.0]:
				k.cylinder(0.0, 0.05, 0.28, MeshKit.at(Vector3(0.24 * side, 0.18, 0), Vector3(0, 0, -40 * side)), Color(0.9, 0.86, 0.75), 0.0, 6)
			k.sphere(0.04, MeshKit.at(Vector3(0, 0.22, -0.2)), accent, 1.0, 6, 2, true)
		# Chest pieces
		"Robe":
			k.cylinder(0.18, 0.3, 0.6, MeshKit.at(Vector3(0, -0.05, 0)), cloth, 0.0, 10)
			k.cylinder(0.2, 0.2, 0.06, MeshKit.at(Vector3(0, 0.12, 0)), gold, 0.1, 10)
			k.sphere(0.22, MeshKit.at(Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.3, 0.5, 1.0)), cloth.darkened(0.3))
			k.sphere(0.05, MeshKit.at(Vector3(0, 0.12, -0.2)), accent, 1.0, 6, 2, true)
		"Vest":
			k.box(Vector3(0.44, 0.5, 0.26), MeshKit.at(Vector3(0, 0, 0)), leather)
			for side: float in [-1.0, 1.0]:
				k.sphere(0.13, MeshKit.at(Vector3(0.26 * side, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), iron, 0.0, 8, 4, true)
			for y: float in [-0.12, 0.0, 0.12]:
				k.box(Vector3(0.05, 0.04, 0.03), MeshKit.at(Vector3(0, y, -0.14)), silver)
			k.sphere(0.045, MeshKit.at(Vector3(0, 0.18, -0.14)), accent, 1.0, 6, 2, true)
		"Mantle":
			k.sphere(0.3, MeshKit.at(Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1.2, 0.45, 0.9)), Color(0.5, 0.12, 0.15))
			k.box(Vector3(0.5, 0.5, 0.04), MeshKit.at(Vector3(0, -0.12, 0.16), Vector3(10, 0, 0)), Color(0.5, 0.12, 0.15))
			k.torus(0.05, 0.08, MeshKit.at(Vector3(0, 0.12, -0.24), Vector3(90, 0, 0)), gold, 0.1, 10)
			k.sphere(0.045, MeshKit.at(Vector3(0, 0.12, -0.25)), accent, 1.0, 6, 2, true)
		# Boots: a pair.
		"Sandals", "Boots", "Greaves":
			for side: float in [-1.0, 1.0]:
				var x := 0.13 * side
				var tall := 0.12 if base_name == "Sandals" else 0.32
				var mat := leather if base_name != "Greaves" else iron
				k.box(Vector3(0.14, 0.06, 0.32), MeshKit.at(Vector3(x, -0.2, -0.05)), leather.darkened(0.4))
				if base_name == "Sandals":
					k.box(Vector3(0.15, 0.03, 0.04), MeshKit.at(Vector3(x, -0.15, -0.12)), leather)
					k.box(Vector3(0.15, 0.03, 0.04), MeshKit.at(Vector3(x, -0.15, 0.02)), leather)
				else:
					k.cylinder(0.075, 0.08, tall, MeshKit.at(Vector3(x, -0.17 + tall * 0.5, 0.02)), mat, 0.0, 8, base_name == "Greaves")
					k.box(Vector3(0.13, 0.1, 0.16), MeshKit.at(Vector3(x, -0.13, -0.1)), mat)
					k.cylinder(0.09, 0.09, 0.04, MeshKit.at(Vector3(x, -0.17 + tall, 0.02)), gold if base_name == "Greaves" else leather.darkened(0.3), 0.1, 8)
				k.sphere(0.03, MeshKit.at(Vector3(x, -0.1, -0.2)), accent, 1.0, 6, 2, true)
		# Jewelry
		"Charm", "Pendant", "Talisman":
			k.torus(0.2, 0.23, MeshKit.at(Vector3(0, 0.08, 0), Vector3(90, 0, 0)), gold, 0.15, 16)
			match base_name:
				"Charm":
					k.sphere(0.09, MeshKit.at(Vector3(0, -0.2, 0)), accent, 1.0, 8, 2, true)
				"Pendant":
					k.cylinder(0.0, 0.1, 0.16, MeshKit.at(Vector3(0, -0.24, 0), Vector3(180, 0, 0)), accent, 1.0, 4, true)
					k.cylinder(0.0, 0.1, 0.06, MeshKit.at(Vector3(0, -0.13, 0)), accent, 1.0, 4, true)
				_:
					k.box(Vector3(0.18, 0.18, 0.04), MeshKit.at(Vector3(0, -0.22, 0), Vector3(0, 0, 45)), gold, 0.15)
					k.sphere(0.06, MeshKit.at(Vector3(0, -0.22, -0.03)), accent, 1.2, 6, 2, true)
		"Band", "Signet", "Loop":
			var metal := silver if base_name == "Loop" else gold
			k.torus(0.13, 0.18, MeshKit.at(Vector3(0, 0, 0), Vector3(90, 0, 0)), metal, 0.15, 16)
			if base_name == "Signet":
				k.box(Vector3(0.12, 0.05, 0.12), MeshKit.at(Vector3(0, 0.18, 0)), metal, 0.15)
				k.sphere(0.04, MeshKit.at(Vector3(0, 0.21, 0)), accent, 1.2, 6, 2, true)
			else:
				k.sphere(0.06, MeshKit.at(Vector3(0, 0.18, 0)), accent, 1.2, 6, 2, true)
		_:
			k.box(Vector3(0.3, 0.3, 0.3), MeshKit.at(Vector3.ZERO), accent, 0.5)


# --- projectiles, gems, effects ----------------------------------------------------

## The Magic Bolt: a white-hot core in a colored glow with a fading tail,
## pointing down -Z. Tinted per instance.
static func bolt() -> ArrayMesh:
	return _cached("bolt", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.sphere(0.1, MeshKit.at(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 2.4)), Color(1, 1, 1, 1.0), 0.0, 8, 4)
		k.sphere(0.28, MeshKit.at(Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(1.0, 1.0, 1.7)), Color(0.55, 0.6, 1.0, 0.45), 0.0, 10, 6)
		k.cylinder(0.0, 0.16, 1.1, MeshKit.at(Vector3(0, 0, 0.6), Vector3(-90, 0, 0)), Color(0.5, 0.55, 1.0, 0.35), 0.0, 8)
		return k.commit(material("glow")))


## A hostile fireball (EnemyShots), pointing down -Z. Tinted per instance.
static func enemy_orb() -> ArrayMesh:
	return _cached("enemy_orb", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.sphere(0.12, MeshKit.at(Vector3.ZERO), Color(1, 0.95, 0.8, 1.0), 0.0, 8, 4)
		k.sphere(0.3, MeshKit.at(Vector3.ZERO), Color(1.0, 0.4, 0.4, 0.5), 0.0, 10, 6)
		k.cylinder(0.0, 0.2, 0.7, MeshKit.at(Vector3(0, 0, 0.4), Vector3(-90, 0, 0)), Color(1.0, 0.35, 0.3, 0.35), 0.0, 8)
		return k.commit(material("glow")))


## One Spirit Blade: a glowing crystal sword pointing down -Z.
static func spirit_blade() -> ArrayMesh:
	return _cached("spirit_blade", func() -> ArrayMesh:
		var k := MeshKit.new()
		var c := Color(0.45, 1.0, 0.85)
		k.box(Vector3(0.14, 0.03, 0.75), MeshKit.at(Vector3(0, 0, -0.25)), c, 1.6)
		k.cylinder(0.0, 0.1, 0.25, MeshKit.at(Vector3(0, 0, -0.74), Vector3(-90, 0, 0), Vector3(1.0, 1.0, 0.3)), c, 1.8, 4, true)
		k.box(Vector3(0.34, 0.05, 0.06), MeshKit.at(Vector3(0, 0, 0.14)), Color(0.9, 0.95, 1.0), 0.8)
		k.box(Vector3(0.05, 0.05, 0.22), MeshKit.at(Vector3(0, 0, 0.28)), Color(0.2, 0.5, 0.45), 0.4)
		return k.commit(kit_material()))


## A wayside shrine: a carved obelisk with a floating rune crystal, both
## glowing in `glow`.
static func shrine(glow: Color) -> ArrayMesh:
	return _cached("shrine|" + glow.to_html(), func() -> ArrayMesh:
		var k := MeshKit.new()
		var st := Color(0.4, 0.4, 0.43)
		k.cylinder(1.2, 1.3, 0.2, MeshKit.at(Vector3(0, 0.1, 0)), st.darkened(0.3), 0.0, 10, true)
		k.cylinder(0.9, 1.0, 0.15, MeshKit.at(Vector3(0, 0.27, 0)), st.darkened(0.15), 0.0, 10, true)
		k.box(Vector3(0.5, 2.0, 0.5), MeshKit.at(Vector3(0, 1.3, 0), Vector3(0, 45, 0)), st)
		k.cylinder(0.0, 0.42, 0.5, MeshKit.at(Vector3(0, 2.55, 0), Vector3(0, 45, 0)), st, 0.0, 4, true)
		for a in 4:
			var ang := a * PI / 2.0 + PI / 4.0
			k.box(Vector3(0.06, 1.2, 0.02), MeshKit.at(Vector3(cos(ang) * 0.26, 1.3, sin(ang) * 0.26), Vector3(0, -rad_to_deg(ang) + 90, 0)), glow, 1.8)
		k.sphere(0.28, MeshKit.at(Vector3(0, 3.4, 0), Vector3.ZERO, Vector3(0.7, 1.3, 0.7)), glow, 2.0, 6, 2, true)
		return k.commit(kit_material()))


## A cursed chest bound in iron with a glowing seal.
static func chest() -> ArrayMesh:
	return _cached("chest", func() -> ArrayMesh:
		var k := MeshKit.new()
		var wood := Color(0.35, 0.22, 0.13)
		var iron := Color(0.25, 0.25, 0.28)
		var curse := Color(0.75, 0.3, 1.0)
		k.box(Vector3(1.2, 0.6, 0.8), MeshKit.at(Vector3(0, 0.3, 0)), wood)
		k.cylinder(0.4, 0.4, 1.2, MeshKit.at(Vector3(0, 0.6, 0), Vector3(0, 0, 90), Vector3(1.0, 1.0, 1.0)), wood.darkened(0.1), 0.0, 8, true)
		for x: float in [-0.45, 0.0, 0.45]:
			k.box(Vector3(0.08, 0.65, 0.84), MeshKit.at(Vector3(x, 0.32, 0)), iron)
			k.torus(0.37, 0.42, MeshKit.at(Vector3(x, 0.6, 0), Vector3(0, 0, 90)), iron, 0.0, 10)
		k.box(Vector3(0.24, 0.28, 0.06), MeshKit.at(Vector3(0, 0.55, -0.42)), curse, 2.2)
		for i in 3:
			k.sphere(0.07, MeshKit.at(Vector3(-0.5 + i * 0.5, 1.15, 0)), curse, 1.8, 5, 2)
		return k.commit(kit_material()))


## A floating red heart crystal: heals when picked up.
## The Ferryman: a tall hooded figure on a little raft, leaning on a pole
## hung with a soul lantern. About 2.6 m tall; faces -Z.
static func ferryman() -> ArrayMesh:
	return _cached("ferryman", func() -> ArrayMesh:
		var k := MeshKit.new()
		var robe := Color(0.1, 0.1, 0.13)
		var trim := Color(0.75, 0.62, 0.32)
		var wood := Color(0.3, 0.21, 0.14)
		var soul := Color(0.55, 0.9, 1.0)
		var gold := Color(1.0, 0.82, 0.35)
		# The raft, with a dark water shimmer under it.
		k.cylinder(1.25, 1.25, 0.04, MeshKit.at(Vector3(0, 0.02, 0)), Color(0.08, 0.14, 0.2), 0.5, 16)
		for i in 5:
			k.box(Vector3(0.32, 0.12, 1.9), MeshKit.at(Vector3(-0.68 + i * 0.34, 0.1, 0)), wood.lightened(0.06 * (i % 2)))
		# A long robe and a deep hood.
		k.cylinder(0.24, 0.5, 1.5, MeshKit.at(Vector3(0, 0.91, 0.05)), robe, 0.0, 10)
		k.cylinder(0.5, 0.52, 0.06, MeshKit.at(Vector3(0, 0.2, 0.05)), trim, 0.4, 10)
		k.sphere(0.3, MeshKit.at(Vector3(0, 1.72, 0.02), Vector3.ZERO, Vector3(1.0, 1.15, 1.0)), robe, 0.0, 10, 6)
		k.cylinder(0.0, 0.22, 0.4, MeshKit.at(Vector3(0, 2.06, 0.08), Vector3(25, 0, 0)), robe, 0.0, 8)
		k.sphere(0.2, MeshKit.at(Vector3(0, 1.7, -0.14), Vector3.ZERO, Vector3(1.0, 1.1, 0.5)), Color(0.02, 0.02, 0.03), 0.0, 8, 4)
		k.sphere(0.035, MeshKit.at(Vector3(-0.07, 1.72, -0.25)), soul, 2.5, 5, 2)
		k.sphere(0.035, MeshKit.at(Vector3(0.07, 1.72, -0.25)), soul, 2.5, 5, 2)
		# A coin on a cord around the neck.
		k.cylinder(0.08, 0.08, 0.02, MeshKit.at(Vector3(0, 1.35, -0.26), Vector3(90, 0, 0)), gold, 1.0, 10)
		# The pole, the lantern on its hook, and a bony hand on the shaft.
		k.cylinder(0.035, 0.035, 2.9, MeshKit.at(Vector3(0.48, 1.45, -0.15)), wood, 0.0, 6)
		k.box(Vector3(0.4, 0.04, 0.04), MeshKit.at(Vector3(0.48, 2.85, -0.33), Vector3(0, 90, 0)), wood)
		k.box(Vector3(0.18, 0.24, 0.18), MeshKit.at(Vector3(0.48, 2.6, -0.52)), Color(0.18, 0.18, 0.2))
		k.sphere(0.09, MeshKit.at(Vector3(0.48, 2.6, -0.52)), soul, 3.0, 6, 3)
		k.sphere(0.07, MeshKit.at(Vector3(0.4, 1.4, -0.15)), Color(0.85, 0.82, 0.72), 0.0, 6, 3)
		return k.commit(kit_material()))


static func health_orb() -> ArrayMesh:
	return _cached("health_orb", func() -> ArrayMesh:
		var k := MeshKit.new()
		var red := Color(1.0, 0.2, 0.25)
		k.sphere(0.2, MeshKit.at(Vector3(-0.12, 0.08, 0)), red, 1.5, 8, 4)
		k.sphere(0.2, MeshKit.at(Vector3(0.12, 0.08, 0)), red, 1.5, 8, 4)
		k.cylinder(0.0, 0.3, 0.36, MeshKit.at(Vector3(0, -0.14, 0), Vector3(180, 0, 0)), red, 1.5, 8)
		return k.commit(kit_material()))


## An XP crystal (a double pyramid), centered on its middle.
static func gem() -> ArrayMesh:
	return _cached("gem", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.cylinder(0.0, 0.13, 0.24, MeshKit.at(Vector3(0, 0.12, 0)), Color.WHITE, 0.3, 5, true)
		k.cylinder(0.13, 0.0, 0.16, MeshKit.at(Vector3(0, -0.08, 0)), Color(0.85, 0.85, 0.85), 0.0, 5, true)
		return k.commit(material("gem")))


# --- props ------------------------------------------------------------------------
# Scenery for WorldDecor. Each returns a mesh with feet at y = 0.

const PROPS := ["grass", "rock", "bush", "mushroom", "bones", "tree", "grave", "pillar", "crystal",
		"pine", "ice", "snowrock", "obsidian", "brimstone", "ashtree",
		# Imported GLB scenery (AssetProps). New kinds go last so existing props keep their places.
		"rune_gravestone", "soul_brazier", "ruined_pillar", "crystal_cluster", "tome_pedestal", "barrel", "crate_stack",
		"weapon_rack", "offering_bowl", "sarcophagus", "prison_cage", "gravedigger_bench", "lantern_post", "mausoleum",
		"soul_altar", "broken_archway", "ruined_wall", "ruin_corner", "portcullis", "guardian_statue", "soul_obelisk",
		"stone_well", "ritual_door", "iron_fence", "bell_gibbet", "funeral_wagon", "ossuary_wall", "winged_memorial",
		"snow_boulder", "frosted_pine", "ice_stalagmites", "supply_tripod", "wind_chime", "ice_arch", "watchtower",
		"sled", "ribcage", "frozen_pond", "fishing_hut", "whale_skull", "obsidian_outcrop", "brimstone_vent",
		"ashen_tree", "basalt_columns", "scorched_banner", "skull_gateway", "forge", "cauldron", "siege_barricade",
		"minecart", "furnace", "chained_gong"]


static func prop(kind: String) -> ArrayMesh:
	if AssetProps.has(kind):
		return AssetProps.mesh(kind)
	return _cached("prop|" + kind, func() -> ArrayMesh:
		var k := MeshKit.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(kind)
		match kind:
			"grass":
				for i in 7:
					var a := rng.randf() * TAU
					var r := rng.randf() * 0.18
					var h := rng.randf_range(0.3, 0.6)
					var c := Color(0.26, 0.4, 0.16).lerp(Color(0.45, 0.5, 0.2), rng.randf())
					k.cylinder(0.0, 0.045, h, MeshKit.at(Vector3(cos(a) * r, h * 0.5, sin(a) * r), Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))), c, 0.0, 3, true)
			"rock":
				k.sphere(0.5, MeshKit.at(Vector3(0, 0.15, 0), Vector3(0, 20, 8), Vector3(1.2, 0.75, 0.9)), Color(0.47, 0.46, 0.46), 0.0, 7, 4, true)
				k.sphere(0.28, MeshKit.at(Vector3(0.55, 0.06, 0.25), Vector3(0, 50, -10), Vector3(1.0, 0.7, 0.9)), Color(0.42, 0.41, 0.41), 0.0, 6, 3, true)
				k.sphere(0.2, MeshKit.at(Vector3(0.1, 0.42, 0.05), Vector3(0, 0, 0), Vector3(1.4, 0.5, 1.2)), Color(0.22, 0.3, 0.14), 0.0, 6, 3, true) # moss
			"bush":
				for i in 4:
					var off := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
					var r := rng.randf_range(0.3, 0.45)
					k.sphere(r, MeshKit.at(off + Vector3(0, r * 0.8, 0)), Color(0.12, 0.2, 0.1).lerp(Color(0.2, 0.28, 0.12), rng.randf()), 0.0, 7, 4, true)
			"mushroom":
				for i in 4:
					var off := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
					var h := rng.randf_range(0.12, 0.35)
					k.cylinder(0.03, 0.04, h, MeshKit.at(off + Vector3(0, h * 0.5, 0)), Color(0.8, 0.78, 0.7), 0.0, 5)
					k.sphere(h * 0.45, MeshKit.at(off + Vector3(0, h, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0)), Color(0.3, 0.9, 0.85), 1.4, 8, 3)
			"bones":
				k.sphere(0.13, MeshKit.at(Vector3(0, 0.1, 0), Vector3(0, 30, 0), Vector3(1.0, 0.95, 1.15)), Color(0.85, 0.82, 0.72), 0.0, 7, 4, true)
				k.box(Vector3(0.12, 0.06, 0.06), MeshKit.at(Vector3(0.02, 0.05, -0.12), Vector3(0, 30, 0)), Color(0.75, 0.72, 0.62))
				k.sphere(0.03, MeshKit.at(Vector3(-0.03, 0.12, -0.12)), Color(0.05, 0.05, 0.05))
				k.sphere(0.03, MeshKit.at(Vector3(0.05, 0.12, -0.1)), Color(0.05, 0.05, 0.05))
				for i in 3:
					k.capsule(0.025, 0.4, MeshKit.at(Vector3(rng.randf_range(-0.3, 0.4), 0.03, rng.randf_range(-0.2, 0.4)), Vector3(90, rng.randf() * 180.0, 0)), Color(0.82, 0.8, 0.7), 0.0, 5)
			"tree":
				var bark := Color(0.22, 0.18, 0.16)
				k.cylinder(0.12, 0.24, 2.4, MeshKit.at(Vector3(0, 1.2, 0)), bark, 0.0, 7, true)
				for i in 5:
					var a := i * TAU / 5.0 + rng.randf() * 0.6
					var y := rng.randf_range(1.2, 2.2)
					var tilt := rng.randf_range(40, 65)
					var length := rng.randf_range(0.7, 1.2)
					var dir := Vector3(cos(a), 0, sin(a))
					k.cylinder(0.02, 0.07, length, Transform3D(Basis.from_euler(Vector3(0, -a + PI / 2.0, 0)) * Basis.from_euler(Vector3(deg_to_rad(tilt), 0, 0)), Vector3(0, y, 0) + dir * length * 0.4 + Vector3(0, length * 0.3, 0)), bark, 0.0, 5, true)
				for i in 3:
					var a := rng.randf() * TAU
					k.cylinder(0.04, 0.12, 0.5, MeshKit.at(Vector3(cos(a) * 0.25, 0.1, sin(a) * 0.25), Vector3(0, -rad_to_deg(a), 70)), bark.darkened(0.2), 0.0, 5, true)
			"grave":
				var st := Color(0.42, 0.42, 0.45)
				k.box(Vector3(0.6, 0.75, 0.14), MeshKit.at(Vector3(0, 0.37, 0), Vector3(0, 0, 4)), st)
				k.cylinder(0.3, 0.3, 0.14, MeshKit.at(Vector3(-0.026, 0.75, 0), Vector3(90, 0, 4)), st, 0.0, 10, true)
				k.box(Vector3(0.08, 0.32, 0.03), MeshKit.at(Vector3(-0.02, 0.5, -0.08), Vector3(0, 0, 4)), st.darkened(0.35))
				k.box(Vector3(0.24, 0.08, 0.03), MeshKit.at(Vector3(-0.02, 0.56, -0.08), Vector3(0, 0, 4)), st.darkened(0.35))
				k.box(Vector3(0.8, 0.06, 1.2), MeshKit.at(Vector3(0, 0.03, 0.65)), Color(0.2, 0.17, 0.13))
			"pillar":
				var st := Color(0.5, 0.48, 0.45)
				k.box(Vector3(1.0, 0.25, 1.0), MeshKit.at(Vector3(0, 0.12, 0)), st.darkened(0.15))
				k.cylinder(0.33, 0.36, 1.5, MeshKit.at(Vector3(0, 1.0, 0)), st, 0.0, 8, true)
				k.cylinder(0.2, 0.33, 0.3, MeshKit.at(Vector3(0.03, 1.88, 0.0), Vector3(0, 0, 12)), st, 0.0, 8, true)
				k.cylinder(0.33, 0.33, 0.8, MeshKit.at(Vector3(1.1, 0.33, 0.4), Vector3(0, 30, 88)), st.darkened(0.1), 0.0, 8, true)
				k.sphere(0.3, MeshKit.at(Vector3(-0.3, 0.6, -0.36), Vector3.ZERO, Vector3(1.2, 1.8, 0.5)), Color(0.2, 0.3, 0.14), 0.0, 6, 3, true)
			"crystal":
				for i in 5:
					var h := rng.randf_range(0.5, 1.3)
					var a := rng.randf() * TAU
					var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.3)
					k.cylinder(0.0, 0.13, h, MeshKit.at(off + Vector3(0, h * 0.4, 0), Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))), Color(0.65, 0.35, 1.0), 1.1, 5, true)
				k.sphere(0.3, MeshKit.at(Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.4, 0.4, 1.4)), Color(0.3, 0.3, 0.33), 0.0, 6, 3, true)
			"pine":
				# A snow-laden dead pine: stacked cones on a dark trunk.
				k.cylinder(0.08, 0.14, 1.0, MeshKit.at(Vector3(0, 0.5, 0)), Color(0.22, 0.17, 0.14), 0.0, 6, true)
				for i in 4:
					var r := 0.75 - i * 0.16
					k.cylinder(0.0, r, 0.7, MeshKit.at(Vector3(0, 0.9 + i * 0.42, 0)), Color(0.12, 0.2, 0.17), 0.0, 7, true)
					k.cylinder(0.0, r * 0.8, 0.28, MeshKit.at(Vector3(0, 1.1 + i * 0.42, 0)), Color(0.88, 0.92, 0.98), 0.0, 7, true)
			"ice":
				for i in 5:
					var h := rng.randf_range(0.6, 1.8)
					var a := rng.randf() * TAU
					var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.4)
					k.cylinder(0.0, 0.16, h, MeshKit.at(off + Vector3(0, h * 0.4, 0), Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))), Color(0.62, 0.86, 1.0), 0.45, 5, true)
			"snowrock":
				k.sphere(0.5, MeshKit.at(Vector3(0, 0.15, 0), Vector3(0, 20, 8), Vector3(1.2, 0.75, 0.9)), Color(0.42, 0.44, 0.48), 0.0, 7, 4, true)
				k.sphere(0.45, MeshKit.at(Vector3(0.05, 0.32, 0.0), Vector3(0, 20, 0), Vector3(1.15, 0.35, 0.85)), Color(0.9, 0.93, 0.98), 0.0, 7, 3, true)
			"obsidian":
				for i in 3:
					var a := rng.randf() * TAU
					var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.5)
					k.sphere(rng.randf_range(0.25, 0.5), MeshKit.at(off + Vector3(0, 0.15, 0), Vector3(rng.randf() * 40, rng.randf() * 180, 0), Vector3(1.0, 1.4, 0.8)), Color(0.08, 0.07, 0.1), 0.0, 5, 3, true)
				k.box(Vector3(0.05, 0.02, 0.6), MeshKit.at(Vector3(0, 0.02, 0), Vector3(0, 30, 0)), Color(1.0, 0.4, 0.1), 2.0)
			"brimstone":
				# A cracked vent glowing from inside.
				k.sphere(0.55, MeshKit.at(Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.3, 0.35, 1.3)), Color(0.18, 0.12, 0.1), 0.0, 8, 3, true)
				k.cylinder(0.25, 0.32, 0.12, MeshKit.at(Vector3(0, 0.18, 0)), Color(1.0, 0.5, 0.12), 2.4, 8)
				for i in 4:
					var a := i * TAU / 4.0 + 0.3
					k.box(Vector3(0.06, 0.03, 0.5), MeshKit.at(Vector3(cos(a) * 0.45, 0.05, sin(a) * 0.45), Vector3(0, -rad_to_deg(a) + 90, 0)), Color(1.0, 0.35, 0.08), 1.8)
			"ashtree":
				var char_color := Color(0.1, 0.08, 0.08)
				k.cylinder(0.1, 0.22, 2.0, MeshKit.at(Vector3(0, 1.0, 0)), char_color, 0.0, 6, true)
				for i in 4:
					var a := i * TAU / 4.0 + rng.randf()
					k.cylinder(0.02, 0.06, 0.8, Transform3D(Basis.from_euler(Vector3(0, -a + PI / 2.0, 0)) * Basis.from_euler(Vector3(deg_to_rad(55), 0, 0)), Vector3(cos(a) * 0.3, 1.6 + i * 0.1, sin(a) * 0.3)), char_color, 0.0, 4, true)
				k.box(Vector3(0.04, 0.6, 0.02), MeshKit.at(Vector3(0, 0.8, -0.16)), Color(1.0, 0.4, 0.1), 1.6) # ember crack
		return k.commit(kit_material()))
