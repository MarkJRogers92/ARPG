class_name InventoryScreen
extends CanvasLayer
## The pausing equipment screen. Built in code like the HUD.
##
## Left: worn gear and the hero's stats. Middle: the backpack ("▲" marks items
## that likely beat what you're wearing). Right: details for the selected item.
## Select with mouse, arrows or d-pad; Enter / double-click equips or unequips.

signal closed

var _inventory: Inventory
var _stats: PlayerStats

var _root: Control
var _equipment_list: ItemList
var _backpack_list: ItemList
var _backpack_title: Label
var _details: RichTextLabel
var _stats_text: RichTextLabel
var _equip_button: Button
var _discard_button: Button
var _upgrades_button: Button
var _icons: ItemIcons

var _selected: Item
var _selected_worn := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the tree is paused
	layer = 11
	_icons = ItemIcons.new()
	add_child(_icons)
	_build()
	_root.hide()


func setup(player: Player) -> void:
	_inventory = player.inventory
	_stats = player.stats
	_inventory.changed.connect(func() -> void:
		if is_open():
			_refresh())


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_refresh()
	_root.show()
	(_backpack_list if _backpack_list.item_count > 0 else _equipment_list).grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


# --- actions ---------------------------------------------------------------------

func _on_equip_pressed() -> void:
	if _selected == null:
		return
	if _selected_worn:
		_inventory.unequip(_selected.slot)
	else:
		_inventory.equip(_selected)


func _on_discard_pressed() -> void:
	if _selected != null and not _selected_worn:
		var item := _selected
		_selected = null
		_inventory.discard(item)


func _on_upgrades_pressed() -> void:
	_inventory.equip_upgrades()


func _on_equipment_selected(index: int) -> void:
	_backpack_list.deselect_all()
	_selected = _inventory.equipped.get(ItemData.SLOTS[index])
	_selected_worn = true
	_show_details()


func _on_backpack_selected(index: int) -> void:
	_equipment_list.deselect_all()
	_selected = _inventory.backpack[index]
	_selected_worn = false
	_show_details()


# --- drawing ---------------------------------------------------------------------

func _refresh() -> void:
	_equipment_list.clear()
	for slot in ItemData.SLOTS:
		var item: Item = _inventory.equipped.get(slot)
		var index := _equipment_list.add_item("%s:  %s" % [ItemData.SLOT_NAMES[slot], item.name if item else "-"],
				_icons.icon(item) if item else null)
		_equipment_list.set_item_custom_fg_color(index, item.color() if item else Color(0.5, 0.5, 0.55))

	_backpack_list.clear()
	for item in _inventory.backpack:
		var marker := "▲ " if _inventory.is_upgrade(item) else "    "
		var index := _backpack_list.add_item(marker + item.name, _icons.icon(item))
		_backpack_list.set_item_custom_fg_color(index, item.color())
	_backpack_title.text = "Backpack  %d / %d" % [_inventory.backpack.size(), Inventory.BACKPACK_SIZE]

	# Keep the selection if the item is still around.
	if _selected != null:
		var worn: Item = _inventory.equipped.get(_selected.slot)
		var in_pack := _inventory.backpack.find(_selected)
		if worn == _selected:
			_selected_worn = true
			_equipment_list.select(ItemData.SLOTS.find(_selected.slot))
		elif in_pack >= 0:
			_selected_worn = false
			_backpack_list.select(in_pack)
		else:
			_selected = null

	_show_details()
	_stats_text.text = _stats_bbcode()
	_upgrades_button.disabled = not _inventory.backpack.any(func(i: Item) -> bool: return _inventory.is_upgrade(i))


func _show_details() -> void:
	_equip_button.disabled = _selected == null
	_equip_button.text = "Unequip" if _selected_worn else "Equip"
	_discard_button.disabled = _selected == null or _selected_worn
	_icons.show_item(_selected)
	if _selected == null:
		_details.text = "[color=#8a8f9c]Select an item.[/color]"
		return

	var item := _selected
	var lines := "[font_size=24][color=#%s][b]%s[/b][/color][/font_size]\n" % [item.color().to_html(false), item.name]
	lines += "[color=#8a8f9c]%s  ·  %s[/color]\n\n" % [item.subtitle(), ItemData.SLOT_NAMES[item.slot]]
	for mod in item.implicit:
		lines += "[color=#b8bcc8]%s[/color]\n" % ItemData.mod_text(mod)
	for mod in item.affixes:
		lines += "[color=#8fb4ff]%s[/color]\n" % ItemData.mod_text(mod)

	if not _selected_worn:
		var worn: Item = _inventory.equipped.get(item.slot)
		lines += "\n"
		if worn == null:
			lines += "[color=#7ee08a]▲ Empty slot[/color]"
		else:
			var better := item.score() > worn.score()
			lines += "[color=#%s]%s[/color]  [color=#8a8f9c]vs worn[/color]\n" % [
					"7ee08a" if better else "e08a7e", "▲ Likely upgrade" if better else "▼ Likely downgrade"]
			lines += "[color=#%s]%s[/color]\n" % [worn.color().to_html(false), worn.name]
			for mod in worn.modifiers():
				lines += "[color=#8a8f9c]%s[/color]\n" % ItemData.mod_text(mod)
	_details.text = lines


