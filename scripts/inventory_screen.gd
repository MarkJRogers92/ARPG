class_name InventoryScreen
extends CanvasLayer
## The pausing equipment screen. Built in code like the HUD.
##
## Left: worn gear and the hero's stats. Middle: the backpack ("▲" marks items
## that likely beat what you're wearing). Right: details for the selected item.
## Select with mouse, arrows or d-pad; Enter / double-click equips or unequips.

signal closed

const ItemComparison = preload("res://scripts/campaign/item_comparison.gd")
const CampaignMenuStyle = preload("res://scripts/campaign/campaign_menu_style.gd")

var _inventory: Inventory
var _stats: PlayerStats
var _player: Player
var _loot: LootManager
var _source_tabs: TabContainer
var _nearby_list: ItemList
var _nearby_hint: Label
var _nearby_drops: Array[LootDrop] = []
var _selected_drop: LootDrop
var _selected_from_ground := false
var _collecting := false

var _root: Control
var _equipment_list: ItemList
var _backpack_list: ItemList
var _backpack_title: Label
var _details: RichTextLabel
var _impact: RichTextLabel
var _detail_tabs: TabContainer
var _stats_text: RichTextLabel
var _equip_button: Button
var _discard_button: Button
var _upgrades_button: Button
var _icons: ItemIcons
var _selection_name: Label
var _selection_meta: Label

var _selected: Item
var _selected_worn := false
var _campaign_combat := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the tree is paused
	layer = 11
	_icons = ItemIcons.new()
	add_child(_icons)
	_build()
	_root.hide()


func setup(player: Player, campaign_combat := false, loot: LootManager = null) -> void:
	_player = player
	_loot = loot
	_inventory = player.inventory
	_stats = player.stats
	_campaign_combat = campaign_combat
	_inventory.changed.connect(func() -> void:
		if is_open():
			_refresh())


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_refresh()
	_root.show()
	(_nearby_list if _source_tabs.current_tab == 1 else (_backpack_list if _backpack_list.item_count > 0 else _equipment_list)).grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif is_open() and get_viewport().gui_get_focus_owner() in [_impact, _details]:
		var focused := get_viewport().gui_get_focus_owner() as RichTextLabel
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			focused.get_v_scroll_bar().value += 48.0 if event.is_action_pressed("ui_down") else -48.0
			get_viewport().set_input_as_handled()


# --- actions ---------------------------------------------------------------------

func _on_equip_pressed() -> void:
	if _collecting: return
	if _selected_from_ground:
		if _player.dead or not is_instance_valid(_selected_drop) or _loot == null:
			_refresh(); return
		var item := _selected
		_collecting = true
		var result := _loot.collect(_selected_drop, _player.pos2, _stats.pickup_radius, _inventory)
		_collecting = false
		if result in ["equipped","backpack"]:
			_selected_drop = null; _selected_from_ground = false; _selected = null; _selected_worn = false
		_refresh()
		if result in ["equipped","backpack"]:
			_selection_name.text = item.name
			_selection_meta.text = "Collected · Backpack" if result == "backpack" else "Collected · Equipped"
			_impact.text = "Stored in Backpack. Select it there to review or equip." if result == "backpack" else "Equipped in the previously empty slot."
			_nearby_list.grab_focus()
		return
	if _selected == null:
		return
	if _selected_worn:
		_inventory.unequip(_selected.slot)
	else:
		_inventory.equip(_selected)


func _on_discard_pressed() -> void:
	if _collecting: return
	if not _campaign_combat and _selected != null and not _selected_worn and not _selected_from_ground:
		var item := _selected
		_selected = null
		_inventory.discard(item)


func _on_upgrades_pressed() -> void:
	if not _collecting: _inventory.equip_upgrades()


func _on_equipment_selected(index: int) -> void:
	if index < 0 or index >= ItemData.SLOTS.size(): return
	_selected_drop = null; _selected_from_ground = false
	_nearby_list.deselect_all()
	_backpack_list.deselect_all()
	_selected = _inventory.equipped.get(ItemData.SLOTS[index])
	_selected_worn = true
	_show_details()


