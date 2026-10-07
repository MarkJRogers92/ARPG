class_name TitleScreen
extends CanvasLayer
## The title screen: pick a realm to spend the night in. The world behind it
## is the real scene, so hovering a realm previews its ground, scenery and
## light (main.gd listens to `previewed`). Realms open in order: winning one
## unlocks the next. The Altar of Souls is reachable from here too.

signal previewed(realm_id: String)
signal chosen(realm_id: String)

const GAME_TITLE := "SOULBOUND"

var _root: Control
var _altar_overlay: Control
var _altar: AltarPanel
var _first: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()


func open() -> void:
	_root.show()
	if _first:
		_first.grab_focus.call_deferred()


func close() -> void:
	_root.hide()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if is_open() and _altar_overlay.visible and event.is_action_pressed("ui_cancel"):
		_altar_overlay.hide()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_root.add_child(column)

	var title := UiStyle.label(84)
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0, 0.95))
	title.add_theme_constant_override("outline_size", 16)
	column.add_child(title)
	var tagline := UiStyle.label(20)
	tagline.text = "Survive the night.   Bind the dead.   Greet the dawn."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1, 1, 1, 0.75)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	column.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for id: String in Realm.ORDER:
		var card := _realm_card(id)
		row.add_child(card)
		if _first == null and not card.disabled:
			_first = card

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 18
	column.add_child(gap2)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	column.add_child(bottom)
	var altar_button := Button.new()
	altar_button.text = "Altar of Souls   ·   %d ◆" % MetaProgress.shards
	altar_button.custom_minimum_size = Vector2(280, 46)
	altar_button.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	altar_button.pressed.connect(func() -> void:
		_altar.refresh()
		_altar_overlay.show())
	bottom.add_child(altar_button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(140, 46)
	quit.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit)

	# The Altar, over everything.
	_altar_overlay = ColorRect.new()
	(_altar_overlay as ColorRect).color = Color(0, 0, 0.02, 0.75)
	_altar_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_altar_overlay.hide()
	_root.add_child(_altar_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_altar_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var altar_box := VBoxContainer.new()
	altar_box.add_theme_constant_override("separation", 16)
	margin.add_child(altar_box)
	_altar = AltarPanel.new()
	altar_box.add_child(_altar)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		_altar_overlay.hide()
		altar_button.text = "Altar of Souls   ·   %d ◆" % MetaProgress.shards)
	altar_box.add_child(back)


func _realm_card(id: String) -> Button:
	var d := Realm.data(id)
	var accent: Color = d["accent"]
	var unlocked := MetaProgress.is_unlocked(id)
	var won := MetaProgress.is_won(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(330, 380)
	card.disabled = not unlocked
	card.pivot_offset = card.custom_minimum_size * 0.5
	var normal := UiStyle.box(Color(0.06, 0.06, 0.08, 0.92), accent.darkened(0.5), 2, 12)
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 14
	var hover := UiStyle.box(Color(0.09, 0.09, 0.11, 0.96), accent, 3, 12)
	hover.shadow_color = Color(accent, 0.35)
	hover.shadow_size = 20
	var locked := UiStyle.box(Color(0.04, 0.04, 0.05, 0.85), Color(0.2, 0.2, 0.22), 2, 12)
	card.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		card.add_theme_stylebox_override(state, hover)
	card.add_theme_stylebox_override("disabled", locked)
	card.pressed.connect(func() -> void: chosen.emit(id))
	for signal_name in ["mouse_entered", "focus_entered"]:
		card.connect(signal_name, func() -> void:
			previewed.emit(id)
			card.create_tween().tween_property(card, "scale", Vector2(1.04, 1.04), 0.12))
	for signal_name in ["mouse_exited", "focus_exited"]:
		card.connect(signal_name, func() -> void:
			card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.12))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_top = 18
	col.offset_right = -20
	col.offset_bottom = -18
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var night := UiStyle.label(14)
	night.text = "NIGHT %d   ·   %s" % [Realm.index(id) + 1, "◆".repeat(Realm.index(id) + 1) + "◇".repeat(2 - Realm.index(id))]
	night.modulate = Color(1, 1, 1, 0.55)
	col.add_child(night)
	var name_label := UiStyle.label(25)
	name_label.text = d["name"]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", accent.lightened(0.2) if unlocked else UiStyle.MUTED)
	col.add_child(name_label)
	var tag := UiStyle.label(15)
	tag.text = d["tagline"]
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.modulate = Color(1, 1, 1, 0.65)
	col.add_child(tag)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.3)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var desc := UiStyle.label(15)
	desc.text = d["rule"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)
	var boss := UiStyle.label(15)
	boss.text = "At dawn:  %s" % d["enemies"]["FinalBoss"]["label"]
	boss.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	col.add_child(boss)
	var status := UiStyle.label(16)
	if not unlocked:
		var prev: String = Realm.ORDER[Realm.index(id) - 1]
		status.text = "Locked: conquer %s first" % Realm.data(prev)["name"]
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.modulate = Color(1, 1, 1, 0.5)
	elif won:
		var best := MetaProgress.endless_best(id)
		status.text = "★ Conquered" + ("   ·   Endless +%d:%02d" % [int(best) / 60, int(best) % 60] if best > 0.0 else "")
		status.add_theme_color_override("font_color", UiStyle.GOLD)
	else:
		status.text = "Unconquered   ·   Enter"
		status.add_theme_color_override("font_color", accent)
	col.add_child(status)
	return card
