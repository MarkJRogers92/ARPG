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
var _exit_confirmation: Control
var _exit_cancel: Button
var _exit_accept: Button
var _exit_title: Label
var _exit_message: Label
var _exit_started := false
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
var _controls_focus_action := ""
var _controls_feedback := ""
var _binding_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	_root.hide()


func open() -> void:
	_exit_started = false
	_root.show()
	_show_controls(false)
	_page_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 100.0, 260.0, 580.0)
	_guide_button.disabled = build_stats == null
	_refresh_build_goal()
	_page_scroll.scroll_vertical = 0
	_focus_resume.call_deferred()


func _focus_resume() -> void:
	if is_inside_tree() and is_open() and _main_box.visible:
		_resume.grab_focus()

func close() -> void:
	if _exit_confirmation: _exit_confirmation.hide()
	_root.hide()
	resumed.emit()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if is_instance_valid(_exit_confirmation) and _exit_confirmation.visible:
		if event.is_action_pressed("ui_cancel"):
			_cancel_exit()
			get_viewport().set_input_as_handled()
		return # The confirmation owns Escape/Enter until dismissed.
	if _listening != "":
		# Rebinding: the next key is the new one (Esc cancels).
		var key := event as InputEventKey
		if key and key.pressed and not key.echo:
			get_viewport().set_input_as_handled()
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			_controls_focus_action = _listening
			var label := _control_label(_listening)
			if code != KEY_ESCAPE:
				var old_name := Controls.key_name(_listening)
				var swapped := ""
				for pair: Array in Controls.ACTIONS:
					if pair[0] != _listening and Controls.key_code(pair[0]) == code:
						swapped = str(pair[1])
				Controls.rebind(_listening, code)
				_controls_feedback = "%s: %s" % [label, Controls.key_name(_listening)]
				if swapped != "": _controls_feedback += " · %s moved to %s" % [swapped, old_name]
				Sound.play("ui_click")
			else:
				_controls_feedback = "%s unchanged: %s" % [label, Controls.key_name(_listening)]
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
	box.custom_minimum_size.x = 640
	box.add_theme_constant_override("separation", 10)
	stack.add_child(box)
	_main_box = box
	_controls_box = VBoxContainer.new()
	_controls_box.custom_minimum_size.x = 640
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

	var title := UiStyle.heading(30)
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_color", RunUi.TEXT)
	box.add_child(title)
	var settings_heading := _menu_label(12)
	settings_heading.text = "Settings"
	settings_heading.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	box.add_child(settings_heading)

	box.add_child(_slider("Music", "music_volume"))
	box.add_child(_slider("Sound", "sfx_volume"))
	var opacity := _slider("Bolt / aura opacity", "friendly_opacity")
	opacity.tooltip_text = "Fade Magic Bolt and Frost Aura only. Other friendly effects, hostile shots, warnings, hero/ally markers and hitboxes are unchanged."
	box.add_child(opacity)
	box.add_child(_toggle("Screen shake", "shake"))
	box.add_child(_toggle("Damage numbers", "numbers"))
	var calm_toggle := _toggle("Calm effects", "calm")
	calm_toggle.tooltip_text = "No slow motion, with softer flashes and reduced intense effects."
	box.add_child(calm_toggle)
	var bold_toggle := _toggle("Bold danger warnings", "bold_telegraphs")
	bold_toggle.tooltip_text = "Brighter danger circles and lines."
	box.add_child(bold_toggle)
	box.add_child(_slider("Aim assist", "aim_assist"))
	_guide_button = Button.new()
	_guide_button.name = "OpenBuildGuide"
	_guide_button.text = "Build guide"
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
	controls.text = "Controls"
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
		_confirm_exit())
	box.add_child(quit)
	# Keep navigation above settings so opening Pause never scrolls past Resume.
	var actions := HBoxContainer.new()
	actions.name = "PauseActions"
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	box.move_child(actions, 1)
	for button: Button in [_resume, _save_button, _quit_button]:
		button.reparent(actions)
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
	_resume.text = "Resume  [Esc]"
	box.move_child(_campaign_notice, 2)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	box.add_child(tools)
	box.move_child(tools, 3)
	for button: Button in [_guide_button, controls]:
		button.reparent(tools)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.move_child(_goal_label, 4)
	_campaign_labels()


