class_name Hud
extends CanvasLayer
## HUD, level-up cards and game-over screen. The UI is built in code to keep
## the scene file small; restyle it freely or swap in a hand-made scene.

signal upgrade_chosen(id: String)
signal restart_pressed
signal reroll_requested
signal realms_pressed
signal endless_pressed

## Card colors by upgrade: a skill tree branch name, or a color of its own.
const CARD_COLORS := {
	"bolt_damage": "offense", "bolt_rate": "offense", "bolt_count": "offense", "bolt_pierce": "offense",
	"aura": "aura", "max_hp": "defense", "regen": "defense", "heal": "defense",
	"move_speed": "utility", "magnet": "utility",
	"lightning": Color(0.72, 0.6, 1.0), "orbit": Color(0.45, 1.0, 0.85), "nova": Color(1.0, 0.5, 0.9),
	"legion": Color(0.45, 0.8, 1.0), "harvest": Color(0.45, 0.8, 1.0),
	"ignite": Color(1.0, 0.5, 0.15), "frostbite": Color(0.55, 0.85, 1.0),
}

var _hp_bar: ProgressBar
var _hp_text: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _skill_label: Label
var _time_label: Label
var _kills_label: Label
var _debug_label: Label
var _toasts: VBoxContainer
var _vignette: ColorRect
var _upgrade_root: Control
var _upgrade_row: HBoxContainer
var _upgrade_ids: Array[String] = []
var _game_over_root: Control
var _game_over_label: Label
var _hurt := 0.0
var _low_hp := 0.0
var _reroll_button: Button
var _shards_label: Label
var _dash_bar: ProgressBar
var _dash_label: Label
var _boss_box: Control
var _boss_label: Label
var _boss_bar: ProgressBar
var _shards_earned_label: Label
var _altar: AltarPanel
var _end_title: Label
var _endless_button: Button
var _restart_button: Button
var _clock_text := ""
var _clock_color := Color(0.95, 0.93, 0.88)
var _soul_bar: ProgressBar
var _soul_label: Label


func _ready() -> void:
	# The menu has to keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()


## Refresh the always-on display. Cheap enough to call every frame.
func refresh(stats: PlayerStats, elapsed: float, kills: int, enemies: int, skill_points := 0) -> void:
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_hp_text.text = "%d / %d" % [ceili(stats.hp), roundi(stats.max_hp)]
	_xp_bar.max_value = stats.xp_to_next
	_xp_bar.value = stats.xp
	_level_label.text = str(stats.level)
	_skill_label.visible = skill_points > 0
	_skill_label.text = "%d skill point%s  [K]" % [skill_points, "" if skill_points == 1 else "s"]
	_time_label.text = _clock_text if _clock_text != "" else _format_time(elapsed)
	_time_label.add_theme_color_override("font_color", _clock_color)
	_kills_label.text = "%d" % kills
	_debug_label.text = "%d FPS   %d enemies   [Tab] inventory   [K] skills   [T] aim   [F11] fullscreen" % [Engine.get_frames_per_second(), enemies]
	_low_hp = clampf(1.0 - stats.hp / maxf(stats.max_hp, 1.0) * 3.0, 0.0, 1.0)


## Reddens the screen edges while the hero is taking contact damage.
func set_hurt(hurting: bool, delta: float) -> void:
	_hurt = minf(_hurt + delta * 4.0, 1.0) if hurting else maxf(_hurt - delta * 2.0, 0.0)
	var pulse := _low_hp * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	(_vignette.material as ShaderMaterial).set_shader_parameter("hurt", maxf(_hurt * 0.6, pulse * 0.7))


## A short message that fades out, e.g. loot pickups. Newest at the bottom.
func toast(text: String, color := Color.WHITE) -> void:
	var label := UiStyle.label(18)
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toasts.add_child(label)
	while _toasts.get_child_count() > 6:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


## The bits of the HUD beyond the basics: Soul Shards found this run, the dash
## cooldown (0 = ready) and the boss health bar (`boss_health` < 0 hides it).
func refresh_extras(shards: int, dash_cooldown: float, boss_name: String, boss_health: float) -> void:
	_shards_label.text = str(shards)
	_dash_bar.value = 1.0 - dash_cooldown
	_dash_label.text = "DASH  [Space]" if dash_cooldown <= 0.0 else "DASH"
	_dash_label.modulate = Color(1, 1, 1, 0.9 if dash_cooldown <= 0.0 else 0.45)
	_boss_box.visible = boss_health >= 0.0
	if _boss_box.visible:
		_boss_label.text = boss_name
		_boss_bar.value = boss_health


## The Soul Army: souls toward the next minion, and how big the army is.
func refresh_army(souls: int, cost: int, minions: int, max_minions: int) -> void:
	_soul_bar.max_value = cost
	_soul_bar.value = souls
	_soul_label.text = "SOULS %d/%d   ARMY %d/%d" % [mini(souls, cost), cost, minions, max_minions]


