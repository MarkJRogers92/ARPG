class_name TitleScreen
extends CanvasLayer
## Quiet opening navigation, with separate adventure preparation and progression
## pages. The backdrop and campaign thumbnail render the real scene;
## main.gd listens to `previewed`. Existing progression and save flows are reused.

signal previewed(realm_id: String)
signal chosen(realm_id: String)
## Resume the suspended night (RunSave's data).
signal resume_requested(data: Dictionary)

const GAME_TITLE := "Soulbound"
const CampaignMenuStyle = preload("res://scripts/campaign/campaign_menu_style.gd")

var _root: Control
var _home: Control
var _selection_page: Control
var _progress_page: Control
var _selection_mode := "classic"
var _heroes: HBoxContainer
var _realm_row: HBoxContainer
var _classic_row: HBoxContainer
var _campaign_panel: Control
var _selection_back: Button
var _home_buttons: Dictionary = {}
var _home_new: Button
var _home_classic: Button
var _home_settings: Button
var _home_wallet: Label
var _home_detail: PanelContainer
var _home_detail_title: Label
var _home_detail_text: Label
var _home_summary: Label
var _modal_return: Control
var _modal_page: Control
var _page_return: Control
var _transitioning := false
var _new_confirmation: ConfirmationDialog
var _title_camera: Camera3D
var _title_dressing: Node3D
var _title_hero: HeroModel
var _player_was_visible := true
var _title_realm := ""
var _game_camera: Camera3D
var _detail_viewport: SubViewport
var _detail_camera: Camera3D
var _home_selection := "continue"

var _altar_overlay: Control
var _altar: AltarPanel
## Focus priority: a suspended night, then a resumable campaign's Continue,
## then New Campaign preparation.
var _resume_night: Button
var _campaign_new: Button
var _first_realm: Button
var _class_desc: Label
var _class_heading: Label
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
	_transitioning = false
	_root.show()
	_show_home(false)
	_refresh_campaign_state()
	_ensure_title_camera()
	var target := _default_focus()
	if target:
		target.grab_focus.call_deferred()


## The button a keyboard player lands on: resuming beats starting fresh.
func _default_focus() -> Button:
	if is_instance_valid(_resume_night):
		return _resume_night
	if is_instance_valid(_campaign_continue) and CampaignSave.resumable():
		return _campaign_continue
	return _home_new


