class_name Hud
extends CanvasLayer
## HUD, level-up menu and game-over screen. The UI is built in code to keep
## the scene file small; restyle it freely or swap in a hand-made scene.

signal upgrade_chosen(id: String)
signal restart_pressed

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _debug_label: Label
var _toasts: VBoxContainer
var _upgrade_root: Control
var _upgrade_row: HBoxContainer
var _upgrade_ids: Array[String] = []
var _game_over_root: Control
var _game_over_label: Label


func _ready() -> void:
	# The menu has to keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()


## Refresh the always-on display. Cheap enough to call every frame.
func refresh(stats: PlayerStats, elapsed: float, kills: int, enemies: int) -> void:
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_xp_bar.max_value = stats.xp_to_next
	_xp_bar.value = stats.xp
	_level_label.text = "Lv %d" % stats.level
	_time_label.text = _format_time(elapsed)
	_kills_label.text = "Kills %d" % kills
	_debug_label.text = "%d FPS   %d enemies   [Tab] inventory" % [Engine.get_frames_per_second(), enemies]


## A short message that fades out, e.g. loot pickups. Newest at the bottom.
func toast(text: String, color := Color.WHITE) -> void:
	var label := _make_label(18)
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toasts.add_child(label)
	while _toasts.get_child_count() > 6:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func show_upgrades(choices: Array[Dictionary]) -> void:
	for child in _upgrade_row.get_children():
		child.queue_free()
	_upgrade_ids.clear()
	for i in choices.size():
		var choice := choices[i]
		_upgrade_ids.append(choice["id"])
		var button := Button.new()
		button.text = "[%d]  %s\n\n%s" % [i + 1, choice["title"], choice["desc"]]
		button.custom_minimum_size = Vector2(230, 120)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_choose.bind(i))
		_upgrade_row.add_child(button)
		if i == 0:
			button.grab_focus.call_deferred()
	_upgrade_root.show()


func show_game_over(elapsed: float, kills: int, level: int) -> void:
	_game_over_label.text = "You died\n\nSurvived %s   Level %d   Kills %d" % [
			_format_time(elapsed), level, kills]
	_game_over_root.show()


func _input(event: InputEvent) -> void:
	if not _upgrade_root.visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var index := key.keycode - KEY_1
		if index >= 0 and index < _upgrade_ids.size():
			_choose(index)
			get_viewport().set_input_as_handled()


func _choose(index: int) -> void:
	_upgrade_root.hide()
	upgrade_chosen.emit(_upgrade_ids[index])


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top: XP bar across the screen, then HP / level / timer row.
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(column)

	_xp_bar = _make_bar(Color(0.3, 0.8, 1.0), 14)
	column.add_child(_xp_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	_hp_bar = _make_bar(Color(0.9, 0.25, 0.25), 22)
	_hp_bar.custom_minimum_size.x = 260
	row.add_child(_hp_bar)
	_level_label = _make_label(22)
	row.add_child(_level_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_time_label = _make_label(22)
	row.add_child(_time_label)
	_kills_label = _make_label(22)
	row.add_child(_kills_label)

	_debug_label = _make_label(14)
	_debug_label.modulate = Color(1, 1, 1, 0.6)
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.position += Vector2(12, -28)
	root.add_child(_debug_label)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_right = -16.0
	_toasts.offset_bottom = -16.0
	root.add_child(_toasts)

	# Level-up menu.
	var upgrade_box := VBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 16)
	var title := _make_label(30)
	title.text = "Level Up!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_box.add_child(title)
	_upgrade_row = HBoxContainer.new()
	_upgrade_row.add_theme_constant_override("separation", 14)
	upgrade_box.add_child(_upgrade_row)
	_upgrade_root = _make_modal(root, upgrade_box)

	# Game over.
	var over_box := VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 20)
	_game_over_label = _make_label(28)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(_game_over_label)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(200, 56)
	restart.add_theme_font_size_override("font_size", 22)
	restart.pressed.connect(restart_pressed.emit)
	over_box.add_child(restart)
	_game_over_root = _make_modal(root, over_box)
	_game_over_root.visibility_changed.connect(func() -> void:
		if _game_over_root.visible:
			restart.grab_focus())


## Wraps `content` in a centered panel over a dimmed full-screen overlay.
## Returns the (initially hidden) overlay; show()/hide() it to open/close.
func _make_modal(parent: Control, content: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	margin.add_child(content)
	return overlay


@warning_ignore("integer_division")
func _format_time(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _make_label(size: int) -> Label:
	return UiStyle.label(size)