## `rerolls` > 0 shows a button (and the R key) to roll new cards.
func show_upgrades(choices: Array[Dictionary], rerolls := 0) -> void:
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll  [R]   ·   %d left" % rerolls
	for child in _upgrade_row.get_children():
		child.queue_free()
	_upgrade_ids.clear()
	for i in choices.size():
		var choice := choices[i]
		_upgrade_ids.append(choice["id"])
		var card := _make_card(i, choice)
		_upgrade_row.add_child(card)
		# Deal the cards in one by one.
		card.modulate.a = 0.0
		card.scale = Vector2(0.85, 0.85)
		var tween := card.create_tween().set_parallel()
		tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.06 * i)
		tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(0.06 * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0:
			card.grab_focus.call_deferred()
	_upgrade_root.show()


## What the clock at the top says ("DAWN IN 12:34", "SLAY THE LICH KING"...).
## Empty shows the run time.
func set_clock(text: String, color := Color(0.95, 0.93, 0.88)) -> void:
	_clock_text = text
	_clock_color = color


func show_game_over(elapsed: float, kills: int, level: int, shards := 0) -> void:
	_show_end("YOU DIED", Color(0.85, 0.12, 0.1), "Survived %s     Level %d     Kills %d" % [_format_time(elapsed), level, kills],
			shards, false)


## The night is won: the realm's final boss is dead.
func show_victory(realm_name: String, elapsed: float, kills: int, level: int, shards: int) -> void:
	_show_end("DAWN BREAKS", Color(1.0, 0.82, 0.4), "%s is conquered.\nLevel %d     Kills %d     %s" % [
			realm_name, level, kills, _format_time(elapsed)], shards, true)


func _show_end(title: String, color: Color, line: String, shards: int, victory: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_game_over_label.text = line
	_shards_earned_label.text = "+%d Soul Shards this run" % shards
	_endless_button.visible = victory
	_restart_button.text = "Play again" if victory else "Rise again"
	_altar.refresh()
	_game_over_root.show()


func hide_end() -> void:
	_game_over_root.hide()


func _input(event: InputEvent) -> void:
	# Handled here because the HUD keeps running while the game is paused.
	if event.is_action_pressed("toggle_fullscreen"):
		var window := get_window()
		var full := window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		window.mode = Window.MODE_WINDOWED if full else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if not _upgrade_root.visible:
		return
	if event.is_action_pressed("reroll") and _reroll_button.visible:
		reroll_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var index := key.keycode - KEY_1
		if index >= 0 and index < _upgrade_ids.size():
			_choose(index)
			get_viewport().set_input_as_handled()


func _choose(index: int) -> void:
	_upgrade_root.hide()
	upgrade_chosen.emit(_upgrade_ids[index])


# --- building -------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = load("res://shaders/vignette.gdshader")
	_vignette.material = vignette_mat
	root.add_child(_vignette)

	# XP across the very top of the screen.
	_xp_bar = UiStyle.bar(Color(0.3, 0.75, 1.0), 8)
	_xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_left = 4
	_xp_bar.offset_right = -4
	_xp_bar.offset_top = 4
	_xp_bar.offset_bottom = 12
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_xp_bar)

	# Top left: level badge and health.
	var vitals := HBoxContainer.new()
	vitals.position = Vector2(14, 22)
	vitals.add_theme_constant_override("separation", 10)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vitals)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(54, 54)
	var badge_style := UiStyle.box(Color(0.08, 0.07, 0.06, 0.92), UiStyle.GOLD, 3, 27)
	badge_style.shadow_color = Color(1.0, 0.75, 0.3, 0.25)
	badge_style.shadow_size = 6
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(badge)
	_level_label = UiStyle.label(24)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_color", UiStyle.GOLD)
	badge.add_child(_level_label)

	var hp_column := VBoxContainer.new()
	hp_column.add_theme_constant_override("separation", 4)
	hp_column.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(hp_column)
	_hp_bar = UiStyle.bar(Color(0.78, 0.13, 0.15), 22)
	_hp_bar.custom_minimum_size.x = 280
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_column.add_child(_hp_bar)
	_hp_text = UiStyle.label(15)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_bar.add_child(_hp_text)
	_skill_label = UiStyle.label(16)
	_skill_label.add_theme_color_override("font_color", UiStyle.GOLD)
	_skill_label.visible = false
	hp_column.add_child(_skill_label)

	# Top center: the run timer.
	_time_label = UiStyle.label(30)
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_time_label.offset_top = 18
	_time_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	root.add_child(_time_label)

	# Top right: kills.
	var kills_row := HBoxContainer.new()
	kills_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kills_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kills_row.offset_right = -16
	kills_row.offset_top = 22
	kills_row.add_theme_constant_override("separation", 8)
	kills_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kills_row)
	var skull := _SkullIcon.new()
	skull.custom_minimum_size = Vector2(26, 26)
	skull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kills_row.add_child(skull)
	_kills_label = UiStyle.label(24)
	kills_row.add_child(_kills_label)
	var gem := _ShardIcon.new()
	gem.custom_minimum_size = Vector2(22, 26)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kills_row.add_child(gem)
	_shards_label = UiStyle.label(24)
	_shards_label.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	kills_row.move_child(gem, 0)
	kills_row.add_child(_shards_label)
	kills_row.move_child(_shards_label, 1)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 14
	kills_row.add_child(spacer)
	kills_row.move_child(spacer, 2)

	# Under the health bar: the dash cooldown.
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 8)
	dash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_column.add_child(dash_row)
	hp_column.move_child(dash_row, 1)
	_dash_bar = UiStyle.bar(Color(0.45, 0.75, 1.0), 6)
	_dash_bar.max_value = 1.0
	_dash_bar.custom_minimum_size.x = 110
	_dash_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_row.add_child(_dash_bar)
	_dash_label = UiStyle.label(12)
	dash_row.add_child(_dash_label)

	var soul_row := HBoxContainer.new()
	soul_row.add_theme_constant_override("separation", 8)
	soul_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_column.add_child(soul_row)
	hp_column.move_child(soul_row, 2)
	_soul_bar = UiStyle.bar(Color(0.45, 0.8, 1.0), 6)
	_soul_bar.custom_minimum_size.x = 110
	_soul_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_soul_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_row.add_child(_soul_bar)
	_soul_label = UiStyle.label(12)
	_soul_label.add_theme_color_override("font_color", Color(0.6, 0.88, 1.0))
	soul_row.add_child(_soul_label)

	# Top center, under the timer: the boss health bar.
	var boss_column := VBoxContainer.new()
	boss_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_column.offset_top = 62
	boss_column.offset_left = -260
	boss_column.offset_right = 260
	boss_column.add_theme_constant_override("separation", 2)
	boss_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_column.visible = false
	root.add_child(boss_column)
	_boss_box = boss_column
	_boss_label = UiStyle.label(18)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	boss_column.add_child(_boss_label)
	_boss_bar = UiStyle.bar(Color(0.75, 0.12, 0.08), 16)
	_boss_bar.max_value = 1.0
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_column.add_child(_boss_bar)

	_debug_label = UiStyle.label(13)
	_debug_label.modulate = Color(1, 1, 1, 0.5)
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.position += Vector2(12, -26)
	root.add_child(_debug_label)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_right = -16.0
	_toasts.offset_bottom = -16.0
	root.add_child(_toasts)

	# Level-up cards.
	var upgrade_box := VBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 6)
	var title := UiStyle.label(38)
	title.text = "LEVEL UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.18, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	upgrade_box.add_child(title)
	var subtitle := UiStyle.label(16)
	subtitle.text = "Choose a power   ·   1 / 2 / 3 or click"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	upgrade_box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	upgrade_box.add_child(gap)
	_upgrade_row = HBoxContainer.new()
	_upgrade_row.add_theme_constant_override("separation", 18)
	_upgrade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_box.add_child(_upgrade_row)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 10
	upgrade_box.add_child(gap2)
	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(240, 40)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.focus_mode = Control.FOCUS_NONE
	_reroll_button.pressed.connect(reroll_requested.emit)
	upgrade_box.add_child(_reroll_button)
	_upgrade_root = _make_overlay(root, upgrade_box, false)

	# Game over.
	var over_box := VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 18)
	_end_title = UiStyle.label(56)
	_end_title.text = "YOU DIED"
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	_end_title.add_theme_constant_override("outline_size", 12)
	over_box.add_child(_end_title)
	_game_over_label = UiStyle.label(22)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(_game_over_label)
	_shards_earned_label = UiStyle.label(20)
	_shards_earned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shards_earned_label.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	over_box.add_child(_shards_earned_label)
	_altar = AltarPanel.new()
	over_box.add_child(_altar)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	over_box.add_child(buttons)
	_endless_button = _end_button("Endless  (keep going)", Color(1.0, 0.82, 0.4))
	_endless_button.pressed.connect(endless_pressed.emit)
	buttons.add_child(_endless_button)
	_restart_button = _end_button("Rise again")
	_restart_button.pressed.connect(restart_pressed.emit)
	buttons.add_child(_restart_button)
	var realms := _end_button("Choose realm")
	realms.pressed.connect(realms_pressed.emit)
	buttons.add_child(realms)
	_game_over_root = _make_overlay(root, over_box, true)
	_game_over_root.visibility_changed.connect(func() -> void:
		if _game_over_root.visible:
			(_endless_button if _endless_button.visible else _restart_button).grab_focus())


