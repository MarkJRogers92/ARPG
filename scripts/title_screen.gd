class_name TitleScreen
extends CanvasLayer
## The title screen: pick a hero and a realm to spend the night in. The world behind it
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
var _class_desc: Label
var _pact_overlay: Control
var _pact_box: VBoxContainer
var _pact_button: Button
var _bestiary_overlay: Control
var _crypt_overlay: Control
var _crypt_box: VBoxContainer
var _bestiary_label: Label


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
	if not is_open() or not event.is_action_pressed("ui_cancel"):
		return
	for overlay in [_altar_overlay, _pact_overlay, _bestiary_overlay, _crypt_overlay]:
		if overlay and overlay.visible:
			overlay.hide()
			_refresh_pact_button()
			get_viewport().set_input_as_handled()
			return


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

	var title := UiStyle.label(76)
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
	gap.custom_minimum_size.y = 14
	column.add_child(gap)

	# Heroes: pick one, or buy one with Soul Shards.
	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 12)
	column.add_child(heroes)
	for id: String in HeroClass.ORDER:
		heroes.add_child(_class_button(id))
	_class_desc = UiStyle.label(15)
	_class_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_desc.custom_minimum_size = Vector2(900, 24)
	_class_desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc.modulate = Color(1, 1, 1, 0.8)
	_class_desc.text = HeroClass.data(MetaProgress.hero_class)["desc"]
	column.add_child(_class_desc)
	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 8
	column.add_child(gap3)

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
	bottom.add_theme_constant_override("separation", 10)
	column.add_child(bottom)
	var altar_button := Button.new()
	altar_button.text = "Altar of Souls   ·   %d ◆" % MetaProgress.shards
	altar_button.custom_minimum_size = Vector2(250, 46)
	altar_button.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	altar_button.pressed.connect(func() -> void:
		_altar.refresh()
		_altar_overlay.show())
	bottom.add_child(altar_button)
	_pact_button = Button.new()
	_pact_button.custom_minimum_size = Vector2(235, 46)
	_pact_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_pact_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_pacts()
		_pact_overlay.show())
	bottom.add_child(_pact_button)
	var bestiary_button := Button.new()
	bestiary_button.text = "Bestiary   ·   %d ★" % MetaProgress.total_stars()
	bestiary_button.custom_minimum_size = Vector2(180, 46)
	bestiary_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_bestiary()
		_bestiary_overlay.show())
	bottom.add_child(bestiary_button)
	var crypt_button := Button.new()
	crypt_button.text = "The Crypt   ·   %d" % MetaProgress.crypt.size()
	crypt_button.tooltip_text = "Veterans of past nights. Choose one to rise beside you."
	crypt_button.custom_minimum_size = Vector2(170, 46)
	crypt_button.add_theme_color_override("font_color", Army.VETERAN_COLOR)
	crypt_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_crypt()
		_crypt_overlay.show())
	bottom.add_child(crypt_button)
	var daily_button := Button.new()
	daily_button.text = "Daily Night"
	daily_button.tooltip_text = "Today's realm, omen and seed are the same for every run today. Beat your best kill count."
	daily_button.custom_minimum_size = Vector2(150, 46)
	daily_button.add_theme_color_override("font_color", UiStyle.GOLD)
	daily_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		var unlocked := Realm.ORDER.filter(func(id: String) -> bool: return MetaProgress.is_unlocked(id))
		Realm.daily = true
		chosen.emit(Realm.daily_pick(unlocked)["realm"]))
	bottom.add_child(daily_button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(100, 46)
	quit.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit)

	_pact_overlay = _overlay()
	_pact_box = VBoxContainer.new()
	_pact_box.add_theme_constant_override("separation", 10)
	_pact_box.custom_minimum_size.x = 560
	(_pact_overlay.get_meta("box") as VBoxContainer).add_child(_pact_box)
	_bestiary_overlay = _overlay()
	_bestiary_label = UiStyle.label(16)
	_bestiary_label.custom_minimum_size = Vector2(520, 0)
	(_bestiary_overlay.get_meta("box") as VBoxContainer).add_child(_bestiary_label)
	_crypt_overlay = _overlay()
	_crypt_box = VBoxContainer.new()
	_crypt_box.add_theme_constant_override("separation", 10)
	_crypt_box.custom_minimum_size.x = 620
	(_crypt_overlay.get_meta("box") as VBoxContainer).add_child(_crypt_box)
	_refresh_pact_button()

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


