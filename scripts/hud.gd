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
	"lightning": Color(0.72, 0.6, 1.0), "orbit": Color(0.45, 1.0, 0.85), "nova": Color(1.0, 0.5, 0.9), "obol": Color(1.0, 0.82, 0.35), "scythe": Color(0.65, 0.95, 0.85), "bell": Color(0.85, 0.8, 1.0),
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
var _marker_canvas: Control
var _marker_items: Array = []
var _blessing_label: Label
var _power_label: Label
var _prompt_label: Label
var _bet_label: Label
var _upgrade_title: Label
var _frenzy_label: Label
var _omen_label: Label
var _report: Label
var _recap_label: Label
var _recap_chart: DeathRecap
var _title_card: VBoxContainer
var _title_main: Label
var _title_sub: Label
var _title_tween: Tween
var _upgrade_subtitle: Label
var _shards_earned_label: Label
var _altar: AltarPanel
var _end_title: Label
var _endless_button: Button
var _restart_button: Button
## Copies the Daily Night's code (only shown after one).
var _code_button: Button
var _daily_code := ""
var _clock_text := ""
var _night: _NightArc
var _clock_color := Color(0.95, 0.93, 0.88)
var _soul_bar: ProgressBar
var _soul_label: Label
var _expedition_label: Label
var _campaign_guidance_label: Label


func _ready() -> void:
	# The menu has to keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()


## The HUD keeps running while the game is paused (menus), so game speed
## effects end on time there too (see Juice.tick()).
func _process(_delta: float) -> void:
	Juice.tick()


## Refresh the always-on display. Cheap enough to call every frame.
func refresh(stats: PlayerStats, elapsed: float, kills: int, enemies: int, skill_points := 0) -> void:
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_hp_text.text = "%d / %d" % [mini(ceili(stats.hp), roundi(stats.max_hp)), roundi(stats.max_hp)]
	_xp_bar.max_value = stats.xp_to_next
	_xp_bar.value = stats.xp
	_level_label.text = str(stats.level)
	_skill_label.visible = skill_points > 0
	_skill_label.text = "%d skill point%s  %s" % [skill_points, "" if skill_points == 1 else "s", Controls.tag("skill_tree")]
	_time_label.text = _clock_text if _clock_text != "" else _format_time(elapsed)
	_time_label.add_theme_color_override("font_color", _clock_color)
	_kills_label.text = "%d" % kills
	_debug_label.text = "%d FPS   %d enemies   %s inventory   %s skills   %s aim   [F11] fullscreen" % [Engine.get_frames_per_second(), enemies,
			Controls.tag("inventory"), Controls.tag("skill_tree"), Controls.tag("toggle_aim")]
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
	_dash_label.text = "DASH  " + Controls.tag("dash") if dash_cooldown <= 0.0 else "DASH"
	_dash_label.modulate = Color(1, 1, 1, 0.9 if dash_cooldown <= 0.0 else 0.45)
	_boss_box.visible = boss_health >= 0.0
	if _boss_box.visible:
		_boss_label.text = boss_name
		_boss_bar.value = boss_health


## The timed power-ups in effect ("" hides it).
func set_power(text: String, color: Color) -> void:
	_power_label.visible = text != ""
	if _power_label.visible:
		_power_label.text = text
		_power_label.add_theme_color_override("font_color", color)


## The shrine blessing in effect ("" hides it) and its seconds left.
func set_blessing(blessing_name: String, seconds: float, color: Color) -> void:
	_blessing_label.visible = blessing_name != ""
	if _blessing_label.visible:
		_blessing_label.text = "✦ Blessing of %s   %d s" % [blessing_name, ceili(seconds)]
		_blessing_label.add_theme_color_override("font_color", color)
		_blessing_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006)) if seconds < 5.0 else 1.0