func _stats_bbcode() -> String:
	var s := _stats
	var rows: Array[String] = [
		"Max HP  [b]%d[/b]    Regen  [b]%.1f[/b]/s" % [roundi(s.max_hp), s.regen],
		"Armor  [b]%d[/b]  (%d%% less damage)" % [roundi(s.armor), roundi((1.0 - s.damage_taken_factor()) * 100.0)],
		"Move speed  [b]%.1f[/b]    Pickup  [b]%.1f[/b]" % [s.move_speed, s.pickup_radius],
		"Bolt damage  [b]%.1f[/b]  x%d  (pierce %d)" % [s.bolt_damage, s.bolt_count, s.bolt_pierce],
		"Bolt rate  [b]%.2f[/b]/s" % (1.0 / s.bolt_cooldown),
		"Crit  [b]%d%%[/b]  for  [b]x%.2f[/b]" % [roundi(s.crit_chance * 100.0), s.crit_mult],
		"XP gain  [b]%+d%%[/b]    Magic find  [b]%+d%%[/b]" % [roundi((s.xp_gain - 1.0) * 100.0), roundi(s.magic_find * 100.0)],
	]
	if s.aura_level > 0:
		rows.append("Frost Aura  Lv [b]%d[/b]  r[b]%.1f[/b]  dmg [b]%.1f[/b]" % [s.aura_level, s.aura_radius, s.aura_damage])
	if s.lightning_level > 0:
		rows.append("Lightning  Lv [b]%d[/b]  dmg [b]%.1f[/b]  jumps [b]%d[/b]" % [s.lightning_level, s.lightning_damage, s.lightning_chains])
	if s.orbit_level > 0:
		rows.append("Blades  Lv [b]%d[/b]  x[b]%d[/b]  dmg [b]%.1f[/b]" % [s.orbit_level, s.orbit_count, s.orbit_damage])
	if s.nova_level > 0:
		rows.append("Nova  Lv [b]%d[/b]  dmg [b]%.1f[/b]  every [b]%.1f[/b]s" % [s.nova_level, s.nova_damage, s.nova_cooldown])
	rows.append("Dash  every [b]%.1f[/b]s" % s.dash_cooldown)
	return "\n".join(rows)


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0.02, 0.7)
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
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# Header
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UiStyle.label(30)
	title.text = "Inventory"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var hint := UiStyle.label(15)
	hint.text = "Tab / Esc  close      Enter  equip / unequip"
	hint.modulate = Color(1, 1, 1, 0.55)
	header.add_child(hint)

	# Three columns
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	body.add_child(left)
	left.add_child(_section_label("Equipped"))
	_equipment_list = _make_list(Vector2(330, 290))
	_equipment_list.item_selected.connect(_on_equipment_selected)
	_equipment_list.item_activated.connect(func(_i: int) -> void: _on_equip_pressed())
	left.add_child(_equipment_list)
	left.add_child(_section_label("Stats"))
	_stats_text = _make_text(Vector2(330, 190))
	left.add_child(_stats_text)

	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 290
	body.add_child(middle)
	_backpack_title = _section_label("Backpack")
	middle.add_child(_backpack_title)
	_backpack_list = _make_list(Vector2(300, 520))
	_backpack_list.item_selected.connect(_on_backpack_selected)
	_backpack_list.item_activated.connect(func(_i: int) -> void: _on_equip_pressed())
	middle.add_child(_backpack_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	body.add_child(right)
	right.add_child(_section_label("Selected"))
	right.add_child(_icons.make_preview(Vector2(330, 150)))
	_details = _make_text(Vector2(330, 300))
	right.add_child(_details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	_equip_button = Button.new()
	_equip_button.text = "Equip"
	_equip_button.custom_minimum_size = Vector2(120, 40)
	_equip_button.pressed.connect(_on_equip_pressed)
	buttons.add_child(_equip_button)
	_discard_button = Button.new()
	_discard_button.text = "Discard"
	_discard_button.custom_minimum_size = Vector2(120, 40)
	_discard_button.pressed.connect(_on_discard_pressed)
	buttons.add_child(_discard_button)

	# Footer
	_upgrades_button = Button.new()
	_upgrades_button.text = "Equip all likely upgrades (▲)"
	_upgrades_button.custom_minimum_size = Vector2(0, 38)
	_upgrades_button.pressed.connect(_on_upgrades_pressed)
	column.add_child(_upgrades_button)


func _section_label(text: String) -> Label:
	var label := UiStyle.label(16)
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.GOLD.darkened(0.1))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_list(min_size: Vector2) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = min_size
	list.add_theme_font_size_override("font_size", 16)
	list.allow_reselect = true
	list.fixed_icon_size = Vector2i(36, 36)
	return list


func _make_text(min_size: Vector2) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = min_size
	text.focus_mode = Control.FOCUS_NONE
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 16)
	return text
