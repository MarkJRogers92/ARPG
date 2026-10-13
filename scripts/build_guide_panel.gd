class_name BuildGuidePanel
extends VBoxContainer
## Reusable evolution checklist for PauseMenu or any other parent.
##
## Shows compatible Soulbound recipes, their progress, a concise preview of what
## the selected recipe changes, and a pin/unpin control.  Pins last only for the
## current UI session (not saved).  Does not mutate the passed PlayerStats.

signal goal_changed(recipe_id: String)
signal back_requested

const CampaignMenuStyle = preload("res://scripts/campaign/campaign_menu_style.gd")

var _pinned_id := ""
var _rows: Array[Dictionary] = []
var _row_by_id: Dictionary = {}
var _pin_by_id: Dictionary = {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _details: Label
var _details_scroll: ScrollContainer
var _back: Button
var _detail_name: Label
var _next_step: Label
var _selected_id := ""
var _last_stats: PlayerStats
var _last_snapshot: Variant


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = RunUi.theme()
	_ensure_built()


func _ensure_built() -> void:
	if _list != null:
		return
	_build()


## Refresh the list.  `pinned_id` pre-selects a recipe for the current session.
func present(stats: PlayerStats, unlocked_snapshot: Variant = null, pinned_id: String = "") -> void:
	_ensure_built()
	_last_stats = stats
	_last_snapshot = unlocked_snapshot
	_rows = BuildGuide.rows(stats, unlocked_snapshot)
	_row_by_id.clear()
	_pin_by_id.clear()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for row in _rows:
		_row_by_id[row["id"]] = _make_row(row)
		_list.add_child(_row_by_id[row["id"]])
	_pinned_id = pinned_id if _row_by_id.has(pinned_id) else ""
	if not pinned_id.is_empty() and _pinned_id.is_empty(): goal_changed.emit("")
	_update_pins()
	var select_id := _pinned_id
	if select_id == "" and not _rows.is_empty():
		select_id = _rows[0]["id"]
	_present_details(select_id)
	if _pinned_id != "" and _row_by_id.has(_pinned_id):
		_focus_recipe.call_deferred(_pinned_id)
	elif not _rows.is_empty():
		_focus_recipe.call_deferred(_rows[0]["id"])
	else:
		_focus_recipe.call_deferred("")


func _focus_recipe(id: String) -> void:
	# present() can replace/remove rows twice before the deferred call runs.
	# Resolve from the current map, never retain the detached original button.
	if not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree(): return
	var target: Control = _back
	if _row_by_id.has(id): target = _row_by_id[id].get_child(0)
	if is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion(): target.grab_focus()


func _build() -> void:
	custom_minimum_size.x = 760
	add_theme_constant_override("separation", 12)
	var header := RunUi.label(26)
	header.text = "Build guide"
	add_child(header)
	var policy := RunUi.label(13, RunUi.MUTED)
	policy.text = "Complete the weapon's card upgrades and take its catalyst once. Hero or equipment abilities don't replace these cards."
	policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(policy)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(350, 370)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	columns.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_list)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", RunUi.panel(16))
	columns.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)
	_detail_name = RunUi.label(22)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_name)
	_next_step = RunUi.label(14, RunUi.SOUL)
	_next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_next_step)
	var preview_heading := RunUi.label(12, RunUi.MUTED)
	preview_heading.text = "ON EVOLUTION"
	detail_box.add_child(preview_heading)
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "EvolutionDetailsScroll"
	_details_scroll.custom_minimum_size.y = 180
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_scroll.follow_focus = true
	_details_scroll.focus_mode = Control.FOCUS_ALL
	_details_scroll.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			_details_scroll.scroll_vertical += 48 if event.is_action_pressed("ui_down") else -48
			_details_scroll.accept_event())
	detail_box.add_child(_details_scroll)
	_details = RunUi.label(14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_scroll.add_child(_details)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)
	var pin_policy := RunUi.label(13, RunUi.MUTED)
	pin_policy.text = "Pin one goal for this attempt. Pins are not saved."
	pin_policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(pin_policy)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(130, 40)
	_back.pressed.connect(func() -> void:
		Sound.play("ui_click")
		back_requested.emit())
	footer.add_child(_back)
	_details_scroll.focus_next = _details_scroll.get_path_to(_back)


