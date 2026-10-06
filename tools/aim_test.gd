extends SceneTree
## Drives aiming in the real game: mouse aim, the T toggle back to auto-aim,
## and right-stick aim. Moves the real mouse cursor, so it needs a display
## (not --headless); on a server, wrap it in xvfb-run:
##
##   xvfb-run godot --path . --fixed-fps 60 -s tools/aim_test.gd
##
## Exit code 0 means every check passed.

var _main: Node
var _player: Player
var _projectiles: ProjectileSwarm
var _grunts: EnemySwarm
var _frame := 0
var _step := 0
var _failures := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 5:
		return false
	if _player == null:
		_player = _main.get_node("Player")
		_projectiles = _main.get_node("Projectiles")
		_grunts = _main.get_node("Grunts")
	# Keep one tough enemy to the hero's right (+X) so bolts keep firing. New
	# spawns arrive far outside bolt range, so they don't change the target.
	_player.stats.hp = _player.stats.max_hp
	if _grunts.alive_count() == 0:
		_grunts.spawn(_player.pos2 + Vector2(6, 0), 1000.0)
	else:
		_grunts.pos[0] = _player.pos2 + Vector2(6, 0)

	match _step:
		0:
			_check(_player.aim_mode == Player.Aim.AUTO, "starts on auto-aim")
			_next()
		1:
			if _wait(40):
				_check(_bolts_heading(Vector2(1, 0)), "auto-aim shoots the enemy on the right")
				# Cursor well to the left of the hero (screen center).
				var size := root.get_visible_rect().size
				root.warp_mouse(Vector2(size.x * 0.12, size.y * 0.5))
				_next()
		2:
			if _wait(40):
				_check(_player.aim_mode == Player.Aim.MOUSE, "moving the mouse switches to mouse aim")
				_check(_player.aim_dir.x < -0.9, "aims at the cursor, to the left (aim_dir=%s)" % _player.aim_dir)
				_check(_bolts_heading(Vector2(-1, 0)), "bolts fly toward the cursor, away from the enemy")
				_check(_player._reticle.visible, "reticle shows under the cursor")
				var facing := Vector2(-sin(_player._visual.rotation.y), -cos(_player._visual.rotation.y))
				_check(facing.dot(Vector2(-1, 0)) > 0.9, "hero faces the cursor (facing=%s)" % facing)
				# Walk right while aiming left.
				Input.action_press("move_right")
				_next()
		3:
			if _wait(30):
				_check(_player.velocity.x > 1.0, "walks right while aiming left")
				var facing := Vector2(-sin(_player._visual.rotation.y), -cos(_player._visual.rotation.y))
				_check(facing.dot(Vector2(-1, 0)) > 0.9, "still faces the cursor while walking away")
				Input.action_release("move_right")
				_press_toggle()
				_next()
		4:
			if _wait(40):
				_check(_player.aim_mode == Player.Aim.AUTO and not _player.mouse_aim_enabled, "T switches to auto-aim")
				_check(not _player._reticle.visible, "reticle hides on auto-aim")
				_check(_bolts_heading(Vector2(1, 0)), "auto-aim shoots the enemy again")
				var size := root.get_visible_rect().size
				root.warp_mouse(Vector2(size.x * 0.2, size.y * 0.3))
				_next()
		5:
			if _wait(20):
				_check(_player.aim_mode == Player.Aim.AUTO, "mouse moves don't take over while auto-aim is chosen")
				_press_toggle()
				root.warp_mouse(Vector2(root.get_visible_rect().size.x * 0.12, root.get_visible_rect().size.y * 0.5))
				_next()
		6:
			if _wait(20):
				_check(_player.mouse_aim_enabled and _player.aim_mode == Player.Aim.MOUSE, "T again brings mouse aim back")
				Input.action_press("aim_down", 1.0)
				_next()
		7:
			if _wait(40):
				_check(_player.aim_mode == Player.Aim.STICK and _player.aim_dir.y > 0.9, "right stick aims (aim_dir=%s)" % _player.aim_dir)
				_check(_bolts_heading(Vector2(0, 1)), "bolts follow the stick")
				Input.action_release("aim_down")
				_next()
		8:
			if _wait(5):
				_check(_player.aim_mode == Player.Aim.AUTO, "releasing the stick goes back to auto-aim")
				print("AIM TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


var _waited := 0

func _wait(frames: int) -> bool:
	_waited += 1
	return _waited >= frames


func _next() -> void:
	_step += 1
	_waited = 0


func _press_toggle() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


## True when the bolts fired in the last half second head roughly along `dir`
## (the middle one of a volley is dead on; the spread is a few degrees).
func _bolts_heading(dir: Vector2) -> bool:
	var fresh := 0
	var along := 0
	for i in _projectiles.count:
		if _projectiles._life[i] > 1.0:
			fresh += 1
			if _projectiles._vel[i].normalized().dot(dir) > 0.95:
				along += 1
	print("      (%d fresh bolts, %d heading %s)" % [fresh, along, dir])
	return fresh > 0 and along == fresh


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
