class_name WagerPanel
extends CanvasLayer
## The Ferryman's table: the prize on offer, the posted odds and what you can
## do about them. Ferryman owns the rules and the outcomes; this only shows
## them and reports clicks (`chosen`). Runs while the tree is paused.

signal chosen(action: String)

var heading := "The Ferryman"
var flavor_text := "\"Every soul pays the toll. Will you pay it twice, for a richer crossing?\""

var _root: Control
var _title: Label
var _prize: Label
var _detail: Label
var _odds: Label
var _result: Label
var _buttons: HBoxContainer
var _cards: HBoxContainer
var _actions: Dictionary = {}
var _generation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 14
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func close() -> void:
	_generation += 1
	_root.hide()


## Shows a state: {"prize": String, "prize_color": Color, "detail": String,
## "odds": String, "result": String, "result_color": Color,
## "actions": [[id, label, enabled]]}.
func action_button(id: String) -> Button:
	return _actions.get(id)


func show_state(state: Dictionary) -> void:
	_generation += 1
	var generation := _generation
	_root.show()
	_prize.text = state.get("prize", "")
	_prize.add_theme_color_override("font_color", RunUi.GOLD)
	_detail.text = state.get("detail", "")
	_odds.text = state.get("odds", "")
	_result.text = state.get("result", "")
	_result.add_theme_color_override("font_color", RunUi.MUTED)
	for parent: Control in [_buttons,_cards]:
		for child in parent.get_children():
			parent.remove_child(child);child.queue_free()
	_actions.clear()
	var cards: Dictionary = state.get("cards",{})
	_cards.visible = not cards.is_empty()
	_detail.visible = cards.is_empty() and _detail.text != ""
	var first: Button = null
	for a: Array in state.get("actions", []):
		var id: String = a[0]
		var b := Button.new()
		b.text = a[1];b.disabled = not a[2]
		b.custom_minimum_size = Vector2(120,42)
		b.add_theme_font_size_override("font_size",15)
		if cards.has(id):
			var data: Dictionary = cards[id]
			var panel := PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			panel.add_theme_stylebox_override("panel",RunUi.panel(18,RunUi.SOUL if id=="seal" else RunUi.EDGE))
			_cards.add_child(panel)
			var column:=VBoxContainer.new();column.custom_minimum_size.x=290;column.add_theme_constant_override("separation",10);panel.add_child(column)
			var eyebrow:=RunUi.label(12,RunUi.SOUL if id=="seal" else RunUi.MUTED);eyebrow.text=data.get("eyebrow","");column.add_child(eyebrow)
			var title:=RunUi.label(24);title.text=data.get("title",a[1]);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(title)
			var reward:=RunUi.label(17,RunUi.GOLD);reward.text=data.get("reward","");reward.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(reward)
			var detail:=RunUi.label(15,RunUi.MUTED);detail.text=data.get("challenge","");detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size.y=78;column.add_child(detail)
			b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(b)
		else:
			_buttons.add_child(b)
		_actions[id]=b
		b.pressed.connect(func() -> void:
			if generation != _generation or not is_open() or b.disabled:return
			Sound.play("ui_click");chosen.emit(id))
		if first==null and not b.disabled:first=b
	var buttons := _actions.values()
	for i in buttons.size():
		var button: Button=buttons[i]
		button.focus_next=button.get_path_to(buttons[(i+1)%buttons.size()])
		button.focus_previous=button.get_path_to(buttons[(i-1+buttons.size())%buttons.size()])
	if not cards.is_empty() and _actions.has("hunt") and _actions.has("seal"):
		_actions.hunt.focus_neighbor_right=_actions.hunt.get_path_to(_actions.seal)
		_actions.seal.focus_neighbor_left=_actions.seal.get_path_to(_actions.hunt)
		_actions.hunt.focus_neighbor_bottom=_actions.hunt.get_path_to(_actions.leave)
		_actions.seal.focus_neighbor_bottom=_actions.seal.get_path_to(_actions.leave)
		_actions.leave.focus_neighbor_top=_actions.leave.get_path_to(_actions.hunt)
	if first:_focus_action.call_deferred(first,generation)


func _focus_action(button: Button, generation: int) -> void:
	if generation==_generation and is_open() and is_instance_valid(button) and button.is_inside_tree() and not button.disabled:
		button.grab_focus()


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		chosen.emit("leave")
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.015, 0.02, 0.025, 0.88)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = RunUi.theme()
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RunUi.panel(0))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(760,580)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 740
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	_title = RunUi.heading(30)
	_title.text = heading.capitalize()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_color_override("font_color", RunUi.TEXT)
	box.add_child(_title)
	var flavor := RunUi.label(15)
	flavor.text = flavor_text
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flavor.add_theme_color_override("font_color",RunUi.MUTED)
	box.add_child(flavor)
	_prize = RunUi.label(17)
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_prize)
	_detail = RunUi.label(15)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", RunUi.MUTED)
	box.add_child(_detail)
	_odds = RunUi.label(14)
	_odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_odds.add_theme_color_override("font_color", RunUi.MUTED)
	_cards=HBoxContainer.new()
	_cards.add_theme_constant_override("separation",16)
	box.add_child(_cards)
	box.add_child(_odds)
	_result = RunUi.label(13)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_result)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
