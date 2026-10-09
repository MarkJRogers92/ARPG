class_name TitleScreen
extends CanvasLayer
## The title screen: pick a hero and a realm to spend the night in. The world behind it
## is the real scene, so hovering a realm previews its ground, scenery and
## light (main.gd listens to `previewed`). Realms open in order: winning one
## unlocks the next. The Altar of Souls is reachable from here too.

signal previewed(realm_id: String)
signal chosen(realm_id: String)
## Resume the suspended night (RunSave's data).
signal resume_requested(data: Dictionary)

const GAME_TITLE := "SOULBOUND"
const CampaignMenuStyle = preload("res://scripts/campaign/campaign_menu_style.gd")

var _root: Control
var _altar_overlay: Control
var _altar: AltarPanel
## Focus priority: a suspended night, then a resumable campaign's Continue,
## then New Campaign, then the first unlocked Classic realm.
var _resume_night: Button
var _campaign_new: Button
var _first_realm: Button
var _class_desc: Label
var _pact_overlay: Control
var _pact_box: VBoxContainer
var _pact_button: Button
var _bestiary_overlay: Control
var _crypt_overlay: Control
var _crypt_box: VBoxContainer
var _bestiary_label: Label
var _relic_overlay: Control
var _relic_box: VBoxContainer
var _relic_button: Button
var _daily_overlay: Control
var _daily_box: VBoxContainer
var _campaign_summary: Label
var _campaign_continue: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()


func open() -> void:
	_root.show()
	_refresh_campaign_state()
	var target := _default_focus()
	if target:
		target.grab_focus.call_deferred()


## The button a keyboard player lands on: resuming beats starting fresh.
func _default_focus() -> Button:
	if is_instance_valid(_resume_night):
		return _resume_night
	if is_instance_valid(_campaign_continue) and CampaignSave.resumable():
		return _campaign_continue
	if is_instance_valid(_campaign_new):
		return _campaign_new
	return _first_realm


