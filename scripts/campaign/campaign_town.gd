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

var _controller: Node
var _state: Dictionary = {}
var _active_service := "route"
var _root: Control
var _status_label: Label
var _abandon_button: Button
var _delivery_button: Button
var _service_buttons: Dictionary = {}
var _content: VBoxContainer
var _content_title: Label
var _feedback: Label
var _selected_item_id := ""
var _selected_slot := "weapon"
var _clause_slot := "weapon"
var _clause_offer := 0
var _event_selection: Dictionary = {}
var _wager_pledge := false
var _wager_node_id := ""
var _stolen_offers: Array = []


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
	if is_inside_tree() and _service_buttons.has(_active_service):
		(_service_buttons[_active_service] as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _state.get("phase", "") == "CAMPAIGN_COMPLETE":
			get_viewport().set_input_as_handled()
			return
		if str(_state.get("phase", "")) in ["EVENT_PENDING", "RESULT_PENDING"]:
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
	backdrop.color = Color(0.028, 0.042, 0.065)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var veil := ColorRect.new()
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


func _build_header(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	parent.add_child(header)
	var title := UiStyle.label(30)
	title.text = "THE LAST LANTERN"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	header.add_child(title)
	var subtitle := UiStyle.label(14)
	subtitle.text = "   SANCTUARY BETWEEN EXPEDITIONS"
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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)


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
	_render_panel()


func _on_changed(state: Dictionary) -> void:
	_state = state.duplicate(true)
	_feedback.text = ""
	_render()


func _on_error(message: String) -> void:
	_feedback.text = message


func _render() -> void:
	if not is_instance_valid(_root):
		return
	var biome_names := ["THE HOLLOW GRAVEYARD", "THE FROZEN WASTES", "THE EMBER RIFT"]
	var biome := clampi(int(_state.get("biome_index", 0)), 0, 2)
	var phase := str(_state.get("phase", "TOWN"))
	_abandon_button.visible = phase not in ["CAMPAIGN_COMPLETE", "ABANDONED"]
	_delivery_button.visible = not _state.get("outbox", []).is_empty() and phase not in ["RESULT_PENDING", "CAMPAIGN_COMPLETE", "ABANDONED"]
	var clear_count := _current_biome_clear_count(_state)
	_status_label.text = "%s   ·   %s" % [biome_names[biome], phase.replace("_", " ")]
	_set_named_value("Value_biome", "%s   ·   %d / 3 clears" % [biome_names[biome], clear_count])
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


func _render_route() -> void:
	var graph: Dictionary = _state.get("graph", {})
	if graph.is_empty():
		_add_copy("The route map will appear once the campaign begins.")
		return
	var route_view := CampaignRouteView.new()
	route_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_view.choose_requested.connect(_choose_route)
	_content.add_child(route_view)
	var available: Array = _controller.available_routes()
	route_view.present(_state, available)
	var selected := str(_state.get("selected_node", ""))
	var ready := str(_state.get("phase", "")) == "DEPARTURE_READY"
	var action := _button("Depart for the committed route", func() -> void:
		if not ready:
			return
		var response: Dictionary = _command("depart")
		if response.get("ok", false):
			expedition_requested.emit(response.get("spec", {}))
	, Color(0.3, 0.62, 0.72))
	action.disabled = not ready or selected.is_empty()
	_content.add_child(action)
	if ready:
		_add_copy("Your departure is ready. The route is committed; combat starts from a fresh expedition build.")


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
		button.disabled = item_id.is_empty()
		item_column.add_child(button)
	_add_subtitle(item_column, "BACKPACK · %d" % backpack.size())
	for item_id_variant: Variant in backpack:
		var item_id := str(item_id_variant)
		var rec: Dictionary = items.get(item_id, {})
		var mark := "◆ " if bool(rec.get("locked", false)) else ("× " if bool(rec.get("junk", false)) else "")
		var b := _button("%s%s  ·  %s" % [mark, _item_name(rec), _rarity_text(rec)], func() -> void: _select_item(item_id, str(rec.get("data", {}).get("slot", "weapon"))), _rarity_color(rec))
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
		tray_actions.add_child(_button("Compare", func() -> void: _select_item(item_id, str(rec.get("data", {}).get("slot", "weapon")))))
		var claim := _button("Claim", func() -> void: _command("claim_item", [item_id]), UiStyle.GOLD)
		claim.disabled = backpack.size() >= Inventory.BACKPACK_SIZE
		tray_actions.add_child(claim)
		tray_actions.add_child(_button("Sell", func() -> void: _command("sell_items", [[item_id], false]), Color(0.88, 0.75, 0.48)))
		tray_actions.add_child(_button("Discard", func() -> void: _confirm_discard(item_id), Color(0.9, 0.55, 0.46)))
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size.x = 230
	columns.add_child(detail_column)
	_add_subtitle(detail_column, "COMPARE & MANAGE")
	var selected: Dictionary = items.get(_selected_item_id, {})
	_add_item_detail(detail_column, selected)
	var worn_id := str(equipped.get(_selected_slot, ""))
	var worn: Dictionary = items.get(worn_id, {})
	if not _selected_item_id.is_empty() and not worn_id.is_empty() and worn_id != _selected_item_id:
		_add_copy_to(detail_column, "VERSUS WORN", UiStyle.MUTED)
		_add_item_detail(detail_column, worn)
	if not _selected_item_id.is_empty():
		var in_backpack := backpack.has(_selected_item_id)
		var in_tray := tray.has(_selected_item_id)
		var equipped_here := str(equipped.get(_selected_slot, "")) == _selected_item_id
		if equipped_here or in_backpack:
			var equipped_action := "unequip_item" if equipped_here else "equip_item"
			var equipped_args: Array = [_selected_slot] if equipped_here else [_selected_item_id]
			detail_column.add_child(_button("Unequip" if equipped_here else "Equip", func() -> void: _command(equipped_action, equipped_args)))
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


func _select_item(item_id: String, slot: String) -> void:
	_selected_item_id = item_id
	_selected_slot = slot
	_render_panel()


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
	_add_item_detail(parent, {"data": pending.get("old", {})})
	_add_item_detail(parent, {"data": pending.get("new", {})})
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_button("Keep original", func() -> void: _command("resolve_reforge", [false])))
	row.add_child(_button("Keep new", func() -> void: _command("resolve_reforge", [true]), UiStyle.GOLD))