func _confirm_exit() -> void:
	if _exit_started or not is_open(): return
	if _exit_confirmation == null:
		var shade := ColorRect.new()
		shade.color = Color(0.015, 0.02, 0.025, 0.94)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(shade)
		_exit_confirmation = shade
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", RunUi.panel(24))
		center.add_child(panel)
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 520
		box.add_theme_constant_override("separation", 18)
		panel.add_child(box)
		_exit_title = RunUi.heading(26)
		box.add_child(_exit_title)
		_exit_message = RunUi.label(16, RunUi.MUTED)
		_exit_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_exit_message)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 12)
		box.add_child(buttons)
		_exit_cancel = Button.new()
		_exit_cancel.text = "Keep this run"
		_exit_accept = Button.new()
		_exit_accept.add_theme_color_override("font_color", RunUi.LOSS)
		for button: Button in [_exit_cancel, _exit_accept]:
			button.custom_minimum_size.y = 44
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(button)
		_exit_cancel.focus_next = _exit_cancel.get_path_to(_exit_accept)
		_exit_cancel.focus_previous = _exit_cancel.get_path_to(_exit_accept)
		_exit_accept.focus_next = _exit_accept.get_path_to(_exit_cancel)
		_exit_accept.focus_previous = _exit_accept.get_path_to(_exit_cancel)
		_exit_cancel.focus_neighbor_right = _exit_cancel.get_path_to(_exit_accept)
		_exit_accept.focus_neighbor_left = _exit_accept.get_path_to(_exit_cancel)
		for button: Button in [_exit_cancel, _exit_accept]:
			button.focus_neighbor_top = button.get_path_to(button)
			button.focus_neighbor_bottom = button.get_path_to(button)
		_exit_cancel.pressed.connect(_cancel_exit)
		_exit_accept.pressed.connect(_commit_exit)
	_exit_title.text = "Retreat to town?" if campaign_mode else "Abandon this run?"
	_exit_message.text = "Unbanked expedition loot will be lost. The route stays committed." if campaign_mode else "This run will end and cannot be resumed. Current run progress is lost; saved account upgrades stay."
	_exit_accept.text = "Retreat" if campaign_mode else "Abandon run"
	_exit_confirmation.show()
	_exit_cancel.grab_focus()


func _cancel_exit() -> void:
	_exit_confirmation.hide()
	_focus_resume.call_deferred()


func _commit_exit() -> void:
	if _exit_started or not is_instance_valid(_exit_confirmation) or not _exit_confirmation.visible: return
	_exit_started = true
	_exit_confirmation.hide()
	quit_to_title.emit()


func _campaign_labels() -> void:
	if _save_button:
		_save_button.text = "Save & quit"
	if _quit_button:
		_quit_button.text = "Retreat to town" if campaign_mode else "Abandon run"
	if _campaign_notice:
		_campaign_notice.text = "Save & quit: restart from departure. Retreat: return to town; unbanked loot is lost." if campaign_mode else "Save & quit: resume from the title. Unfinished chests and rituals end. Abandon: end this run."
		_campaign_notice.visible = true


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
	check.add_theme_font_size_override("font_size", 16)
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
	_page_scroll.scroll_vertical = 0
	if on:
		_controls_focus_action = ""
		_controls_feedback = ""
		_fill_controls()
	else:
		_focus_resume.call_deferred()


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
	_binding_buttons.clear()
	for child in _controls_box.get_children():
		_controls_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.heading(24)
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_color", RunUi.TEXT)
	_controls_box.add_child(title)
	var hint := _menu_label(13)
	hint.text = "Choose a key, then press its replacement. Used keys swap. Esc cancels.\nArrow keys and controller mappings stay unchanged."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	_controls_box.add_child(hint)
	var feedback := RunUi.label(14, RunUi.SOUL)
	feedback.name = "BindingFeedback"
	feedback.text = "Binding %s · press a key, or Esc to cancel" % _control_label(_listening) if _listening != "" else _controls_feedback
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.visible = feedback.text != ""
	_controls_box.add_child(feedback)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 24)
	_controls_box.add_child(groups)
	var movement := VBoxContainer.new()
	var actions := VBoxContainer.new()
	for group: VBoxContainer in [movement, actions]:
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.custom_minimum_size.x = 300
		group.add_theme_constant_override("separation", 8)
		groups.add_child(group)
		var heading := RunUi.label(12, RunUi.MUTED)
		heading.text = "Movement" if group == movement else "Actions"
		group.add_child(heading)
	for pair: Array in Controls.ACTIONS:
		var action: String = pair[0]
		var group: VBoxContainer = movement if action.begins_with("move_") else actions
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := _menu_label(15)
		label.text = pair[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 36)
		b.add_theme_font_size_override("font_size", 14)
		b.text = "Press a key…" if _listening == action else Controls.key_name(action)
		b.name = "Bind_" + action
		_binding_buttons[action] = b
		if _listening == action: b.add_theme_stylebox_override("normal", RunUi.panel(8, RunUi.SOUL))
		b.pressed.connect(func() -> void:
			Sound.play("ui_click")
			if _binding_buttons.get(action) != b or not is_open() or not _controls_box.visible: return
			_listening = action
			_controls_focus_action = action
			_fill_controls())
		row.add_child(b)
		group.add_child(row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.custom_minimum_size = Vector2(190, 40)
	reset.pressed.connect(func() -> void:
		Sound.play("ui_click")
		Controls.reset()
		_controls_feedback = "Keyboard bindings restored to defaults."
		_controls_focus_action = ""
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
	_focus_control_key.call_deferred()


func _focus_control_key() -> void:
	if not is_inside_tree() or not is_open() or not _controls_box.visible: return
	var target: Button = _binding_buttons.get(_controls_focus_action, _binding_buttons.get("move_up"))
	if is_instance_valid(target) and target.is_inside_tree(): target.grab_focus()


func _control_label(action: String) -> String:
	for pair: Array in Controls.ACTIONS:
		if pair[0] == action: return pair[1]
	return action


func _menu_label(font_size: int) -> Label:
	var label := UiStyle.label(font_size)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", RunUi.TEXT)
	return label
