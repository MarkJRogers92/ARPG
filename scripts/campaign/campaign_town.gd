class_name CampaignTown
extends CanvasLayer
## Campaign hub presentation. Every state change is a CampaignController
## command; this screen only renders snapshots and reports player choices.

signal expedition_requested(spec: Dictionary)
signal quit_requested

const SERVICES := [
	{"id": "route", "label": "ROUTE MAP", "glyph": "◇"},
	{"id": "pack", "label": "EQUIPMENT", "glyph": "▣"},
	{"id": "market", "label": "THE MARKET", "glyph": "⚒"},
	{"id": "trainer", "label": "THE TRAINER", "glyph": "✧"},
	{"id": "roster", "label": "VETERANS", "glyph": "♜"},
	{"id": "ferryman", "label": "FERRYMAN", "glyph": "◉"},
	{"id": "ledger", "label": "THE LEDGER", "glyph": "⌖"},
]

## -1 auto (walkable town except headless test runs), 0 classic menu, 1 walkable.
static var walk_mode := -1
## Phases whose panel must stay on screen until the player resolves it.
const FORCED_PANEL_PHASES := ["EVENT_PENDING", "RESULT_PENDING", "CAMPAIGN_COMPLETE"]

var _controller: Node
var _walk: CampaignWalkTown
var _panel_open := false
var _backdrop_rect: ColorRect
var _veil: ColorRect
var _body_row: HBoxContainer
var _walk_hint: Label
var _walk_spacer: Control
var _state: Dictionary = {}
var _active_service := "route"
var _sanctuary: CampaignBackdrop
var _root: Control
var _status_label: Label
var _abandon_button: Button
var _delivery_button: Button
var _service_buttons: Dictionary = {}
var _content: VBoxContainer
var _content_title: Label
var _place_header_title: Label
var _place_header_subtitle: Label
var _place_context: Label
var _talent_inspection_footer: PanelContainer
var _route_action_footer: PanelContainer
var _route_action_copy: Label
var _route_action_base_copy := ""
var _route_action_button: Button
var _route_preview_id := ""
var _route_preview_can_choose := false
var _route_committed_id := ""
var _route_blocker_service := ""
var _talent_inspection_title: Label
var _talent_inspection_status: Label
var _talent_inspection_description: Label
var _inspected_talent_id := ""
var _feedback: Label
var _selected_item_id := ""
var _selected_slot := "weapon"
var _pack_slot_filter := "all"
var _pack_sort := "bag"
var _pack_filter_dropdown: OptionButton
var _pack_sort_dropdown: OptionButton
var _clause_slot := "weapon"
var _clause_offer := 0
var _event_selection: Dictionary = {}
var _wager_pledge := false
var _wager_node_id := ""
var _stolen_offers: Array = []
var _mara_dialogue: PanelContainer
var _mara_title: Label
var _mara_copy: Label
var _mara_choices: VBoxContainer
var _mara_dialogue_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	if not _state.is_empty():
		_render()


func setup(controller: Node) -> void:
	_controller = controller
	if _controller.has_signal("changed") and not _controller.is_connected("changed", _on_changed):
		_controller.connect("changed", _on_changed)
	if _controller.has_signal("error_raised") and not _controller.is_connected("error_raised", _on_error):
		_controller.connect("error_raised", _on_error)
	_state = _controller.snapshot()
	_render()
	# Put keyboard and gamepad users on a meaningful control as soon as the town opens.
	if is_inside_tree() and _service_buttons.has(_active_service) and _body_row.is_visible_in_tree():
		(_service_buttons[_active_service] as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _state.get("phase", "") == "CAMPAIGN_COMPLETE":
			get_viewport().set_input_as_handled()
			return
		if str(_state.get("phase", "")) in ["EVENT_PENDING", "RESULT_PENDING"]:
			get_viewport().set_input_as_handled()
			return
		if _mara_dialogue_open:
			_close_mara_dialogue()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(_walk) and _panel_open:
			_close_panel()
			get_viewport().set_input_as_handled()
			return
		if _active_service != "route":
			_active_service = "route"
			_render()
			get_viewport().set_input_as_handled()
			return
		quit_requested.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var backdrop := ColorRect.new()
	_backdrop_rect = backdrop
	backdrop.color = Color(0.028, 0.042, 0.065)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var veil := ColorRect.new()
	_veil = veil
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.018, 0.035, 0.34)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 22 if side in ["left", "right"] else 16)
	_root.add_child(frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	frame.add_child(layout)
	_build_header(layout)
	var body := HBoxContainer.new()
	_body_row = body
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	_build_service_rail(body)
	_build_center(body)
	_build_status(body)
	_feedback = UiStyle.label(14)
	_feedback.custom_minimum_size.y = 24
	_feedback.add_theme_color_override("font_color", Color(1.0, 0.72, 0.48))
	layout.add_child(_feedback)
	if walking_enabled():
		_build_walk(layout)
		_build_mara_dialogue()


static func walking_enabled() -> bool:
	return walk_mode == 1 or (walk_mode == -1 and DisplayServer.get_name() != "headless")


## The walkable sanctuary sits behind this CanvasLayer; service panels become
## overlays opened at their stations (see docs/expedition_campaign/WALKABLE_TOWN.md).
func _build_walk(layout: Control) -> void:
	_walk = CampaignWalkTown.new()
	_walk.name = "WalkableSanctuary"
	add_child(_walk)
	_walk.station_used.connect(_open_station)
	_walk.mara_used.connect(_open_mara_dialogue)
	_backdrop_rect.visible = false
	if is_instance_valid(_sanctuary):
		_sanctuary.visible = false
	_walk_spacer = Control.new()
	_walk_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_walk_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_walk_spacer)
	_walk_hint = UiStyle.label(15)
	_walk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_walk_hint.text = "%s  move     %s  use     ESC  save & leave" % ["WASD", Controls.tag("interact")]
	_walk_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_walk_hint.modulate = Color(1, 1, 1, 0.7)
	layout.add_child(_walk_hint)


func _open_station(id: String) -> void:
	Sound.play("ui_click", 0.88, -7.0)
	_active_service = id
	_panel_open = true
	_render()
	if _service_buttons.has(id):
		(_service_buttons[id] as Button).grab_focus.call_deferred()


func _close_panel() -> void:
	_panel_open = false
	_render()
	get_viewport().gui_release_focus()


func _build_mara_dialogue() -> void:
	_mara_dialogue = PanelContainer.new()
	_mara_dialogue.name = "MaraConversation"
	_mara_dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_mara_dialogue.anchor_left = 0.24
	_mara_dialogue.anchor_right = 0.76
	_mara_dialogue.anchor_top = 0.64
	_mara_dialogue.anchor_bottom = 0.97
	_mara_dialogue.offset_left = 0
	_mara_dialogue.offset_right = 0
	_mara_dialogue.offset_top = 0
	_mara_dialogue.offset_bottom = -12
	_mara_dialogue.add_theme_stylebox_override("panel", UiStyle.box(Color(0.035, 0.038, 0.048, 0.97), Color(0.58, 0.43, 0.25), 2, 8))
	_mara_dialogue.visible = false
	_root.add_child(_mara_dialogue)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_mara_dialogue.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	_mara_title = UiStyle.label(19)
	_mara_title.text = "MARA VENN  ·  GRAVEDIGGER"
	_mara_title.add_theme_color_override("font_color", UiStyle.GOLD)
	column.add_child(_mara_title)
	_mara_copy = UiStyle.label(16)
	_mara_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mara_copy.custom_minimum_size.y = 44
	_mara_copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_mara_copy)
	_mara_choices = VBoxContainer.new()
	_mara_choices.add_theme_constant_override("separation", 4)
	column.add_child(_mara_choices)


## Walk mode: the panel row shows only while a service is open or a phase
## demands an answer; otherwise the hero walks the plaza.
func _apply_walk_layout() -> void:
	if not is_instance_valid(_walk):
		return
	var panel_visible := _panel_open or str(_state.get("phase", "TOWN")) in FORCED_PANEL_PHASES
	_body_row.visible = panel_visible
	_veil.visible = panel_visible or _mara_dialogue_open
	_veil.color.a = 0.34 if panel_visible else (0.12 if _mara_dialogue_open else 0.0)
	_walk_spacer.visible = not panel_visible
	_walk_hint.visible = not panel_visible and not _mara_dialogue_open
	_walk.walking = not panel_visible and not _mara_dialogue_open
	_walk.present(_state)
	if is_instance_valid(_walk._camp_life):
		_walk._camp_life.set_talk_prompt(_walk._camp_talk_enabled, _walk._hero_pos, _walk.walking)
	if is_instance_valid(_mara_dialogue):
		_mara_dialogue.visible = _mara_dialogue_open
		if _mara_dialogue_open and (panel_visible or not _mara_available()):
			_mara_dialogue_open = false
			_mara_dialogue.visible = false
			_walk.walking = not panel_visible
			_walk_hint.visible = not panel_visible
			_veil.visible = panel_visible
			_veil.color.a = 0.34 if panel_visible else 0.0


func _mara_available() -> bool:
	if str(_state.get("phase", "")) != "TOWN":
		return false
	var place := CampaignWaystops.resolve(_state)
	return int(place.get("biome_index", -1)) == 0 and int(place.get("stage", -1)) == 1 and str(place.get("kind", "")) == "camp"


func _open_mara_dialogue() -> void:
	if not is_instance_valid(_walk) or _panel_open or _mara_dialogue_open or not _mara_available():
		return
	Sound.play("ui_click", 0.88, -7.0)
	_mara_dialogue_open = true
	_set_mara_page("intro")
	_apply_walk_layout()
	if _mara_choices.get_child_count() > 0:
		call_deferred("_focus_mara_choice_if_open", _mara_choices.get_child(0))


func _set_mara_page(page: String) -> void:
	for child: Node in _mara_choices.get_children():
		_mara_choices.remove_child(child)
		child.queue_free()
	var buttons: Array[Dictionary]
	match page:
		"ahead":
			_mara_copy.text = "Follow the old bell road north. Bellwether's crossing is still standing, though its tower rings at the wrong hours. If you hear the bells twice, keep to the stones."
			buttons = [{"text": "Ask something else", "page": "intro"}, {"text": "Leave", "page": "close"}]
		"stay":
			_mara_copy.text = "Someone has to tend the plots and keep the lamps lit. The crew buried here were our neighbors before they were names on a stone. We won't leave them in the dark."
			buttons = [{"text": "Ask something else", "page": "intro"}, {"text": "Leave", "page": "close"}]
		_:
			_mara_copy.text = "Mara wipes soot from her gloves. “I'm Mara Venn. I keep the lamps and graves, so the road can stay clear for you.”"
			buttons = [{"text": "What lies ahead?", "page": "ahead"}, {"text": "Why stay here?", "page": "stay"}, {"text": "Leave", "page": "close"}]
	for choice: Dictionary in buttons:
		var button := Button.new()
		button.text = str(choice["text"])
		button.custom_minimum_size.y = 35
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_mara_choice.bind(str(choice["page"])))
		_mara_choices.add_child(button)


func _mara_choice(page: String) -> void:
	if page == "close":
		_close_mara_dialogue()
	else:
		_set_mara_page(page)
		if _mara_choices.get_child_count() > 0:
			call_deferred("_focus_mara_choice_if_open", _mara_choices.get_child(0))


func _focus_mara_choice_if_open(button: Button) -> void:
	if _mara_dialogue_open and is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _close_mara_dialogue() -> void:
	_mara_dialogue_open = false
	if is_instance_valid(_mara_dialogue):
		_mara_dialogue.visible = false
	if is_instance_valid(_walk):
		_walk.walking = not (_panel_open or str(_state.get("phase", "TOWN")) in FORCED_PANEL_PHASES)
		_walk_hint.visible = not _panel_open and str(_state.get("phase", "TOWN")) not in FORCED_PANEL_PHASES
		_veil.visible = _panel_open or str(_state.get("phase", "TOWN")) in FORCED_PANEL_PHASES
		_veil.color.a = 0.34 if _veil.visible else 0.0
	get_viewport().gui_release_focus()


func _build_header(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	parent.add_child(header)
	var title := UiStyle.label(30)
	title.text = "THE LAST LANTERN"
	_place_header_title = title
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	header.add_child(title)
	var subtitle := UiStyle.label(14)
	subtitle.text = "   SANCTUARY BETWEEN EXPEDITIONS"
	_place_header_subtitle = subtitle
	subtitle.modulate = Color(1, 1, 1, 0.7)
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_status_label = UiStyle.label(16)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_status_label)
	var leave := Button.new()
	leave.text = "Save & Leave"
	leave.custom_minimum_size = Vector2(144, 42)
	leave.pressed.connect(func() -> void: quit_requested.emit())
	header.add_child(leave)


