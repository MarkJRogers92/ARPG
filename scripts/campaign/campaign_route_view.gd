class_name CampaignRouteView
extends VBoxContainer
## Route graph presentation. Selecting a node only previews it; the second,
## explicit action commits the route through the campaign controller.

signal choose_requested(node_id: String)

const DEPTH_TITLES := ["APPROACH", "THE VEIL", "DEEP ROAD", "BIOME FINALE"]
const PATH := Color(0.45, 0.62, 0.67, 0.55)
const PATH_OPEN := Color(0.95, 0.72, 0.34, 0.95)
const CONTRACT_GLYPHS := {
	"hunt": "⌖", "breach": "◉", "seal_breach": "◉", "seal_the_breach": "◉", "elite_hunt": "✦",
	"cursed_cache": "☠", "finale": "♜", "boss": "♜",
}

var _graph: Dictionary = {}
var _available: Array = []
var _nodes: Dictionary = {}
var _positions: Dictionary = {}
var _buttons: Dictionary = {}
var _selected_id := ""
var _committed := false
var _committed_id := ""
var _biome_index := 0
var _details: Label
var _confirm: Button
var _heading: Label
var _map: Control
var _lines_layer: Control
var _node_columns: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build()


func present(state: Dictionary, available_routes: Array) -> void:
	_graph = state.get("graph", {})
	_biome_index = int(state.get("biome_index", 0))
	_available = available_routes.duplicate(true)
	_nodes = _graph.get("nodes", {}).duplicate(true)
	_selected_id = str(state.get("selected_node", ""))
	_committed_id = _selected_id
	_committed = not _selected_id.is_empty()
	_build_map()
	var current := _selected_id
	if not current.is_empty() and _is_available(current):
		_preview(current)
	else:
		for route: Variant in _available:
			var first_id := str(route.get("id", route.get("node_id", ""))) if route is Dictionary else str(route)
			if _nodes.has(first_id):
				_preview(first_id)
				break
	if _selected_id.is_empty():
		_update_preview()


func _build() -> void:
	_heading = UiStyle.label(24)
	_heading.text = "THREE DEPTHS · ONE BIOME FINALE"
	_heading.add_theme_font_size_override("font_size", 16)
	_heading.add_theme_color_override("font_color", UiStyle.GOLD)
	add_child(_heading)
	var intro := UiStyle.label(14)
	intro.text = "Read the road. A preview costs nothing; your choice commits the next expedition."
	intro.modulate = Color(1, 1, 1, 0.72)
	add_child(intro)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(0, 190)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.resized.connect(_layout_nodes)
	add_child(_map)
	_lines_layer = Control.new()
	_lines_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_lines_layer)
	_node_columns = HBoxContainer.new()
	_node_columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node_columns.add_theme_constant_override("separation", 24)
	_map.add_child(_node_columns)
	var divider := HSeparator.new()
	add_child(divider)
	_details = UiStyle.label(16)
	_details.custom_minimum_size = Vector2(0, 56)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_details)
	_confirm = Button.new()
	_confirm.text = "Choose this route"
	_confirm.custom_minimum_size = Vector2(240, 48)
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm.disabled = true
	_confirm.pressed.connect(func() -> void:
		if not _selected_id.is_empty():
			choose_requested.emit(_selected_id)
	)
	add_child(_confirm)


func _build_map() -> void:
	for child in _node_columns.get_children():
		child.queue_free()
	_positions.clear()
	_buttons.clear()
	var by_depth: Array[Array] = [[], [], [], []]
	for key: Variant in _nodes:
		var node: Dictionary = _nodes[key]
		var depth := clampi(int(node.get("depth", 1)) - 1, 0, 3)
		by_depth[depth].append(node)
	for depth in 4:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		_node_columns.add_child(column)
		var label := UiStyle.label(12)
		label.text = DEPTH_TITLES[depth]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UiStyle.MUTED)
		column.add_child(label)
		by_depth[depth].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
		if by_depth[depth].is_empty():
			var empty := UiStyle.label(12)
			empty.text = "◇"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(empty)
			continue
		for node: Dictionary in by_depth[depth]:
			var id := str(node.get("id", ""))
			var accessible := _is_available(id)
			var button := Button.new()
			button.text = _node_title(node)
			button.tooltip_text = _node_summary(node)
			button.custom_minimum_size = Vector2(112, 50)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_color_override("font_color", UiStyle.GOLD if accessible else UiStyle.MUTED)
			button.pressed.connect(_preview.bind(id))
			column.add_child(button)
			_buttons[id] = button
			_positions[id] = Vector2.ZERO
	_layout_nodes.call_deferred()


func _layout_nodes() -> void:
	if not is_instance_valid(_map) or not is_instance_valid(_node_columns):
		return
	var children := _node_columns.get_children()
	if children.is_empty():
		return
	var count := children.size()
	for id: String in _buttons:
		var button := _buttons[id] as Control
		var column_index := clampi(int((_nodes[id] as Dictionary).get("depth", 1)) - 1, 0, count - 1)
		var column := children[column_index] as Control
		_positions[id] = button.get_global_rect().get_center() - _map.get_global_rect().position
	for child in _lines_layer.get_children():
		child.queue_free()
	for id_variant: Variant in _nodes:
		var node: Dictionary = _nodes[id_variant]
		var from_id := str(id_variant)
		if not _positions.has(from_id):
			continue
		for next: Variant in node.get("next", []):
			var to_id := str(next)
			if not _positions.has(to_id):
				continue
			var active := _is_available(from_id) or _is_available(to_id) or from_id == _selected_id
			var line := Line2D.new()
			line.width = 3.0 if active else 1.4
			line.default_color = PATH_OPEN if active else PATH
			line.antialiased = true
			line.add_point(_positions[from_id])
			line.add_point(_positions[to_id])
			_lines_layer.add_child(line)


