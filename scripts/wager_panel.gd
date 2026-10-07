class_name WagerPanel
extends CanvasLayer
## The Ferryman's table: the prize on offer, the posted odds and what you can
## do about them. Ferryman owns the rules and the outcomes; this only shows
## them and reports clicks (`chosen`). Runs while the tree is paused.

signal chosen(action: String)

var _root: Control
var _title: Label
var _prize: Label
var _detail: Label
var _odds: Label
var _result: Label
var _buttons: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 14
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func close() -> void:
	_root.hide()


## Shows a state: {"prize": String, "prize_color": Color, "detail": String,
## "odds": String, "result": String, "result_color": Color,
## "actions": [[id, label, enabled]]}.
func show_state(state: Dictionary) -> void:
	_root.show()
	_prize.text = state.get("prize", "")
	_prize.add_theme_color_override("font_color", state.get("prize_color", UiStyle.TEXT))
	_detail.text = state.get("detail", "")
	_odds.text = state.get("odds", "")
	_result.text = state.get("result", "")
	_result.add_theme_color_override("font_color", state.get("result_color", UiStyle.GOLD))
	for child in _buttons.get_children():
		child.queue_free()
	var first: Button = null
	for a: Array in state.get("actions", []):
		var b := Button.new()
		b.text = a[1]
		b.disabled = not a[2]
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 17)
		var id: String = a[0]
		b.pressed.connect(func() -> void:
			Sound.play("ui_click")
			chosen.emit(id))
		_buttons.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		chosen.emit("leave")
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.0, 0.01, 0.03, 0.65)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.04, 0.05, 0.07, 0.97), Color(0.75, 0.62, 0.32), 2, 12))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 760
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = UiStyle.label(34)
	_title.text = "THE FERRYMAN"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	box.add_child(_title)
	var flavor := UiStyle.label(15)
	flavor.text = "\"Every soul pays the toll. Will you pay it twice, for a richer crossing?\""
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.modulate = Color(1, 1, 1, 0.6)
	box.add_child(flavor)
	_prize = UiStyle.label(24)
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prize)
	_detail = UiStyle.label(15)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_detail)
	_odds = UiStyle.label(18)
	_odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_odds.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_odds)
	_result = UiStyle.label(26)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