func _on_backpack_selected(index: int) -> void:
	if index < 0 or index >= _inventory.backpack.size(): return
	_selected_drop = null; _selected_from_ground = false
	_nearby_list.deselect_all()
	_equipment_list.deselect_all()
	_selected = _inventory.backpack[index]
	_selected_worn = false
	_show_details()


func _on_nearby_selected(index: int) -> void:
	if index < 0 or index >= _nearby_drops.size() or not is_instance_valid(_nearby_drops[index]): return
	_equipment_list.deselect_all(); _backpack_list.deselect_all()
	_selected_from_ground = true
	_selected_drop = _nearby_drops[index]
	_selected = _selected_drop.item
	_selected_worn = false
	_show_details()


func _on_source_changed(index: int) -> void:
	_selected_drop = null; _selected_from_ground = false; _selected = null; _selected_worn = false
	if index == 1 and not _nearby_drops.is_empty():
		_nearby_list.select(0); _on_nearby_selected(0)
	elif index == 0 and not _inventory.backpack.is_empty():
		_backpack_list.select(0); _on_backpack_selected(0)
	else: _show_details()


# --- drawing ---------------------------------------------------------------------

func _refresh() -> void:
	_equipment_list.clear()
	for slot in ItemData.SLOTS:
		var item: Item = _inventory.equipped.get(slot)
		var index := _equipment_list.add_item("%s:  %s" % [ItemData.SLOT_NAMES[slot], item.name if item else "-"],
				_icons.icon(item) if item else null)
		_equipment_list.set_item_custom_fg_color(index, RunUi.TEXT if item else RunUi.MUTED)

	_backpack_list.clear()
	for item in _inventory.backpack:
		var marker := "▲ " if _inventory.is_upgrade(item) else "    "
		var index := _backpack_list.add_item(marker + item.name, _icons.icon(item))
		_backpack_list.set_item_custom_fg_color(index, RunUi.TEXT)
	_backpack_title.text = "Backpack  %d / %d" % [_inventory.backpack.size(), Inventory.BACKPACK_SIZE]

	_nearby_drops = _loot.nearby(_player.pos2, _stats.pickup_radius) if _loot != null else []
	_nearby_list.clear()
	for node: LootDrop in _nearby_drops:
		var index := _nearby_list.add_item(node.item.name, _icons.icon(node.item))
		_nearby_list.set_item_tooltip(index, node.item.subtitle())
	_source_tabs.set_tab_title(1, "Nearby · %d" % _nearby_drops.size())
	_nearby_hint.text = "Within pickup reach. " + ("New loot is kept on a successful return." if _campaign_combat else "Uncollected ground loot is not saved.")
	if _nearby_drops.is_empty(): _nearby_hint.text = "No loot within pickup reach. Move closer, then reopen Equipment."
	if not is_instance_valid(_selected_drop) or not _nearby_drops.has(_selected_drop):
		_selected_drop = null; _selected_from_ground = false

	# Keep the selection if the item is still around.
	if _selected != null:
		var worn: Item = _inventory.equipped.get(_selected.slot)
		var in_pack := _inventory.backpack.find(_selected)
		if _selected_drop != null:
			_selected_worn = false
			_nearby_list.select(_nearby_drops.find(_selected_drop))
		elif worn == _selected:
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
	_equip_button.disabled = _selected == null or (_selected_worn and _inventory.is_full())
	_equip_button.tooltip_text = "Backpack full. Swap a carried item or free one space before unequipping." if _selected_worn and _inventory.is_full() else ""
	_equip_button.text = "Unequip" if _selected_worn else "Equip"
	_discard_button.disabled = _campaign_combat or _selected == null or _selected_worn
	_discard_button.tooltip_text = "Banked campaign gear can only be discarded in town." if _campaign_combat else ""
	if _selected_drop != null:
		_equip_button.text = "Collect"
		_equip_button.disabled = _player.dead or (_inventory.equipped.has(_selected.slot) and _inventory.is_full())
		_equip_button.tooltip_text = "Make one backpack space to collect this item." if _equip_button.disabled else "Uses normal pickup rules: fills an empty equipment slot, otherwise stores in your backpack."
		_discard_button.disabled = true
		_discard_button.tooltip_text = "Nearby items stay on the ground until collected."
	_icons.show_item(_selected)
	if _selected == null:
		_selection_name.text = "Inspect your gear"
		_selection_meta.text = "Choose an item to compare"
		_details.text = "[color=#%s]Select an item.[/color]" % CampaignMenuStyle.MUTED.to_html(false)
		_impact.text = "No loot within pickup reach. Move closer, then reopen Equipment." if _source_tabs.current_tab == 1 else "Preview the change before you equip. Select worn gear to see what removing it would change."
		return

	var item := _selected
	_selection_name.text = item.name
	_selection_name.tooltip_text = item.name
	_selection_meta.text = ("On ground · " if _selected_drop != null else "") + "%s · %s" % [ItemData.RARITIES[item.rarity]["name"],ItemData.SLOT_NAMES[item.slot]]
	_selection_meta.add_theme_color_override("font_color",RunUi.GOLD if item.rarity >= ItemData.Rarity.RARE else RunUi.MUTED)
	var after := _inventory.preview_swap(item.slot, null if _selected_worn else item)
	_impact.text = "[font_size=12][color=#b5b4ab]%s[/color][/font_size]\n" % ("PREVIEW: UNEQUIP" if _selected_worn else "PREVIEW: EQUIP")
	if _selected_worn and _inventory.is_full():
		_impact.text += "[color=#ffb46b]Backpack full. Free one space to unequip.[/color]\n\n"
	if _selected_drop != null:
		_impact.text = "[font_size=12][color=#b5b4ab]IF EQUIPPED AFTER COLLECTION[/color][/font_size]\n"
		if _inventory.equipped.has(item.slot) and _inventory.is_full():
			_impact.text += "[color=#e0a18f]Backpack full. " + ("Manage carried gear in town." if _campaign_combat else "Free one space in Backpack, then collect here.") + "[/color]\n"
		else: _impact.text += "Collecting " + ("equips this empty slot." if not _inventory.equipped.has(item.slot) else "stores it in your backpack; your worn item stays equipped.") + "\n"
	_impact.text += GearImpact.text(_stats, after)
	_impact.scroll_to_line(0)
	_details.scroll_to_line(0)
	var lines := "[font_size=24][color=#%s][b]%s[/b][/color][/font_size]\n" % [item.color().to_html(false), item.name]
	lines += "[color=#%s]%s  ·  %s[/color]\n\n" % [CampaignMenuStyle.MUTED.to_html(false), item.subtitle(), ItemData.SLOT_NAMES[item.slot]]
	if item.power != "":
		lines += "[color=#ffb46b]★ %s[/color]\n\n" % item.power_text()
	for mod in item.implicit:
		lines += "[color=#cfd6dc]%s[/color]\n" % ItemData.mod_text(mod)
	for mod in item.affixes:
		lines += "[color=#9fd0d8]%s[/color]\n" % ItemData.mod_text(mod)
	var worn: Item = _inventory.equipped.get(item.slot) if not _selected_worn else item
	if not _selected_worn:
		lines += "\n[color=#%s]GEAR COMPARISON  ·  WORN → CARRIED[/color]\n" % CampaignMenuStyle.MUTED.to_html(false)
		lines += "[color=#%s]%s[/color]\n" % [CampaignMenuStyle.MUTED.to_html(false), worn.name if worn != null else "Empty slot"]
		lines += _modifier_comparison_text(worn, item)
		lines += _power_comparison_text(worn, item)

	if not _selected_worn:
		lines += "\n"
		if worn == null:
			lines += "[color=#7ee08a]▲ Empty slot[/color]"
		else:
			var better := item.score() > worn.score()
			lines += "[color=#%s]%s[/color]\n[color=#%s]Estimated fit; compare bonuses and powers.[/color]\n" % [
					"7ee08a" if better else "e08a7e", "▲ Likely upgrade" if better else "▼ Likely downgrade",
					CampaignMenuStyle.MUTED.to_html(false)]
	_details.text = lines.replace("CARRIED","GROUND").replace("Carried power","Ground power") if _selected_drop != null else lines


