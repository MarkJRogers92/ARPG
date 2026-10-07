class_name AltarPanel
extends GridContainer
## The Altar of Souls: permanent upgrades bought with Soul Shards (see
## MetaProgress). Shown on the death and victory screens and the title screen.


func _ready() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 8)
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var header := UiStyle.label(18)
	header.text = "ALTAR OF SOULS   ·   %d shards" % MetaProgress.shards
	header.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	add_child(header)
	add_child(Control.new())
	for id: String in MetaProgress.UPGRADES:
		var def: Dictionary = MetaProgress.UPGRADES[id]
		var r := MetaProgress.rank(id)
		var cost := MetaProgress.cost(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(350, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pips := "●".repeat(r) + "○".repeat(def["max"] - r)
		button.text = "%s  %s   %s" % [def["name"], pips, def["desc"]]
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = not MetaProgress.can_buy(id)
		var price := UiStyle.label(14)
		price.text = "max" if cost < 0 else "%d ◆" % cost
		price.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		price.offset_left = -64
		price.offset_right = -10
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0) if MetaProgress.can_buy(id) else UiStyle.MUTED)
		button.add_child(price)
		button.pressed.connect(func() -> void:
			if MetaProgress.buy(id):
				refresh.call_deferred())
		add_child(button)
