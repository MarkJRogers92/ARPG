extends SceneTree
## Headless playthrough: a dumb bot walks in a square, takes the first upgrade
## it is offered, and we check the game loop actually did things.
##
##   godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd
##   godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 300   # seconds of game time
##   godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420 frozen  # optional realm
##
## --fixed-fps makes every frame exactly 1/60 s and removes real-time pacing,
## so a minute of game time takes a second or two. Exit code is 0 on success.
## Script errors are printed (look for "SCRIPT ERROR") but don't change the code.

var _main: Node
var _frame := 0
var _max_frames := 60 * 60
var _upgrades_taken := 0
const _WALK := ["move_right", "move_down", "move_left", "move_up"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_max_frames = int(float(args[0]) * 60.0)
	if args.size() > 1:
		if args[1] not in Realm.ORDER:
			push_error("Unknown smoke-test realm: " + args[1])
			quit(1)
			return
		Realm.current = args[1]
	print("SMOKE REALM: " + Realm.current)
	MetaProgress.disabled = true # saved upgrades mustn't change results
	Realm.in_title = false # straight into a run
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if not is_instance_valid(_main):
		return false
	_frame += 1

	var heading: String = _WALK[(_frame / 240) % _WALK.size()]
	for action: String in _WALK:
		if action == heading:
			Input.action_press(action)
		else:
			Input.action_release(action)

	var hud: Hud = _main.get_node("Hud")
	if hud._upgrade_root.visible:
		hud._choose(0)
		_upgrades_taken += 1

	var player: Player = _main.get_node("Player")
	var finished: bool = _frame >= _max_frames or _main._game_over
	if _frame % (60 * 30) == 0 or finished:
		var mix: Array[String] = []
		for swarm in get_nodes_in_group(EnemySwarm.GROUP):
			mix.append("%s %d" % [swarm.name, swarm.alive_count()])
		print("t=%6.1fs  enemies=%5d (%s)  kills=%5d  level=%2d  hp=%6.1f/%.0f  gear=%d worn, %d carried, %d on ground" % [
				_main.elapsed, _main._enemy_count(), ", ".join(mix), _main.kills,
				player.stats.level, player.stats.hp, player.stats.max_hp,
				player.inventory.equipped.size(), player.inventory.backpack.size(),
				_main.get_node("Loot").drops.size()])
	if not finished:
		return false

	var ok: bool = _main.kills > 0 and _upgrades_taken > 0
	print("%s  (died=%s, kills=%d, upgrades taken=%d)" % [
			"SMOKE TEST PASSED" if ok else "SMOKE TEST FAILED",
			_main._game_over, _main.kills, _upgrades_taken])
	quit(0 if ok else 1)
	return true