func _end_button(text: String, color := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 54)
	b.add_theme_font_size_override("font_size", 20)
	if color.a > 0.0:
		b.add_theme_color_override("font_color", color)
	return b


func _make_card(index: int, choice: Dictionary) -> Button:
	var id: String = choice["id"]
	var tint = CARD_COLORS.get(id, "core")
	var color: Color = tint if tint is Color else SkillData.BRANCHES[tint]
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 310)
	card.pivot_offset = card.custom_minimum_size * 0.5
	var normal := UiStyle.box(Color(0.075, 0.07, 0.085, 0.97), color.darkened(0.45), 2, 12)
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 12
	var hover := UiStyle.box(Color(0.11, 0.1, 0.11, 0.98), color, 3, 12)
	hover.shadow_color = Color(color, 0.35)
	hover.shadow_size = 16
	for state in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		card.add_theme_stylebox_override(state, hover)
	card.pressed.connect(_choose.bind(index))
	for signal_name in ["mouse_entered", "focus_entered"]:
		card.connect(signal_name, func() -> void:
			card.create_tween().tween_property(card, "scale", Vector2(1.05, 1.05), 0.12))
	for signal_name in ["mouse_exited", "focus_exited"]:
		card.connect(signal_name, func() -> void:
			if not card.has_focus() or signal_name == "focus_exited":
				card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.12))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		column.set("offset_" + side, 16.0 if side in ["left", "top"] else -16.0)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var key := UiStyle.label(15)
	key.text = str(index + 1)
	key.modulate = Color(1, 1, 1, 0.5)
	top.add_child(key)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var tag := UiStyle.label(14)
	var level: int = choice.get("level", 0)
	tag.text = "NEW" if level == 1 else ("" if level == 0 else "RANK %d" % level)
	tag.add_theme_color_override("font_color", UiStyle.GOLD if level == 1 else Color(color, 0.85))
	top.add_child(tag)

	var icon := UiIcons.new()
	icon.icon = id
	icon.color = color
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var name_label := UiStyle.label(21)
	name_label.text = choice.get("name", choice.get("title", id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", color.lightened(0.25))
	column.add_child(name_label)

	# Rank pips: filled up to the rank this card gives.
	var max_level: int = choice.get("max", 0)
	if max_level > 0:
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 5)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in max_level:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(12, 12)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var filled := k < level
			var fresh := k == level - 1
			pip.add_theme_stylebox_override("panel", UiStyle.box(
					(Color.WHITE if fresh else color) if filled else Color(0, 0, 0, 0.4),
					color.darkened(0.2), 1, 6))
			pips.add_child(pip)
		column.add_child(pips)

	var rule := ColorRect.new()
	rule.color = Color(color, 0.25)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var desc := UiStyle.label(17)
	desc.text = choice["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_constant_override("outline_size", 2)
	column.add_child(desc)
	return card


## A dimmed full-screen overlay with `content` centered on it (in a panel if
## `framed`). Returns the (initially hidden) overlay; show()/hide() it.
func _make_overlay(parent: Control, content: Control, framed: bool) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.02, 0.68)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	if not framed:
		center.add_child(content)
		return overlay
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(margin)
	margin.add_child(content)
	return overlay


@warning_ignore("integer_division")
func _format_time(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## The Soul Shard gem next to the shard count.
class _ShardIcon extends Control:
	func _draw() -> void:
		var s := size
		var c := Color(0.72, 0.6, 1.0)
		draw_colored_polygon([Vector2(s.x * 0.5, 0), Vector2(s.x, s.y * 0.4), Vector2(s.x * 0.5, s.y), Vector2(0, s.y * 0.4)], c)
		draw_colored_polygon([Vector2(s.x * 0.5, 0), Vector2(s.x, s.y * 0.4), Vector2(s.x * 0.5, s.y * 0.5)], c.lightened(0.4))


## The little skull next to the kill count.
class _SkullIcon extends Control:
	func _draw() -> void:
		var s := size
		var bone := Color(0.9, 0.87, 0.8)
		draw_circle(Vector2(s.x * 0.5, s.y * 0.42), s.x * 0.4, bone)
		draw_rect(Rect2(s.x * 0.28, s.y * 0.55, s.x * 0.44, s.y * 0.35), bone)
		draw_circle(Vector2(s.x * 0.35, s.y * 0.45), s.x * 0.11, Color(0.1, 0.05, 0.05))
		draw_circle(Vector2(s.x * 0.65, s.y * 0.45), s.x * 0.11, Color(0.1, 0.05, 0.05))
		for k in 3:
			draw_line(Vector2(s.x * (0.38 + k * 0.12), s.y * 0.72), Vector2(s.x * (0.38 + k * 0.12), s.y * 0.9), Color(0.1, 0.05, 0.05), 1.5)