func _build_service_rail(parent: Control) -> void:
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 174
	rail.add_theme_constant_override("separation", 8)
	parent.add_child(rail)
	for service: Dictionary in SERVICES:
		var button := Button.new()
		button.text = "%s   %s" % [service["glyph"], service["label"]]
		button.custom_minimum_size = Vector2(168, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_service.bind(service["id"]))
		rail.add_child(button)
		_service_buttons[service["id"]] = button
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(spacer)
	var hint := UiStyle.label(12)
	hint.text = "ARROWS / D-PAD   navigate\nTAB   move focus\nESC   back / save & leave"
	hint.modulate = Color(1, 1, 1, 0.55)
	rail.add_child(hint)


func _build_center(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.038, 0.049, 0.067, 0.98), Color(0.43, 0.34, 0.22, 0.92), 2, 8))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var title_row := HBoxContainer.new()
	stack.add_child(title_row)
	_content_title = UiStyle.label(24)
	_content_title.add_theme_color_override("font_color", UiStyle.GOLD)
	title_row.add_child(_content_title)
	_place_context = UiStyle.label(13)
	_place_context.add_theme_color_override("font_color", UiStyle.MUTED)
	_place_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_place_context)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	stack.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_route_action_footer = PanelContainer.new()
	_route_action_footer.visible = false
	_route_action_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_action_footer.add_theme_stylebox_override("panel", UiStyle.box(Color(0.075, 0.085, 0.105, 0.99), Color(0.77, 0.59, 0.3, 0.95), 1, 6))
	stack.add_child(_route_action_footer)
	var route_footer_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		route_footer_margin.add_theme_constant_override("margin_" + side, 10 if side in ["left", "right"] else 6)
	_route_action_footer.add_child(route_footer_margin)
	var route_footer_row := HBoxContainer.new()
	route_footer_row.add_theme_constant_override("separation", 12)
	route_footer_margin.add_child(route_footer_row)
	_route_action_copy = UiStyle.label(13)
	_route_action_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_action_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_footer_row.add_child(_route_action_copy)
	_route_action_button = Button.new()
	_route_action_button.custom_minimum_size = Vector2(250, 44)
	_route_action_button.pressed.connect(_activate_route_action)
	route_footer_row.add_child(_route_action_button)
	_talent_inspection_footer = PanelContainer.new()
	_talent_inspection_footer.visible = false
	_talent_inspection_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_inspection_footer.add_theme_stylebox_override("panel", UiStyle.box(Color(0.07, 0.08, 0.1, 0.98), Color(0.3, 0.34, 0.39, 0.72), 1, 5))
	stack.add_child(_talent_inspection_footer)
	var footer_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		footer_margin.add_theme_constant_override("margin_" + side, 9 if side in ["left", "right"] else 6)
	_talent_inspection_footer.add_child(footer_margin)
	var footer_content := VBoxContainer.new()
	footer_content.add_theme_constant_override("separation", 2)
	footer_margin.add_child(footer_content)
	var footer_heading := HBoxContainer.new()
	footer_content.add_child(footer_heading)
	_talent_inspection_title = UiStyle.label(15)
	_talent_inspection_title.add_theme_color_override("font_color", UiStyle.GOLD)
	footer_heading.add_child(_talent_inspection_title)
	_talent_inspection_status = UiStyle.label(12)
	_talent_inspection_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_inspection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_talent_inspection_status.add_theme_color_override("font_color", UiStyle.MUTED)
	footer_heading.add_child(_talent_inspection_status)
	_talent_inspection_description = UiStyle.label(12)
	_talent_inspection_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_inspection_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_content.add_child(_talent_inspection_description)


func _build_status(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 226
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.035, 0.046, 0.065, 0.98), Color(0.3, 0.34, 0.39, 0.7), 1, 8))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := UiStyle.label(16)
	title.text = "CAMPAIGN RECORD"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(title)
	box.add_child(_section("Journey", "biome"))
	box.add_child(_section("Campaign Gold", "gold"))
	box.add_child(_section("Talent Points", "talents"))
	box.add_child(_section("Veterans", "veterans"))
	box.add_child(HSeparator.new())
	var ledger := UiStyle.label(14)
	ledger.name = "ClauseSummary"
	ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ledger)
	box.add_child(HSeparator.new())
	var rule := UiStyle.label(12)
	rule.text = "COMBAT GROWTH RESETS\nYOUR BANKED BUILD REMAINS"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.modulate = Color(0.72, 0.83, 0.86, 0.68)
	box.add_child(rule)
	_abandon_button = Button.new()
	_abandon_button.text = "Abandon Campaign"
	_abandon_button.tooltip_text = "End this campaign and return to the title screen."
	_abandon_button.custom_minimum_size.y = 38
	_abandon_button.add_theme_color_override("font_color", Color(0.92, 0.58, 0.48))
	_abandon_button.pressed.connect(_confirm_abandon_campaign)
	box.add_child(_abandon_button)
	_delivery_button = Button.new()
	_delivery_button.text = "Retry Profile Rewards"
	_delivery_button.tooltip_text = "Retry saving earned campaign rewards to your profile."
	_delivery_button.custom_minimum_size.y = 38
	_delivery_button.add_theme_color_override("font_color", Color(0.62, 0.82, 0.93))
	_delivery_button.pressed.connect(func() -> void: _command("deliver_outbox"))
	box.add_child(_delivery_button)
	var sanctuary := CampaignBackdrop.new()
	_sanctuary = sanctuary
	sanctuary.name = "SanctuaryVignette"
	# Decoration yields space to ledger text and reward recovery controls.
	sanctuary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sanctuary)


func _section(title: String, key: String) -> Control:
	var wrapper := VBoxContainer.new()
	var heading := UiStyle.label(12)
	heading.text = title.to_upper()
	heading.modulate = Color(1, 1, 1, 0.5)
	wrapper.add_child(heading)
	var value := UiStyle.label(18)
	value.name = "Value_" + key
	value.add_theme_color_override("font_color", UiStyle.GOLD if key == "gold" else UiStyle.TEXT)
	wrapper.add_child(value)
	return wrapper


func _select_service(id: String) -> void:
	_active_service = id
	_panel_open = true
	_render()


func _on_changed(state: Dictionary) -> void:
	var restore_pack_focus := _pack_content_has_focus()
	var action_focus := _current_action_focus_identity()
	var focus_service := _active_service
	_state = state.duplicate(true)
	_feedback.text = ""
	_render()
	if restore_pack_focus and _active_service == "pack" and str(_state.get("phase", "TOWN")) in ["TOWN", "DEPARTURE_READY"]:
		_restore_pack_selection_focus.call_deferred()
	elif not action_focus.is_empty() and _active_service == focus_service and str(_state.get("phase", "TOWN")) in ["TOWN", "DEPARTURE_READY"]:
		_restore_town_action_focus.call_deferred(focus_service, str(action_focus["kind"]), str(action_focus["id"]))


func _on_error(message: String) -> void:
	_feedback.text = message


func _render() -> void:
	if not is_instance_valid(_root):
		return
	_apply_walk_layout()
	if is_instance_valid(_sanctuary):
		_sanctuary.present(_state)
	var biome_names := ["THE HOLLOW GRAVEYARD", "THE FROZEN WASTES", "THE EMBER RIFT"]
	var biome := clampi(int(_state.get("biome_index", 0)), 0, 2)
	var waystop := CampaignWaystops.resolve(_state)
	var phase := str(_state.get("phase", "TOWN"))
	_place_header_title.text = str(waystop["name"]).to_upper()
	_place_header_subtitle.text = "   %s  ·  STOP %d / 4" % [biome_names[biome], int(waystop["stage"]) + 1] if int(waystop["stage"]) < 4 else "   THE ROAD ENDS IN DAWN"
	_place_context.text = str(waystop["description"])
	if is_instance_valid(_walk_hint):
		_walk_hint.text = "%s\n%s  move     %s  use     ESC  save & leave" % [str(waystop["arrival_line"]), "WASD", Controls.tag("interact")]
	_abandon_button.visible = phase not in ["CAMPAIGN_COMPLETE", "ABANDONED"]
	_delivery_button.visible = not _state.get("outbox", []).is_empty() and phase not in ["RESULT_PENDING", "CAMPAIGN_COMPLETE", "ABANDONED"]
	var clear_count := _current_biome_clear_count(_state)
	_status_label.text = "%s   ·   %d / 3 CLEARS" % [phase.replace("_", " "), clear_count]
	_set_named_value("Value_biome", "%s\n%s   ·   %d / 3 clears" % [str(waystop["name"]), biome_names[biome], clear_count])
	_set_named_value("Value_gold", "%s G" % _number(int(_state.get("gold", 0))))
	var talents: Dictionary = _state.get("talents", {})
	_set_named_value("Value_talents", "%d available   ·   %d earned" % [int(talents.get("points", 0)), int(talents.get("earned", 0))])
	var roster: Array = _state.get("roster", [])
	_set_named_value("Value_veterans", "%d / 3   ·   %s" % [roster.size(), "deployed" if not str(_state.get("deployed_veteran", "")).is_empty() else "none deployed"])
	var clause_names: Array[String] = []
	for clause: Variant in _state.get("clauses", []):
		if clause is Dictionary:
			var clause_id := str(clause.get("id", ""))
			var clause_definition: Dictionary = CampaignCatalog.CLAUSES.get(clause_id, {})
			clause_names.append(str(clause.get("name", clause_definition.get("name", clause_id.replace("_", " ").capitalize()))))
		else:
			clause_names.append(str(clause))
	var clause_text := "THE FERRYMAN'S LEDGER\n%s" % ("\n".join(clause_names) if not clause_names.is_empty() else "No obligations accepted")
	_set_named_value("ClauseSummary", clause_text)
	for id: Variant in _service_buttons:
		var button := _service_buttons[id] as Button
		button.add_theme_stylebox_override("normal", UiStyle.box(Color(0.19, 0.15, 0.09, 0.96) if str(id) == _active_service else Color(0.08, 0.085, 0.1, 0.92), UiStyle.GOLD if str(id) == _active_service else UiStyle.BRONZE.darkened(0.3), 2, 5))
	_render_panel()


func _set_named_value(node_name: String, text: String) -> void:
	var node := _root.find_child(node_name, true, false)
	if node is Label:
		(node as Label).text = text


func _render_panel() -> void:
	if not is_instance_valid(_content):
		return
	for child in _content.get_children():
		child.queue_free()
	var phase := str(_state.get("phase", "TOWN"))
	_route_action_footer.visible = _active_service == "route" and phase in ["TOWN", "DEPARTURE_READY"]
	_route_preview_id = ""
	_route_preview_can_choose = false
	_route_committed_id = str(_state.get("selected_node", ""))
	_update_talent_inspection_footer()
	if phase == "EVENT_PENDING":
		_content_title.text = "AN EVENT ON THE ROAD"
		_render_event()
		return
	if phase == "RESULT_PENDING":
		_content_title.text = "RETURN FROM THE EXPEDITION"
		_render_result()
		return
	if phase == "CAMPAIGN_COMPLETE":
		_content_title.text = "THE ROAD ENDS IN DAWN"
		_render_complete()
		return
	match _active_service:
		"route":
			_content_title.text = "THE ROAD THROUGH THE VEIL"
			_render_route()
		"pack":
			_content_title.text = "THE ARMORY"
			_render_pack()
		"market":
			_content_title.text = "THE MARKET & FORGE"
			_render_market()
		"trainer":
			_content_title.text = "THE TRAINER"
			_render_trainer()
		"roster":
			_content_title.text = "THE VETERAN HALL"
			_render_roster()
		"ferryman":
			_content_title.text = "THE FERRYMAN'S TABLE"
			_render_ferryman()
		"ledger":
			_content_title.text = "THE FERRYMAN'S LEDGER"
			_render_ledger()


func _current_action_focus_identity() -> Dictionary:
	if _active_service not in ["market", "trainer", "ledger"] or not is_instance_valid(_content):
		return {}
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not (_content == focused or _content.is_ancestor_of(focused)):
		return {}
	var kind := str(focused.get_meta("town_action_focus_kind", ""))
	var item_id := str(focused.get_meta("town_action_focus_id", ""))
	return {"kind": kind, "id": item_id} if not kind.is_empty() and not item_id.is_empty() else {}


func _restore_town_action_focus(service: String, kind: String, item_id: String) -> void:
	if not is_inside_tree() or _active_service != service or service not in ["market", "trainer", "ledger"] or str(_state.get("phase", "TOWN")) not in ["TOWN", "DEPARTURE_READY"]:
		return
	var current_focus := get_viewport().gui_get_focus_owner()
	if current_focus != null and not current_focus.is_queued_for_deletion() and not (_content == current_focus or _content.is_ancestor_of(current_focus)):
		return
	var target := _find_town_action_focus_target(_content, kind, item_id)
	if _town_action_control_is_available(target):
		target.grab_focus()
		return
	var fallback := _find_available_town_action_focus_target(_content)
	if fallback != null:
		fallback.grab_focus()
		return
	if _service_buttons.has(service):
		(_service_buttons[service] as Button).grab_focus()