func close() -> void:
	_root.hide()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed("ui_cancel"):
		return
	for overlay in [_altar_overlay, _pact_overlay, _bestiary_overlay, _crypt_overlay, _relic_overlay, _daily_overlay]:
		if overlay and overlay.visible:
			overlay.hide()
			_refresh_pact_button()
			get_viewport().set_input_as_handled()
			return


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = CampaignMenuStyle.make_theme(UiStyle.theme())
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	_root.add_child(column)

	var title := _menu_label(48)
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.045, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	column.add_child(title)
	var tagline := _menu_label(16)
	tagline.text = "Survive the night.   Bind the dead.   Greet the dawn."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1, 1, 1, 0.75)
	column.add_child(tagline)
	# A suspended night takes the tagline's place.
	var saved := RunSave.read()
	if not saved.is_empty():
		tagline.hide()
		var resume := Button.new()
		resume.text = "Resume the night   ·   " + RunSave.describe(saved)
		resume.custom_minimum_size = Vector2(560, 40)
		resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		resume.add_theme_color_override("font_color", UiStyle.GOLD)
		resume.add_theme_stylebox_override("normal", UiStyle.box(Color(0.1, 0.1, 0.12, 0.95), UiStyle.GOLD, 2, 8))
		resume.tooltip_text = "Pick up where you left off. Starting a new night abandons it."
		resume.pressed.connect(func() -> void:
			Sound.play("ui_click")
			resume_requested.emit(saved))
		column.add_child(resume)
		_resume_night = resume
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)

	# Heroes: pick one, or buy one with Soul Shards.
	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 12)
	column.add_child(heroes)
	for id: String in HeroClass.ORDER:
		heroes.add_child(_class_button(id))
	# The hero's description, and beside it the Reliquary (relic, starting
	# weapon and lost lore for the next night).
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 18)
	column.add_child(hero_row)
	_class_desc = _menu_label(15)
	_class_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_desc.custom_minimum_size = Vector2(640, 40)
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc.modulate = Color(1, 1, 1, 0.8)
	_class_desc.text = HeroClass.data(MetaProgress.hero_class)["desc"]
	hero_row.add_child(_class_desc)
	_relic_button = Button.new()
	_relic_button.custom_minimum_size = Vector2(360, 40)
	_relic_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relic_button.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_relic_button.tooltip_text = "Relics, a starting weapon and lost lore, bought with Soul Shards and Bestiary stars."
	_relic_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_reliquary()
		_relic_overlay.show())
	hero_row.add_child(_relic_button)
	_refresh_relic_button()
	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 2
	column.add_child(gap3)

	var campaign_panel := PanelContainer.new()
	campaign_panel.add_theme_stylebox_override("panel", CampaignMenuStyle.panel(Color("151f28"), Color("4b5558"), 1, 8))
	campaign_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(campaign_panel)
	var campaign_stack := VBoxContainer.new()
	campaign_stack.add_theme_constant_override("separation", 5)
	campaign_panel.add_child(campaign_stack)
	var campaigns := HBoxContainer.new()
	campaigns.alignment = BoxContainer.ALIGNMENT_CENTER
	campaigns.add_theme_constant_override("separation", 8)
	campaign_stack.add_child(campaigns)
	var campaign_new := Button.new()
	_campaign_new = campaign_new
	campaign_new.text = "New Campaign"
	campaign_new.custom_minimum_size = Vector2(230, 46)
	campaign_new.add_theme_stylebox_override("normal", CampaignMenuStyle.quiet_box())
	campaign_new.tooltip_text = "A persistent adventurer across three realms. Short expeditions, town services, and biome bosses."
	campaign_new.pressed.connect(_new_campaign)
	campaigns.add_child(campaign_new)
	_campaign_continue = Button.new()
	_campaign_continue.text = "Continue Campaign"
	_campaign_continue.custom_minimum_size = Vector2(300, 46)
	_campaign_continue.disabled = not CampaignSave.resumable()
	_campaign_continue.add_theme_stylebox_override("normal", CampaignMenuStyle.primary_box())
	_campaign_continue.add_theme_stylebox_override("hover", CampaignMenuStyle.button_box(Color("715a30"), CampaignMenuStyle.SOUL, 1))
	_campaign_continue.add_theme_stylebox_override("focus", CampaignMenuStyle.button_box(Color("273844"), CampaignMenuStyle.SOUL, 2))
	_campaign_continue.tooltip_text = "Town and results are saved. An active expedition restarts from its departure checkpoint."
	_campaign_continue.pressed.connect(func() -> void: _open_campaign(false))
	campaigns.add_child(_campaign_continue)
	_campaign_summary = _menu_label(13)
	_campaign_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_summary.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	campaign_stack.add_child(_campaign_summary)
	_refresh_campaign_state()
	var classic_label := _menu_label(15)
	classic_label.text = "Classic Night"
	classic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classic_label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	column.add_child(classic_label)
	var classic_hint := _menu_label(12)
	classic_hint.text = "Choose a realm for a single night"
	classic_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classic_hint.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	column.add_child(classic_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for id: String in Realm.ORDER:
		var card := _realm_card(id)
		row.add_child(card)
		if _first_realm == null and not card.disabled:
			_first_realm = card

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 4
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
	daily_button.tooltip_text = "Today's realm, omen and seed are the same for every run today. Beat your best kill count, and share the code."
	daily_button.custom_minimum_size = Vector2(150, 46)
	daily_button.add_theme_color_override("font_color", UiStyle.GOLD)
	daily_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_daily()
		_daily_overlay.show())
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
	_bestiary_label = _menu_label(16)
	_bestiary_label.custom_minimum_size = Vector2(520, 0)
	(_bestiary_overlay.get_meta("box") as VBoxContainer).add_child(_bestiary_label)
	_crypt_overlay = _overlay()
	_crypt_box = VBoxContainer.new()
	_crypt_box.add_theme_constant_override("separation", 10)
	_crypt_box.custom_minimum_size.x = 620
	(_crypt_overlay.get_meta("box") as VBoxContainer).add_child(_crypt_box)
	_relic_overlay = _overlay()
	_relic_box = VBoxContainer.new()
	_relic_box.add_theme_constant_override("separation", 8)
	(_relic_overlay.get_meta("box") as VBoxContainer).add_child(_relic_box)
	_daily_overlay = _overlay()
	_daily_box = VBoxContainer.new()
	_daily_box.add_theme_constant_override("separation", 8)
	_daily_box.custom_minimum_size.x = 700
	(_daily_overlay.get_meta("box") as VBoxContainer).add_child(_daily_box)
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


