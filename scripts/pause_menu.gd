class_name PauseMenu
extends CanvasLayer
## Esc during a run: pauses, with the settings (music and sound volume,
## screen shake, damage numbers, calm effects, bold warnings, aim assist),
## the Controls panel (key rebinding, see Controls), Resume, and a way back
## to the title. Settings are saved by MetaProgress and applied by main.gd's
## apply_settings().

signal resumed
signal settings_changed
signal quit_to_title
signal save_and_quit

const CampaignMenuStyle = preload("res://scripts/campaign/campaign_menu_style.gd")

## Whether "Save and quit" is offered (main.gd sets it before opening).
var can_save := true:
	set(value):
		can_save = value
		if _save_button:
			_save_button.disabled = not value
			_save_button.tooltip_text = "" if value else "Not while the master of the realm is up."

var _root: Control
var _resume: Button
var _save_button: Button
var _quit_button: Button
var _campaign_notice: Label
var campaign_mode := false:
	set(value):
		campaign_mode = value
		_campaign_labels()
var _main_box: VBoxContainer
var _controls_box: VBoxContainer
## The action waiting for a key press in the Controls panel ("" for none).
var _listening := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	_root.hide()


func open() -> void:
	_root.show()
	_show_controls(false)
	_resume.grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	resumed.emit()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if _listening != "":
		# Rebinding: the next key is the new one (Esc cancels).
		var key := event as InputEventKey
		if key and key.pressed and not key.echo:
			get_viewport().set_input_as_handled()
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if code != KEY_ESCAPE:
				Controls.rebind(_listening, code)
				Sound.play("ui_click")
			_listening = ""
			_fill_controls()
		return
	if event.is_action_pressed("ui_cancel"):
		Sound.play("ui_click")
		if _controls_box.visible:
			_show_controls(false)
		else:
			close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.0, 0.0, 0.02, 0.6)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = CampaignMenuStyle.make_theme(UiStyle.theme())
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CampaignMenuStyle.panel(Color("111923"), Color("554d42"), 1, 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 440
	box.add_theme_constant_override("separation", 10)
	stack.add_child(box)
	_main_box = box
	_controls_box = VBoxContainer.new()
	_controls_box.custom_minimum_size.x = 440
	_controls_box.add_theme_constant_override("separation", 6)
	_controls_box.hide()
	stack.add_child(_controls_box)

	var title := _menu_label(30)
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(title)
	var settings_heading := _menu_label(12)
	settings_heading.text = "SETTINGS"
	settings_heading.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	box.add_child(settings_heading)

	box.add_child(_slider("Music", "music_volume"))
	box.add_child(_slider("Sound", "sfx_volume"))
	box.add_child(_toggle("Screen shake", "shake"))
	box.add_child(_toggle("Damage numbers", "numbers"))
	var calm_toggle := _toggle("Calm effects  ·  gentler motion & flashes", "calm")
	calm_toggle.tooltip_text = "No slow motion, with softer flashes and reduced intense effects."
	box.add_child(calm_toggle)
	var bold_toggle := _toggle("Bold warnings  ·  brighter danger cues", "bold_telegraphs")
	bold_toggle.tooltip_text = "Brighter danger circles and lines."
	box.add_child(bold_toggle)
	box.add_child(_slider("Aim assist", "aim_assist"))
	var controls := Button.new()
	controls.text = "Controls   ·   rebind keys"
	controls.custom_minimum_size.y = 42
	controls.add_theme_stylebox_override("normal", CampaignMenuStyle.quiet_box())
	controls.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_show_controls(true))
	box.add_child(controls)

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)
	_resume = Button.new()
	_resume.text = "Resume   [Esc]"
	_resume.custom_minimum_size.y = 46
	_resume.add_theme_stylebox_override("normal", CampaignMenuStyle.primary_box())
	_resume.add_theme_stylebox_override("hover", CampaignMenuStyle.button_box(Color("715a30"), CampaignMenuStyle.SOUL, 1))
	_resume.add_theme_stylebox_override("focus", CampaignMenuStyle.button_box(Color("273844"), CampaignMenuStyle.SOUL, 2))
	_resume.pressed.connect(func() -> void:
		Sound.play("ui_click")
		close())
	box.add_child(_resume)
	_save_button = Button.new()
	_save_button.text = "Save and quit   ·   resume from the title"
	_save_button.custom_minimum_size.y = 46
	_save_button.add_theme_stylebox_override("normal", CampaignMenuStyle.quiet_box())
	_save_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		save_and_quit.emit())
	box.add_child(_save_button)
	_campaign_notice = _menu_label(13)
	_campaign_notice.text = "This expedition will restart from its saved departure."
	_campaign_notice.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	_campaign_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_notice.custom_minimum_size.x = 440
	box.add_child(_campaign_notice)
	var quit := Button.new()
	_quit_button = quit
	quit.text = "Abandon run   ·   back to the title"
	quit.custom_minimum_size.y = 46
	quit.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	quit.add_theme_stylebox_override("normal", CampaignMenuStyle.button_box(Color("261d20"), Color("69474a"), 1))
	quit.pressed.connect(func() -> void:
		Sound.play("ui_click")
		quit_to_title.emit())
	box.add_child(quit)
	_campaign_labels()


func _campaign_labels() -> void:
	if _save_button:
		_save_button.text = "Save and quit   ·   restart from departure" if campaign_mode else "Save and quit   ·   resume from the title"
	if _quit_button:
		_quit_button.text = "Retreat   ·   return to town, lose unbanked loot" if campaign_mode else "Abandon run   ·   back to the title"
	if _campaign_notice: _campaign_notice.visible = campaign_mode


func _slider(text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _menu_label(16)
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
	var value := _menu_label(14)
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % roundi(v * 100.0)
		MetaProgress.set_setting(key, v)
		Sound.apply_volumes()
		if key == "sfx_volume":
			Sound.play("ui_hover")
		if key == "aim_assist":
			settings_changed.emit())
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


func _show_controls(on: bool) -> void:
	_listening = ""
	_main_box.visible = not on
	_controls_box.visible = on
	if on:
		_fill_controls()


## One row per rebindable action: its name and its key (click, then press the
## new key). A key taken from another action swaps with it.
func _fill_controls() -> void:
	for child in _controls_box.get_children():
		child.queue_free()
	var title := _menu_label(24)
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	_controls_box.add_child(title)
	var hint := _menu_label(13)
	hint.text = "Click a key, then press the new one (Esc cancels). Gamepad buttons and the arrow keys stay as they are."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	_controls_box.add_child(hint)
	for pair: Array in Controls.ACTIONS:
		var action: String = pair[0]
		var row := HBoxContainer.new()
		var label := _menu_label(15)
		label.text = pair[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 32)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "press a key..." if _listening == action else Controls.key_name(action)
		b.pressed.connect(func() -> void:
			Sound.play("ui_click")
			_listening = action
			_fill_controls())
		row.add_child(b)
		_controls_box.add_child(row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.custom_minimum_size = Vector2(190, 40)
	reset.pressed.connect(func() -> void:
		Sound.play("ui_click")
		Controls.reset()
		_fill_controls())
	buttons.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 40)
	back.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_show_controls(false))
	buttons.add_child(back)
	_controls_box.add_child(buttons)


func _menu_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	return label