func _find_town_action_focus_target(node: Node, kind: String, item_id: String) -> Control:
	if node.is_queued_for_deletion():
		return null
	if node is Control and node.get_meta("town_action_focus_kind", "") == kind and node.get_meta("town_action_focus_id", "") == item_id:
		return node as Control
	for child: Node in node.get_children():
		var target := _find_town_action_focus_target(child, kind, item_id)
		if target != null:
			return target
	return null


func _find_available_town_action_focus_target(node: Node) -> Control:
	if node.is_queued_for_deletion():
		return null
	if node is Control and not str(node.get_meta("town_action_focus_kind", "")).is_empty() and _town_action_control_is_available(node as Control):
		return node as Control
	for child: Node in node.get_children():
		var target := _find_available_town_action_focus_target(child)
		if target != null:
			return target
	return null


func _town_action_control_is_available(control: Control) -> bool:
	if control == null or control.is_queued_for_deletion() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	return not control is BaseButton or not (control as BaseButton).disabled


func _set_town_action_focus_identity(control: Control, kind: String, item_id: String) -> void:
	control.set_meta("town_action_focus_kind", kind)
	control.set_meta("town_action_focus_id", item_id)


func _render_route() -> void:
	var waystop := CampaignWaystops.resolve(_state)
	_add_copy("%s · stop %d of 4\nVictory takes you to the next stop. Failure or retreat brings you back here." % [
		str(waystop["name"]), int(waystop["stage"]) + 1])
	var graph: Dictionary = _state.get("graph", {})
	if graph.is_empty():
		_add_copy("The route map will appear once the campaign begins.")
		return
	var route_view := CampaignRouteView.new()
	route_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_view.show_confirm_button = false
	route_view.choose_requested.connect(_choose_route)
	route_view.preview_changed.connect(_on_route_preview_changed)
	var selected := str(_state.get("selected_node", ""))
	_content.add_child(route_view)
	var available: Array = _controller.available_routes()
	route_view.present(_state, available)
	_render_preparation_panel(selected)
	_refresh_route_action()
	var ready := _departure_blockers().is_empty()
	if ready:
		var delivery_pending: bool = not _state.get("outbox", []).is_empty()
		_add_copy("Departure checks passed. %s" % ("Profile rewards still await delivery; you may leave and retry delivery from the campaign record." if delivery_pending else "The route is committed; combat starts from a fresh expedition build."))


func _on_route_preview_changed(node_id: String, route_title: String, can_choose: bool, committed_id: String, committed_title: String) -> void:
	_route_preview_id = node_id
	_route_preview_can_choose = can_choose
	_route_committed_id = committed_id
	var title := route_title if not route_title.is_empty() else "No route selected"
	if not committed_id.is_empty():
		var committed_name := committed_title if not committed_title.is_empty() else committed_id
		_route_action_base_copy = "Preview · %s\nCommitted route · %s" % [title, committed_name] if node_id != committed_id else "Committed route · %s" % committed_name
	else:
		_route_action_base_copy = "Preview · %s\nYour preview is free; choose it to commit this expedition." % title
	_refresh_route_action()


func _refresh_route_action() -> void:
	if not is_instance_valid(_route_action_button):
		return
	if not _route_committed_id.is_empty():
		var blockers := _departure_blockers()
		_route_blocker_service = str(blockers[0].get("service", "")) if not blockers.is_empty() else ""
		if blockers.is_empty():
			_route_action_button.text = "Depart for committed route"
			_route_action_button.disabled = false
			_route_action_copy.text = _route_action_base_copy + "\nReady to depart."
		else:
			_route_action_button.text = "Open %s" % str(blockers[0].get("label", "Preparation")) if not _route_blocker_service.is_empty() else "Departure blocked"
			_route_action_button.disabled = _route_blocker_service.is_empty()
			_route_action_copy.text = _route_action_base_copy + "\nDeparture blocked · " + str(blockers[0].get("text", "Preparation required."))
	else:
		_route_action_copy.text = _route_action_base_copy
		_route_action_button.text = "Choose this route"
		_route_action_button.disabled = not _route_preview_can_choose or _route_preview_id.is_empty()


func _activate_route_action() -> void:
	if not _route_committed_id.is_empty():
		var blockers := _departure_blockers()
		if not blockers.is_empty():
			var service := str(blockers[0].get("service", ""))
			if not service.is_empty():
				_select_service(service)
			return
		var response: Dictionary = _command("depart")
		if response.get("ok", false):
			Sound.play("ui_click", 0.82, -3.0)
			expedition_requested.emit(response.get("spec", {}))
	elif _route_preview_can_choose and not _route_preview_id.is_empty():
		_choose_route(_route_preview_id)


func _render_preparation_panel(selected_node_id: String) -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	_content.add_child(panel)
	_add_subtitle(panel, "BEFORE YOU DEPART")
	var mission := "No mission committed · choose an open route on the map below."
	var graph: Dictionary = _state.get("graph", {})
	var nodes: Dictionary = graph.get("nodes", {})
	var selected_node: Variant = nodes.get(selected_node_id, {})
	if not selected_node_id.is_empty() and selected_node is Dictionary and not selected_node.is_empty():
		var node: Dictionary = selected_node
		var contract_id := str(node.get("contract", "hunt"))
		var contract: Dictionary = CampaignCatalog.CONTRACTS.get(contract_id, {})
		var contract_name := str(contract.get("name", contract_id.replace("_", " ").capitalize()))
		var biome_index := clampi(int(_state.get("biome_index", 0)), 0, Realm.ORDER.size() - 1)
		var realm := str(Realm.data(Realm.ORDER[biome_index]).get("name", "The Hollow Graveyard"))
		mission = "Destination · %s\nCommitted mission · %s%s" % [realm, contract_name, " · Elite" if bool(node.get("elite", false)) and contract_id != "elite_hunt" else ""]
	_add_preparation_copy(panel, mission, Color(0.83, 0.86, 0.91))
	var clauses: Array[String] = []
	for clause_value: Variant in _state.get("clauses", []):
		var clause_id := str(clause_value.get("id", "")) if clause_value is Dictionary else str(clause_value)
		var definition: Dictionary = CampaignCatalog.CLAUSES.get(clause_id, {})
		clauses.append(str(definition.get("name", clause_value.get("name", clause_id.replace("_", " ").capitalize()) if clause_value is Dictionary else clause_id.replace("_", " ").capitalize())))
	_add_preparation_copy(panel, "Ledger obligations · %s" % (", ".join(clauses) if not clauses.is_empty() else "none"), UiStyle.MUTED)
	_render_starting_build_summary(panel)
	var blockers := _departure_blockers()
	if not blockers.is_empty():
		_add_copy_to(panel, "REQUIRED BEFORE DEPARTURE", Color(0.96, 0.67, 0.48))
		for blocker: Dictionary in blockers:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			panel.add_child(row)
			_add_preparation_copy(row, "• " + str(blocker["text"]), Color(1.0, 0.78, 0.66))
			if not str(blocker.get("service", "")).is_empty():
				var service_button := _button("Open %s" % blocker["label"], _select_service.bind(str(blocker["service"])), Color(0.78, 0.85, 0.96))
				service_button.custom_minimum_size.y = 32
				row.add_child(service_button)
	else:
		_add_copy_to(panel, "No required preparation remains.", Color(0.67, 0.88, 0.75))
	var choices: Array[Dictionary] = _optional_preparation_choices()
	if not choices.is_empty():
		_add_copy_to(panel, "OPTIONAL PREPARATION", UiStyle.GOLD)
		for choice: Dictionary in choices:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			panel.add_child(row)
			_add_preparation_copy(row, "• " + str(choice["text"]), UiStyle.TEXT)
			var service_button := _button("Open %s" % choice["label"], _select_service.bind(str(choice["service"])), Color(0.78, 0.85, 0.96))
			service_button.custom_minimum_size.y = 32
			row.add_child(service_button)


func _departure_blockers() -> Array[Dictionary]:
	var blockers: Array[Dictionary] = []
	var phase := str(_state.get("phase", "TOWN"))
	var allowed_phase := phase in ["TOWN", "DEPARTURE_READY"]
	var selected := str(_state.get("selected_node", ""))
	if phase == "CAMPAIGN_COMPLETE" or bool(_state.get("completed", false)):
		blockers.append({"text": "The campaign is complete; no further departure is available."})
	elif not allowed_phase:
		var phase_copy := "Resolve the road event first." if phase == "EVENT_PENDING" else ("Acknowledge the expedition result before another departure." if phase == "RESULT_PENDING" else "Departure is unavailable during this campaign phase.")
		blockers.append({"text": phase_copy})
	if selected.is_empty() and phase != "EVENT_PENDING":
		blockers.append({"text": "Choose and commit a route before departure."})
	var inventory: Dictionary = _state.get("inventory", {})
	var tray: Array = inventory.get("tray", [])
	if not tray.is_empty():
		blockers.append({"text": "%d reward%s wait in the tray; claim, sell, or discard them." % [tray.size(), "s" if tray.size() != 1 else ""], "service": "pack", "label": "Armory"})
	if not (_state.get("reforge", {}) as Dictionary).is_empty():
		blockers.append({"text": "Choose which reforge copy to keep.", "service": "market", "label": "Market"})
	if not (_state.get("veteran_candidate", {}) as Dictionary).is_empty():
		blockers.append({"text": "Keep or decline the veteran who returned with you.", "service": "roster", "label": "Veterans"})
	var wager: Dictionary = _state.get("wager", {})
	if str(wager.get("status", "")) in ["open", "won"]:
		blockers.append({"text": "Take or finish the reserved Ferryman prize.", "service": "ferryman", "label": "Ferryman"})
	return blockers


func _optional_preparation_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var talents: Dictionary = _state.get("talents", {})
	var points := int(talents.get("points", 0))
	if points > 0:
		choices.append({"text": "%d unspent talent point%s." % [points, "s" if points != 1 else ""], "service": "trainer", "label": "Trainer"})
	if int(talents.get("earned", 0)) > 3 and str(_state.get("specialization", "")).is_empty():
		choices.append({"text": "Your specialization is unlocked but not selected.", "service": "trainer", "label": "Trainer"})
	var deployed := str(_state.get("deployed_veteran", ""))
	var usable_deployed := false
	var available_veteran: Dictionary = {}
	for veteran_value: Variant in _state.get("roster", []):
		if not veteran_value is Dictionary:
			continue
		var veteran: Dictionary = veteran_value
		var veteran_id := str(veteran.get("id", ""))
		var unpledged := str(veteran.get("pledge_node", "")).is_empty()
		if veteran_id == deployed and unpledged:
			usable_deployed = true
		elif available_veteran.is_empty() and unpledged:
			available_veteran = veteran
	if not usable_deployed and not available_veteran.is_empty():
		var text := "%s is available in the Crypt; deploy a veteran for this expedition." % str(available_veteran.get("name", "A veteran"))
		choices.append({"text": text, "service": "roster", "label": "Veterans"})
	return choices