func _modifier_comparison_text(worn: Item, offered: Item) -> String:
	var worn_data: Dictionary = _item_comparison_data(worn)
	var offered_data: Dictionary = _item_comparison_data(offered)
	var lines := ""
	for row: Dictionary in ItemComparison.rows(worn_data, offered_data):
		var stat := str(row["stat"])
		var op := int(row["op"])
		var label := str(ItemData.STAT_INFO.get(stat, {}).get("label", stat))
		var operation := "Added" if op == PlayerStats.Op.ADD else ("Increased" if op == PlayerStats.Op.INCREASED else "More")
		var current := "—" if is_zero_approx(float(row["current"])) else ItemData.mod_text({"stat": stat, "op": op, "value": float(row["current"])})
		var next := "—" if is_zero_approx(float(row["offered"])) else ItemData.mod_text({"stat": stat, "op": op, "value": float(row["offered"])})
		current = current.trim_suffix(" " + label)
		next = next.trim_suffix(" " + label)
		var muted := CampaignMenuStyle.MUTED.to_html(false)
		var tint := CampaignMenuStyle.comparison_color(stat, op, float(row["current"]), float(row["offered"])).to_html(false)
		lines += "[color=#%s]%s · %s[/color]  [color=#%s]%s[/color]  [color=#%s]→[/color]  [color=#%s]%s[/color]\n" % [
				muted, operation, label, muted, current, muted, tint, next]
	return lines if lines != "" else "[color=#%s]No rolled stat modifiers.[/color]\n" % CampaignMenuStyle.MUTED.to_html(false)