func _render_market() -> void:
	_add_copy("The Market's stock is saved for this town visit. Compare the item and listed cost before you buy.")
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
		var data: Dictionary = stock_item.get("data", stock_item.get("item", {}))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_content.add_child(row)
		var description := _summary(data)
		var label := UiStyle.label(15)
		label.text = description
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var price := int(stock_item.get("price", stock_item.get("valuation", 0)))
		var buy := _button("Buy · %d G" % price, func() -> void: _command("buy_item", [id]), UiStyle.GOLD)
		buy.disabled = id.is_empty() or int(_state.get("gold", 0)) < price
		row.add_child(buy)
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
		if not (_state.get("reforge", {}) as Dictionary).is_empty():
			_render_reforge(_content)


func _render_trainer() -> void:
	var talents: Dictionary = _state.get("talents", {})
	var allocated: Array = talents.get("allocated", [])
	_add_copy("Campaign talents survive each expedition. Only successful node settlements grant points; refunds return them here.")
	var points := UiStyle.label(20)
	points.text = "%d talent points available   ·   %d / 18 earned" % [int(talents.get("points", 0)), int(talents.get("earned", 0))]
	points.add_theme_color_override("font_color", UiStyle.GOLD)
	_content.add_child(points)
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
		button.custom_minimum_size = Vector2(132, 52)
		button.tooltip_text = "\n".join(SkillData.description_lines(id))
		button.disabled = not owned and (not reachable or int(talents.get("points", 0)) < cost)
		tree.add_child(button)
	var action_row := HBoxContainer.new()
	_content.add_child(action_row)
	action_row.add_child(_button("Free talent respec", func() -> void: _confirm_reset_talents(), Color(0.8, 0.66, 0.5)))
	_add_subtitle(_content, "SPECIALIZATION · SELECT OR RESPEC IN TOWN")
	var specialization := str(_state.get("specialization", ""))
	var specialization_unlocked := int(talents.get("earned", 0)) > 3
	if not specialization_unlocked:
		_add_copy("Earn one more talent point from a successful expedition to unlock a specialization.")
	for path: Dictionary in Specializations.paths(str(_state.get("hero_class", "battlemage"))):
		var button := _button("%s%s\n%s" % ["✓ " if specialization == str(path["id"]) else "", path["name"], path["desc"]], func() -> void: _command("choose_specialization", [str(path["id"])]), path["color"])
		button.custom_minimum_size.y = 70
		button.disabled = specialization == str(path["id"]) or not specialization_unlocked
		_content.add_child(button)


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
		info.text = "%s  ·  %s  ·  Rank %d (travels as %d)\n%s\n%s" % [veteran.get("name", "Unnamed veteran"), veteran.get("role", "Veteran"), rank, effective_rank, pledge_copy, veteran.get("deeds", "A soul who has seen the road.")]
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
		var add_candidate := _button("Add to the roster", func() -> void: _recruit_veteran(candidate_id, ""), UiStyle.GOLD)
		add_candidate.disabled = roster.size() >= 3
		_content.add_child(add_candidate)
		for veteran: Variant in roster:
			if veteran is Dictionary:
				var replace_id := str(veteran.get("id", ""))
				_content.add_child(_button("Replace %s" % veteran.get("name", "veteran"), func() -> void: _confirm_recruit_veteran(candidate_id, replace_id, str(veteran.get("name", "this veteran"))), Color(0.9, 0.68, 0.42)))
		_content.add_child(_button("Decline this veteran", func() -> void: _command("decline_veteran"), Color(0.8, 0.57, 0.51)))
	if roster.is_empty() and candidate.is_empty():
		_add_copy("No veteran is ready yet. Survive a mission and a named soul may choose to follow you home.")


func _recruit_veteran(candidate_id: String, replace_id: String) -> void:
	_command("recruit_veteran", [candidate_id, replace_id])