func _add_preparation_copy(parent: Control, text: String, color: Color) -> Label:
	var label := _add_copy_to(parent, text, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _choose_route(node_id: String) -> void:
	var response := _command("choose_route", [node_id])
	if response.get("ok", false):
		_active_service = "route"
		_render()


func _render_pack() -> void:
	var inventory: Dictionary = _state.get("inventory", {})
	var items: Dictionary = inventory.get("items", {})
	var equipped: Dictionary = inventory.get("equipped", {})
	var backpack: Array = inventory.get("backpack", [])
	var tray: Array = inventory.get("tray", [])
	var backpack_full := backpack.size() >= Inventory.BACKPACK_SIZE
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(columns)
	var item_column := VBoxContainer.new()
	item_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(item_column)
	_add_subtitle(item_column, "WORN GEAR · SIX SLOTS")
	for slot: Variant in ItemData.SLOTS:
		var item_id := str(equipped.get(slot, ""))
		var record: Dictionary = items.get(item_id, {})
		var button := _button("%s   ·   %s" % [ItemData.SLOT_NAMES.get(slot, str(slot)), _item_name(record)], func() -> void: _select_item(item_id, str(slot)), UiStyle.GOLD)
		_set_pack_focus_identity(button, "worn", item_id)
		button.disabled = item_id.is_empty()
		item_column.add_child(button)
	_add_subtitle(item_column, "BACKPACK · %d / %d" % [backpack.size(), Inventory.BACKPACK_SIZE])
	if backpack_full:
		_add_copy_to(item_column, "Backpack full. Free a slot to buy, claim, or unequip gear; sell or discard an item here.", UiStyle.MUTED)
	var pack_tools := HBoxContainer.new()
	pack_tools.add_theme_constant_override("separation", 6)
	item_column.add_child(pack_tools)
	var slot_filter := OptionButton.new()
	_pack_filter_dropdown = slot_filter
	slot_filter.add_item("All slots")
	for slot: Variant in ItemData.SLOTS:
		slot_filter.add_item(ItemData.SLOT_NAMES.get(slot, str(slot)))
	var selected_filter := 0
	if _pack_slot_filter != "all":
		selected_filter = ItemData.SLOTS.find(_pack_slot_filter) + 1
	if selected_filter >= 0:
		slot_filter.select(selected_filter)
	slot_filter.tooltip_text = "Filter backpack by equipment slot. Rewards stay visible below."
	slot_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_filter.item_selected.connect(_on_pack_filter_selected)
	pack_tools.add_child(slot_filter)
	var sort_order := OptionButton.new()
	_pack_sort_dropdown = sort_order
	for label in ["Bag order", "Rarity", "Item level", "Name"]:
		sort_order.add_item(label)
	var sort_options := ["bag", "rarity", "ilvl", "name"]
	sort_order.select(maxi(0, sort_options.find(_pack_sort)))
	sort_order.tooltip_text = "Change how backpack gear is listed. This affects only this view."
	sort_order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_order.item_selected.connect(_on_pack_sort_selected)
	pack_tools.add_child(sort_order)
	var filtered_ids := _pack_item_ids(backpack, items)
	var visible_ids: Array[String] = []
	for item_id: String in filtered_ids:
		var record: Dictionary = items.get(item_id, {})
		if _pack_slot_filter == "all" or str(record.get("data", {}).get("slot", "weapon")) == _pack_slot_filter:
			visible_ids.append(item_id)
	var count := UiStyle.label(12)
	count.text = "Showing %d of %d" % [visible_ids.size(), backpack.size()]
	count.modulate = Color(1, 1, 1, 0.62)
	item_column.add_child(count)
	var tray_hint := UiStyle.label(12)
	tray_hint.text = "Reward tray: %d unclaimed below the backpack; slot filters never hide rewards." % tray.size()
	tray_hint.modulate = Color(0.68, 0.82, 0.9, 0.9)
	tray_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_column.add_child(tray_hint)
	for item_id: String in visible_ids:
		var rec: Dictionary = items.get(item_id, {})
		var mark := "◆ " if bool(rec.get("locked", false)) else ("× " if bool(rec.get("junk", false)) else "")
		var b := _button("%s%s  ·  %s" % [mark, _item_name(rec), _rarity_text(rec)], func() -> void: _select_item(item_id, str(rec.get("data", {}).get("slot", "weapon"))), _rarity_color(rec))
		_set_pack_focus_identity(b, "backpack", item_id)
		item_column.add_child(b)
	_add_subtitle(item_column, "REWARD TRAY · %d unclaimed" % tray.size())
	for item_id_variant: Variant in tray:
		var item_id := str(item_id_variant)
		var rec: Dictionary = items.get(item_id, {})
		var tray_card := VBoxContainer.new()
		tray_card.add_theme_constant_override("separation", 5)
		item_column.add_child(tray_card)
		var tray_label := UiStyle.label(14)
		tray_label.text = _summary(rec.get("data", {}))
		tray_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tray_card.add_child(tray_label)
		var tray_actions := HBoxContainer.new()
		tray_actions.add_theme_constant_override("separation", 4)
		tray_card.add_child(tray_actions)
		var compare := _button("Compare", func() -> void: _select_item(item_id, str(rec.get("data", {}).get("slot", "weapon"))))
		_set_pack_focus_identity(compare, "tray", item_id)
		tray_actions.add_child(compare)
		var claim := _button("Claim", func() -> void: _command("claim_item", [item_id]), UiStyle.GOLD)
		claim.disabled = backpack.size() >= Inventory.BACKPACK_SIZE
		tray_actions.add_child(claim)
		tray_actions.add_child(_button("Sell", func() -> void: _command("sell_items", [[item_id], false]), Color(0.88, 0.75, 0.48)))
		tray_actions.add_child(_button("Discard", func() -> void: _confirm_discard(item_id), Color(0.9, 0.55, 0.46)))
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size.x = 280
	columns.add_child(detail_column)
	_add_subtitle(detail_column, "COMPARE & MANAGE")
	if not _selected_item_id.is_empty() and not _inventory_has_item(inventory, _selected_item_id):
		_selected_item_id = ""
	var selected: Dictionary = items.get(_selected_item_id, {})
	_add_item_detail(detail_column, selected)
	if not _selected_item_id.is_empty() and not visible_ids.has(_selected_item_id) and backpack.has(_selected_item_id):
		_add_copy_to(detail_column, "Selected item is outside this backpack filter. Clear the slot filter to see it in the list.", UiStyle.MUTED)
	var worn_id := str(equipped.get(_selected_slot, ""))
	var worn: Dictionary = items.get(worn_id, {})
	if not _selected_item_id.is_empty() and worn_id != _selected_item_id:
		_add_item_comparison(detail_column, worn, selected)
	if not _selected_item_id.is_empty():
		var in_backpack := backpack.has(_selected_item_id)
		var in_tray := tray.has(_selected_item_id)
		var equipped_here := str(equipped.get(_selected_slot, "")) == _selected_item_id
		if equipped_here or in_backpack:
			var equipped_action := "unequip_item" if equipped_here else "equip_item"
			var equipped_args: Array = [_selected_slot] if equipped_here else [_selected_item_id]
			var equip_button := _button("Unequip" if equipped_here else "Equip", func() -> void: _command(equipped_action, equipped_args))
			equip_button.disabled = equipped_here and backpack_full
			detail_column.add_child(equip_button)
		if not equipped_here and not in_tray:
			detail_column.add_child(_button("Lock / unlock", func() -> void: _toggle_item_mark(_selected_item_id, "locked")))
			detail_column.add_child(_button("Mark / unmark junk", func() -> void: _toggle_item_mark(_selected_item_id, "junk")))
			var discard := _button("Discard selected", func() -> void: _confirm_discard(_selected_item_id), Color(0.9, 0.55, 0.46))
			discard.disabled = bool(selected.get("locked", false))
			detail_column.add_child(discard)
			var reforge := _button("Reforge · %d G" % int(_reforge_fee()), func() -> void: _command("reforge_item", [_selected_item_id]), UiStyle.GOLD)
			reforge.disabled = bool(selected.get("locked", false)) or int(_state.get("gold", 0)) < _reforge_fee()
			detail_column.add_child(reforge)
		elif in_tray:
			var claim_selected := _button("Claim to backpack", func() -> void: _command("claim_item", [_selected_item_id]), UiStyle.GOLD)
			claim_selected.disabled = backpack.size() >= Inventory.BACKPACK_SIZE
			detail_column.add_child(claim_selected)
			detail_column.add_child(_button("Sell selected", func() -> void: _command("sell_items", [[_selected_item_id], false]), Color(0.88, 0.75, 0.48)))
			detail_column.add_child(_button("Discard selected", func() -> void: _confirm_discard(_selected_item_id), Color(0.9, 0.55, 0.46)))
	var marked_ids: Array[String] = []
	for item_id_value: Variant in backpack:
		var record: Dictionary = items.get(str(item_id_value), {})
		if bool(record.get("junk", false)) and not bool(record.get("locked", false)):
			marked_ids.append(str(item_id_value))
	var sale := _button("Sell marked junk", func() -> void: _command("sell_items", [marked_ids, true]), Color(0.88, 0.75, 0.48))
	sale.disabled = marked_ids.is_empty()
	detail_column.add_child(sale)
	if _state.get("reforge", {}) is Dictionary and not (_state.get("reforge", {}) as Dictionary).is_empty():
		_render_reforge(detail_column)


func _on_pack_filter_selected(index: int) -> void:
	_pack_slot_filter = "all" if index == 0 else str(ItemData.SLOTS[index - 1])
	_render_panel()
	if is_instance_valid(_pack_filter_dropdown):
		_pack_filter_dropdown.grab_focus.call_deferred()


func _on_pack_sort_selected(index: int) -> void:
	_pack_sort = ["bag", "rarity", "ilvl", "name"][index]
	_render_panel()
	if is_instance_valid(_pack_sort_dropdown):
		_pack_sort_dropdown.grab_focus.call_deferred()


func _pack_item_ids(backpack: Array, items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for item_id_value: Variant in backpack:
		ids.append(str(item_id_value))
	if _pack_sort == "bag":
		return ids
	ids.sort_custom(func(a: String, b: String) -> bool:
		var a_record: Dictionary = items.get(a, {})
		var b_record: Dictionary = items.get(b, {})
		var a_data: Dictionary = a_record.get("data", {})
		var b_data: Dictionary = b_record.get("data", {})
		var a_value: Variant
		var b_value: Variant
		match _pack_sort:
			"rarity":
				a_value = int(a_data.get("rarity", 0))
				b_value = int(b_data.get("rarity", 0))
			"ilvl":
				a_value = int(a_data.get("ilvl", 0))
				b_value = int(b_data.get("ilvl", 0))
			"name":
				a_value = str(a_data.get("name", a_data.get("base_name", "Item"))).to_lower()
				b_value = str(b_data.get("name", b_data.get("base_name", "Item"))).to_lower()
		if a_value == b_value:
			return a < b
		return a_value > b_value if _pack_sort != "name" else a_value < b_value
	)
	return ids


func _inventory_has_item(inventory: Dictionary, item_id: String) -> bool:
	return inventory.get("items", {}).has(item_id) and (inventory.get("backpack", []).has(item_id) or inventory.get("tray", []).has(item_id) or inventory.get("equipped", {}).values().has(item_id))


func _select_item(item_id: String, slot: String) -> void:
	_selected_item_id = item_id
	_selected_slot = slot
	_render_panel()
	_restore_pack_selection_focus.call_deferred()


func _set_pack_focus_identity(control: Control, kind: String, item_id: String) -> void:
	control.set_meta("equipment_pack_focus_kind", kind)
	control.set_meta("equipment_pack_focus_id", item_id)


func _pack_content_has_focus() -> bool:
	if not is_instance_valid(_content):
		return false
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and (_content == focused or _content.is_ancestor_of(focused))


func _restore_pack_selection_focus() -> void:
	if not is_inside_tree() or _active_service != "pack" or str(_state.get("phase", "TOWN")) not in ["TOWN", "DEPARTURE_READY"]:
		return
	var current_focus := get_viewport().gui_get_focus_owner()
	if current_focus != null and not current_focus.is_queued_for_deletion() and not (_content == current_focus or _content.is_ancestor_of(current_focus)):
		return
	var target_kind := ""
	var inventory: Dictionary = _state.get("inventory", {})
	var item_id := _selected_item_id
	if not item_id.is_empty() and _inventory_has_item(inventory, item_id):
		if inventory.get("equipped", {}).values().has(item_id):
			target_kind = "worn"
		elif inventory.get("backpack", []).has(item_id):
			target_kind = "backpack"
		elif inventory.get("tray", []).has(item_id):
			target_kind = "tray"
	var target := _find_pack_focus_target(_content, target_kind, item_id) if not target_kind.is_empty() else null
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		if not target is BaseButton or not (target as BaseButton).disabled:
			if target_kind == "worn":
				# The panel rebuild queues old rows and creates replacements. Wait for
				# their geometry to settle before changing focus or scroll state.
				await get_tree().process_frame
				if not is_inside_tree() or _active_service != "pack" or not is_instance_valid(target) or target.is_queued_for_deletion():
					return
				var post_layout_focus := get_viewport().gui_get_focus_owner()
				if post_layout_focus != null and not post_layout_focus.is_queued_for_deletion() and not (_content == post_layout_focus or _content.is_ancestor_of(post_layout_focus)):
					return
				if not target.is_visible_in_tree() or target.focus_mode == Control.FOCUS_NONE:
					return
				if target is BaseButton and (target as BaseButton).disabled:
					return
				var scroll := _content.get_parent() as ScrollContainer
				if not is_instance_valid(scroll):
					return
				# Worn rows are at the top. Suppress stale focus-follow geometry
				# only during this synchronous focus-and-scroll update.
				var follow_focus := scroll.follow_focus
				scroll.follow_focus = false
				target.grab_focus()
				scroll.scroll_vertical = 0
				scroll.follow_focus = follow_focus
			else:
				target.grab_focus()
				var scroll := _content.get_parent() as ScrollContainer
				if is_instance_valid(scroll):
					scroll.ensure_control_visible(target)
			return
	if is_instance_valid(_pack_filter_dropdown) and _pack_filter_dropdown.is_visible_in_tree():
		_pack_filter_dropdown.grab_focus()


func _find_pack_focus_target(node: Node, kind: String, item_id: String) -> Control:
	if node.is_queued_for_deletion():
		return null
	if node is Control and node.get_meta("equipment_pack_focus_kind", "") == kind and node.get_meta("equipment_pack_focus_id", "") == item_id:
		return node as Control
	for child: Node in node.get_children():
		var target := _find_pack_focus_target(child, kind, item_id)
		if target != null:
			return target
	return null


func _toggle_item_mark(item_id: String, key: String) -> void:
	var rec: Dictionary = _state.get("inventory", {}).get("items", {}).get(item_id, {})
	var locked := bool(rec.get("locked", false))
	var junk := bool(rec.get("junk", false))
	if key == "locked":
		locked = not locked
	else:
		junk = not junk
	_command("mark_item", [item_id, locked, junk])


func _confirm_discard(item_id: String) -> void:
	var box := ConfirmationDialog.new()
	box.dialog_text = "Discard this item permanently?"
	box.confirmed.connect(func() -> void: _command("discard_item", [item_id]))
	_root.add_child(box)
	box.popup_centered()


func _render_reforge(parent: Control) -> void:
	var pending: Dictionary = _state.get("reforge", {})
	_add_subtitle(parent, "REFORGE · KEEP ONE COPY")
	var original: Dictionary = pending.get("old", {})
	var reforged: Dictionary = pending.get("new", {})
	_add_copy_to(parent, "%d Gold already paid · either choice consumes this biome's reforge for the item." % int(pending.get("cost", 0)), UiStyle.MUTED)
	_add_copy_to(parent, "Original · %s · item level %d" % [_rarity_text(original), int(original.get("data", {}).get("ilvl", 1))], UiStyle.MUTED)
	_add_copy_to(parent, "Reforged · %s · item level %d" % [_rarity_text(reforged), int(reforged.get("data", {}).get("ilvl", 1))], UiStyle.MUTED)
	_add_item_comparison(parent, original, reforged, "Original", "Reforged")
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_button("Keep original", func() -> void: _command("resolve_reforge", [false])))
	row.add_child(_button("Keep new", func() -> void: _command("resolve_reforge", [true]), UiStyle.GOLD))


func _render_market() -> void:
	_add_copy("The Market's stock is saved for this town visit. Compare the item and listed cost before you buy.")
	var pending_reforge: Dictionary = _state.get("reforge", {})
	if not pending_reforge.is_empty():
		_render_reforge(_content)
	var inventory: Dictionary = _state.get("inventory", {})
	var backpack: Array = inventory.get("backpack", [])
	var backpack_full := backpack.size() >= Inventory.BACKPACK_SIZE
	if backpack_full:
		_add_copy("Backpack · %d / %d — full. Free a slot to buy, claim, or unequip gear; sell or discard an item in Equipment." % [backpack.size(), Inventory.BACKPACK_SIZE])
		_content.add_child(_button("Open Equipment to free a slot", func() -> void: _select_service("pack"), Color(0.67, 0.82, 0.93)))
	else:
		_add_copy("Backpack · %d / %d" % [backpack.size(), Inventory.BACKPACK_SIZE])
	var shop: Variant = _state.get("shop", [])
	var stock: Variant = shop.get("stock", []) if shop is Dictionary else shop
	if stock is Dictionary:
		var keyed_stock: Array = []
		for stock_id: Variant in stock:
			var entry: Variant = stock[stock_id]
			if entry is Dictionary:
				var record: Dictionary = entry.duplicate(true)
				record["id"] = str(record.get("id", stock_id))
				keyed_stock.append(record)
		stock = keyed_stock
	for entry: Variant in stock:
		var stock_item: Dictionary = entry if entry is Dictionary else {}
		var id := str(stock_item.get("id", stock_item.get("stock_id", "")))
		var item_value: Variant = stock_item.get("item", {})
		var item_record: Dictionary = item_value if item_value is Dictionary else {}
		var data_value: Variant = item_record.get("data", stock_item.get("data", {}))
		var data: Dictionary = data_value if data_value is Dictionary else {}
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_content.add_child(row)
		var item_details := VBoxContainer.new()
		item_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_details)
		_add_item_detail(item_details, item_record if not item_record.is_empty() else {"data": data, "valuation": stock_item.get("valuation", 0)})
		var price := int(stock_item.get("price", stock_item.get("valuation", 0)))
		var purchased := bool(stock_item.get("purchased", false))
		var buy := _button("Purchased" if purchased else "Buy · %d G" % price, func() -> void: _command("buy_item", [id]), UiStyle.GOLD)
		_set_town_action_focus_identity(buy, "market_stock", id)
		buy.disabled = purchased or id.is_empty() or backpack_full or int(_state.get("gold", 0)) < price
		row.add_child(buy)
		var slot := str(data.get("slot", ""))
		if ItemData.SLOTS.has(slot):
			var worn_id := str(_state.get("inventory", {}).get("equipped", {}).get(slot, ""))
			var worn: Dictionary = _state.get("inventory", {}).get("items", {}).get(worn_id, {})
			_add_item_comparison(_content, worn, item_record if not item_record.is_empty() else {"data": data})
	if stock.is_empty():
		_add_copy("The shelves are bare. A new shipment comes after the next expedition.")
	if _selected_item_id.is_empty():
		_add_subtitle(_content, "SELECT A BACKPACK ITEM IN THE ARMORY TO REFORGE OR SELL")
	else:
		var row := HBoxContainer.new()
		_content.add_child(row)
		var record: Dictionary = _state.get("inventory", {}).get("items", {}).get(_selected_item_id, {})
		var is_backpack: bool = _state.get("inventory", {}).get("backpack", []).has(_selected_item_id)
		var reforge := _button("Reforge selected · %d G" % int(_reforge_fee()), func() -> void: _command("reforge_item", [_selected_item_id]), UiStyle.GOLD)
		reforge.disabled = not is_backpack or bool(record.get("locked", false)) or int(_state.get("gold", 0)) < _reforge_fee()
		row.add_child(reforge)
		var sell := _button("Sell selected · %d G" % _sell_value(_selected_item_id), func() -> void: _command("sell_items", [[_selected_item_id], false]))
		sell.disabled = not is_backpack or bool(record.get("locked", false))
		row.add_child(sell)