## A boss arrives: its name across the screen for a moment.
func title_card(boss_name: String, subtitle: String, color: Color, campaign_arrival := false) -> void:
	if is_instance_valid(_title_tween) and _title_tween.is_running():
		_title_tween.kill()
	_title_main.text = boss_name.to_upper()
	_title_main.add_theme_color_override("font_color", color)
	_title_sub.text = subtitle
	_title_main.add_theme_font_size_override("font_size", 30 if campaign_arrival else 56)
	_title_sub.add_theme_font_size_override("font_size", 15 if campaign_arrival else 18)
	_title_card.offset_top = -140 if campaign_arrival else -300
	_title_card.offset_bottom = -70 if campaign_arrival else -190
	var t := _title_card.create_tween()
	_title_tween = t
	var calm_campaign_card := campaign_arrival and bool(MetaProgress.setting("calm"))
	_title_card.scale = Vector2.ONE if calm_campaign_card else Vector2(1.15, 1.15)
	_title_card.pivot_offset = _title_card.size * 0.5
	t.set_parallel()
	t.tween_property(_title_card, "modulate:a", 1.0, 0.35)
	if not calm_campaign_card:
		t.tween_property(_title_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.8)
	t.chain().tween_property(_title_card, "modulate:a", 0.0, 0.7)


func set_omen(omen_name: String, desc: String, color: Color, heat: int) -> void:
	_omen_label.text = "OMEN: %s%s" % [omen_name.to_upper(), ("   ·   HEAT %d" % heat) if heat > 0 else ""]
	_omen_label.tooltip_text = desc
	_omen_label.add_theme_color_override("font_color", color)


## The run report on the end screen: damage by source, best first.
## "Why I died": the causes line and the health / pressure chart.
func set_recap(text: String, samples: Array[Vector3]) -> void:
	_recap_label.text = text
	_recap_chart.show_samples(samples)


## `daily_code` (a Daily Night's, see DailyCode) joins the omen line, with a
## button to copy it.
func set_report(damage_by: Dictionary, kills: int, heat: int, omen: String, daily_code := "") -> void:
	var total := 0.0
	for k: String in damage_by:
		total += damage_by[k]
	var keys := damage_by.keys()
	keys.sort_custom(func(a, b) -> bool: return damage_by[a] > damage_by[b])
	var parts := []
	for k: String in keys.slice(0, 6):
		if total > 0.0:
			parts.append("%s %d%%" % [k, roundi(100.0 * damage_by[k] / total)])
	var line := "DAMAGE:  " + "   ·   ".join(parts) if not parts.is_empty() else ""
	var extras := []
	if omen != "":
		extras.append("Omen: %s" % RunModifiers.OMENS[omen]["name"])
	if heat > 0:
		extras.append("Heat %d (+%d%% shards)" % [heat, roundi(100.0 * RunModifiers.HEAT_BONUS * heat)])
	if daily_code != "":
		extras.append("Daily code: " + daily_code)
	_report.text = line + ("\n" + "   ·   ".join(extras) if not extras.is_empty() else "")
	_daily_code = daily_code
	_code_button.visible = daily_code != ""


## The Frenzy tier next to the kill count (0 hides it).
func set_frenzy(tier: int) -> void:
	_frenzy_label.text = "FRENZY %s" % "I".repeat(tier) if tier > 0 else ""


## The night's progress under the clock: 0 at dusk, 1 at dawn. `glow` is
## First Light (the moon becoming the sun). Hidden when `on` is false.
func set_night(progress: float, glow: float, on := true) -> void:
	_night.visible = on
	if on and (absf(_night.progress - progress) > 0.0005 or absf(_night.glow - glow) > 0.005):
		_night.progress = progress
		_night.glow = glow
		_night.queue_redraw()


## The Ferryman's side bet countdown ("" hides it).
func set_bet(text: String) -> void:
	_bet_label.text = text


## Campaign objective and contract/finale clock.
func set_expedition(objective: String, clock: String) -> void:
	_clock_text = clock
	_clock_color = UiStyle.GOLD
	_time_label.text = clock
	_expedition_label.text = objective
	_expedition_label.visible = objective != ""
	_night.visible = false


## Optional campaign field guidance and the active guardian's mechanic.
func set_campaign_guidance(text: String) -> void:
	_campaign_guidance_label.text = text
	_campaign_guidance_label.visible = text != ""


## The interact prompt at the bottom ("" hides it).
func set_prompt(text: String, color := Color.WHITE) -> void:
	_prompt_label.visible = text != ""
	if _prompt_label.visible:
		_prompt_label.text = text
		_prompt_label.add_theme_color_override("font_color", color)