## A dimmed full-screen overlay with a panel; its content box is meta "box".
func _overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0.02, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		overlay.hide()
		_refresh_pact_button())
	box.add_child(back)
	box.move_child(back, 0)
	overlay.set_meta("box", box)
	# Content goes above the Back button.
	box.child_order_changed.connect(func() -> void:
		if back.get_index() != box.get_child_count() - 1:
			box.move_child(back, box.get_child_count() - 1))
	return overlay


func _refresh_pact_button() -> void:
	var open := MetaProgress.any_won()
	var heat := RunModifiers.heat(MetaProgress.pacts)
	_pact_button.disabled = not open
	var asc := ("A%d  ·  " % MetaProgress.ascension) if MetaProgress.ascension > 0 else ""
	_pact_button.text = ("Pact of Night   ·   %sheat %d" % [asc, heat]) if open else "Pact of Night   ·   win a realm"


func _fill_pacts() -> void:
	for child in _pact_box.get_children():
		child.queue_free()
	var title := UiStyle.label(30)
	title.text = "PACT OF NIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_pact_box.add_child(title)
	_pact_box.add_child(_ascension_row())
	var heat_label := UiStyle.label(17)
	heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pact_box.add_child(heat_label)
	var update := func() -> void:
		var h := RunModifiers.heat(MetaProgress.pacts)
		heat_label.text = "Heat %d   ·   +%d%% Soul Shards" % [h, roundi(100.0 * RunModifiers.HEAT_BONUS * h)]
	update.call()
	for id: String in RunModifiers.PACT_ORDER:
		var p: Dictionary = RunModifiers.PACTS[id]
		var check := CheckButton.new()
		check.text = "%s  (heat %d):  %s" % [p["name"], p["heat"], p["desc"]]
		check.button_pressed = id in MetaProgress.pacts
		check.add_theme_font_size_override("font_size", 16)
		check.toggled.connect(func(on: bool) -> void:
			Sound.play("ui_click")
			var list := MetaProgress.pacts.duplicate()
			if on and not id in list:
				list.append(id)
			elif not on:
				list.erase(id)
			MetaProgress.set_pacts(list)
			update.call())
		_pact_box.add_child(check)


## The Ascension picker: ◀ level ▶ and the rules it adds up to.
func _ascension_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var down := Button.new()
	down.text = "◀"
	down.custom_minimum_size = Vector2(44, 38)
	row.add_child(down)
	var label := UiStyle.label(22)
	label.custom_minimum_size.x = 260
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	row.add_child(label)
	var up := Button.new()
	up.text = "▶"
	up.custom_minimum_size = Vector2(44, 38)
	row.add_child(up)
	var rules := UiStyle.label(15)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size.x = 560
	rules.modulate = Color(1, 1, 1, 0.8)
	box.add_child(rules)
	var update := func() -> void:
		var a := MetaProgress.ascension
		label.text = "ASCENSION %d" % a if a > 0 else "NO ASCENSION"
		down.disabled = a <= 0
		up.disabled = a >= MetaProgress.ascension_unlocked
		if a == 0:
			rules.text = "Win a realm to climb higher (unlocked: %d of %d)." % [MetaProgress.ascension_unlocked, RunModifiers.ASCENSION_MAX]
		else:
			var lines: Array[String] = []
			for k in a:
				lines.append("%d. %s" % [k + 1, RunModifiers.ASCENSION[k]])
			rules.text = "\n".join(lines) + "\n+%d%% Soul Shards  ·  the night pushes back harder  ·  unlocked: %d" % [
					roundi(100.0 * RunModifiers.ASCENSION_SHARDS * a), MetaProgress.ascension_unlocked]
	update.call()
	down.pressed.connect(func() -> void:
		Sound.play("ui_click")
		MetaProgress.set_ascension(MetaProgress.ascension - 1)
		update.call())
	up.pressed.connect(func() -> void:
		Sound.play("ui_click")
		MetaProgress.set_ascension(MetaProgress.ascension + 1)
		update.call())
	return box


func _fill_bestiary() -> void:
	var lines := ["BESTIARY   ·   %d ★  (+%d%% damage, for good)" % [MetaProgress.total_stars(), MetaProgress.total_stars()], ""]
	if not MetaProgress.nemesis.is_empty():
		var n := MetaProgress.nemesis
		lines.insert(1, "YOUR NEMESIS:  %s   ·   rank %d   ·   %d of your souls stolen" % [n["name"], n["rank"], n["stolen"]])
	if MetaProgress.nemeses_slain > 0:
		lines.insert(1, "Nemeses destroyed: %d" % MetaProgress.nemeses_slain)
	var kinds := MetaProgress.bestiary.keys()
	kinds.sort_custom(func(a, b) -> bool: return MetaProgress.bestiary[a] > MetaProgress.bestiary[b])
	if kinds.is_empty():
		lines.append("Nothing slain yet. Every 100, 1,000 and 5,000 kills of a kind earn a star.")
	for kind: String in kinds.slice(0, 22):
		var stars := MetaProgress.stars(kind)
		var next := ""
		for step: int in MetaProgress.BESTIARY_STEPS:
			if MetaProgress.bestiary[kind] < step:
				next = "   (next star at %d)" % step
				break
		lines.append("%s   %s   %d slain%s" % ["★".repeat(stars) + "☆".repeat(3 - stars), kind, MetaProgress.bestiary[kind], next])
	_bestiary_label.text = "\n".join(lines)


