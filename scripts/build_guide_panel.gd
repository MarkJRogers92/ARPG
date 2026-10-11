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
var _last_stats: PlayerStats
var _last_snapshot: Variant


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = CampaignMenuStyle.make_theme(UiStyle.theme())
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
	add_theme_constant_override("separation", 10)

	var header := CampaignMenuStyle.label(22)
	header.text = "Evolutions"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", CampaignMenuStyle.GOLD)
	add_child(header)
	var policy := CampaignMenuStyle.label(12)
	policy.text = "Known recipes for your hero. Requirements are card ranks, not class/gear access.\nPinned goals last this night/expedition only; they are not saved or kept on retry."
	policy.custom_minimum_size.x = 450
	policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	policy.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	add_child(policy)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 190)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_list)

	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "EvolutionDetailsScroll"
	_details_scroll.custom_minimum_size.y = 190
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_scroll.follow_focus = true
	_details_scroll.focus_mode = Control.FOCUS_ALL
	add_child(_details_scroll)
	_details = CampaignMenuStyle.label(12)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(450, 70)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	_details_scroll.add_child(_details)

	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.y = 40
	_back.pressed.connect(func() -> void:
		Sound.play("ui_click")
		back_requested.emit())
	add_child(_back)


func _make_row(row: Dictionary) -> Control:
	var id: String = row["id"]
	var color: Color = row["color"]

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	var body := Button.new()
	body.custom_minimum_size.y = 88
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("normal", CampaignMenuStyle.card_box(CampaignMenuStyle.SURFACE, color.darkened(0.5), 1, 5, 6))
	body.add_theme_stylebox_override("hover", CampaignMenuStyle.card_box(CampaignMenuStyle.SURFACE_RAISED, color, 1, 5, 6))
	body.add_theme_stylebox_override("focus", CampaignMenuStyle.card_box(Color(0, 0, 0, 0), CampaignMenuStyle.GOLD, 2, 5, 6))
	body.focus_mode = Control.FOCUS_ALL
	body.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_present_details(id))
	body.focus_entered.connect(func() -> void:
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

	var name_label := CampaignMenuStyle.label(15)
	name_label.text = "%s · %s" % [row["name"], _status_text(row)]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", color.lightened(0.25))
	lines.add_child(name_label)

	var weapon_label := CampaignMenuStyle.label(13)
	weapon_label.text = "%s %d/%d" % [row["weapon"]["name"], row["weapon"]["rank"], row["weapon"]["max"]]
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	lines.add_child(weapon_label)

	var catalyst_label := CampaignMenuStyle.label(13)
	catalyst_label.text = "Catalyst · %s · %s" % [row["catalyst"]["name"], "owned (%d cards)" % row["catalyst"]["rank"] if row["catalyst"]["rank"] > 0 else "take 1 card"]
	catalyst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalyst_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalyst_label.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	lines.add_child(catalyst_label)

	var pin := CheckButton.new()
	pin.text = "Pin"
	pin.tooltip_text = "Pin this goal"
	pin.button_pressed = (id == _pinned_id)
	pin.toggled.connect(func(on: bool) -> void:
		Sound.play("ui_click")
		_set_pinned(id if on else ""))
	pin.focus_entered.connect(func() -> void:
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
		return "Active from class/gear · no cards yet"
	if row["owned"]:
		return "Weapon cards owned"
	return "No weapon cards yet"


func _set_pinned(id: String) -> void:
	if not id.is_empty() and not _row_by_id.has(id): return
	if _pinned_id == id:
		return
	_pinned_id = id
	_update_pins()
	goal_changed.emit(id)


func _update_pins() -> void:
	for rid: String in _pin_by_id:
		_pin_by_id[rid].set_pressed_no_signal(rid == _pinned_id)
		_pin_by_id[rid].tooltip_text = "Unpin this goal" if rid == _pinned_id else "Pin this goal for this night/expedition only"


func _present_details(id: String) -> void:
	_details_scroll.scroll_vertical = 0
	if id == "" or _last_stats == null:
		_details.text = ""
		return
	if not Evolutions.DEFS.has(id):
		_details.text = BuildGuide.goal_summary(id, _last_stats)
		return
	_details.text = str(Evolutions.DEFS[id]["desc"]) + "\n" + BuildGuide.affected_text(id, _last_stats)
