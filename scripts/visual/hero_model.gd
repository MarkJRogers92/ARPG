class_name HeroModel
extends Node3D
## The hero's look: a hooded battle-mage holding whatever weapon is equipped.
## Player drives it with set_motion() every frame and cast() when a volley
## fires; everything else (bobbing, leaning, the weapon recoil) happens here.

const DEFAULT_WEAPON := "Staff"
const DEFAULT_ACCENT := Color(0.5, 0.85, 1.0)

var _body: MeshInstance3D
var _rig: Node3D
var _weapon_pivot: Node3D
var _weapon: MeshInstance3D
var _light: OmniLight3D
var _speed := 0.0
var _walk := 0.0
var _cast := 0.0


func _ready() -> void:
	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * 1.12
	add_child(_rig)
	_body = MeshInstance3D.new()
	_body.mesh = Models.hero_body()
	_rig.add_child(_body)

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Models.HERO_HAND
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


## Shows the weapon base `base_name` (see ItemData.BASES) with an `accent` gem.
func set_weapon(base_name: String, accent: Color) -> void:
	_weapon.mesh = Models.item("weapon", base_name, accent)
	# Staffs are planted like a walking stick; wands and orbs are held up.
	match base_name:
		"Staff":
			_weapon.position = Vector3(0, 0.15, 0)
			_weapon.rotation_degrees = Vector3(-10, 0, 0)
		"Orb":
			_weapon.position = Vector3(0, 0.18, -0.05)
			_weapon.rotation_degrees = Vector3.ZERO
		_:
			_weapon.position = Vector3(0, 0.25, -0.05)
			_weapon.rotation_degrees = Vector3(-35, 0, 0)


## `speed` is the hero's current ground speed in units per second.
func set_motion(speed: float, delta: float) -> void:
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))


func cast() -> void:
	_cast = 1.0


func _process(delta: float) -> void:
	_cast = maxf(_cast - delta * 5.0, 0.0)
	var moving := clampf(_speed / 6.0, 0.0, 1.5)
	_walk += delta * (2.0 + _speed * 1.6)
	var idle := sin(Time.get_ticks_msec() * 0.002) * 0.03
	_rig.position.y = absf(sin(_walk)) * 0.12 * moving + idle * (1.0 - minf(moving, 1.0))
	_rig.rotation.x = -0.14 * minf(moving, 1.0)
	_rig.rotation.z = sin(_walk) * 0.05 * moving
	# The weapon thrusts forward when a volley fires.
	_weapon_pivot.rotation.x = -0.7 * _cast + sin(_walk) * 0.1 * moving
	_light.light_energy = 2.4 + _cast * 1.6