## Things worth walking to: [{"at": world Vector2, "color", "label"}]. Off
## screen they get an arrow at the edge; on screen, a marker bobbing above.
func set_markers(items: Array, camera: Camera3D, campaign_objectives := false) -> void:
	_marker_items.clear()
	if camera == null:
		_marker_canvas.queue_redraw()
		return
	var view := _marker_canvas.get_viewport_rect().size
	var center := view * 0.5
	var nearest_inside := -1
	var nearest_inside_distance := INF
	for m: Dictionary in items:
		var world := Vector3(m["at"].x, 1.5, m["at"].y)
		var behind := camera.is_position_behind(world)
		var p := camera.unproject_position(world)
		if behind:
			p = center - (p - center) * 1000.0
		var margin := 44.0
		var inside := not behind and Rect2(Vector2.ONE * margin, view - Vector2.ONE * margin * 2.0).has_point(p)
		var item := {"color": m["color"], "label": m["label"], "inside": inside, "p": p,
			"campaign_objective": campaign_objectives}
		if not inside:
			var d := (p - center)
			var half := center - Vector2.ONE * margin
			var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
			item["p"] = center + d * minf(t, 1.0)
			item["dir"] = d.normalized()
		_marker_items.append(item)
		if inside and p.distance_squared_to(center) < nearest_inside_distance:
			nearest_inside = _marker_items.size() - 1
			nearest_inside_distance = p.distance_squared_to(center)
	if nearest_inside >= 0:
		_marker_items[nearest_inside]["prominent"] = true
	_marker_canvas.queue_redraw()


func _draw_markers() -> void:
	var font := ThemeDB.fallback_font
	var bob := 0.0 if bool(MetaProgress.setting("calm")) else sin(Time.get_ticks_msec() * 0.006) * 4.0
	for m: Dictionary in _marker_items:
		var color: Color = m["color"]
		var p: Vector2 = m["p"]
		if m["inside"] and m.get("campaign_objective", false) and m.get("prominent", false):
			var tip := p + Vector2(0, -40 + bob)
			_marker_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -12), tip + Vector2(9, -12), tip]), color)
			var text: String = m["label"]
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			var badge_size := Vector2(text_size.x + 12.0, 19.0)
			var viewport_size := _marker_canvas.get_viewport_rect().size
			var badge_position := Vector2(tip.x - badge_size.x * 0.5, tip.y - 33.0)
			badge_position.x = clampf(badge_position.x, 4.0, maxf(viewport_size.x - badge_size.x - 4.0, 4.0))
			badge_position.y = clampf(badge_position.y, 4.0, maxf(viewport_size.y - badge_size.y - 4.0, 4.0))
			var badge := Rect2(badge_position, badge_size)
			_marker_canvas.draw_rect(badge, Color(0.025, 0.035, 0.055, 0.9))
			_marker_canvas.draw_rect(badge, color, false, 1.0)
			_marker_canvas.draw_string_outline(font, badge.position + Vector2(6.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.95))
			_marker_canvas.draw_string(font, badge.position + Vector2(6.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
			continue
		if m["inside"]:
			var tip := p + Vector2(0, -40 + bob)
			_marker_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -12), tip + Vector2(9, -12), tip]), color)
			continue
		var dir: Vector2 = m["dir"]
		var side := dir.orthogonal()
		var tip := p + dir * (6.0 + bob)
		var pts := PackedVector2Array([tip + dir * 12.0, tip - dir * 8.0 + side * 11.0, tip - dir * 8.0 - side * 11.0])
		_marker_canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
		var inner := PackedVector2Array()
		for q in pts:
			inner.append(tip + (q - tip) * 0.75)
		_marker_canvas.draw_colored_polygon(inner, color)
		var text: String = m["label"]
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var at := p - dir * 26.0 - Vector2(size.x * 0.5, -5.0)
		_marker_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
		_marker_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


## The Soul Army: souls toward the next minion, and how big the army is.
func refresh_army(souls: int, cost: int, minions: int, max_minions: int, stance := "") -> void:
	_soul_bar.max_value = cost
	_soul_bar.value = souls
	_soul_label.text = "SOULS %d/%d   ARMY %d/%d%s" % [mini(souls, cost), cost, minions, max_minions,
			("   %s %s" % [stance, Controls.tag("army_stance")]) if stance != "" else ""]