func _confirm_recruit_veteran(candidate_id: String, replace_id: String, old_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Replace %s with this surviving veteran?" % old_name
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
	_add_subtitle(_content, "THE STAKE · RESERVED FROM YOUR EXPEDITION REWARD")
	for prize: Variant in prizes:
		if prize is Dictionary:
			_add_item_detail(_content, prize)
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
	var status := str(wager.get("status", "open"))
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
	for slot: String in ItemData.SLOTS:
		slots.add_item(ItemData.SLOT_NAMES[slot])
		if slot == _clause_slot:
			slots.select(slots.item_count - 1)
	slots.item_selected.connect(func(index: int) -> void:
		_clause_slot = ItemData.SLOTS[index]
		_clause_offer = 0
		_stolen_offers.clear()
		_render_panel()
	)
	_content.add_child(slots)
	for id: String in ["advance_payment", "stolen_arsenal", "borrowed_battalion"]:
		if active_ids.has(id):
			continue
		var definition: Dictionary = CampaignCatalog.CLAUSES.get(id, {})
		var title := str(definition.get("name", id.replace("_", " ").capitalize()))
		_add_info_card(_content, title, str(definition.get("benefit", "Immediate expedition help.")), str(definition.get("consequence", "Adds a fixed complication to this biome's finale.")))
		if id == "stolen_arsenal":
			_content.add_child(_button("Inspect three %s rewards" % ItemData.SLOT_NAMES.get(_clause_slot, _clause_slot), func() -> void: _inspect_stolen_offers(), Color(0.65, 0.83, 0.96)))
			for index in _stolen_offers.size():
				var offer: Dictionary = _stolen_offers[index]
				var choice := _button("%s%s" % ["✓  " if index == _clause_offer else "◇  ", _summary(offer.get("data", {}))], func() -> void:
					_clause_offer = index
					_render_panel()
				, _rarity_color(offer))
				choice.custom_minimum_size.y = 52
				_content.add_child(choice)
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
	var heading := UiStyle.label(32)
	heading.text = "THE ROAD YIELDS ITS REWARD" if success else "THE ROAD CLAIMS THIS ATTEMPT"
	heading.add_theme_color_override("font_color", Color(0.95, 0.79, 0.4) if success else Color(0.94, 0.52, 0.43))
	_content.add_child(heading)
	_add_copy(str(result.get("report", {}).get("summary", "The settlement is saved. Review the tray before you continue.")))
	_add_copy("Combat time: %s" % _duration(float(result.get("elapsed", 0))))
	_add_copy("Gold earned: %d G   ·   Soul Shard conversion: %d   ·   Talent points: +%d" % [int(result.get("gold", 0)), int(result.get("shard_conversion", 0)), int(result.get("talent_points", 0))])
	var tray: Array = _state.get("inventory", {}).get("tray", [])
	var items: Dictionary = _state.get("inventory", {}).get("items", {})
	var reward_ids: Array = result.get("items", [])
	if not reward_ids.is_empty():
		_add_subtitle(_content, "REWARDS BANKED")
		for item_id_value: Variant in reward_ids:
			var record: Dictionary = items.get(str(item_id_value), {})
			if not record.is_empty():
				_add_copy(_summary(record.get("data", {})))
	if not str(result.get("reserved_prize", "")).is_empty():
		_add_copy("A reserved expedition prize is waiting at the Ferryman's table.")
	_add_subtitle(_content, "UNCLAIMED TRAY · %d item%s" % [tray.size(), "" if tray.size() == 1 else "s"])
	if not tray.is_empty():
		_add_copy("After continuing, compare, claim, sell, or discard tray rewards in the Armory before choosing another route.")
	if not _state.get("outbox", []).is_empty():
		_add_copy("Some account rewards are waiting to be recorded. Your expedition result is safely saved; you can retry here.")
		_content.add_child(_button("Retry account reward delivery", func() -> void: _command("deliver_outbox"), Color(0.62, 0.82, 0.93)))
	_content.add_child(_button("Continue to town", func() -> void: _command("acknowledge_result"), UiStyle.GOLD))


func _render_complete() -> void:
	var pending_rewards: Array = _state.get("outbox", [])
	_add_copy("The final gate is quiet. The three realms are free.")
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


func _add_copy_to(parent: Control, text: String, color: Color) -> void:
	var label := UiStyle.label(13)
	label.text = text
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


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
	meta.text = "%s · item level %d · value %d G%s" % [_rarity_text(record), int(data.get("ilvl", 1)), int(record.get("valuation", 0)), " · LOCKED" if bool(record.get("locked", false)) else ""]
	meta.modulate = Color(1, 1, 1, 0.62)
	parent.add_child(meta)
	for modifier: Variant in data.get("implicit", []) + data.get("affixes", []):
		if modifier is Dictionary:
			_add_copy_to(parent, _modifier_text(modifier), Color(0.7, 0.82, 0.98))
	if not str(data.get("power", "")).is_empty():
		_add_copy_to(parent, "Legendary power · %s" % str(data["power"]).replace("_", " "), Color(1.0, 0.7, 0.35))


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
