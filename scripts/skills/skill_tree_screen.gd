class_name SkillTreeScreen
extends CanvasLayer
## The pausing skill tree screen, built in code like the other panels.
##
## Click a node to allocate it, right-click (or Backspace on a focused node) to
## refund it. Hover or focus a node for its details. Arrow keys / d-pad move
## between nodes and Enter allocates, so it plays on a controller too.
##
## Node states: owned (filled), available (bright ring: linked to something you
## own and affordable), reachable but too expensive (dim ring), locked (grey).

signal closed

const SPACING := 78.0
const NODE_SIZES := {
	SkillData.Tier.SMALL: 44.0,
	SkillData.Tier.NOTABLE: 56.0,
	SkillData.Tier.KEYSTONE: 68.0,
}

var _tree: SkillTree

var _root: Control
var _canvas: Control
var _buttons := {}
var _points_label: Label
var _details: RichTextLabel
var _reset_button: Button
var _shown := SkillData.ROOT
var _message := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the tree is paused
	layer = 11
	_build()
	_root.hide()


func setup(player: Player) -> void:
	_tree = player.skills
	_tree.changed.connect(func() -> void:
		if is_open():
			_refresh())


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_message = ""
	_refresh()
	_root.show()
	# Start on something you can actually buy, or the origin.
	var start: String = SkillData.ROOT
	for id: String in SkillData.ids():
		if _tree.can_allocate(id):
			start = id
			break
	(_buttons[start] as Button).grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("skill_tree") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


# --- actions ---------------------------------------------------------------------

func _on_node_pressed(id: String) -> void:
	_shown = id
	if _tree.is_allocated(id):
		_message = ""
	elif not _tree.is_reachable(id):
		_message = "[color=#e08a7e]Not connected to your tree yet.[/color]"
	elif not _tree.can_allocate(id):
		var missing := SkillData.cost(id) - _tree.points
		_message = "[color=#e08a7e]Needs %d more skill point%s.[/color]" % [missing, "" if missing == 1 else "s"]
	else:
		_message = ""
		_tree.allocate(id)
		return # changed() refreshes
	_show_details()


func _on_node_input(event: InputEvent, id: String) -> void:
	var refund := false
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		refund = true
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_BACKSPACE, KEY_DELETE]:
		refund = true
	if not refund:
		return
	_shown = id
	if _tree.is_allocated(id) and id != SkillData.ROOT and not _tree.can_refund(id):
		_message = "[color=#e08a7e]Other nodes depend on this one. Refund those first.[/color]"
		_show_details()
	else:
		_message = ""
		_tree.refund(id)
	get_viewport().set_input_as_handled()


func _on_reset_pressed() -> void:
	_message = ""
	_tree.reset()


# --- drawing ---------------------------------------------------------------------

func _refresh() -> void:
	for id: String in _buttons:
		_style_button(_buttons[id], id)
	_points_label.text = "Skill points: %d" % _tree.points
	_points_label.modulate = Color(1.0, 0.85, 0.3) if _tree.points > 0 else Color(0.75, 0.78, 0.85)
	_reset_button.disabled = _tree.spent() == 0
	_canvas.queue_redraw()
	_show_details()


func _show_details() -> void:
	var def: Dictionary = SkillData.NODES[_shown]
	var branch_color: Color = SkillData.color(_shown)
	var text := "[font_size=24][color=#%s][b]%s[/b][/color][/font_size]\n" % [branch_color.to_html(false), def["name"]]
	text += "[color=#8a8f9c]%s  ·  %s[/color]\n\n" % [
		SkillData.TIER_NAMES[def["tier"]] if _shown != SkillData.ROOT else "Origin",
		"cost %d" % SkillData.cost(_shown) if _shown != SkillData.ROOT else "free"]

	for mod: Dictionary in def["mods"]:
		if mod["stat"] == "aura_level":
			continue
		var color := "e08a7e" if mod["value"] < 0.0 else "8fb4ff"
		text += "[color=#%s]%s[/color]\n" % [color, ItemData.mod_text(mod)]
	if def.has("note"):
		text += "[color=#b8bcc8]%s[/color]\n" % def["note"]

	text += "\n"
	if _shown == SkillData.ROOT:
		pass
	elif _tree.is_allocated(_shown):
		text += "[color=#7ee08a]Owned[/color]  [color=#8a8f9c]- right-click to refund[/color]\n"
	elif _tree.can_allocate(_shown):
		text += "[color=#7ee08a]Click to allocate[/color]\n"
	elif _tree.is_reachable(_shown):
		text += "[color=#e0c07e]Linked, but you need %d point%s.[/color]\n" % [
			SkillData.cost(_shown), "" if SkillData.cost(_shown) == 1 else "s"]
	else:
		text += "[color=#8a8f9c]Locked: not linked to your tree yet.[/color]\n"
	if _message != "":
		text += "\n" + _message
	_details.text = text