## `rerolls` > 0 shows a button (and the R key) to roll new cards.
func show_upgrades(choices: Array[Dictionary], rerolls := 0, heading := "LEVEL UP", subheading := "Choose a power   ·   1 / 2 / 3 or click") -> void:
	_upgrade_title.text = heading
	_upgrade_subtitle.text = subheading
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll  %s   ·   %d left" % [Controls.tag("reroll"), rerolls]
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
		Sound.play("reroll")
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
	Sound.play("card_pick")
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
	_expedition_label = UiStyle.label(15)
	_expedition_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_expedition_label.offset_top = 58
	_expedition_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_expedition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expedition_label.add_theme_color_override("font_color", Color(0.58, 0.88, 1.0))
	_expedition_label.visible = false
	root.add_child(_expedition_label)
	_campaign_guidance_label = UiStyle.label(14)
	_campaign_guidance_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_campaign_guidance_label.offset_top = 184
	_campaign_guidance_label.offset_left = -560
	_campaign_guidance_label.offset_right = 560
	_campaign_guidance_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_campaign_guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_guidance_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.77))
	_campaign_guidance_label.add_theme_constant_override("outline_size", 4)
	_campaign_guidance_label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.06, 0.92))
	_campaign_guidance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_guidance_label.hide()
	root.add_child(_campaign_guidance_label)
	# Under it, the night's arc: the moon crossing toward dawn.
	_night = _NightArc.new()
	_night.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_night.offset_left = -130
	_night.offset_right = 130
	_night.offset_top = 58
	_night.offset_bottom = 74
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_night)

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
	_frenzy_label = UiStyle.label(18)
	_frenzy_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
	_frenzy_label.add_theme_constant_override("outline_size", 6)
	_frenzy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kills_row.add_child(_frenzy_label)
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
	boss_column.offset_top = 76
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

	# Under the boss bar: the shrine blessing in effect.
	_blessing_label = UiStyle.label(18)
	_blessing_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_blessing_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_blessing_label.offset_top = 126
	_blessing_label.offset_left = -260
	_blessing_label.offset_right = 260
	_blessing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blessing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blessing_label.hide()
	root.add_child(_blessing_label)
	_power_label = _blessing_label.duplicate()
	_power_label.offset_top = 150
	root.add_child(_power_label)

	# Under the army bar: this night's omen (and pact heat).
	_omen_label = UiStyle.label(14)
	_omen_label.position = Vector2(100, 116)
	_omen_label.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_omen_label)

	# A boss's name, big, when it arrives.
	_title_card = VBoxContainer.new()
	_title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_card.offset_top = -300
	_title_card.offset_bottom = -190
	_title_card.offset_left = -600
	_title_card.offset_right = 600
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate.a = 0.0
	root.add_child(_title_card)
	_title_sub = UiStyle.label(18)
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub.modulate = Color(1, 1, 1, 0.75)
	_title_card.add_child(_title_sub)
	_title_main = UiStyle.label(56)
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_main.add_theme_constant_override("outline_size", 14)
	_title_main.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 0.95))
	_title_card.add_child(_title_main)

	# Under the blessing: the Ferryman's side bet.
	_bet_label = UiStyle.label(18)
	_bet_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bet_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bet_label.offset_top = 152
	_bet_label.offset_left = -260
	_bet_label.offset_right = 260
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_bet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bet_label)

	# Bottom center: what the nearby landmark does (see Landmarks).
	_prompt_label = UiStyle.label(20)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_label.offset_bottom = -64
	_prompt_label.offset_left = -500
	_prompt_label.offset_right = 500
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.add_theme_constant_override("outline_size", 8)
	_prompt_label.hide()
	root.add_child(_prompt_label)

	# Arrows at the screen edge toward events and bosses (see set_markers).
	_marker_canvas = Control.new()
	_marker_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_canvas.draw.connect(_draw_markers)
	root.add_child(_marker_canvas)

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
	_upgrade_title = title
	title.text = "LEVEL UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.18, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	upgrade_box.add_child(title)
	var subtitle := UiStyle.label(16)
	_upgrade_subtitle = subtitle
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
	_reroll_button.pressed.connect(func() -> void:
		Sound.play("reroll")
		reroll_requested.emit())
	upgrade_box.add_child(_reroll_button)
	_upgrade_root = _make_overlay(root, upgrade_box, false)

	# Game over.
	var over_box := VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 12)
	_end_title = UiStyle.label(56)
	_end_title.text = "YOU DIED"
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	_end_title.add_theme_constant_override("outline_size", 12)
	over_box.add_child(_end_title)
	_game_over_label = UiStyle.label(22)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(_game_over_label)
	_report = UiStyle.label(16)
	_report.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.custom_minimum_size.x = 820
	_report.modulate = Color(1, 1, 1, 0.85)
	over_box.add_child(_report)
	_recap_label = UiStyle.label(16)
	_recap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recap_label.custom_minimum_size.x = 820
	_recap_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.62))
	over_box.add_child(_recap_label)
	_recap_chart = DeathRecap.new()
	_recap_chart.visible = false
	over_box.add_child(_recap_chart)
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
	_code_button = _end_button("Copy daily code", UiStyle.GOLD)
	_code_button.visible = false
	_code_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_daily_code)
		toast("Copied: " + _daily_code, UiStyle.GOLD))
	buttons.add_child(_code_button)
	_game_over_root = _make_overlay(root, over_box, true)
	_game_over_root.visibility_changed.connect(func() -> void:
		if _game_over_root.visible:
			(_endless_button if _endless_button.visible else _restart_button).grab_focus())