## Legendary powers sit outside the numeric rolls, so name both sides plainly.
func _power_comparison_text(worn: Item, offered: Item) -> String:
	var worn_power := worn.power if worn != null else ""
	var offered_power := offered.power
	if worn_power == "" and offered_power == "":
		return ""
	var worn_text: String = "none" if worn_power == "" else str(ItemData.POWERS[worn_power]["desc"])
	var offered_text: String = "none" if offered_power == "" else str(ItemData.POWERS[offered_power]["desc"])
	return "[color=#ffb46b]★ Worn power — %s[/color]\n[color=#ffb46b]★ Carried power — %s[/color]\n" % [worn_text, offered_text]


func _item_comparison_data(item: Item) -> Dictionary:
	if item == null:
		return {}
	return {"implicit": item.implicit, "affixes": item.affixes, "power": item.power}


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
	rows.append("[color=#8fd8ff]Army [b]%d[/b]   %d souls each   [b]%.0f[/b] dmg/s[/color]" % [
			s.minion_max, s.soul_cost, s.minion_damage])
	if s.ignite_chance > 0.0 or s.chill_chance > 0.0:
		rows.append("Ignite [b]%d%%[/b]  (burn [b]%.0f[/b]/s)   Chill [b]%d%%[/b]" % [
				roundi(s.ignite_chance * 100.0), s.burn_dps, roundi(s.chill_chance * 100.0)])
	return "\n".join(rows)


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.015,0.02,0.025,0.93)
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
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# Header
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _menu_label(26)
	title.text = "Equipment"
	title.add_theme_color_override("font_color", RunUi.TEXT)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var hint := _menu_label(12)
	hint.text = "Tab / Esc   Close     ·     Enter   Selected action"
	hint.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	header.add_child(hint)

	# Three columns
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)

	var left := _card(body, 270)
	left.add_child(_section_label("Equipped"))
	_equipment_list = _make_list(Vector2(270, 238))
	_equipment_list.item_selected.connect(_on_equipment_selected)
	_equipment_list.item_activated.connect(func(_i: int) -> void: _on_equip_pressed())
	left.add_child(_equipment_list)
	left.add_child(_section_label("Stats"))
	_stats_text = _make_text(Vector2(270, 200))
	left.add_child(_stats_text)

	var middle := _card(body, 270)
	_backpack_title = _section_label("Backpack")
	middle.add_child(_backpack_title)
	_source_tabs = TabContainer.new()
	_source_tabs.custom_minimum_size = Vector2(270,456)
	_source_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	middle.add_child(_source_tabs)
	_backpack_list = _make_list(Vector2(270,410))
	_backpack_list.name = "Backpack"
	_backpack_list.item_selected.connect(_on_backpack_selected)
	_backpack_list.item_activated.connect(func(_i: int) -> void: _on_equip_pressed())
	_source_tabs.add_child(_backpack_list)
	var nearby_box := VBoxContainer.new(); nearby_box.name = "Nearby"
	_source_tabs.add_child(nearby_box)
	_nearby_list = _make_list(Vector2(270,348))
	_nearby_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nearby_list.item_selected.connect(_on_nearby_selected)
	_nearby_list.item_activated.connect(func(_i: int) -> void: _on_equip_pressed())
	nearby_box.add_child(_nearby_list)
	_nearby_hint = RunUi.label(12,RunUi.MUTED)
	_nearby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nearby_hint.custom_minimum_size = Vector2(270,48)
	nearby_box.add_child(_nearby_hint)
	_source_tabs.tab_changed.connect(_on_source_changed)

	var right := _card(body, 390)
	var selected_header:=HBoxContainer.new()
	selected_header.add_theme_constant_override("separation",12)
	right.add_child(selected_header)
	selected_header.add_child(_icons.make_preview(Vector2(64,64)))
	var selected_text:=VBoxContainer.new();selected_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_header.add_child(selected_text)
	_selection_name=RunUi.label(22)
	_selection_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_selection_name.max_lines_visible=2
	_selection_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_selection_name.custom_minimum_size.x=308
	selected_text.add_child(_selection_name)
	_selection_meta=RunUi.label(13,RunUi.MUTED);selected_text.add_child(_selection_meta)
	_detail_tabs = TabContainer.new()
	_detail_tabs.custom_minimum_size = Vector2(390, 368)
	_detail_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	right.add_child(_detail_tabs)
	_impact = _make_text(Vector2(390, 318))
	_impact.name = "Build impact"
	_impact.focus_mode = Control.FOCUS_ALL
	_impact.add_theme_font_size_override("normal_font_size", 14)
	_impact.add_theme_font_size_override("bold_font_size", 14)
	_detail_tabs.add_child(_impact)
	_details = _make_text(Vector2(390, 318))
	_details.name = "Item rolls"
	_details.focus_mode = Control.FOCUS_ALL
	_details.add_theme_font_size_override("normal_font_size", 14)
	_details.add_theme_font_size_override("bold_font_size", 14)
	_detail_tabs.add_child(_details)
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
	_upgrades_button.text = "Quick-equip by score  ▲"
	_upgrades_button.tooltip_text = "Uses the existing rough item score, not build synergy. Inspect Build impact to review actual stats and powers before swapping."
	_upgrades_button.custom_minimum_size = Vector2(0, 38)
	_upgrades_button.pressed.connect(_on_upgrades_pressed)
	column.add_child(_upgrades_button)


func _section_label(text: String) -> Label:
	var label := _menu_label(14)
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.GOLD.darkened(0.1))
	label.add_theme_constant_override("outline_size", 3)
	return label


## One readable column card: a framed panel holding a vertical stack.
func _card(parent: Control, min_width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			RunUi.panel(12,Color("384047")))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = min_width
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _make_list(min_size: Vector2) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = min_size
	list.add_theme_font_size_override("font_size", 14)
	list.allow_reselect = true
	list.fixed_icon_size = Vector2i(32, 32)
	return list


func _make_text(min_size: Vector2) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = min_size
	text.focus_mode = Control.FOCUS_NONE
	text.add_theme_constant_override("line_separation",4)
	text.add_theme_constant_override("table_h_separation",12)
	text.add_theme_constant_override("table_v_separation",6)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	return text


func _menu_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	return label