func _draw_links() -> void:
	var center := _canvas.size / 2.0
	# A faint star chart behind the tree.
	for r in [1.0, 2.0, 3.0]:
		_canvas.draw_arc(center, r * SPACING, 0.0, TAU, 96, Color(0.6, 0.55, 0.45, 0.07), 1.5, true)
	# Owned nodes glow in their branch color.
	for id: String in SkillData.ids():
		if _tree.is_allocated(id):
			var at := center + Vector2(SkillData.NODES[id]["pos"]) * SPACING
			var glow: Color = SkillData.color(id)
			var radius: float = NODE_SIZES[SkillData.NODES[id]["tier"]] * 0.5
			for k in 4:
				_canvas.draw_circle(at, radius + 4.0 + k * 5.0, Color(glow, 0.09))
	var drawn := {}
	for a: String in SkillData.ids():
		for b: String in SkillData.neighbors(a):
			var key := a + "|" + b if a < b else b + "|" + a
			if drawn.has(key):
				continue
			drawn[key] = true
			var from := center + Vector2(SkillData.NODES[a]["pos"]) * SPACING
			var to := center + Vector2(SkillData.NODES[b]["pos"]) * SPACING
			var a_owned := _tree.is_allocated(a)
			var b_owned := _tree.is_allocated(b)
			if a_owned and b_owned:
				# Colored by the outer node, so each branch glows its own color.
				var outer := b if a == SkillData.ROOT else a
				_canvas.draw_line(from, to, Color(SkillData.color(outer), 0.25), 11.0, true)
				_canvas.draw_line(from, to, SkillData.color(outer), 4.0, true)
			elif a_owned or b_owned:
				_canvas.draw_line(from, to, Color(0.55, 0.6, 0.75, 0.8), 3.0, true)
			else:
				_canvas.draw_line(from, to, Color(0.28, 0.3, 0.38, 0.9), 2.0, true)


func _style_button(button: Button, id: String) -> void:
	var branch: Color = SkillData.color(id)
	var size: float = button.custom_minimum_size.x
	var owned := _tree.is_allocated(id)
	var affordable := _tree.can_allocate(id)
	var reachable := _tree.is_reachable(id)

	var fill := Color(0.09, 0.1, 0.13)
	var border := Color(0.3, 0.32, 0.4)
	var border_width := 2
	var text_color := Color(0.5, 0.52, 0.6)
	if owned:
		fill = branch.darkened(0.25)
		border = Color(1, 1, 1, 0.9)
		border_width = 3
		text_color = Color(0.05, 0.06, 0.09)
	elif affordable:
		border = branch
		border_width = 4
		text_color = Color.WHITE
	elif reachable:
		border = Color(branch, 0.5)
		text_color = Color(0.8, 0.82, 0.9)

	for state in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _circle(fill, border, border_width, size))
	button.add_theme_stylebox_override("hover", _circle(fill.lightened(0.15), border.lightened(0.2), border_width, size))
	button.add_theme_stylebox_override("focus", _circle(fill.lightened(0.1), Color.WHITE, 4, size))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)


func _circle(fill: Color, border: Color, border_width: int, size: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(size / 2.0))
	return style


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0.02, 0.7)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	var title := UiStyle.label(30)
	title.text = "Skill Tree"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	header.add_child(title)
	_points_label = UiStyle.label(22)
	header.add_child(_points_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var hint := UiStyle.label(15)
	hint.text = "Click: allocate     Right-click / Backspace: refund     K / Esc: close"
	hint.modulate = Color(1, 1, 1, 0.55)
	header.add_child(hint)

	# Body: the graph on the left, details on the right.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var extent := Vector2.ZERO
	for id: String in SkillData.ids():
		var pos: Vector2i = SkillData.NODES[id]["pos"]
		extent = extent.max(Vector2(absi(pos.x), absi(pos.y)))
	_canvas = Control.new()
	_canvas.custom_minimum_size = extent * 2.0 * SPACING + Vector2(96, 96)
	_canvas.draw.connect(_draw_links)
	body.add_child(_canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 270
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.focus_mode = Control.FOCUS_NONE
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.custom_minimum_size = Vector2(270, 360)
	_details.add_theme_font_size_override("normal_font_size", 16)
	_details.add_theme_font_size_override("bold_font_size", 16)
	side.add_child(_details)
	_reset_button = Button.new()
	_reset_button.text = "Reset all (refund every point)"
	_reset_button.custom_minimum_size = Vector2(0, 40)
	_reset_button.pressed.connect(_on_reset_pressed)
	side.add_child(_reset_button)

	# Node buttons sit on the canvas, positioned around its center.
	for id: String in SkillData.ids():
		var def: Dictionary = SkillData.NODES[id]
		var size: float = NODE_SIZES[def["tier"]]
		var button := Button.new()
		button.custom_minimum_size = Vector2(size, size)
		button.size = Vector2(size, size)
		button.position = _canvas.custom_minimum_size / 2.0 + Vector2(def["pos"]) * SPACING - Vector2(size, size) / 2.0
		button.text = _initials(def["name"])
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_node_pressed.bind(id))
		button.gui_input.connect(_on_node_input.bind(id))
		button.mouse_entered.connect(func() -> void: _hover(id))
		button.focus_entered.connect(func() -> void: _hover(id))
		_canvas.add_child(button)
		_buttons[id] = button


func _hover(id: String) -> void:
	_shown = id
	_message = ""
	_show_details()


## A short label that fits in the node: initials for two-word names ("Keen Eye"
## -> "KE"), the first three letters for single words ("Quickened" -> "Qui").
func _initials(node_name: String) -> String:
	var words := node_name.split(" ")
	if words.size() == 1:
		return node_name.substr(0, 3)
	var letters := ""
	for word in words:
		if word != "" and letters.length() < 2:
			letters += word.substr(0, 1)
	return letters