func _end_button(text: String, color := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void: Sound.play("ui_click"))
	if color.a > 0.0:
		b.add_theme_color_override("font_color", color)
	return b


func _make_card(index: int, choice: Dictionary) -> Button:
	var id: String = choice["id"]
	var tint = choice["color"] if choice.has("color") else CARD_COLORS.get(id, "core")
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
			Sound.play("ui_hover")
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
	if choice.has("tag"):
		tag.text = choice["tag"]
		tag.add_theme_color_override("font_color", UiStyle.GOLD)
		normal.border_color = UiStyle.GOLD
		normal.border_width_left = 3
		normal.border_width_right = 3
		normal.border_width_top = 3
		normal.border_width_bottom = 3
		normal.shadow_color = Color(UiStyle.GOLD, 0.45)
		normal.shadow_size = 18
	top.add_child(tag)

	var icon := UiIcons.new()
	icon.icon = choice.get("icon", id)
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


## A shallow arc with the moon riding it toward the horizon; it warms into
## the sun over First Light.
class _NightArc extends Control:
	var progress := 0.0
	var glow := 0.0
	const NIGHT := Color(0.55, 0.62, 0.95)
	const SUN := Color(1.0, 0.78, 0.4)

	func _point(t: float) -> Vector2:
		return Vector2(lerpf(8.0, size.x - 8.0, t), size.y - 3.0 - sin(t * PI) * (size.y - 7.0))

	func _draw() -> void:
		var steps := 32
		for k in steps:
			var t0 := float(k) / steps
			var t1 := float(k + 1) / steps
			var c := NIGHT.lerp(SUN, smoothstep(0.55, 1.0, t1))
			c.a = 0.75 if t1 <= progress else 0.22
			draw_line(_point(t0), _point(t1), c, 2.0, true)
		# Dawn waits at the right-hand end.
		draw_circle(_point(1.0), 3.0, Color(SUN, 0.35 + 0.65 * glow))
		var at := _point(clampf(progress, 0.0, 1.0))
		var body := Color(0.85, 0.88, 1.0).lerp(SUN, glow)
		if glow > 0.05:
			for r in 8:
				var dir := Vector2.from_angle(TAU * r / 8.0)
				draw_line(at + dir * 7.0, at + dir * (7.0 + 4.0 * glow), Color(SUN, glow), 1.5, true)
		draw_circle(at, 5.5, body)
		if glow < 0.95:
			# The crescent: a dark disc slides off the moon as it becomes the sun.
			draw_circle(at + Vector2(2.5 + 6.0 * glow, -1.5), 4.6, Color(0.05, 0.05, 0.1, 1.0 - glow))


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
