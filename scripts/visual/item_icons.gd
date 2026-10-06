class_name ItemIcons
extends Node
## Renders item models (Models.item) into small textures for the inventory,
## plus a live, slowly turning preview of the selected item. Each icon is a
## tiny SubViewport with its own world that renders once and is then reused,
## so there are no icon images to maintain: a new base item gets an icon for
## free. Icons are made on first use and cached per base and rarity.
##
## Under --headless nothing renders, so icons come out blank; the screens
## still work.

const ICON_SIZE := 64

var _icons := {}
var _preview_viewport: SubViewport
var _preview_pivot: Node3D
var _preview_model: MeshInstance3D


func icon(item: Item) -> Texture2D:
	var key := "%s|%s|%d" % [item.slot, item.base_name, item.rarity]
	if not _icons.has(key):
		var vp := _make_viewport(Vector2i(ICON_SIZE, ICON_SIZE))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var model := MeshInstance3D.new()
		model.mesh = Models.item(item.slot, item.base_name, item.color())
		_pose(model, item)
		vp.add_child(model)
		_icons[key] = vp.get_texture()
	return _icons[key]


## A control showing the selected item turning on a pedestal glow. Call
## show_item() to change what it shows.
func make_preview(min_size: Vector2) -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = min_size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_viewport = _make_viewport(Vector2i(min_size), true)
	_preview_viewport.get_parent().remove_child(_preview_viewport)
	container.add_child(_preview_viewport)
	_preview_pivot = Node3D.new()
	_preview_viewport.add_child(_preview_pivot)
	_preview_model = MeshInstance3D.new()
	_preview_pivot.add_child(_preview_model)
	return container


func show_item(item: Item) -> void:
	if _preview_model == null:
		return
	_preview_model.visible = item != null
	if item:
		_preview_model.mesh = Models.item(item.slot, item.base_name, item.color())
		_pose(_preview_model, item)
		_preview_model.scale *= 1.15


func _process(delta: float) -> void:
	if _preview_pivot and _preview_pivot.is_visible_in_tree():
		_preview_pivot.rotation.y += delta * 0.9


## Fits each slot's model into the frame: weapons lie diagonally, jewelry
## tilts toward the camera.
func _pose(model: MeshInstance3D, item: Item) -> void:
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	match item.slot:
		"weapon":
			model.rotation_degrees = Vector3(0, 0, -40)
			var fit := {"Staff": 0.6, "Wand": 1.15, "Orb": 1.7}
			model.scale = Vector3.ONE * fit.get(item.base_name, 0.8)
			model.position = Vector3(0.05, 0.0, 0)
		"ring", "amulet":
			model.rotation_degrees = Vector3(-35, 25, 0)
			model.scale = Vector3.ONE * 1.55
			model.position = Vector3(0, 0.05 if item.slot == "ring" else 0.1, 0)
		_:
			model.rotation_degrees = Vector3(10, 30, 0)
			model.scale = Vector3.ONE * 1.25
			model.position = Vector3.ZERO


func _make_viewport(size: Vector2i, glow := false) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = glow
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	camera.environment = env
	camera.position = Vector3(0, 0.35, 2.0)
	camera.rotation_degrees = Vector3(-10, 0, 0)
	vp.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.75, 1.0)
	vp.add_child(rim)
	return vp