func close() -> void:
	_root.hide()
	if is_instance_valid(_title_camera): _title_camera.current = false
	if is_instance_valid(_game_camera): _game_camera.make_current()
	if is_instance_valid(_title_dressing): _title_dressing.hide()
	if is_instance_valid(_title_hero): _title_hero.hide()
	var player: Player = get_parent().get_node_or_null("Player")
	if player: player.visible = _player_was_visible


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(_new_confirmation) and _new_confirmation.visible: return
	for overlay in [_altar_overlay, _pact_overlay, _bestiary_overlay, _crypt_overlay, _relic_overlay, _daily_overlay]:
		if overlay and overlay.visible:
			_dismiss_overlay(overlay)
			get_viewport().set_input_as_handled()
			return
	if _selection_page.visible or _progress_page.visible:
		_show_home()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = CampaignMenuStyle.make_theme(UiStyle.theme())
	add_child(_root)
	var shade := ColorRect.new()
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://shaders/quiet_menu_shade.gdshader")
	shade.material = shade_material
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_selection_page = Control.new()
	_selection_page.name = "AdventureSelection"
	_selection_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_selection_page)
	var selection_shade := ColorRect.new()
	selection_shade.color = Color(0.035, 0.052, 0.07, 0.94)
	selection_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_page.add_child(selection_shade)
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 36)
	content_margin.add_theme_constant_override("margin_right", 36)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	_selection_page.add_child(content_margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	content_margin.add_child(column)

	var brand := HBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation", 30)
	column.add_child(brand)
	var title := UiStyle.heading(64)
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.045, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	brand.add_child(title)
	var tagline := _menu_label(18)
	tagline.text = "Survive the night.\nBind the dead. Greet the dawn."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tagline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	brand.add_child(tagline)
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
			_resume_saved_night(saved))
		brand.add_child(resume)
		_resume_night = resume

	# Heroes: pick one, or buy one with Soul Shards.
	var heroes := HBoxContainer.new()
	_heroes = heroes
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 12)
	column.add_child(heroes)
	for id: String in HeroClass.ORDER:
		heroes.add_child(_class_button(id))
	# Preparation is one scan row: hero/loadout left, campaign actions right.
	var preparation := HBoxContainer.new()
	preparation.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preparation.add_theme_constant_override("separation", 16)
	column.add_child(preparation)
	var hero_panel := PanelContainer.new()
	hero_panel.add_theme_stylebox_override("panel", CampaignMenuStyle.card_box(Color("11191f"), Color("504b40"), 1, 5, 12))
	preparation.add_child(hero_panel)
	var hero_stack := VBoxContainer.new()
	hero_stack.custom_minimum_size.x = 644
	hero_stack.add_theme_constant_override("separation", 8)
	hero_panel.add_child(hero_stack)
	var hero_header := HBoxContainer.new()
	hero_header.add_theme_constant_override("separation", 12)
	hero_stack.add_child(hero_header)
	_class_heading = UiStyle.heading(22)
	_class_heading.add_theme_color_override("font_color", UiStyle.GOLD)
	hero_header.add_child(_class_heading)
	var hero_spacer := Control.new()
	hero_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_header.add_child(hero_spacer)
	var description_scroll := ScrollContainer.new()
	description_scroll.name = "HeroDescriptionScroll"
	description_scroll.custom_minimum_size = Vector2(644, 108)
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	description_scroll.follow_focus = true
	description_scroll.focus_mode = Control.FOCUS_ALL
	description_scroll.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			description_scroll.scroll_vertical += 28 if event.is_action_pressed("ui_down") else -28
			description_scroll.accept_event())
	hero_stack.add_child(description_scroll)
	_class_desc = _menu_label(16)
	_class_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_desc.custom_minimum_size.x = 644
	description_scroll.add_child(_class_desc)
	_show_class_details(MetaProgress.hero_class)
	_relic_button = Button.new()
	_relic_button.custom_minimum_size = Vector2(360, 42)
	_relic_button.clip_text = true
	_relic_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_relic_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_relic_button.add_theme_color_override("font_color", Color(0.89, 0.81, 1.0))
	_relic_button.tooltip_text = "Relics, a starting weapon and lost lore, bought with Soul Shards and Bestiary stars."
	_relic_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_reliquary()
		_open_overlay(_relic_overlay))
	hero_header.add_child(_relic_button)
	_refresh_relic_button()

	var campaign_panel := PanelContainer.new()
	_campaign_panel = campaign_panel
	campaign_panel.add_theme_stylebox_override("panel", CampaignMenuStyle.card_box(Color("171a1d"), Color("75654b"), 1, 5, 12))
	preparation.add_child(campaign_panel)
	var campaign_stack := VBoxContainer.new()
	campaign_stack.custom_minimum_size.x = 420
	campaign_stack.add_theme_constant_override("separation", 6)
	campaign_panel.add_child(campaign_stack)
	var campaign_heading := UiStyle.heading(22)
	campaign_heading.text = "The campaign"
	campaign_heading.add_theme_color_override("font_color", UiStyle.GOLD)
	campaign_stack.add_child(campaign_heading)
	var campaigns := HBoxContainer.new()
	campaigns.alignment = BoxContainer.ALIGNMENT_CENTER
	campaigns.add_theme_constant_override("separation", 8)
	campaign_stack.add_child(campaigns)
	var campaign_new := Button.new()
	_campaign_new = campaign_new
	campaign_new.text = "New Campaign"
	campaign_new.custom_minimum_size = Vector2(206, 42)
	campaign_new.add_theme_stylebox_override("normal", CampaignMenuStyle.quiet_box())
	campaign_new.tooltip_text = "A persistent adventurer across three realms. Short expeditions, town services, and biome bosses."
	campaign_new.pressed.connect(_new_campaign)
	campaigns.add_child(campaign_new)
	_campaign_continue = Button.new()
	_campaign_continue.text = "Continue Campaign"
	_campaign_continue.custom_minimum_size = Vector2(206, 42)
	_campaign_continue.disabled = not CampaignSave.resumable()
	_campaign_continue.add_theme_stylebox_override("normal", CampaignMenuStyle.primary_box())
	_campaign_continue.add_theme_stylebox_override("hover", CampaignMenuStyle.button_box(Color("715a30"), CampaignMenuStyle.SOUL, 1))
	_campaign_continue.add_theme_stylebox_override("focus", CampaignMenuStyle.button_box(Color("273844"), CampaignMenuStyle.SOUL, 2))
	_campaign_continue.tooltip_text = "Town and results are saved. An active expedition restarts from its departure checkpoint."
	_campaign_continue.pressed.connect(func() -> void: _open_campaign(false))
	campaigns.add_child(_campaign_continue)
	_campaign_summary = _menu_label(14)
	_campaign_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_campaign_summary.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	campaign_stack.add_child(_campaign_summary)
	_refresh_campaign_state()
	var classic_row := HBoxContainer.new()
	_classic_row = classic_row
	classic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	classic_row.add_theme_constant_override("separation", 16)
	column.add_child(classic_row)
	var classic_label := UiStyle.heading(22)
	classic_label.text = "Classic Night"
	classic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classic_label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	classic_row.add_child(classic_label)
	var classic_hint := _menu_label(15)
	classic_hint.text = "Choose a realm for a single night"
	classic_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classic_hint.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	classic_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	classic_row.add_child(classic_hint)
	# Tonight's real moon shares the Classic row (a row of its own pushes Back
	# off short screens); the full effect is in the tooltip.
	var moon := MoonPhase.phase_for(Time.get_unix_time_from_system())
	var moon_glyph := MoonGlyph.new()
	moon_glyph.age = MoonPhase.age_days(Time.get_unix_time_from_system())
	moon_glyph.tint = MoonPhase.PHASES[moon]["color"]
	moon_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moon_glyph.tooltip_text = MoonPhase.title(moon)
	classic_row.add_child(moon_glyph)
	var moon_label := _menu_label(15)
	moon_label.text = MoonPhase.PHASES[moon]["name"]
	moon_label.tooltip_text = MoonPhase.title(moon)
	moon_label.mouse_filter = Control.MOUSE_FILTER_PASS
	moon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	moon_label.add_theme_color_override("font_color", MoonPhase.PHASES[moon]["color"])
	classic_row.add_child(moon_label)
	var row := HBoxContainer.new()
	_realm_row = row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for id: String in Realm.ORDER:
		var card := _realm_card(id)
		row.add_child(card)
		if _first_realm == null and not card.disabled:
			_first_realm = card

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
		_open_overlay(_altar_overlay))
	bottom.add_child(altar_button)
	_pact_button = Button.new()
	_pact_button.custom_minimum_size = Vector2(235, 46)
	_pact_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_pact_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_pacts()
		_open_overlay(_pact_overlay))
	bottom.add_child(_pact_button)
	var bestiary_button := Button.new()
	bestiary_button.text = "Bestiary   ·   %d ★" % MetaProgress.total_stars()
	bestiary_button.custom_minimum_size = Vector2(180, 46)
	bestiary_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_bestiary()
		_open_overlay(_bestiary_overlay))
	bottom.add_child(bestiary_button)
	var crypt_button := Button.new()
	crypt_button.text = "The Crypt   ·   %d" % MetaProgress.crypt.size()
	crypt_button.tooltip_text = "Veterans of past nights. Choose one to rise beside you."
	crypt_button.custom_minimum_size = Vector2(170, 46)
	crypt_button.add_theme_color_override("font_color", Army.VETERAN_COLOR)
	crypt_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_crypt()
		_open_overlay(_crypt_overlay))
	bottom.add_child(crypt_button)
	var daily_button := Button.new()
	daily_button.text = "Daily Night"
	daily_button.tooltip_text = "Today's realm, omen and seed are the same for every run today. Beat your best kill count, and share the code."
	daily_button.custom_minimum_size = Vector2(150, 46)
	daily_button.add_theme_color_override("font_color", UiStyle.GOLD)
	daily_button.pressed.connect(func() -> void:
		Sound.play("ui_click")
		_fill_daily()
		_open_overlay(_daily_overlay))
	bottom.add_child(daily_button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(100, 46)
	quit.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit)

	_progress_page = Control.new()
	_progress_page.name = "Sanctum"
	_progress_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_progress_page)
	var progress_shade := ColorRect.new()
	progress_shade.color = Color(0.035, 0.052, 0.07, 0.96)
	progress_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_progress_page.add_child(progress_shade)
	var progress_center := CenterContainer.new()
	progress_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_progress_page.add_child(progress_center)
	var progress_stack := VBoxContainer.new()
	progress_stack.add_theme_constant_override("separation", 24)
	progress_center.add_child(progress_stack)
	var progress_title := UiStyle.heading(44)
	progress_title.text = "The Sanctum"
	progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_stack.add_child(progress_title)
	var progress_copy := _menu_label(18)
	progress_copy.text = "Lasting gifts, the dead you remember, and challenges for the next night."
	progress_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_stack.add_child(progress_copy)
	bottom.reparent(progress_stack)
	var progress_back := Button.new()
	progress_back.text = "Back"
	progress_back.custom_minimum_size = Vector2(180, 44)
	progress_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	progress_back.pressed.connect(_show_home)
	progress_stack.add_child(progress_back)
	_selection_back = Button.new()
	_selection_back.text = "Back"
	_selection_back.custom_minimum_size = Vector2(180, 44)
	_selection_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_selection_back.pressed.connect(_show_home)
	column.add_child(_selection_back)

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
	var relic_scroll := ScrollContainer.new()
	relic_scroll.name = "ReliquaryScroll"
	relic_scroll.custom_minimum_size = Vector2(980, 500)
	relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	relic_scroll.follow_focus = true
	(_relic_overlay.get_meta("box") as VBoxContainer).add_child(relic_scroll)
	_relic_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_scroll.add_child(_relic_box)
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
		_dismiss_overlay(_altar_overlay)
		altar_button.text = "Altar of Souls   ·   %d ◆" % MetaProgress.shards)
	altar_box.add_child(back)
	_build_home()
	_selection_page.hide()
	_progress_page.hide()


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
		_dismiss_overlay(overlay))
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
	_relic_button.tooltip_text = _relic_button.text + "\nRelics, a starting weapon and lost lore, bought with Soul Shards and Bestiary stars."


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
	if is_instance_valid(_home_summary):
		_home_summary.text = _campaign_summary.text
		_update_home_detail(_home_selection)
		_refresh_wallet()


