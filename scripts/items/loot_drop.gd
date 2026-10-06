class_name LootDrop
extends Node3D
## An item lying on the ground. There are only ever a few dozen of these, so
## unlike enemies they are ordinary nodes. Magic and better items get a light
## beam, and Rare and better show their name so they stand out in a crowd.

var item: Item
## Ground position as Vector2(x, z), the space the swarms use.
var pos2 := Vector2.ZERO

var _gem: MeshInstance3D
var _age := 0.0

## Materials are shared per rarity.
static var _gem_materials := {}
static var _beam_materials := {}


func setup(p_item: Item, at: Vector2) -> void:
	item = p_item
	pos2 = at
	position = Vector3(at.x, 0.0, at.y)


func _ready() -> void:
	var color := item.color()

	_gem = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * (0.35 + 0.08 * item.rarity)
	_gem.mesh = box
	_gem.material_override = _gem_material(item.rarity, color)
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.position.y = 0.7
	add_child(_gem)

	if item.rarity >= ItemData.Rarity.MAGIC:
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.07
		cylinder.bottom_radius = 0.12
		cylinder.height = 6.0
		cylinder.radial_segments = 8
		cylinder.rings = 1
		beam.mesh = cylinder
		beam.material_override = _beam_material(item.rarity, color)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = 3.0
		add_child(beam)

	if item.rarity >= ItemData.Rarity.RARE:
		var label := Label3D.new()
		label.text = item.name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.011
		label.font_size = 44
		label.outline_size = 14
		label.modulate = color
		label.position.y = 1.7
		add_child(label)


func _process(delta: float) -> void:
	_age += delta
	_gem.rotation.y += delta * 2.2
	_gem.position.y = 0.7 + sin(_age * 3.0) * 0.1


static func _gem_material(rarity: int, color: Color) -> StandardMaterial3D:
	if not _gem_materials.has(rarity):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.7
		_gem_materials[rarity] = m
	return _gem_materials[rarity]


static func _beam_material(rarity: int, color: Color) -> StandardMaterial3D:
	if not _beam_materials.has(rarity):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color, 0.5)
		_beam_materials[rarity] = m
	return _beam_materials[rarity]