func _render_starting_build_summary(parent: Control) -> void:
	var preview: Dictionary = CampaignLoadout.preview(_state)
	if preview.is_empty():
		var unavailable := UiStyle.label(11)
		unavailable.text = "Starting build summary unavailable."
		unavailable.modulate = UiStyle.MUTED
		parent.add_child(unavailable)
		return
	var heading := UiStyle.label(12)
	heading.text = "STARTING BUILD"
	heading.add_theme_color_override("font_color", UiStyle.GOLD)
	parent.add_child(heading)
	var metric_values := [
		"HP %s" % _format_starting_build_number(float(preview["max_hp"])),
		"Armor %s" % _format_starting_build_number(float(preview["armor"])),
		"Move %s" % _format_starting_build_number(float(preview["move_speed"])),
		"Crit %s%%" % String.num(float(preview["crit_chance"]) * 100.0, 1),
		"Army capacity %d" % int(preview["minion_max"]),
	]
	var primary_text := str(preview["primary_attack_label"])
	primary_text += " · %s dmg per hit · %s s cooldown" % [
		_format_starting_build_number(float(preview["primary_damage"])),
		_format_starting_build_cooldown(float(preview["primary_cooldown"])),
	]
	var summary := UiStyle.label(13)
	summary.text = "%s\nPrimary %s" % [" · ".join(metric_values), primary_text]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.modulate = Color(1.0, 1.0, 1.0, 0.84)
	parent.add_child(summary)
	var route_copy := "Baseline · no route committed. Values are before temporary upgrades or conditional combat bonuses."
	var selected_node_id := str(preview["selected_node_id"])
	var stat_effect_count := int(preview["stat_effect_count"])
	if not selected_node_id.is_empty():
		if stat_effect_count > 0:
			var names: PackedStringArray = []
			for effect_name: Variant in preview["stat_effect_names"]:
				names.append(str(effect_name))
			route_copy = "Route stat modifiers included · %s. Values are before temporary upgrades or conditional combat bonuses." % ", ".join(names)
		else:
			route_copy = "Committed route · no added starting stat modifiers. Values are before temporary upgrades or conditional combat bonuses."
	var note := UiStyle.label(11)
	note.text = route_copy
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = UiStyle.MUTED
	parent.add_child(note)

func _format_starting_build_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 1)


func _format_starting_build_cooldown(value: float) -> String:
	return String.num(value, 2)