func _menu_label(font_size: int) -> Label:
	var label := UiStyle.label(font_size)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", CampaignMenuStyle.TEXT)
	return label


## Relics on the left; starting weapons and lost lore on the right. Rebuilt
## after every purchase or pick.
func _fill_reliquary() -> void:
	for child in _relic_box.get_children():
		_relic_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.heading(30)
	title.text = "RELIQUARY   ·   %d ◆   ·   %d ★" % [MetaProgress.shards, MetaProgress.total_stars()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_relic_box.add_child(title)
	var goal := _menu_label(14)
	goal.text = NextGoals.suggested()
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_relic_box.add_child(goal)
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
		var description := str(d["desc"])
		if d.has("trial"):
			description += "\nUnlock: " + Relics.price_text(id) + "."
			if not owned: action = "Locked"
		var can: bool = owned or (not d.has("stars") and MetaProgress.shards >= d["cost"])
		left.add_child(_pick_row(d["name"], description, MetaProgress.relic == id, action, can, func() -> void:
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

	right.add_child(_heading("OPTIONAL STARTING PACKAGES"))
	for id: String in Relics.PACKAGES:
		var package: Dictionary = Relics.PACKAGES[id]
		var owned := MetaProgress.package_owned(id)
		var picked: bool = MetaProgress.relic == package["relic"] and MetaProgress.start_weapon == package["weapon"]
		right.add_child(_pick_row(package["name"], "Uses your relic and weapon slots: %s + %s. Requires owned relic (stars or trial clear) and starting weapon." % [Relics.DEFS[package["relic"]]["name"], Upgrades.DEFS[package["weapon"]]["name"]], picked, "Use kit" if owned else "Locked", owned, func() -> void: MetaProgress.pick_package(id)))
	right.add_child(_heading("TACTIC CONTRACT UNLOCKS"))
	for choice: Dictionary in NextGoals.choice_rows():
		if not str(choice["scope"]).begins_with("Account unlock"): continue
		var row := _menu_label(13)
		row.text = "%s · %d/%d stars · %s\nAvailable on a new campaign's roads; fixed kit, 3:00 target / 4:00 deadline." % [choice["name"], mini(choice["progress"], choice["target"]), choice["target"], "Owned" if choice["owned"] else "Locked"]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(row)
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
		_pact_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.heading(30)
	title.text = "Pact of Night"
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
		_daily_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.heading(30)
	title.text = "Daily Night"
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
		_start_classic(pick["realm"], true))
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
	b.custom_minimum_size = Vector2(217, 48)
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
		if not _selection_page.visible or _transitioning: return
		if MetaProgress.unlock_class(id):
			MetaProgress.select_class(id)
			_refresh_heroes()
			_show_class_details(id)
			_preview_hero(id)
			_heroes.get_child(HeroClass.ORDER.find(id)).grab_focus.call_deferred())
	for signal_name in ["mouse_entered", "focus_entered"]:
		b.connect(signal_name, func() -> void:
			_show_class_details(id))
	return b


func _show_class_details(id: String) -> void:
	var data := HeroClass.data(id)
	_class_heading.text = data["name"]
	(_class_desc.get_parent() as ScrollContainer).scroll_vertical = 0
	_class_desc.text = data["desc"] + "\n" + HeroClass.SIGNATURES[id] + ("" if MetaProgress.class_unlocked(id) else "   (unlock for %d Soul Shards)" % data["cost"])


func _realm_card(id: String) -> Button:
	var d := Realm.data(id)
	var accent: Color = d["accent"]
	var unlocked := MetaProgress.is_unlocked(id)
	var won := MetaProgress.is_won(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(368, 280)
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
		_start_classic(id, false))
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
	night.text = "Night %d   ·   %s" % [Realm.index(id) + 1, "◆".repeat(Realm.index(id) + 1) + "◇".repeat(2 - Realm.index(id))]
	night.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	col.add_child(night)
	var name_label := UiStyle.heading(26)
	name_label.text = d["name"]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", accent.lightened(0.2) if unlocked else UiStyle.MUTED)
	col.add_child(name_label)
	var tag := _menu_label(15)
	tag.text = d["tagline"]
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	col.add_child(tag)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.3)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var desc := _menu_label(16)
	desc.text = d["rule"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)
	var boss := _menu_label(15)
	boss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss.text = "At dawn:  %s" % d["enemies"]["FinalBoss"]["label"]
	boss.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	col.add_child(boss)
	var status := _menu_label(15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not unlocked:
		var prev: String = Realm.ORDER[Realm.index(id) - 1]
		status.text = "Locked · Conquer Night %d first" % Realm.index(id)
		card.tooltip_text = "Conquer %s to unlock this realm." % Realm.data(prev)["name"]
		status.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
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
		_crypt_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.heading(30)
	title.text = "The Crypt"
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
	if _transitioning or not _selection_page.visible or _selection_mode != "campaign": return
	if is_instance_valid(_new_confirmation):
		_new_confirmation.grab_focus()
		return
	if not CampaignSave.resumable():
		_open_campaign(true)
		return
	var confirm := ConfirmationDialog.new()
	_new_confirmation = confirm
	confirm.title = "Replace expedition campaign?"
	confirm.dialog_text = "Start a fresh campaign with the selected hero? Current campaign equipment, Gold, talents and route progress will be replaced. Earned account rewards are retained."
	confirm.ok_button_text = "Start new campaign"
	confirm.confirmed.connect(func() -> void:
		confirm.queue_free()
		_open_campaign(true))
	confirm.canceled.connect(func() -> void:
		confirm.queue_free()
		_new_confirmation = null
		_campaign_new.grab_focus.call_deferred())
	add_child(confirm)
	confirm.popup_centered(Vector2i(580, 190))


func _open_campaign(new_campaign: bool) -> void:
	if _transitioning: return
	if not new_campaign and not _home.visible: return
	_transitioning = true
	Sound.play("ui_click")
	CampaignShell.new_requested = new_campaign
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")


# Quiet Fantasy opening composition. Every label remains a real control.
func _build_home() -> void:
	_home = Control.new()
	_home.name = "QuietFantasyHome"
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_home)
	var logo := UiStyle.heading(76)
	logo.name = "SoulboundLogo"
	logo.text = GAME_TITLE.to_upper()
	logo.position = Vector2(76, 72)
	logo.add_theme_color_override("font_color", Color("eee9dc"))
	_home.add_child(logo)
	var logo_line := ColorRect.new()
	logo_line.color = Color("b9a883", 0.55)
	logo_line.position = Vector2(80, 184)
	logo_line.size = Vector2(450, 1)
	_home.add_child(logo_line)
	var nav := VBoxContainer.new()
	nav.name = "HomeNavigation"
	nav.position = Vector2(76, 226)
	nav.custom_minimum_size.x = 390
	nav.add_theme_constant_override("separation", 4)
	_home.add_child(nav)
	if is_instance_valid(_resume_night):
		_resume_night.reparent(nav)
		_resume_night.text = "Resume the night"
		_home_buttons["resume"] = _resume_night
		_style_nav(_resume_night)
		_resume_night.focus_entered.connect(_update_home_detail.bind("resume"))
		_resume_night.mouse_entered.connect(_update_home_detail.bind("resume"))
	_campaign_continue.reparent(nav)
	_home_buttons["continue"] = _campaign_continue
	_style_nav(_campaign_continue)
	_campaign_continue.focus_entered.connect(_update_home_detail.bind("continue"))
	_campaign_continue.mouse_entered.connect(_update_home_detail.bind("continue"))
	_home_new = _home_nav(nav, "new", "New Campaign", _show_selection.bind("campaign"))
	_home_classic = _home_nav(nav, "classic", "Classic Night", _show_selection.bind("classic"))
	_home_nav(nav, "crypt", "The Crypt", func() -> void:
		_fill_crypt(); _open_overlay(_crypt_overlay))
	_home_settings = _home_nav(nav, "settings", "Settings", _open_title_settings)
	_home_nav(nav, "quit", "Quit", func() -> void: get_tree().quit())
	var space := Control.new()
	space.custom_minimum_size.y = 8
	nav.add_child(space)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 14)
	nav.add_child(secondary)
	var sanctum := Button.new()
	sanctum.name = "OpenSanctum"
	sanctum.text = "The Sanctum"
	sanctum.tooltip_text = "Altar of Souls, Bestiary, Pact of Night, veterans and Daily Night."
	sanctum.custom_minimum_size = Vector2(180, 38)
	sanctum.pressed.connect(_show_progression)
	secondary.add_child(sanctum)
	_style_secondary(sanctum)
	var daily := Button.new()
	daily.name = "OpenDailyNight"
	daily.text = "Daily Night"
	daily.custom_minimum_size = Vector2(150, 38)
	daily.pressed.connect(func() -> void: _fill_daily(); _open_overlay(_daily_overlay))
	secondary.add_child(daily)
	_style_secondary(daily)
	var rule := ColorRect.new()
	rule.color = Color("b9a883", 0.45)
	rule.custom_minimum_size = Vector2(390, 1)
	nav.add_child(rule)
	_home_wallet = _menu_label(17)
	_home_wallet.add_theme_color_override("font_color", Color("b9a883"))
	nav.add_child(_home_wallet)
	_home_detail = PanelContainer.new()
	_home_detail.name = "CampaignDetail"
	_home_detail.position = Vector2(492, 232)
	_home_detail.custom_minimum_size = Vector2(326, 0)
	_home_detail.add_theme_stylebox_override("panel", CampaignMenuStyle.card_box(Color(0.035, 0.055, 0.077, 0.94), Color("83765c"), 1, 0, 12))
	_home.add_child(_home_detail)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 300
	detail.add_theme_constant_override("separation", 8)
	_home_detail.add_child(detail)
	_detail_viewport = SubViewport.new()
	_detail_viewport.size = Vector2i(600, 240)
	_detail_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_detail_viewport.world_3d = get_viewport().world_3d
	add_child(_detail_viewport)
	_detail_camera = Camera3D.new()
	_detail_camera.fov = 50
	_detail_viewport.add_child(_detail_camera)
	_detail_camera.make_current()
	var scene_image := TextureRect.new()
	scene_image.texture = _detail_viewport.get_texture()
	scene_image.custom_minimum_size = Vector2(300, 120)
	scene_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	detail.add_child(scene_image)
	_home_detail_title = UiStyle.heading(24)
	_home_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_detail_title.add_theme_color_override("font_color", Color("eee9dc"))
	detail.add_child(_home_detail_title)
	_home_detail_text = _menu_label(17)
	_home_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_home_detail_text)
	_home_summary = _menu_label(15)
	_home_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_summary.add_theme_color_override("font_color", CampaignMenuStyle.MUTED)
	detail.add_child(_home_summary)
	_update_home_detail("continue" if not _campaign_continue.disabled else "new")
	_refresh_wallet()