func _refresh_relic_button() -> void:
	var relic := Relics.data(MetaProgress.relic)
	var weapon: String = Upgrades.DEFS[MetaProgress.start_weapon]["name"] if MetaProgress.start_weapon != "" else ""
	var parts := ["Reliquary"]
	parts.append(relic.get("name", "no relic"))
	if weapon != "":
		parts.append("starts with " + weapon)
	_relic_button.text = "   ·   ".join(parts)


func _refresh_campaign_summary() -> void:
	if not is_instance_valid(_campaign_summary):
		return
	var data := CampaignSave.read()
	if data.is_empty():
		_campaign_summary.text = "A saved campaign needs recovery; its files are preserved." if CampaignSave.resumable() else "Three realms · town services · persistent gear"
		return
	var biome_index := clampi(int(data.get("biome_index", 0)), 0, Realm.ORDER.size() - 1)
	var realm_name := str(Realm.REALMS[Realm.ORDER[biome_index]].get("name", "Unknown realm"))
	var hero_name := str(HeroClass.data(str(data.get("hero_class", "battlemage"))).get("name", "Adventurer"))
	var phase := str(data.get("phase", "TOWN"))
	if phase == "ABANDONED":
		# Continue is hidden for an abandoned run; say so instead of implying
		# that the town is still waiting.
		_campaign_summary.text = "%s  ·  %s  ·  previous campaign was set aside  ·  %d G" % [hero_name, realm_name, int(data.get("gold", 0))]
		return
	var progress := ""
	match phase:
		"TOWN": progress = "in town"
		"EVENT_PENDING": progress = "a road choice awaits"
		"DEPARTURE_READY": progress = "departure is prepared"
		"EXPEDITION_ACTIVE": progress = "on the road since the last departure"
		"RESULT_PENDING": progress = "results await review"
		"CAMPAIGN_COMPLETE": progress = "campaign complete"
		_: progress = phase.to_lower()
	_campaign_summary.text = "%s  ·  %s  ·  %s  ·  %s" % [hero_name, realm_name, progress, "%d G" % int(data.get("gold", 0))]


## Keep the Continue button and its summary honest after a campaign is created,
## resumed, or set aside while the title stays alive.
func _refresh_campaign_state() -> void:
	if is_instance_valid(_campaign_continue):
		_campaign_continue.disabled = not CampaignSave.resumable()
	_refresh_campaign_summary()


func _menu_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	return label


