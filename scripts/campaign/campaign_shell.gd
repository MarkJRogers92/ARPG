class_name CampaignShell
extends Node
## Campaign scene root. Teardown completes before fresh combat is mounted.
static var new_requested := false
var controller: CampaignController
var _view: Node
var _pending_result := {}
var _error_layer: CanvasLayer

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	controller = CampaignController.new()
	add_child(controller)
	var response := controller.create() if new_requested else controller.load_campaign()
	new_requested = false
	if not response["ok"]:
		_show_error(response["error"], _return_title)
		return
	if controller.state["phase"] == "EXPEDITION_ACTIVE": _mount_combat(controller.resume_spec())
	else: _mount_town()

func _clear_view() -> void:
	if not is_instance_valid(_view): return
	# free() runs outgoing _exit_tree synchronously before the new globals bind.
	_view.get_parent().remove_child(_view)
	_view.free()
	_view = null
	get_tree().paused = false
	Engine.time_scale = 1.0

func _mount_town() -> void:
	_clear_view()
	var town_script := load("res://scripts/campaign/campaign_town.gd") as Script
	if town_script == null:
		_show_error("The Last Lantern town could not be loaded.", _return_title)
		return
	_view = town_script.new()
	_view.expedition_requested.connect(_mount_combat.call_deferred)
	_view.quit_requested.connect(_return_title.call_deferred)
	add_child(_view)
	_view.setup(controller)

func _mount_combat(spec: Dictionary) -> void:
	_clear_view()
	Realm.in_title = false
	Realm.daily = false
	Realm.current = spec["biome_id"]
	var scene := load("res://scenes/main.tscn") as PackedScene
	_view = scene.instantiate()
	_view.expedition_spec = spec.duplicate(true)
	_view.expedition_finished.connect(_receive_result)
	_view.expedition_quit_requested.connect(_return_title.call_deferred)
	add_child(_view)

func _receive_result(result: Dictionary) -> void:
	_pending_result = result.duplicate(true)
	_settle_pending.call_deferred()

func _settle_pending() -> void:
	var response := controller.settle(_pending_result)
	if response["ok"]:
		_pending_result = {}
		_mount_town()
	else:
		_show_error(response["error"], _settle_pending, "Retry saving result")

func _return_title() -> void:
	_clear_view()
	Realm.in_title = true
	Realm.daily = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _show_error(message: String, retry: Callable, button_text := "Back to title") -> void:
	if _error_layer: _error_layer.free()
	_error_layer = CanvasLayer.new()
	_error_layer.layer = 100
	_error_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_error_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.035, 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.theme = UiStyle.theme()
	_error_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := UiStyle.label(28)
	title.text = "Checkpoint needs attention"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(title)
	var text := UiStyle.label(18)
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 100)
	box.add_child(text)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size.y = 48
	button.pressed.connect(func() -> void:
		_error_layer.queue_free()
		_error_layer = null
		retry.call_deferred())
	box.add_child(button)
	button.grab_focus.call_deferred()