func _preview(id: String) -> void:
	_selected_id = id
	for key: Variant in _buttons:
		var button := _buttons[key] as Button
		var selected := str(key) == id
		button.add_theme_stylebox_override("normal", UiStyle.box(Color(0.16, 0.13, 0.08) if selected else Color(0.1, 0.095, 0.1), UiStyle.GOLD if selected else UiStyle.BRONZE.darkened(0.25), 2, 5))
	_confirm.disabled = _committed or not _is_available(id)
	_update_preview()
	_layout_nodes.call_deferred()


func _update_preview() -> void:
	if _selected_id.is_empty() or not _nodes.has(_selected_id):
		_details.text = "Choose a glowing node to inspect its contract, danger, reward and attached event."
		_confirm.disabled = true
		return
	var node: Dictionary = _nodes[_selected_id]
	var contract := str(node.get("contract", "Finale" if int(node.get("depth", 0)) == 4 else "Hunt"))
	var contract_record: Dictionary = CampaignCatalog.CONTRACTS.get(contract, {})
	var contract_name := str(contract_record.get("name", contract.replace("_", " ").capitalize()))
	var biome_names := ["The Hollow Graveyard", "The Frozen Wastes", "The Ember Rift"]
	var biome := clampi(_biome_index, 0, biome_names.size() - 1)
	var has_details := _is_available(_selected_id) or bool(node.get("revealed", false))
	var danger := str(contract_record.get("danger", "Elite encounter" if bool(node.get("elite", false)) else "Standard encounter"))
	if bool(node.get("elite", false)) and contract != "elite_hunt":
		danger = "Elite variant · " + danger
	var reward := str(node.get("reward_slot", node.get("reward", contract_record.get("reward", "campaign gear"))))
	var event_id := str(node.get("event", ""))
	var event_record: Dictionary = CampaignCatalog.EVENTS.get(event_id, {})
	var event_text := " · Event: " + str(event_record.get("name", event_id.replace("_", " ").capitalize())) if has_details and not event_id.is_empty() else ""
	if int(node.get("depth", 0)) == 4:
		if has_details:
			_details.text = "%s · %s\n%s · Reward: %s%s\n%s" % [biome_names[biome].to_upper(), _duration(contract), danger, reward.replace("_", " "), event_text, _route_status_copy()]
		else:
			_details.text = "%s · BIOME FINALE · PREVIEW ONLY\n15:00 survival before the final boss; full danger and reward details remain veiled until revealed. %s" % [biome_names[biome].to_upper(), _route_status_copy()]
	elif not has_details:
		_details.text = "%s · preview only\n%s  ·  duration %s  ·  full danger and reward details remain veiled until revealed. %s" % [biome_names[biome].to_upper(), contract_name.to_upper(), _duration(contract), _route_status_copy()]
	else:
		_details.text = "%s · %s\n%s · %s · Reward: %s%s\n%s" % [biome_names[biome].to_upper(), _duration(contract), contract_name.to_upper(), danger, reward.replace("_", " "), event_text, _route_status_copy()]
	_confirm.text = "Route committed" if _committed else "Choose this route"
	_confirm.disabled = _committed or not _is_available(_selected_id)


func _is_available(id: String) -> bool:
	for route: Variant in _available:
		if route is Dictionary and str(route.get("id", route.get("node_id", ""))) == id:
			return true
		if str(route) == id:
			return true
	return false


func _node_title(node: Dictionary) -> String:
	var depth := int(node.get("depth", 1))
	var raw_contract := str(node.get("contract", "finale" if depth == 4 else "hunt")).to_lower()
	var contract_record: Dictionary = CampaignCatalog.CONTRACTS.get(raw_contract, {})
	var contract := str(contract_record.get("name", raw_contract.replace("_", " ").capitalize())).to_upper().replace("THE ", "")
	var glyph := str(CONTRACT_GLYPHS.get(raw_contract, "✦" if bool(node.get("elite", false)) else "◇"))
	var route_type := "BOSS" if depth == 4 else ("ELITE" if bool(node.get("elite", false)) else "DEPTH %d" % depth)
	return "%s  %s\n%s" % [glyph, "BOSS" if depth == 4 else contract.substr(0, mini(contract.length(), 12)), route_type]


func _node_summary(node: Dictionary) -> String:
	var summary := _node_title(node).replace("\n", " · ")
	if (_is_available(str(node.get("id", ""))) or bool(node.get("revealed", false))) and not str(node.get("event", "")).is_empty():
		summary += " · Event: " + str(node.get("event", ""))
	return summary


func _duration(contract: String) -> String:
	var definition: Dictionary = CampaignCatalog.CONTRACTS.get(contract, {})
	var duration_seconds := int(definition.get("duration", 300))
	var deadline_seconds := int(definition.get("deadline", 0))
	if contract == "finale":
		return "%d:%02d survival" % [duration_seconds / 60, duration_seconds % 60]
	if deadline_seconds > 0:
		return "%d:%02d target · %d:%02d deadline" % [duration_seconds / 60, duration_seconds % 60, deadline_seconds / 60, deadline_seconds % 60]
	return "%d:%02d expedition · automatic extraction" % [duration_seconds / 60, duration_seconds % 60]


func _route_status_copy() -> String:
	if _committed and _selected_id != _committed_id:
		return "Preview only · route %s remains committed until it clears." % _committed_id
	if _committed:
		return "This road is committed until you complete it."
	return "Preview costs nothing; choose this road when you are ready."