func _render_trainer() -> void:
	var talents: Dictionary = _state.get("talents", {})
	var allocated: Array = talents.get("allocated", [])
	_add_copy("Campaign talents survive each expedition. Only successful node settlements grant points; refunds return them here.")
	var points := UiStyle.label(20)
	points.text = "%d talent points available   ·   %d / 18 earned" % [int(talents.get("points", 0)), int(talents.get("earned", 0))]
	points.add_theme_color_override("font_color", UiStyle.GOLD)
	_content.add_child(points)
	_render_starting_build_summary(_content)
	var tree := GridContainer.new()
	tree.columns = 4
	tree.add_theme_constant_override("h_separation", 7)
	tree.add_theme_constant_override("v_separation", 6)
	tree.size_flags_horizontal = Control.SIZE_FILL
	_content.add_child(tree)
	for id: String in SkillData.NODES:
		if id == SkillData.ROOT:
			continue
		var def: Dictionary = SkillData.NODES[id]
		var owned := allocated.has(id)
		var cost: int = SkillData.COSTS[def["tier"]]
		var reachable := SkillData.neighbors(id).any(func(neighbor: String) -> bool: return neighbor == SkillData.ROOT or allocated.has(neighbor))
		var button := _button("%s%s\n%d pt" % ["◆ " if owned else "◇ ", def["name"], cost], func() -> void:
			_command("refund_talent" if owned else "allocate_talent", [id]), SkillData.BRANCHES[def["branch"]])
		_set_town_action_focus_identity(button, "talent", id)
		button.custom_minimum_size = Vector2(132, 52)
		button.tooltip_text = "\n".join(SkillData.description_lines(id))
		button.disabled = not owned and (not reachable or int(talents.get("points", 0)) < cost)
		button.focus_entered.connect(_inspect_talent.bind(id, button))
		button.mouse_entered.connect(_inspect_talent.bind(id, button))
		tree.add_child(button)
	_update_talent_inspection_footer()
	var action_row := HBoxContainer.new()
	_content.add_child(action_row)
	action_row.add_child(_button("Free talent respec", func() -> void: _confirm_reset_talents(), Color(0.8, 0.66, 0.5)))
	_add_subtitle(_content, "SPECIALIZATION · SELECT OR RESPEC IN TOWN")
	var specialization := str(_state.get("specialization", ""))
	var specialization_unlocked := int(talents.get("earned", 0)) > 3
	if not specialization_unlocked:
		_add_copy("Earn one more talent point from a successful expedition to unlock a specialization.")
	for path: Dictionary in Specializations.paths(str(_state.get("hero_class", "battlemage"))):
		var path_id := str(path["id"])
		var card := PanelContainer.new()
		card.name = "SpecializationCard_" + path_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiStyle.box(Color(0.055, 0.065, 0.08, 0.96), path["color"].darkened(0.48), 1, 5))
		_content.add_child(card)
		var card_margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			card_margin.add_theme_constant_override("margin_" + side, 8 if side in ["left", "right"] else 5)
		card.add_child(card_margin)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 3)
		card_margin.add_child(card_content)
		var button := _button("%s%s" % ["✓  " if specialization == path_id else "", path["name"]], func() -> void: _command("choose_specialization", [path_id]), path["color"])
		button.name = "SpecializationAction_" + path_id
		_set_town_action_focus_identity(button, "specialization", path_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.disabled = specialization == str(path["id"]) or not specialization_unlocked
		card_content.add_child(button)
		var description := _add_copy_to(card_content, str(path["desc"]), path["color"])
		description.name = "SpecializationDescription_" + path_id


func _inspect_talent(id: String, source: Control) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not is_instance_valid(_content):
		return
	if not _content.is_ancestor_of(source) or _active_service != "trainer" or str(_state.get("phase", "TOWN")) not in ["TOWN", "DEPARTURE_READY"]:
		return
	if _find_town_action_focus_target(_content, "talent", id) != source:
		return
	if not SkillData.NODES.has(id) or id == SkillData.ROOT:
		return
	_inspected_talent_id = id
	_update_talent_inspection_footer()


func _update_talent_inspection_footer() -> void:
	if not is_instance_valid(_talent_inspection_footer):
		return
	var visible := _active_service == "trainer" and str(_state.get("phase", "TOWN")) in ["TOWN", "DEPARTURE_READY"]
	_talent_inspection_footer.visible = visible
	if not visible:
		return
	if _inspected_talent_id.is_empty() or not SkillData.NODES.has(_inspected_talent_id) or _inspected_talent_id == SkillData.ROOT:
		for talent_id: String in SkillData.NODES:
			if talent_id != SkillData.ROOT:
				_inspected_talent_id = talent_id
				break
	if _inspected_talent_id.is_empty() or not SkillData.NODES.has(_inspected_talent_id):
		_talent_inspection_title.text = "TALENT DETAILS"
		_talent_inspection_status.text = ""
		_talent_inspection_description.text = "No talents are available to inspect."
		return
	var definition: Dictionary = SkillData.NODES[_inspected_talent_id]
	var talents: Dictionary = _state.get("talents", {})
	var allocated: Array = talents.get("allocated", [])
	var cost := int(SkillData.COSTS[definition["tier"]])
	_talent_inspection_title.text = str(definition["name"])
	_talent_inspection_status.text = "Cost · %d pt · %s" % [cost, "Owned" if allocated.has(_inspected_talent_id) else "Not owned"]
	_talent_inspection_description.text = "\n".join(SkillData.description_lines(_inspected_talent_id))


func _confirm_reset_talents() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Refund all campaign talent allocations? Points are returned for a new build."
	dialog.confirmed.connect(func() -> void: _command("reset_talents"))
	_root.add_child(dialog)
	dialog.popup_centered()


func _render_roster() -> void:
	var roster: Array = _state.get("roster", [])
	var deployed := str(_state.get("deployed_veteran", ""))
	var effective_rank_cap := int(_state.get("biome_index", 0)) + 1
	_add_copy("Only one veteran travels with you. Campaign echoes recover after a failed attempt; their account Crypt originals remain untouched.")
	for veteran: Variant in roster:
		if not veteran is Dictionary:
			continue
		var id := str(veteran.get("id", ""))
		var row := HBoxContainer.new()
		_content.add_child(row)
		var info := UiStyle.label(16)
		var rank := int(veteran.get("rank", 1))
		var effective_rank := mini(rank, effective_rank_cap)
		var pledge_node := str(veteran.get("pledge_node", ""))
		var pledge_copy := "Pledged until the next route clears" if pledge_node == "next" else ("Pledged to route %s" % pledge_node if not pledge_node.is_empty() else "Available")
		info.text = "%s  ·  %s  ·  Rank %d (travels as %d; biome rank cap %d)\n%s\n%s" % [veteran.get("name", "Unnamed veteran"), _veteran_role_name(veteran), rank, effective_rank, effective_rank_cap, pledge_copy, _veteran_record_details(veteran)]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var button := _button("Deployed" if deployed == id else "Deploy", func() -> void: _command("choose_veteran", [id]), UiStyle.GOLD)
		button.disabled = deployed == id or not str(veteran.get("pledge_node", "")).is_empty()
		row.add_child(button)
	var candidate: Dictionary = _state.get("veteran_candidate", {})
	if not candidate.is_empty():
		_add_subtitle(_content, "A VETERAN SURVIVED THE EXPEDITION")
		_add_copy("Keep this companion, choose whom they replace, or decline. Replacement is confirmed before the roster changes.")
		var candidate_id := str(candidate.get("id", candidate.get("candidate_id", "")))
		var candidate_name := str(candidate.get("name", "Unnamed veteran"))
		var candidate_rank := int(candidate.get("rank", 1))
		var candidate_effective_rank := mini(candidate_rank, effective_rank_cap)
		var candidate_info := UiStyle.label(16)
		candidate_info.text = "%s  ·  %s  ·  Rank %d (travels as %d; biome rank cap %d)\n%s" % [candidate_name, _veteran_role_name(candidate), candidate_rank, candidate_effective_rank, effective_rank_cap, _veteran_record_details(candidate)]
		candidate_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		candidate_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(candidate_info)
		var add_candidate := _button("Add to the roster", func() -> void: _recruit_veteran(candidate_id, ""), UiStyle.GOLD)
		add_candidate.disabled = roster.size() >= 3
		_content.add_child(add_candidate)
		if add_candidate.disabled:
			_add_copy("The roster is full. Replace an available veteran to make room.")
		for veteran: Variant in roster:
			if veteran is Dictionary:
				var replace_id := str(veteran.get("id", ""))
				var replace_button := _button("Replace %s" % veteran.get("name", "veteran"), func() -> void: _confirm_recruit_veteran(candidate_id, replace_id, candidate_name, str(veteran.get("name", "this veteran"))), Color(0.9, 0.68, 0.42))
				replace_button.disabled = not str(veteran.get("pledge_node", "")).is_empty()
				_content.add_child(replace_button)
				if replace_button.disabled:
					_add_copy("%s is pledged and cannot be replaced until that route clears." % veteran.get("name", "This veteran"))
		_content.add_child(_button("Decline this veteran", func() -> void: _command("decline_veteran"), Color(0.8, 0.57, 0.51)))
	if roster.is_empty() and candidate.is_empty():
		_add_copy("No veteran is ready yet. Survive a mission and a named soul may choose to follow you home.")


func _recruit_veteran(candidate_id: String, replace_id: String) -> void:
	_command("recruit_veteran", [candidate_id, replace_id])


func _veteran_role_name(veteran: Dictionary) -> String:
	var role := str(veteran.get("role", "Veteran"))
	if Army.ROLES.has(role):
		return str(Army.ROLES[role].get("label", role))
	return role


func _veteran_record_details(veteran: Dictionary) -> String:
	var details: Array[String] = []
	var deeds: Variant = veteran.get("deeds", null)
	if deeds is int or deeds is float:
		details.append("Kills (deeds): %d" % int(deeds))
	elif deeds != null and not str(deeds).is_empty():
		details.append(str(deeds))
	if veteran.has("nights"):
		details.append("Nights: %d" % int(veteran["nights"]))
	if details.is_empty():
		details.append("A soul who has seen the road.")
	return "  ·  ".join(details)


func _confirm_recruit_veteran(candidate_id: String, replace_id: String, candidate_name: String, old_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Replace %s with %s?" % [old_name, candidate_name]
	dialog.confirmed.connect(func() -> void: _recruit_veteran(candidate_id, replace_id))
	_root.add_child(dialog)
	dialog.popup_centered()


func _render_ferryman() -> void:
	var wager: Dictionary = _state.get("wager", {})
	if wager.is_empty():
		_add_copy("No prize waits on the table. After a successful short expedition, the Ferryman reserves one of that node's settlement rewards here.")
		return
	var node_id := str(wager.get("node_id", ""))
	if node_id != _wager_node_id:
		_wager_node_id = node_id
		_wager_pledge = false
	var prizes: Array = wager.get("prizes", [])
	var status := str(wager.get("status", ""))
	if status in ["open", "won"]:
		_add_subtitle(_content, "THE STAKE · RESERVED FROM YOUR EXPEDITION REWARD")
	elif status == "taken":
		_add_subtitle(_content, "PRIZE TAKEN · BANKED IN YOUR CAMPAIGN INVENTORY")
	elif status == "lost":
		_add_subtitle(_content, "THE FERRYMAN'S PRIZE WAS FORFEITED")
	for prize: Variant in prizes:
		if prize is Dictionary:
			_add_copy("Reserved prize · not yet banked or owned" if status in ["open", "won"] else ("Prize taken · banked" if status == "taken" else "Prize record"))
			_add_item_detail(_content, prize)
			var slot := str(prize.get("data", {}).get("slot", ""))
			var worn_id := str(_state.get("inventory", {}).get("equipped", {}).get(slot, ""))
			_add_item_comparison(_content, _state.get("inventory", {}).get("items", {}).get(worn_id, {}), prize)
	var stage := int(wager.get("stage", 0))
	_add_copy("%s\n%s" % ["First crossing" if stage == 0 else "Second crossing · both prizes at stake", wager.get("detail", "The Ferryman's odds are fixed before the coin is tossed.")])
	var odds := UiStyle.label(19)
	var shown_chance := 0.45 if stage > 0 else (0.8 if _wager_pledge else 0.7)
	if stage == 0:
		for effect: Variant in _state.get("effects", []):
			if effect is Dictionary and effect.get("id", "") == "loaded_passage":
				shown_chance += float(effect.get("odds", 0.0))
	shown_chance = minf(shown_chance, 0.85)
	odds.text = "Chance: %d%%" % roundi(shown_chance * 100.0)
	odds.add_theme_color_override("font_color", UiStyle.GOLD)
	_content.add_child(odds)
	if status in ["open", "won"]:
		if stage == 0:
			var pledge_button := _button("%s · pledge veteran for +10%%" % ("✓" if _wager_pledge else "◇"), func() -> void:
				_wager_pledge = not _wager_pledge
				_render_panel()
			, Color(0.58, 0.8, 0.75))
			var pledge_available := false
			for veteran: Variant in _state.get("roster", []):
				if veteran is Dictionary and str(veteran.get("id", "")) == str(_state.get("deployed_veteran", "")) and str(veteran.get("pledge_node", "")).is_empty():
					pledge_available = true
			pledge_button.disabled = not pledge_available
			_content.add_child(pledge_button)
		var actions := HBoxContainer.new()
		_content.add_child(actions)
		actions.add_child(_button("Take reserved prize", func() -> void: _command("take_wager"), UiStyle.GOLD))
		var can_cross_again := stage < 2
		var wager_label := "Flip the coin" if stage == 0 else "Risk both prizes · 45%"
		var wager_button := _button(wager_label, func() -> void: _command("wager", [_wager_pledge and stage == 0]), Color(0.86, 0.63, 0.34))
		wager_button.disabled = not can_cross_again
		actions.add_child(wager_button)
		if _wager_pledge and stage == 0:
			_add_copy("Your companion is pledged whether the coin wins or loses. They return after the next route node clears.")
	else:
		var outcome: Dictionary = wager.get("outcome", {})
		var result := UiStyle.label(20)
		var won := bool(outcome.get("won", status == "won"))
		result.text = "THE FERRYMAN'S COIN: %s" % ("CLAIMED" if status == "taken" else ("WON" if won else "LOST"))
		result.add_theme_color_override("font_color", UiStyle.GOLD if status == "taken" or won else Color(0.95, 0.54, 0.44))
		_content.add_child(result)


func _render_ledger() -> void:
	var clauses: Array = _state.get("clauses", [])
	_add_copy("Optional bargains grant help now and add one visible complication to this biome's finale. You can always keep an open route with no bargain.")
	_add_subtitle(_content, "ACTIVE OBLIGATIONS · %d / 2" % clauses.size())
	for clause: Variant in clauses:
		if clause is Dictionary:
			var definition: Dictionary = CampaignCatalog.CLAUSES.get(str(clause.get("id", "")), {})
			_add_info_card(_content, str(definition.get("name", clause.get("id", "Ledger clause"))), str(definition.get("benefit", "")), str(definition.get("consequence", "")))
	if clauses.size() >= 2:
		_add_copy("The ledger is full for this biome. Its obligations clear only when the finale is won.")
		return
	_add_subtitle(_content, "AVAILABLE BARGAINS · ACCEPT AT MOST ONE MORE")
	var active_ids: Array[String] = []
	for clause: Variant in clauses:
		if clause is Dictionary:
			active_ids.append(str(clause.get("id", "")))
	var slots := OptionButton.new()
	_set_town_action_focus_identity(slots, "clause_slot", "selected")
	for slot: String in ItemData.SLOTS:
		slots.add_item(ItemData.SLOT_NAMES[slot])
		if slot == _clause_slot:
			slots.select(slots.item_count - 1)
	slots.item_selected.connect(func(index: int) -> void:
		_clause_slot = ItemData.SLOTS[index]
		_clause_offer = 0
		_stolen_offers.clear()
		_render_panel()
		_restore_town_action_focus.call_deferred("ledger", "clause_slot", "selected")
	)
	_content.add_child(slots)
	for id: String in ["advance_payment", "stolen_arsenal", "borrowed_battalion"]:
		if active_ids.has(id):
			continue
		var definition: Dictionary = CampaignCatalog.CLAUSES.get(id, {})
		var title := str(definition.get("name", id.replace("_", " ").capitalize()))
		_add_info_card(_content, title, str(definition.get("benefit", "Immediate expedition help.")), str(definition.get("consequence", "Adds a fixed complication to this biome's finale.")))
		if id == "stolen_arsenal":
			var inspect := _button("Inspect three %s rewards" % ItemData.SLOT_NAMES.get(_clause_slot, _clause_slot), func() -> void: _inspect_stolen_offers(), Color(0.65, 0.83, 0.96))
			_set_town_action_focus_identity(inspect, "ledger_inspect", _clause_slot)
			_content.add_child(inspect)
			for index in _stolen_offers.size():
				var offer: Dictionary = _stolen_offers[index]
				var choice := _button("%s%d · %s · %s · ilvl %d" % ["✓  " if index == _clause_offer else "◇  ", index + 1, _item_name(offer), _rarity_text(offer), int(offer.get("data", {}).get("ilvl", 1))], func() -> void:
					_clause_offer = index
					_render_panel()
					_restore_town_action_focus.call_deferred("ledger", "clause_offer", str(index))
				, _rarity_color(offer))
				choice.custom_minimum_size.y = 52
				_set_town_action_focus_identity(choice, "clause_offer", str(index))
				_content.add_child(choice)
			if not _stolen_offers.is_empty():
				var selected_index := clampi(_clause_offer, 0, _stolen_offers.size() - 1)
				var selected_offer: Dictionary = _stolen_offers[selected_index]
				_add_subtitle(_content, "SELECTED OFFER · %d OF %d" % [selected_index + 1, _stolen_offers.size()])
				_add_item_detail(_content, selected_offer)
				var equipped_id := str(_state.get("inventory", {}).get("equipped", {}).get(_clause_slot, ""))
				var worn: Dictionary = _state.get("inventory", {}).get("items", {}).get(equipped_id, {})
				_add_item_comparison(_content, worn, selected_offer)
		var accept := _button("Accept %s" % title, func() -> void: _command("accept_clause", [id, _clause_slot, _clause_offer]), Color(0.92, 0.58, 0.44))
		if id == "stolen_arsenal":
			accept.disabled = _stolen_offers.size() != 3
		_content.add_child(accept)


func _inspect_stolen_offers() -> void:
	if _controller == null or not _controller.has_method("clause_offers"):
		_feedback.text = "The Ferryman's offers are not ready yet."
		return
	_stolen_offers = _controller.call("clause_offers", _clause_slot)
	_clause_offer = clampi(_clause_offer, 0, maxi(0, _stolen_offers.size() - 1))
	_render_panel()
	_restore_town_action_focus.call_deferred("ledger", "ledger_inspect", _clause_slot)


func _render_event() -> void:
	var event: Dictionary = _state.get("event", {})
	var event_id := str(event.get("id", "")).to_lower()
	var previous_selection := _event_selection.duplicate(true)
	_add_subtitle(_content, str(event.get("name", event.get("title", "A voice waits along the road"))))
	_add_copy(str(event.get("text", event.get("description", "The road offers a choice. Every cost and consequence is shown before you commit."))))
	_event_selection = {}
	if event_id.contains("inventory"):
		var offers: Dictionary = event.get("offers", {})
		var inventory: Dictionary = _state.get("inventory", {})
		var item_records: Dictionary = inventory.get("items", {})
		var available_ids: Array[String] = []
		for item_id_value: Variant in inventory.get("backpack", []):
			var item_id := str(item_id_value)
			var record: Dictionary = item_records.get(item_id, {})
			if offers.has(item_id) and not bool(record.get("locked", false)):
				available_ids.append(item_id)
		if not available_ids.is_empty():
			var previous_id := str(previous_selection.get("item_id", ""))
			_event_selection["item_id"] = previous_id if available_ids.has(previous_id) else available_ids[0]
			_add_subtitle(_content, "CHOOSE WHAT TO TRADE")
			var bag_select := OptionButton.new()
			for item_id: String in available_ids:
				bag_select.add_item(_item_name(item_records.get(item_id, {})))
				bag_select.set_item_metadata(bag_select.item_count - 1, item_id)
			bag_select.select(available_ids.find(str(_event_selection["item_id"])))
			bag_select.item_selected.connect(func(index: int) -> void:
				_event_selection["item_id"] = str(bag_select.get_item_metadata(index))
				_render_panel()
			)
			_content.add_child(bag_select)
			var selected_id := str(_event_selection["item_id"])
			_add_subtitle(_content, "YOUR ITEM")
			_add_item_detail(_content, item_records.get(selected_id, {}))
			_add_subtitle(_content, "OFFERED IN EXCHANGE")
			_add_item_detail(_content, offers.get(selected_id, {}))
		else:
			_add_copy("You have no eligible unlocked backpack item to trade. You can keep your belongings and continue.")
	var event_offers: Variant = event.get("offers", {})
	if event_offers is Dictionary and not event_id.contains("inventory"):
		for offer_key: Variant in event_offers:
			var offer: Dictionary = event_offers[offer_key] if event_offers[offer_key] is Dictionary else {}
			if not offer.is_empty():
				var slot_name: String = ItemData.SLOT_NAMES.get(str(offer.get("data", {}).get("slot", offer_key)), str(offer_key))
				_add_subtitle(_content, "DISPLAYED OFFER · %s" % str(slot_name).to_upper())
				_add_item_detail(_content, offer)
	var choices: Array = event.get("choices", event.get("options", []))
	for choice: Variant in choices:
		var row: Dictionary = choice if choice is Dictionary else {"id": str(choice), "label": str(choice)}
		var id := str(row.get("id", row.get("choice_id", "")))
		var label := str(row.get("name", row.get("label", id.replace("_", " ").capitalize())))
		var detail := str(row.get("description", row.get("detail", "")))
		var price := int(row.get("cost", 0))
		var cost := str(row.get("cost_text", "Cost: %d Gold" % price if price > 0 else "No cost"))
		var b := _button("%s\n%s\n%s" % [label, detail, cost], func() -> void: _resolve_event_choice(id), UiStyle.GOLD)
		b.custom_minimum_size.y = 74
		b.disabled = not bool(row.get("enabled", true))
		if price > int(_state.get("gold", 0)):
			b.disabled = true
			cost = "Need %d Gold" % price
			b.text = "%s\n%s\n%s" % [label, detail, cost]
		if event_id.contains("inventory") and id == "trade" and not _event_selection.has("item_id"):
			b.disabled = true
		if not b.disabled and _content.get_child_count() == 3:
			b.grab_focus.call_deferred()
		_content.add_child(b)
	if choices.is_empty():
		_add_copy("The event offers a safe route onward. The choice record remains attached to the campaign save.")
		_content.add_child(_button("Leave the event", func() -> void: _command("resolve_event", ["leave"])))


func _resolve_event_choice(choice_id: String) -> void:
	var event_id := str(_state.get("event", {}).get("id", ""))
	var response := _command("resolve_event", [choice_id, "", _event_selection.duplicate(true)])
	if response.get("ok", false) and event_id == "honest_ferryman" and choice_id == "view":
		_active_service = "ledger"
		_panel_open = true
		_render()


func _confirm_abandon_campaign() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "End this campaign and return to the title? Its unfinished route, campaign gear, talents, and obligations will no longer be available. Earned profile rewards are delivered first."
	dialog.confirmed.connect(func() -> void:
		var response := _command("abandon")
		if response.get("ok", false):
			quit_requested.emit()
	)
	_root.add_child(dialog)
	dialog.popup_centered()


func _render_result() -> void:
	var result: Dictionary = _state.get("result", {})
	var success := str(result.get("outcome", "failure")) == "success"
	var waystop := CampaignWaystops.resolve(_state)
	var heading := UiStyle.label(32)
	heading.text = "THE ROAD YIELDS ITS REWARD" if success else "THE ROAD CLAIMS THIS ATTEMPT"
	heading.add_theme_color_override("font_color", Color(0.95, 0.79, 0.4) if success else Color(0.94, 0.52, 0.43))
	_content.add_child(heading)
	if str(result.get("outcome", "failure")) == "success":
		_add_copy("NEXT STOP · %s\n%s" % [str(waystop["name"]), str(waystop["arrival_line"])])
	else:
		_add_copy("BACK AT %s\nThe same shelter waits while you prepare for another attempt." % str(waystop["name"]))
	_render_after_action_report(result)
	var payment := int(result.get("gold", 0))
	var conversion := int(result.get("shard_conversion", 0))
	_add_copy("Gold banked from this result: +%d G   ·   contract / bonus %d G + shard conversion %d G" % [payment + conversion, payment, conversion])
	_add_copy("Talent points earned: +%d" % int(result.get("talent_points", 0)))
	_content.add_child(_button("Continue to town", func() -> void: _command("acknowledge_result"), UiStyle.GOLD))
	if not bool(result.get("campaign_complete", false)):
		_add_subtitle(_content, "OR GO STRAIGHT TO")
		var shortcuts := GridContainer.new()
		shortcuts.columns = 2
		shortcuts.add_theme_constant_override("h_separation", 8)
		shortcuts.add_theme_constant_override("v_separation", 6)
		shortcuts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(shortcuts)
		for service: Dictionary in [{"id": "trainer", "label": "Visit Trainer"}, {"id": "pack", "label": "Review Equipment"}, {"id": "ferryman", "label": "Visit Ferryman"}, {"id": "roster", "label": "Visit Crypt"}]:
			var shortcut := _button(str(service["label"]), _acknowledge_and_open.bind(str(service["id"])), UiStyle.GOLD)
			shortcut.custom_minimum_size.y = 34
			shortcuts.add_child(shortcut)
	var tray: Array = _state.get("inventory", {}).get("tray", [])
	var items: Dictionary = _state.get("inventory", {}).get("items", {})
	var reward_ids := _result_reward_ids(result, items)
	if not reward_ids.is_empty():
		_add_subtitle(_content, "GEAR BANKED · CLAIM TRAY ITEMS BEFORE DEPARTURE")
		for item_id_value: Variant in reward_ids:
			var record: Dictionary = items.get(str(item_id_value), {})
			if not record.is_empty():
				_add_item_detail(_content, record)
				var slot := str(record.get("data", {}).get("slot", ""))
				var worn_id := str(_state.get("inventory", {}).get("equipped", {}).get(slot, ""))
				_add_item_comparison(_content, items.get(worn_id, {}), record)
	var wager: Dictionary = _state.get("wager", {})
	var reserved_id := str(result.get("reserved_prize", ""))
	if not reserved_id.is_empty() and not wager.get("prizes", []).is_empty():
		_add_subtitle(_content, "RESERVED AT THE FERRYMAN · NOT BANKED OR OWNED")
		for prize_value: Variant in wager.get("prizes", []):
			if prize_value is Dictionary and str(prize_value.get("id", "")) == reserved_id:
				var prize: Dictionary = prize_value
				_add_item_detail(_content, prize)
				var slot := str(prize.get("data", {}).get("slot", ""))
				var worn_id := str(_state.get("inventory", {}).get("equipped", {}).get(slot, ""))
				_add_item_comparison(_content, items.get(worn_id, {}), prize)
	_add_subtitle(_content, "UNCLAIMED TRAY · %d item%s" % [tray.size(), "" if tray.size() == 1 else "s"])
	if not tray.is_empty():
		_add_copy("After continuing, compare, claim, sell, or discard tray rewards in the Armory before choosing another route.")
	if not _state.get("outbox", []).is_empty():
		_add_copy("Some account rewards are waiting to be recorded. Your expedition result is safely saved; you can retry here.")
		_content.add_child(_button("Retry account reward delivery", func() -> void: _command("deliver_outbox"), Color(0.62, 0.82, 0.93)))


func _render_after_action_report(result: Dictionary) -> void:
	var report_value: Variant = result.get("report", {})
	var report: Dictionary = report_value if report_value is Dictionary else {}
	var objectives_value: Variant = report.get("objectives", {})
	var objectives: Dictionary = objectives_value if objectives_value is Dictionary else {}
	var outcome := str(result.get("outcome", "failure"))
	var contract_id := str(report.get("contract_id", ""))
	var contract: Dictionary = CampaignCatalog.CONTRACTS.get(contract_id, {})
	var realm_id := str(report.get("realm", ""))
	var realm: Dictionary = Realm.REALMS.get(realm_id, {})
	var has_structured_report := report.has("kills") or report.has("level") or report.has("realm") or report.has("contract_id")
	if has_structured_report:
		var summary := "Kills: %d   ·   expedition level: %d   ·   realm: %s   ·   contract: %s   ·   combat time: %s" % [
			int(report.get("kills", 0)), int(report.get("level", 1)), str(realm.get("name", realm_id.replace("_", " ").capitalize() if not realm_id.is_empty() else "Unknown")),
			str(contract.get("name", contract_id.replace("_", " ").capitalize() if not contract_id.is_empty() else "Unknown")), _duration(float(result.get("elapsed", 0)))]
		_add_copy(summary)
	else:
		var legacy_summary: Variant = report.get("summary", "")
		_add_copy(str(legacy_summary) if legacy_summary is String and not legacy_summary.is_empty() else "No expedition report details were saved.")
		_add_copy("Combat time: %s" % _duration(float(result.get("elapsed", 0))))
	var died_value: Variant = report.get("died")
	var damage_value: Variant = report.get("damage_taken_by")
	if died_value is bool and damage_value is Dictionary:
		var died: bool = died_value
		var damage := _valid_damage_report(damage_value)
		var last_value: Variant = report.get("last_cause", "")
		var last_cause := str(last_value) if last_value is String else ""
		var has_damage := false
		for amount: Variant in damage.values():
			if float(amount) > 0.0:
				has_damage = true
				break
		if has_damage:
			_add_copy(DeathRecap.summary(damage, last_cause, died))
	if not bool(result.get("biome_complete", false)) and contract_id == "breach" and objectives.get("seals") is int and int(objectives["seals"]) >= 0:
		_add_copy("Seal objective: %d / 3" % int(objectives["seals"]))
	elif not bool(result.get("biome_complete", false)) and contract_id == "elite_hunt" and objectives.get("elite_dead") is bool:
		_add_copy("Marked elite: %s" % ("defeated" if objectives["elite_dead"] else "not defeated"))
	elif contract_id == "cursed_cache" and objectives.get("cache_claimed") is bool:
		_add_copy("Cursed cache: %s" % ("claimed" if objectives["cache_claimed"] else "not claimed"))
	if outcome == "success":
		if bool(result.get("campaign_complete", false)):
			_add_copy("Campaign complete: all three realms are cleared.")
		elif bool(result.get("biome_complete", false)):
			_add_copy("Realm cleared. The next realm is unlocked: %s." % _biome_name(int(_state.get("biome_index", 0))))
		else:
			_add_copy("Contract settled successfully. This route node is now cleared.")
	else:
		_add_copy(_failure_explanation(outcome, report, contract_id, float(result.get("elapsed", 0))))


func _failure_explanation(outcome: String, report: Dictionary, contract_id: String, elapsed: float) -> String:
	if outcome == "retreat":
		return "You retreated before the contract settled. No contract gold, shard conversion, talent point, or route progress was banked."
	if report.get("died") is bool and bool(report["died"]):
		return "The expedition ended when you fell. Contract rewards and route progress were not banked."
	var contract: Dictionary = CampaignCatalog.CONTRACTS.get(contract_id, {})
	var deadline := float(contract.get("deadline", 0.0))
	if report.get("died") is bool and not bool(report["died"]) and deadline > 0.0 and elapsed >= deadline:
		return "The contract deadline passed while you were still alive. Contract rewards and route progress were not banked."
	return "The contract did not settle successfully. Contract rewards and route progress were not banked."


func _acknowledge_and_open(service_id: String) -> void:
	var response := _command("acknowledge_result")
	if not response.get("ok", false):
		return
	_select_service(service_id)


func _biome_name(index: int) -> String:
	return ["The Hollow Graveyard", "The Frozen Wastes", "The Ember Rift"][clampi(index, 0, 2)]


func _render_complete() -> void:
	var pending_rewards: Array = _state.get("outbox", [])
	_add_copy("The final gate is quiet. The three realms are free.")
	var waystop := CampaignWaystops.resolve(_state)
	_add_copy("ARRIVAL · %s\n%s" % [str(waystop["name"]), str(waystop["arrival_line"])])
	var result_value: Variant = _state.get("result", {})
	if result_value is Dictionary and not result_value.is_empty():
		_render_after_action_report(result_value)
	if pending_rewards.is_empty():
		_add_copy("Your completion, earned Soul Shards, and unlocked content are recorded to your profile.")
	else:
		_add_copy("Your completion is saved. Some profile rewards are waiting to be recorded, and remain safe here until delivery succeeds.")
		_content.add_child(_button("Retry account reward delivery", func() -> void: _command("deliver_outbox"), Color(0.62, 0.82, 0.93)))
	_content.add_child(_button("Return to the title", func() -> void: quit_requested.emit(), UiStyle.GOLD))


func _command(method: String, args: Array = []) -> Dictionary:
	if _controller == null or not _controller.has_method(method):
		_feedback.text = "This service is not ready yet."
		return {"ok": false, "error": "command unavailable"}
	var response: Variant = _controller.callv(method, args)
	if response is Dictionary and not bool(response.get("ok", true)):
		_feedback.text = str(response.get("error", "That choice could not be committed."))
		return response
	return response if response is Dictionary else {"ok": true}


func _add_copy(text: String) -> Label:
	var label := UiStyle.label(15)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.76)
	_content.add_child(label)
	return label


func _add_copy_to(parent: Control, text: String, color: Color) -> Label:
	var label := UiStyle.label(13)
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _add_subtitle(parent: Control, text: String) -> void:
	var label := UiStyle.label(14)
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.GOLD)
	parent.add_child(label)


