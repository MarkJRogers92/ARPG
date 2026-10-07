class_name PauseMenu
extends CanvasLayer
## Esc during a run: pauses, with the settings (music and sound volume,
## screen shake, damage numbers), Resume, and a way back to the title.
## Settings are saved by MetaProgress and applied by main.gd's apply_settings().

signal resumed
signal settings_changed
signal quit_to_title

var _root: Control
var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	_root.hide()


func open() -> void:
	_root.show()
	_resume.grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	resumed.emit()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		Sound.play("ui_click")
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.0, 0.0, 0.02, 0.6)
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
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 420
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := UiStyle.label(40)
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(title)

	box.add_child(_slider("Music", "music_volume"))
	box.add_child(_slider("Sound", "sfx_volume"))
	box.add_child(_toggle("Screen shake", "shake"))
	box.add_child(_toggle("Damage numbers", "numbers"))

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)
	_resume = Button.new()
	_resume.text = "Resume   [Esc]"
	_resume.custom_minimum_size.y = 46
	_resume.pressed.connect(func() -> void:
		Sound.play("ui_click")
		close())
	box.add_child(_resume)
	var quit := Button.new()
	quit.text = "Abandon run   ·   back to the title"
	quit.custom_minimum_size.y = 46
	quit.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	quit.pressed.connect(func() -> void:
		Sound.play("ui_click")
		quit_to_title.emit())
	box.add_child(quit)


func _slider(text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UiStyle.label(18)
	label.text = text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = MetaProgress.setting(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 24
	row.add_child(slider)
	var value := UiStyle.label(16)
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % roundi(v * 100.0)
		MetaProgress.set_setting(key, v)
		Sound.apply_volumes()
		if key == "sfx_volume":
			Sound.play("ui_hover"))
	return row


func _toggle(text: String, key: String) -> Control:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = MetaProgress.setting(key)
	check.add_theme_font_size_override("font_size", 18)
	check.toggled.connect(func(on: bool) -> void:
		Sound.play("ui_click")
		MetaProgress.set_setting(key, on)
		settings_changed.emit())
	return check