func _make_row(row: Dictionary) -> Control:
	var id: String = row["id"]
	var color: Color = row["color"]

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	var body := Button.new()
	body.custom_minimum_size.y = 100
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("normal", RunUi.panel(6, color.lerp(RunUi.EDGE, 0.7)))
	body.add_theme_stylebox_override("hover", RunUi.panel(6, RunUi.GOLD))
	body.add_theme_stylebox_override("focus", RunUi.panel(6, RunUi.GOLD))
	body.focus_mode = Control.FOCUS_ALL
	body.pressed.connect(func() -> void:
		if _row_by_id.get(id) != container: return
		Sound.play("ui_click")
		_present_details(id))
	body.focus_entered.connect(func() -> void:
		if _row_by_id.get(id) != container: return
		_present_details(id))
	container.add_child(body)

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 6)
	body.add_child(inner)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(lines)

	var name_label := RunUi.label(15)
	name_label.text = row["name"]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", RunUi.TEXT)
	lines.add_child(name_label)
	var status := RunUi.label(12, RunUi.SOUL if row["ready"] else RunUi.MUTED)
	status.text = _status_text(row)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(status)

	var weapon_label := RunUi.label(13)
	weapon_label.text = "%s %d/%d" % [row["weapon"]["name"], row["weapon"]["rank"], row["weapon"]["max"]]
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.add_theme_color_override("font_color", RunUi.MUTED)
	lines.add_child(weapon_label)

	var catalyst_label := RunUi.label(13)
	catalyst_label.text = "%s · %s" % [row["catalyst"]["name"], "owned" if row["catalyst"]["rank"] > 0 else "need 1 card"]
	catalyst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalyst_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalyst_label.add_theme_color_override("font_color", RunUi.MUTED)
	lines.add_child(catalyst_label)

	var pin := CheckButton.new()
	pin.text = "Pin"
	pin.tooltip_text = "Pin this goal"
	pin.button_pressed = (id == _pinned_id)
	pin.toggled.connect(func(on: bool) -> void:
		if _pin_by_id.get(id) != pin: return
		Sound.play("ui_click")
		_set_pinned(id if on else ""))
	pin.focus_entered.connect(func() -> void:
		if _pin_by_id.get(id) != pin: return
		_present_details(id))
	container.add_child(pin)
	_pin_by_id[id] = pin

	return container


func _status_text(row: Dictionary) -> String:
	if row["taken"]:
		return "Evolved"
	if row["ready"]:
		return "Ready"
	if row.get("active_from_class_or_gear", false):
		return "Class / gear access"
	if row["owned"]:
		return "In progress"
	return "Not started"


func _set_pinned(id: String) -> void:
	if not id.is_empty() and not _row_by_id.has(id): return
	if _pinned_id == id:
		return
	_pinned_id = id
	_update_pins()
	_present_details(id if id != "" else _selected_id)
	goal_changed.emit(id)


func _update_pins() -> void:
	for rid: String in _pin_by_id:
		_pin_by_id[rid].set_pressed_no_signal(rid == _pinned_id)
		_pin_by_id[rid].tooltip_text = "Unpin this goal" if rid == _pinned_id else "Pin this goal for this night/expedition only"


func _present_details(id: String) -> void:
	_selected_id = id
	_details_scroll.scroll_vertical = 0
	_detail_name.text = "No compatible recipes"
	_next_step.text = ""
	if id == "" or _last_stats == null:
		_details.text = ""
		return
	if not Evolutions.DEFS.has(id):
		_details.text = BuildGuide.goal_summary(id, _last_stats)
		return
	_detail_name.text = str(Evolutions.DEFS[id]["name"]) + (" · pinned" if id == _pinned_id else "")
	_next_step.text = _next_step_text(id)
	_details.text = str(Evolutions.DEFS[id]["desc"]) + "\n\n" + BuildGuide.affected_text(id, _last_stats)
	for recipe: String in _row_by_id:
		var body := _row_by_id[recipe].get_child(0) as Button
		var normal := RunUi.panel(6, RunUi.SOUL if recipe == id else RunUi.EDGE)
		normal.bg_color = RunUi.SURFACE if recipe == id else RunUi.INK
		body.add_theme_stylebox_override("normal", normal)
	if _row_by_id.has(id):
		var body := _row_by_id[id].get_child(0) as Button
		_details_scroll.focus_previous = _details_scroll.get_path_to(body)
		body.focus_neighbor_right = body.get_path_to(_pin_by_id[id])
		_pin_by_id[id].focus_neighbor_right = _pin_by_id[id].get_path_to(_details_scroll)


func _next_step_text(id: String) -> String:
	if Evolutions.taken(id, _last_stats): return "Already evolved."
	var recipe: Dictionary = Evolutions.DEFS[id]
	var weapon: String = recipe["weapon"]
	var catalyst: String = recipe["catalyst"]
	var missing_weapon := maxi(0, int(Upgrades.DEFS[weapon]["max"]) - Upgrades.level_of(weapon, _last_stats))
	var missing_catalyst := maxi(0, 1 - Upgrades.level_of(catalyst, _last_stats))
	var needed: Array[String] = []
	if missing_weapon > 0:
		needed.append("%d more %s card%s" % [missing_weapon, Upgrades.DEFS[weapon]["name"], "" if missing_weapon == 1 else "s"])
	if missing_catalyst > 0:
		needed.append("1 %s card" % Upgrades.DEFS[catalyst]["name"])
	if not needed.is_empty(): return "Take " + " and ".join(needed) + "."
	var ready_count := Evolutions.ready(_last_stats).size()
	return "Ready for the next level-up." if ready_count == 1 else "Ready. One of %d ready evolutions is randomly offered per level-up." % ready_count