func _button(text: String, callback: Callable, color := UiStyle.TEXT) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_color_override("font_color", color)
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	return button


func _add_item_detail(parent: Control, record: Dictionary) -> void:
	var data: Dictionary = record.get("data", {})
	if data.is_empty():
		_add_copy_to(parent, "Select an item to inspect it.", UiStyle.MUTED)
		return
	var title := UiStyle.label(16)
	title.text = _item_name(record)
	title.add_theme_color_override("font_color", _rarity_color(record))
	parent.add_child(title)
	var meta := UiStyle.label(12)
	meta.text = "%s · %s · item level %d · value %d G%s" % [_rarity_text(record), ItemData.SLOT_NAMES.get(str(data.get("slot", "")), str(data.get("slot", ""))), int(data.get("ilvl", 1)), int(record.get("valuation", 0)), " · LOCKED" if bool(record.get("locked", false)) else ""]
	meta.modulate = Color(1, 1, 1, 0.62)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(meta)
	if not str(data.get("power", "")).is_empty():
		var power_id := str(data["power"])
		var power: Dictionary = ItemData.POWERS.get(power_id, {})
		_add_copy_to(parent, "Legendary power · %s: %s" % [power_id.replace("_", " ").capitalize(), str(power.get("desc", "Power description unavailable."))], Color(1.0, 0.7, 0.35))
	for modifier: Variant in ItemComparison.rows({}, data):
		if modifier is Dictionary:
			_add_copy_to(parent, ItemComparison.format_value(str(modifier["stat"]), int(modifier["op"]), float(modifier["offered"])), Color(0.7, 0.82, 0.98))