## Relics on the left; starting weapons and lost lore on the right. Rebuilt
## after every purchase or pick.
func _fill_reliquary() -> void:
	for child in _relic_box.get_children():
		child.queue_free()
	var title := _menu_label(30)
	title.text = "RELIQUARY   ·   %d ◆   ·   %d ★" % [MetaProgress.shards, MetaProgress.total_stars()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_relic_box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	_relic_box.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 520
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 400
	columns.add_child(right)

	left.add_child(_heading("RELICS   ·   carry one into the night"))
	left.add_child(_pick_row("No relic", "", MetaProgress.relic == "", "Carry", true, func() -> void:
		MetaProgress.carry_relic("")))
	for id: String in Relics.ORDER:
		var d := Relics.data(id)
		var owned := MetaProgress.relic_owned(id)
		var action := "Carry" if owned else ("%s ★ needed" % d["stars"] if d.has("stars") else "Buy  ·  %d ◆" % d["cost"])
		var can: bool = owned or (not d.has("stars") and MetaProgress.shards >= d["cost"])
		left.add_child(_pick_row(d["name"], d["desc"], MetaProgress.relic == id, action, can, func() -> void:
			if MetaProgress.buy_relic(id):
				MetaProgress.carry_relic(id), d["color"]))

	right.add_child(_heading("STARTING WEAPON   ·   %d ◆ to unlock" % Relics.WEAPON_COST))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	for id: String in [""] + Relics.WEAPONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(196, 36)
		b.add_theme_font_size_override("font_size", 15)
		var picked := MetaProgress.start_weapon == id
		var unlocked := id == "" or MetaProgress.weapon_unlocked(id)
		var label: String = "None" if id == "" else Upgrades.DEFS[id]["name"]
		b.text = ("✓ " if picked else "") + label + ("" if unlocked else "  ·  %d ◆" % Relics.WEAPON_COST)
		b.disabled = not unlocked and MetaProgress.shards < Relics.WEAPON_COST
		if picked:
			b.add_theme_stylebox_override("normal", UiStyle.box(Color(0.1, 0.1, 0.12, 0.95), UiStyle.GOLD, 2, 6))
		b.tooltip_text = "Start the night with nothing extra." if id == "" else Upgrades.DEFS[id]["desc"]
		b.pressed.connect(func() -> void:
			Sound.play("ui_click")
			if id == "" or MetaProgress.buy_weapon(id):
				MetaProgress.pick_weapon(id)
			_refresh_relic_button()
			_fill_reliquary())
		grid.add_child(b)

	right.add_child(_heading("LOST LORE   ·   new level-up cards"))
	for id: String in Upgrades.DEFS:
		var def: Dictionary = Upgrades.DEFS[id]
		if not def.has("unlock"):
			continue
		var owned := MetaProgress.card_unlocked(id)
		right.add_child(_pick_row(def["name"], def["desc"], owned, "Learned" if owned else "Learn  ·  %d ◆" % def["unlock"],
				not owned and MetaProgress.shards >= def["unlock"], func() -> void:
			MetaProgress.buy_card(id)))


func _heading(text: String) -> Label:
	var l := _menu_label(16)
	l.text = text
	l.add_theme_color_override("font_color", UiStyle.GOLD)
	return l


## One line of the Reliquary: a name and description, and a button.
func _pick_row(title: String, desc: String, picked: bool, action: String, enabled: bool, on_press: Callable,
		color := UiStyle.TEXT) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text := _menu_label(15)
	text.text = ("✓ " if picked else "") + title + ("\n" + desc if desc != "" else "")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("font_color", color if picked or enabled else UiStyle.MUTED)
	row.add_child(text)
	var b := Button.new()
	b.text = "✓" if picked and action == "Carry" else action
	b.custom_minimum_size = Vector2(130, 34)
	b.add_theme_font_size_override("font_size", 14)
	b.disabled = not enabled or (picked and action == "Carry")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Sound.play("ui_click")
		on_press.call()
		_refresh_relic_button()
		_fill_reliquary())
	row.add_child(b)
	return row


func _refresh_pact_button() -> void:
	var open := MetaProgress.any_won()
	var heat := RunModifiers.heat(MetaProgress.pacts)
	_pact_button.disabled = not open
	var asc := ("A%d  ·  " % MetaProgress.ascension) if MetaProgress.ascension > 0 else ""
	_pact_button.text = ("Pact of Night   ·   %sheat %d" % [asc, heat]) if open else "Pact of Night   ·   win a realm"


