class_name LootDrop
extends Node3D
## An item lying on the ground. There are only ever a few dozen of these, so
## unlike enemies they are ordinary nodes. It shows the item's own model
## (a staff looks like a staff) floating over a glow in its rarity color.
## Magic and better items get a light beam, and Rare and better show their
## name so they stand out in a crowd.

var item: Item
## Ground position as Vector2(x, z), the space the swarms use.
var pos2 := Vector2.ZERO

var _model: MeshInstance3D
var _age := 0.0

## Weapons are long, so they're shown smaller than the rest.
const _SLOT_SCALE := {"weapon": 0.95, "chest": 1.5, "helm": 1.6, "boots": 1.6}


func setup(p_item: Item, at: Vector2) -> void:
	item = p_item
	pos2 = at
	position = Vector3(at.x, 0.0, at.y)


func _ready() -> void:
	var color := item.color()
	_age = randf() * 10.0

	_model = MeshInstance3D.new()
	_model.mesh = Models.item(item.slot, item.base_name, color)
	_model.scale = Vector3.ONE * _SLOT_SCALE.get(item.slot, 2.0)
	_model.position.y = 0.9
	# Tip it a little so flat things (rings, amulets) read from above.
	_model.rotation.x = -0.5 if item.slot in ["ring", "amulet"] else 0.0
	add_child(_model)

	var glow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (1.4 + 0.35 * item.rarity)
	glow.mesh = plane
	glow.material_override = Models.material("ground_glow", {
		"color": Color(color, 0.35 + 0.12 * item.rarity), "ring": 0.6,
	}, "loot%d" % item.rarity)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = 0.04
	add_child(glow)

	if item.rarity >= ItemData.Rarity.MAGIC:
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		var height := 4.0 + 2.0 * item.rarity
		cylinder.top_radius = 0.25 + 0.05 * item.rarity
		cylinder.bottom_radius = 0.18 + 0.04 * item.rarity
		cylinder.height = height
		cylinder.radial_segments = 12
		cylinder.rings = 1
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		beam.mesh = cylinder
		beam.material_override = Models.material("beam", {
			"color": Color(color, 0.45 + 0.1 * item.rarity), "height": height,
		}, "beam%d" % item.rarity)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = height * 0.5
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
		label.position.y = 1.9
		add_child(label)


func _process(delta: float) -> void:
	_age += delta
	_model.rotation.y += delta * 1.6
	_model.position.y = 0.9 + sin(_age * 2.5) * 0.12