func _home_nav(parent: Control, id: String, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.name = "Home_" + id
	b.text = text
	_style_nav(b)
	parent.add_child(b)
	_home_buttons[id] = b
	b.set_meta("caption", text)
	b.pressed.connect(func() -> void:
		if _transitioning or not _home.visible: return
		Sound.play("ui_click"); callback.call())
	b.focus_entered.connect(_update_home_detail.bind(id))
	b.mouse_entered.connect(_update_home_detail.bind(id))
	return b


func _style_nav(button: Button) -> void:
	button.set_meta("caption", button.text)
	button.custom_minimum_size = Vector2(390, 48)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_override("font", UiStyle.HEADING)
	button.add_theme_font_size_override("font_size", 24)
	button.icon = preload("res://assets/menu/diamond.svg")
	button.add_theme_constant_override("h_separation", 16)
	button.add_theme_color_override("font_color", Color("eee9dc"))
	button.add_theme_color_override("font_disabled_color", Color("879398"))
	button.add_theme_color_override("font_hover_color", Color("e4cf9d"))
	button.add_theme_color_override("font_focus_color", Color("e4cf9d"))
	var normal := CampaignMenuStyle.card_box(Color(0.03, 0.05, 0.07, 0.2), Color("b9a883", 0.22), 0, 0, 10)
	normal.border_width_bottom = 1
	var selected := CampaignMenuStyle.card_box(Color(0.1, 0.15, 0.19, 0.88), Color("b9a883"), 1, 0, 10)
	for state: String in ["normal", "disabled"]: button.add_theme_stylebox_override(state, normal)
	for state: String in ["hover", "pressed", "hover_pressed", "focus"]: button.add_theme_stylebox_override(state, selected)


func _update_home_detail(id: String) -> void:
	if not is_instance_valid(_home_detail_title): return
	_home_selection = id
	for key: String in _home_buttons:
		var b: Button = _home_buttons[key]
		b.text = str(b.get_meta("caption"))
		b.icon = preload("res://assets/menu/diamond_selected.svg") if key == id else preload("res://assets/menu/diamond.svg")
	var data := CampaignSave.read()
	var biome := clampi(int(data.get("biome_index", 0)), 0, Realm.ORDER.size() - 1)
	var realm_id: String = Realm.ORDER[biome]
	if id == "continue" and not data.is_empty():
		_home_detail_title.text = Realm.data(realm_id)["name"]
		_home_detail_text.text = "Night %d · %s" % [biome + 1, HeroClass.data(str(data.get("hero_class", "battlemage")))["name"]]
		_home_summary.text = _campaign_summary.text
		previewed.emit(realm_id)
		_dress_background(realm_id)
		_preview_hero(str(data.get("hero_class", "battlemage")))
	elif id == "resume":
		var saved := RunSave.read()
		_home_detail_title.text = "The unfinished night"
		_home_detail_text.text = RunSave.describe(saved)
		_home_summary.text = "Resume this night once, with your saved hero, gear and army."
		previewed.emit(str(saved.get("realm", "graveyard")))
		_dress_background(str(saved.get("realm", "graveyard")))
		_preview_hero(str(saved.get("hero_class", "battlemage")))
	else:
		var copy := {
			"continue": ["Campaign recovery", "Your saved campaign needs recovery.", "Continue to review the preserved save files."],
			"new": ["Begin a journey", "Three realms. One persistent adventurer.", "Choose your hero and loadout before starting a campaign."],
			"classic": ["Survive the night", "A single night, from dusk to dawn.", "Choose your hero, loadout and realm on the next screen."],
			"crypt": ["The Crypt", "The dead you remember.", "Choose a veteran to rise beside you on the next Classic night."],
			"settings": ["Make the night yours", "Sound, comfort and controls.", "Adjust volumes, effects, aiming and key bindings."],
			"quit": ["Until the next night", "Your saved progress stays here.", "An unfinished expedition resumes from its saved checkpoint."],
		}
		var entry: Array = copy.get(id, copy["new"])
		_home_detail_title.text = entry[0]; _home_detail_text.text = entry[1]; _home_summary.text = entry[2]
	_refresh_wallet()


func _refresh_wallet() -> void:
	if not is_instance_valid(_home_wallet): return
	var data := CampaignSave.read()
	_home_wallet.text = "%d Gold · %d Soul Shards" % [int(data.get("gold", 0)), MetaProgress.shards]


func _show_home(focus := true) -> void:
	_selection_page.hide(); _progress_page.hide(); _home.show()
	_refresh_campaign_state()
	if focus:
		if is_instance_valid(_page_return) and _page_return.is_visible_in_tree(): _page_return.grab_focus.call_deferred()
		else: _default_focus().grab_focus.call_deferred()


func _show_selection(mode: String) -> void:
	if _transitioning: return
	_page_return = _home_new if mode == "campaign" else _home_classic
	_selection_mode = mode
	_home.hide(); _progress_page.hide(); _selection_page.show()
	_realm_row.visible = mode == "classic"
	_classic_row.visible = mode == "classic"
	_campaign_panel.visible = mode == "campaign"
	_refresh_heroes()
	_show_class_details(MetaProgress.hero_class)
	_preview_hero(MetaProgress.hero_class)
	if mode == "campaign": _campaign_new.grab_focus.call_deferred()
	else: _heroes.get_child(0).grab_focus.call_deferred()


func _show_progression() -> void:
	if _transitioning: return
	_page_return = _home.find_child("OpenSanctum", true, false)
	_home.hide(); _selection_page.hide(); _progress_page.show()
	_refresh_pact_button()
	var buttons := _progress_page.find_children("*", "Button", true, false)
	for b: Button in buttons:
		if not b.disabled: b.grab_focus.call_deferred(); break


func _refresh_heroes() -> void:
	for child in _heroes.get_children():
		_heroes.remove_child(child); child.queue_free()
	for id: String in HeroClass.ORDER: _heroes.add_child(_class_button(id))


func _open_overlay(overlay: Control) -> void:
	if _transitioning: return
	_modal_return = get_viewport().gui_get_focus_owner()
	for page: Control in [_home, _selection_page, _progress_page]:
		if page.visible: _modal_page = page
		page.hide()
	for view: Control in [_altar_overlay, _pact_overlay, _bestiary_overlay, _crypt_overlay, _relic_overlay, _daily_overlay]: view.hide()
	overlay.show()
	_root.move_child(overlay, _root.get_child_count() - 1)
	var back := _find_back(overlay)
	if back: back.grab_focus.call_deferred()


func _find_back(node: Node) -> Button:
	if node is Button and (node as Button).text == "Back": return node
	for child in node.get_children():
		var found := _find_back(child)
		if found: return found
	return null


func _dismiss_overlay(overlay: Control) -> void:
	overlay.hide(); _refresh_pact_button(); _refresh_wallet()
	if is_instance_valid(_modal_page): _modal_page.show()
	if is_instance_valid(_modal_return) and _modal_return.is_visible_in_tree(): _modal_return.grab_focus.call_deferred()


func _open_title_settings() -> void:
	var pause: PauseMenu = get_parent().get("_pause")
	if pause == null or pause.is_open(): return
	_root.hide()
	get_tree().paused = true
	if not pause.resumed.is_connected(_settings_closed): pause.resumed.connect(_settings_closed)
	pause.open(true)


func _settings_closed() -> void:
	var pause: PauseMenu = get_parent().get("_pause")
	if pause and pause.resumed.is_connected(_settings_closed): pause.resumed.disconnect(_settings_closed)
	get_tree().paused = false
	_root.show(); _show_home(false)
	_home_settings.grab_focus.call_deferred()


func _resume_saved_night(saved: Dictionary) -> void:
	if _transitioning or not _home.visible: return
	_transitioning = true
	Sound.play("ui_click"); resume_requested.emit(saved)


func _start_classic(id: String, daily: bool) -> void:
	if _transitioning: return
	if not daily and (not _selection_page.visible or _selection_mode != "classic"): return
	if daily and not _daily_overlay.visible: return
	_transitioning = true
	Realm.daily = daily
	Sound.play("ui_click"); chosen.emit(id)


func _ensure_title_camera() -> void:
	if not is_instance_valid(_title_camera):
		_game_camera = get_parent().get_node_or_null("CameraRig/Camera3D")
		_title_camera = Camera3D.new()
		_title_camera.fov = 50
		_title_camera.far = 150
		add_child(_title_camera)
	_title_camera.position = Vector3(5, 3.7, 8)
	_title_camera.look_at_from_position(_title_camera.position, Vector3(-7, 1, -1))
	_title_camera.make_current()
	if not is_instance_valid(_title_hero): _preview_hero(MetaProgress.hero_class)
	_dress_background(_title_realm if _title_realm != "" else Realm.current)
	if _detail_camera:
		_detail_camera.look_at_from_position(Vector3(9, 6, 12), Vector3(1, 1, -2))


func _preview_hero(id: String) -> void:
	var player: Player = get_parent().get_node_or_null("Player")
	if player == null: return
	if not is_instance_valid(_title_hero):
		_player_was_visible = player.visible
		_title_hero = HeroModel.new()
		_title_hero.name = "TitleHeroPreview"
		_title_hero.scale = Vector3.ONE * 1.2
		add_child(_title_hero)
	# A visual-only duplicate keeps combat markers and gameplay state out of
	# the menu composition. The original player visibility returns on close.
	player.hide()
	_title_hero.show()
	var data := HeroClass.data(id)
	_title_hero.set_body(data["look"])
	_title_hero.set_weapon(data["weapon"], data["accent"])


func _style_secondary(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("c3c5bb"))
	button.add_theme_stylebox_override("normal", CampaignMenuStyle.card_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4))
	button.add_theme_stylebox_override("focus", CampaignMenuStyle.card_box(Color(0.06,0.09,0.12,0.8), Color("b9a883"), 1, 0, 4))


## Menu-only staging from already shipped meshes. No colliders or gameplay
## records are created; the dressing hides with the title and dies with it.
func _dress_background(realm_id: String) -> void:
	if not Realm.in_title: return
	if _title_realm == realm_id and is_instance_valid(_title_dressing):
		_title_dressing.show(); return
	_title_realm = realm_id
	if is_instance_valid(_title_dressing): _title_dressing.free()
	_title_dressing = Node3D.new()
	_title_dressing.name = "TitleScenery"
	add_child(_title_dressing)
	var kinds: Array = {
		"graveyard": ["broken_archway", "ruined_pillar", "soul_brazier"],
		"frozen": ["watchtower", "frosted_pine", "ice_arch"],
		"ember": ["basalt_columns", "ashen_tree", "brimstone_vent"],
	}.get(realm_id, ["broken_archway", "ruined_pillar", "soul_brazier"])
	var positions := [Vector3(5,0,-5), Vector3(-4,0,-6), Vector3(2,0,-3)]
	for i in kinds.size():
		var prop := MeshInstance3D.new()
		prop.mesh = AssetProps.mesh(kinds[i])
		prop.position = positions[i]
		_title_dressing.add_child(prop)