func _fill_pacts() -> void:
	for child in _pact_box.get_children():
		child.queue_free()
	var title := _menu_label(30)
	title.text = "PACT OF NIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_pact_box.add_child(title)
	_pact_box.add_child(_ascension_row())
	var heat_label := _menu_label(17)
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
	var label := _menu_label(22)
	label.custom_minimum_size.x = 260
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	row.add_child(label)
	var up := Button.new()
	up.text = "▶"
	up.custom_minimum_size = Vector2(44, 38)
	row.add_child(up)
	var rules := _menu_label(15)
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


## The Daily Night: today's realm and omen, a button to play it, the past
## nights with their codes, and a box to check a friend's code.
func _fill_daily() -> void:
	for child in _daily_box.get_children():
		child.queue_free()
	var title := _menu_label(30)
	title.text = "DAILY NIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	_daily_box.add_child(title)
	var unlocked := Realm.ORDER.filter(func(id: String) -> bool: return MetaProgress.is_unlocked(id))
	var today := Realm.today()
	var pick := Realm.daily_pick(unlocked)
	var info := _menu_label(16)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "%s   ·   %s   ·   Omen: %s   ·   your best today: %s" % [today, Realm.REALMS[pick["realm"]]["name"],
			RunModifiers.OMENS[RunModifiers.roll_omen(pick["omen"])]["name"],
			("%d kills" % MetaProgress.daily[today]) if MetaProgress.daily.has(today) else "none yet"]
	_daily_box.add_child(info)
	var play := Button.new()
	play.text = "Play today's night"
	play.custom_minimum_size = Vector2(260, 46)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_color_override("font_color", UiStyle.GOLD)
	play.pressed.connect(func() -> void:
		Sound.play("ui_click")
		Realm.daily = true
		chosen.emit(pick["realm"]))
	_daily_box.add_child(play)
	play.grab_focus.call_deferred()

	_daily_box.add_child(_heading("PAST NIGHTS   ·   ★ the best of its day"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_daily_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if MetaProgress.daily_runs.is_empty():
		var empty := _menu_label(15)
		empty.text = "No Daily Night finished yet. Each one leaves a code here to share."
		empty.modulate = Color(1, 1, 1, 0.7)
		list.add_child(empty)
	# Each day's best: the first run that reached its record.
	var starred := {}
	for i in MetaProgress.daily_runs.size():
		var r: Dictionary = MetaProgress.daily_runs[i]
		if not starred.has(r["date"]) and r.get("kills", 0) == MetaProgress.daily.get(r["date"], -1):
			starred[r["date"]] = i
	for i in range(MetaProgress.daily_runs.size() - 1, -1, -1):
		var r: Dictionary = MetaProgress.daily_runs[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := _menu_label(15)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var best: bool = starred.get(r["date"], -1) == i
		text.text = "%s %s   ·   %s\n     %s" % ["★" if best else "   ", r["date"], _daily_result(r), r["code"]]
		if best:
			text.add_theme_color_override("font_color", UiStyle.GOLD)
		row.add_child(text)
		var copy := Button.new()
		copy.text = "Copy code"
		copy.custom_minimum_size = Vector2(120, 34)
		copy.add_theme_font_size_override("font_size", 14)
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var code: String = r["code"]
		copy.pressed.connect(func() -> void:
			copy.text = "Copied"
			Sound.play("ui_click")
			DisplayServer.clipboard_set(code))
		row.add_child(copy)
		list.add_child(row)

	_daily_box.add_child(_heading("CHECK A CODE"))
	var check_row := HBoxContainer.new()
	check_row.add_theme_constant_override("separation", 10)
	_daily_box.add_child(check_row)
	var field := LineEdit.new()
	field.placeholder_text = "SB-20261008-K1234-T1432-W-REA-7Q2F"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = 36
	check_row.add_child(field)
	var check := Button.new()
	check.text = "Check"
	check.custom_minimum_size = Vector2(120, 36)
	check_row.add_child(check)
	var verdict := _menu_label(15)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_daily_box.add_child(verdict)
	var run_check := func() -> void:
		Sound.play("ui_click")
		var parts := DailyCode.decode(field.text)
		if parts.is_empty():
			verdict.text = "That isn't a valid code (a typo, or it was changed)."
			verdict.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			return
		var day := Realm.daily_pick(Realm.ORDER, parts["date"])
		verdict.text = "A true code:  %s   ·   %s\nThat day's night: %s, Omen: %s (with every realm open)" % [parts["date"],
				_daily_result(parts), Realm.REALMS[day["realm"]]["name"], RunModifiers.OMENS[RunModifiers.roll_omen(day["omen"])]["name"]]
		verdict.add_theme_color_override("font_color", UiStyle.GOLD)
	check.pressed.connect(run_check)
	field.text_submitted.connect(func(_text: String) -> void: run_check.call())


## "1234 kills   ·   23:52   ·   won   ·   Reaper" for a history entry or a
## decoded code.
func _daily_result(r: Dictionary) -> String:
	var secs: int = r.get("seconds", 0)
	return "%d kills   ·   %d:%02d   ·   %s   ·   %s" % [r.get("kills", 0), secs / 60, secs % 60,
			"won" if r.get("won", false) else "fell", HeroClass.data(r.get("class", "battlemage"))["name"]]


func _class_button(id: String) -> Button:
	var d := HeroClass.data(id)
	var unlocked := MetaProgress.class_unlocked(id)
	var picked := MetaProgress.hero_class == id
	var accent: Color = d["accent"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 48)
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
	card.custom_minimum_size = Vector2(330, 260)
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
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var night := _menu_label(14)
	night.text = "NIGHT %d   ·   %s" % [Realm.index(id) + 1, "◆".repeat(Realm.index(id) + 1) + "◇".repeat(2 - Realm.index(id))]
	night.modulate = Color(1, 1, 1, 0.55)
	col.add_child(night)
	var name_label := _menu_label(25)
	name_label.text = d["name"]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", accent.lightened(0.2) if unlocked else UiStyle.MUTED)
	col.add_child(name_label)
	var tag := _menu_label(15)
	tag.text = d["tagline"]
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.modulate = Color(1, 1, 1, 0.65)
	col.add_child(tag)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.3)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var desc := _menu_label(15)
	desc.text = d["rule"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)
	var boss := _menu_label(15)
	boss.text = "At dawn:  %s" % d["enemies"]["FinalBoss"]["label"]
	boss.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	col.add_child(boss)
	var status := _menu_label(16)
	if not unlocked:
		var prev: String = Realm.ORDER[Realm.index(id) - 1]
		status.text = "Locked · Conquer Night %d first" % Realm.index(id)
		card.tooltip_text = "Conquer %s to unlock this realm." % Realm.data(prev)["name"]
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
	var title := _menu_label(30)
	title.text = "THE CRYPT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Army.VETERAN_COLOR)
	_crypt_box.add_child(title)
	var hint := _menu_label(15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.text = "Minions that kill enough earn a name. After a night, your greatest veteran rests here.\nThe one you choose rises beside you when the next night begins. If it falls, it's gone for good."
	_crypt_box.add_child(hint)
	if MetaProgress.crypt.is_empty():
		var empty := _menu_label(17)
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
		var fallen := _menu_label(15)
		fallen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallen.modulate = Color(0.75, 0.75, 0.85)
		fallen.text = "\n".join(lines)
		_crypt_box.add_child(fallen)


func _new_campaign() -> void:
	if not CampaignSave.resumable():
		_open_campaign(true)
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "Replace expedition campaign?"
	confirm.dialog_text = "Start a fresh campaign with the selected hero? Current campaign equipment, Gold, talents and route progress will be replaced. Earned account rewards are retained."
	confirm.ok_button_text = "Start new campaign"
	confirm.confirmed.connect(func() -> void:
		confirm.queue_free()
		_open_campaign(true))
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered(Vector2i(580, 190))


func _open_campaign(new_campaign: bool) -> void:
	Sound.play("ui_click")
	CampaignShell.new_requested = new_campaign
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")
