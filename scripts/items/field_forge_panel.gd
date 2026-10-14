class_name FieldForgePanel
extends WagerPanel
## Shared choice styling; rules and transactions remain in Landmarks.
var _comparison: RichTextLabel
var _scroll: ScrollContainer

func _build() -> void:
	heading = "Field forge"
	flavor_text = "One roll. Keep the weapon that fits your build."
	super._build()
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comparison = RichTextLabel.new()
	_comparison.bbcode_enabled = true
	_comparison.custom_minimum_size.y = 220
	_comparison.focus_mode = Control.FOCUS_ALL
	_comparison.add_theme_font_size_override("normal_font_size", 15)
	_comparison.add_theme_font_size_override("bold_font_size", 15)
	var box := _odds.get_parent()
	_scroll = box.get_parent() as ScrollContainer
	box.add_child(_comparison)
	box.move_child(_comparison, _odds.get_index())
	_comparison.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			_comparison.get_v_scroll_bar().value += 40 if event.is_action_pressed("ui_down") else -40
			_comparison.accept_event())

func inspect_weapon(original: Item, roll_level: int, can_afford := true) -> void:
	_comparison.hide()
	_scroll.custom_minimum_size.y = 340
	show_state({"prize":"Equipped · " + original.name,
		"detail":original.subtitle() + "\nRoll one weapon of the same rarity, at item level %d." % roll_level,
		"odds":"Rolls and powers may improve or worsen your build.\nAfter paying, choose the original or the new weapon.",
		"result":"Inspecting is free. Rolling costs 8 Soul Shards and uses this forge. No refunds.",
		"actions":[["leave","Leave",true],["roll","Roll once · 8 shards" if can_afford else "Need 8 run shards",can_afford]]})

func compare_weapon(inventory: Inventory, before: PlayerStats, original: Item, rolled: Item) -> void:
	_scroll.custom_minimum_size.y = 580
	show_state({"prize":"8 shards paid · choose one weapon",
		"detail":"ORIGINAL · %s\n%s\nROLLED · %s\n%s" % [original.name,original.subtitle(),rolled.name,rolled.subtitle()],
		"odds":"Taking the roll replaces your original weapon; it does not go into your backpack.",
		"result":"Esc keeps the original. The fee and forge use are kept on Save & Quit.",
		"actions":[["keep","Keep original",true],["take","Take new weapon",true]]})
	_comparison.text = "[b]If you take the roll[/b]\n" + GearImpact.text(before, inventory.preview_swap("weapon", rolled))
	_comparison.show()
	var keep := action_button("keep")
	var take := action_button("take")
	_comparison.focus_next = _comparison.get_path_to(keep)
	_comparison.focus_previous = _comparison.get_path_to(take)
	keep.focus_neighbor_top = keep.get_path_to(_comparison)
	take.focus_next = take.get_path_to(_comparison)
	keep.focus_previous = keep.get_path_to(_comparison)