func _add_item_comparison(parent: Control, current_record: Dictionary, offered_record: Dictionary, current_label := "Worn", offered_label := "Offered") -> void:
	var offered_data: Dictionary = offered_record.get("data", {})
	if offered_data.is_empty():
		return
	var current_data: Dictionary = current_record.get("data", {})
	var slot := str(offered_data.get("slot", current_data.get("slot", "")))
	_add_subtitle(parent, "ITEM MODIFIERS · %s" % ItemData.SLOT_NAMES.get(slot, slot).to_upper())
	if current_data.is_empty():
		_add_comparison_copy(parent, "%s: empty slot" % current_label)
	else:
		_add_comparison_copy(parent, "%s: %s" % [current_label, _item_name(current_record)])
	_add_comparison_copy(parent, "%s: %s" % [offered_label, _item_name(offered_record)])
	var rows := ItemComparison.rows(current_data, offered_data)
	if rows.is_empty():
		_add_comparison_copy(parent, "No stat modifiers on either item.")
	else:
		for row: Dictionary in rows:
			var current := "—" if is_zero_approx(float(row["current"])) else ItemComparison.format_value(str(row["stat"]), int(row["op"]), float(row["current"]))
			var offered := "—" if is_zero_approx(float(row["offered"])) else ItemComparison.format_value(str(row["stat"]), int(row["op"]), float(row["offered"]))
			_add_comparison_copy(parent, "%s  →  %s" % [current, offered])
	var current_power := str(current_data.get("power", ""))
	var offered_power := str(offered_data.get("power", ""))
	if not current_power.is_empty() or not offered_power.is_empty():
		_add_comparison_copy(parent, _comparison_power_text(current_label, current_data))
		_add_comparison_copy(parent, _comparison_power_text(offered_label, offered_data))


func _comparison_power_text(which: String, data: Dictionary) -> String:
	var power_id := str(data.get("power", ""))
	if power_id.is_empty():
		return "%s legendary power: None" % which
	var power: Dictionary = ItemData.POWERS.get(power_id, {})
	return "%s legendary power · %s: %s" % [which, power_id.replace("_", " ").capitalize(), str(power.get("desc", "Description unavailable."))]


func _add_comparison_copy(parent: Control, text: String) -> Label:
	var label := UiStyle.label(14)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(1, 1, 1, 0.76)
	parent.add_child(label)
	return label


func _valid_damage_report(value: Variant) -> Dictionary:
	var valid: Dictionary = {}
	if not value is Dictionary:
		return valid
	for key: Variant in value:
		var amount: Variant = value[key]
		if (amount is int or amount is float) and is_finite(float(amount)) and float(amount) >= 0.0:
			valid[str(key)] = float(amount)
	return valid


func _result_reward_ids(result: Dictionary, items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var outcome := str(result.get("outcome", ""))
	var reserved_id := str(result.get("reserved_prize", ""))
	if outcome != "success":
		return ids
	var listed_items_value: Variant = result.get("items", [])
	var listed_items: Array = listed_items_value if listed_items_value is Array else []
	for item_id_value: Variant in listed_items:
		var item_id := str(item_id_value)
		if items.has(item_id) and item_id != reserved_id and not ids.has(item_id):
			ids.append(item_id)
	var departure_value: Variant = _state.get("departure", {})
	var departure: Dictionary = departure_value if departure_value is Dictionary else {}
	var loadout_value: Variant = departure.get("starting_loadout", {})
	var loadout: Dictionary = loadout_value if loadout_value is Dictionary else {}
	var starting_value: Variant = loadout.get("inventory", {})
	var starting: Dictionary = starting_value if starting_value is Dictionary else {}
	if not starting.get("equipped") is Dictionary or not starting.get("backpack") is Array:
		return ids
	var original: Dictionary = {}
	var worn_value: Variant = starting.get("equipped", {})
	var worn: Dictionary = worn_value if worn_value is Dictionary else {}
	var bag_value: Variant = starting.get("backpack", [])
	var bag: Array = bag_value if bag_value is Array else []
	var starting_data: Array = worn.values() + bag
	for data: Variant in starting_data:
		if data is Dictionary:
			var id := str(data.get("campaign_id", ""))
			if not id.is_empty():
				original[id] = true
	for item_id_value: Variant in items:
		var item_id := str(item_id_value)
		if not original.has(item_id) and item_id != reserved_id and not ids.has(item_id):
			ids.append(item_id)
	# Legacy reports and fixtures without a departure snapshot use the explicit
	# settlement reward list above as their available source.
	return ids


func _add_info_card(parent: Control, title: String, benefit: String, consequence: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.085, 0.1, 0.92), Color(0.39, 0.33, 0.25), 1, 6))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_add_subtitle(box, title.to_upper())
	if not benefit.is_empty():
		_add_copy_to(box, "NOW · " + benefit, Color(0.7, 0.88, 0.77))
	_add_copy_to(box, "FINALE · " + consequence, Color(0.95, 0.64, 0.51))


func _item_name(record: Dictionary) -> String:
	var data: Dictionary = record.get("data", {})
	return str(data.get("name", data.get("base_name", "Empty")))


func _rarity_text(record: Dictionary) -> String:
	var data: Dictionary = record.get("data", {})
	var rarity: Variant = data.get("rarity", 0)
	return ItemData.rarity_name(int(rarity)) if rarity is int else str(rarity)


func _rarity_color(record: Dictionary) -> Color:
	var data: Dictionary = record.get("data", {})
	var rarity: Variant = data.get("rarity", 0)
	return ItemData.rarity_color(int(rarity)) if rarity is int else UiStyle.TEXT


func _summary(data_value: Variant) -> String:
	if not data_value is Dictionary:
		return "Unidentified campaign item"
	var data: Dictionary = data_value
	var text := "%s · %s %s · item level %d" % [data.get("name", data.get("base_name", "Item")), _rarity_text({"data": data}), ItemData.SLOT_NAMES.get(str(data.get("slot", "weapon")), str(data.get("slot", "weapon"))), int(data.get("ilvl", 1))]
	if data.get("affixes", []).size() > 0:
		text += " · " + _modifier_text(data["affixes"][0])
	return text


func _modifier_text(modifier: Dictionary) -> String:
	return ItemData.mod_text(modifier)


func _current_biome_clear_count(state: Dictionary) -> int:
	var nodes: Dictionary = state.get("graph", {}).get("nodes", {})
	var count := 0
	for node_id_value: Variant in state.get("cleared_nodes", []):
		var node: Dictionary = nodes.get(str(node_id_value), {})
		if not node.is_empty() and int(node.get("depth", 4)) < 4:
			count += 1
	return mini(count, 3)


func _sell_value(item_id: String) -> int:
	var rec: Dictionary = _state.get("inventory", {}).get("items", {}).get(item_id, {})
	return int(rec.get("sell_value", int(rec.get("valuation", 0)) / 4))


func _reforge_fee() -> int:
	return int(_state.get("reforge_fee", 60 * (int(_state.get("biome_index", 0)) + 1)))


func _number(value: int) -> String:
	return str(value)


func _duration(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
