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
var build_stats: PlayerStats
var build_unlocked_snapshot: Variant = null
## UI-only goal for this scene. A new/retried/resumed mission starts unpinned.
var pinned_evolution := ""
var _guide_panel: BuildGuidePanel
var _guide_button: Button
var _goal_label: Label
var _page_scroll: ScrollContainer
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
	_page_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 100.0, 260.0, 580.0)
	_guide_button.disabled = build_stats == null
	_refresh_build_goal()
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
		if _guide_panel.visible:
			_show_build_guide(false)
		elif _controls_box.visible:
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
	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "PausePageScroll"
	_page_scroll.custom_minimum_size.y = 580
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.follow_focus = true
	margin.add_child(_page_scroll)
	_page_scroll.add_child(stack)
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
	_guide_panel = BuildGuidePanel.new()
	_guide_panel.name = "BuildGuide"
	stack.add_child(_guide_panel)
	_guide_panel.hide()
	_guide_panel.back_requested.connect(func() -> void: _show_build_guide(false))
	_guide_panel.goal_changed.connect(func(id: String) -> void:
		pinned_evolution = id
		_refresh_build_goal())

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
	var opacity := _slider("Friendly bolts / aura opacity", "friendly_opacity")
	opacity.tooltip_text = "Fade Magic Bolt and Frost Aura only. Other friendly effects, hostile shots, warnings, hero/ally markers and hitboxes are unchanged."
	box.add_child(opacity)
	box.add_child(_toggle("Screen shake", "shake"))
	box.add_child(_toggle("Damage numbers", "numbers"))
	var calm_toggle := _toggle("Calm effects  ·  gentler motion & flashes", "calm")
	calm_toggle.tooltip_text = "No slow motion, with softer flashes and reduced intense effects."
	box.add_child(calm_toggle)
	var bold_toggle := _toggle("Bold warnings  ·  brighter danger cues", "bold_telegraphs")
	bold_toggle.tooltip_text = "Brighter danger circles and lines."
	box.add_child(bold_toggle)
	box.add_child(_slider("Aim assist", "aim_assist"))
	_guide_button = Button.new()
	_guide_button.name = "OpenBuildGuide"
	_guide_button.text = "Build guide   ·   evolution checklist"
	_guide_button.custom_minimum_size.y = 42
	_guide_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_show_build_guide(true))
	box.add_child(_guide_button)
	_goal_label = _menu_label(13)
	_goal_label.name = "PinnedBuildGoal"
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.custom_minimum_size.x = 440
	_goal_label.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_goal_label)
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
	slider.name = "Setting_" + key
	slider.min_value = 0.15 if key == "friendly_opacity" else 0.0
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
		if key in ["aim_assist", "friendly_opacity"]:
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
	_guide_panel.hide()
	_main_box.visible = not on
	_controls_box.visible = on
	if on:
		_fill_controls()


func _show_build_guide(on: bool) -> void:
	if on and build_stats == null: return
	_listening = ""
	_main_box.visible = not on
	_controls_box.hide()
	_guide_panel.visible = on
	_page_scroll.scroll_vertical = 0
	if on:
		_guide_panel.present(build_stats, build_unlocked_snapshot, pinned_evolution)
	else:
		_refresh_build_goal()
		_guide_button.grab_focus.call_deferred()


func _refresh_build_goal() -> void:
	_goal_label.text = BuildGuide.goal_summary(pinned_evolution, build_stats) if build_stats != null else ""
	_goal_label.visible = not _goal_label.text.is_empty()


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