func _class_button(id: String) -> Button:
	var d := HeroClass.data(id)
	var unlocked := MetaProgress.class_unlocked(id)
	var picked := MetaProgress.hero_class == id
	var accent: Color = d["accent"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 54)
	if picked:
		b.text = "✓ " + d["name"]
	elif unlocked:
		b.text = d["name"]
	else:
		b.text = "%s   ·   %d ◆" % [d["name"], d["cost"]]
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", accent if unlocked else UiStyle.MUTED)
	if picked:
		b.add_theme_stylebox_override("normal", UiStyle.box(Color(0.1, 0.1, 0.12, 0.95), accent, 3, 8))
	b.disabled = not unlocked and MetaProgress.shards < d["cost"]
	b.pressed.connect(func() -> void:
		Sound.play("ui_click")
		if MetaProgress.unlock_class(id):
			MetaProgress.select_class(id)
			get_tree().reload_current_scene())
	for signal_name in ["mouse_entered", "focus_entered"]:
		b.connect(signal_name, func() -> void:
			_class_desc.text = d["desc"] + ("" if unlocked else "   (unlock for %d Soul Shards)" % d["cost"]))
	return b


func _realm_card(id: String) -> Button:
	var d := Realm.data(id)
	var accent: Color = d["accent"]
	var unlocked := MetaProgress.is_unlocked(id)
	var won := MetaProgress.is_won(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(330, 330)
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
	card.pressed.connect(func() -> void:
		Sound.play("ui_click")
		Realm.daily = false
		chosen.emit(id))
	for signal_name in ["mouse_entered", "focus_entered"]:
		card.connect(signal_name, func() -> void:
			Sound.play("ui_hover")
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


func _fill_crypt() -> void:
	for child in _crypt_box.get_children():
		child.queue_free()
	var title := UiStyle.label(30)
	title.text = "THE CRYPT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Army.VETERAN_COLOR)
	_crypt_box.add_child(title)
	var hint := UiStyle.label(15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.text = "Minions that kill enough earn a name. After a night, your greatest veteran rests here.\nThe one you choose rises beside you when the next night begins. If it falls, it's gone for good."
	_crypt_box.add_child(hint)
	if MetaProgress.crypt.is_empty():
		var empty := UiStyle.label(17)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.text = "\nThe Crypt is empty. A minion needs %d kills to earn a name." % Army.RANKS[1]["kills"]
		_crypt_box.add_child(empty)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for v: Dictionary in MetaProgress.crypt:
		var b := CheckBox.new()
		b.button_group = group
		var rank: int = clampi(int(v["rank"]), 0, Army.RANKS.size() - 1)
		b.text = "%s  %s   ·   %s %s, %s   ·   %d kills   ·   %d night%s" % ["★".repeat(rank), v["name"], v["label"],
				Army.ROLES.get(v["role"], {"label": ""})["label"], Army.RANKS[rank]["label"], v["deeds"], v.get("nights", 1),
				"" if v.get("nights", 1) == 1 else "s"]
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Army.VETERAN_COLOR)
		b.button_pressed = v["id"] == MetaProgress.crypt_chosen
		var id: int = v["id"]
		b.toggled.connect(func(on: bool) -> void:
			Sound.play("ui_click")
			if on:
				MetaProgress.choose_veteran(id)
			elif MetaProgress.crypt_chosen == id:
				MetaProgress.choose_veteran(-1))
		_crypt_box.add_child(b)
	if not MetaProgress.fallen.is_empty():
		var lines := ["", "THE FALLEN"]
		for v: Dictionary in MetaProgress.fallen.slice(0, 6):
			lines.append("%s   ·   %s   ·   %d kills" % [v["name"], v["label"], v["deeds"]])
		var fallen := UiStyle.label(15)
		fallen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallen.modulate = Color(0.75, 0.75, 0.85)
		fallen.text = "\n".join(lines)
		_crypt_box.add_child(fallen)
