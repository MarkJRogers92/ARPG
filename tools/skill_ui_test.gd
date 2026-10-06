extends SceneTree
## Drives the real skill tree screen through the real input action, headless.
##
##   godot --headless --path . -s tools/skill_ui_test.gd
##
## Exit code 0 on success.

var _main: Node
var _frame := 0
var _failures := 0
var _player: Player
var _screen: SkillTreeScreen
var _hud: Hud


func _initialize() -> void:
	MetaProgress.disabled = true # saved upgrades mustn't change results
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", message])


func _press_action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)


func _click(id: String) -> void:
	(_screen._buttons[id] as Button).pressed.emit()


func _right_click(id: String) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	(_screen._buttons[id] as Button).gui_input.emit(e)


func _key(id: String, keycode: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	(_screen._buttons[id] as Button).gui_input.emit(e)


func _process(_delta: float) -> bool:
	_frame += 1
	var skills: SkillTree
	match _frame:
		2:
			_player = _main.get_node("Player")
			_screen = _main.get_node("SkillTreeScreen")
			_hud = _main.get_node("Hud")
			_main.get_node("WaveDirector").base_rate = 0.0
			_main.get_node("WaveDirector").rate_growth = 0.0
			_main.get_node("WaveDirector").rate_acceleration = 0.0
			_player.skills.add_points(8)
			print("opening the tree with the skill key")
			_press_action("skill_tree")
		4:
			skills = _player.skills
			_check(_screen.is_open() and paused, "skill key opens the screen and pauses the game")
			_check(_screen._buttons.size() == SkillData.NODES.size(), "one button per node (%d)" % _screen._buttons.size())
			_check(_screen._points_label.text == "Skill points: 8", "header shows the points ('%s')" % _screen._points_label.text)
			_check(_hud._skill_label.visible and _hud._skill_label.text.begins_with("8 skill points"), "HUD shows unspent points ('%s')" % _hud._skill_label.text)

			var cooldown_before := _player.stats.bolt_cooldown
			_click("o1")
			_check(skills.is_allocated("o1") and skills.points == 7, "clicking an adjacent node allocates it")
			_check(_player.stats.bolt_cooldown < cooldown_before, "...and the stats change")
			_check(_screen._points_label.text == "Skill points: 7", "header updates")

			_click("o5")
			_check(not skills.is_allocated("o5") and _screen._message.contains("Not connected"), "a node that isn't linked to yours is refused with a reason")
			_click("o2")
			_click("o5")
			_check(skills.is_allocated("o5") and skills.points == 3, "the keystone is bought once it's reachable (points left: %d)" % skills.points)
			_click("a1")
			_check(skills.is_allocated("a1") and skills.points == 1, "an Aura gateway costs 2 (points left: %d)" % skills.points)
			_click("a2")
			_check(skills.points == 0, "spend the last point")
			_click("a3")
			_check(not skills.is_allocated("a3") and _screen._message.contains("more skill point"), "an unaffordable node says how many points are missing ('%s')" % _screen._message)
		6:
			skills = _player.skills
			_right_click("o1")
			_check(skills.is_allocated("o1") and _screen._message.contains("depend"), "right-click on a node others depend on is refused with a reason")
			_right_click("o5")
			_check(not skills.is_allocated("o5") and skills.points == 3, "right-click refunds a leaf and returns its cost")
			_key("a2", KEY_BACKSPACE)
			_check(not skills.is_allocated("a2") and skills.points == 4, "Backspace on a focused node refunds it")
			_check(_player.stats.bolt_count == int(PlayerStats.BASE["bolt_count"]), "Arcane Barrage's bonus is gone after the refund")
		8:
			skills = _player.skills
			_click("a2")
			_click("o3")
			var spent := skills.spent()
			_check(spent > 0 and not _screen._reset_button.disabled, "Reset is enabled once something is spent")
			_screen._reset_button.pressed.emit()
			_check(skills.spent() == 0 and skills.points == 8, "Reset returns every point (%d)" % skills.points)
			_check(_screen._reset_button.disabled, "...and disables itself")
			print("closing with the skill key")
			_press_action("skill_tree")
		10:
			_check(not _screen.is_open() and not paused, "skill key closes the screen and resumes")
			_check(_hud._skill_label.visible, "HUD still shows the unspent points")
			print("")
			print("SKILL UI TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false
