extends SceneTree
## Plays the game for a while with a simple bot and saves screenshots, so the
## look can be checked without sitting at the editor. Needs a real display (or
## Xvfb), not --headless:
##
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 -s tools/screenshot.gd -- out_dir 40
##
## Saves <out_dir>/game_<t>.png every 10 s of game time, then the level-up
## menu, the inventory and the skill tree. A third argument "crowd" starts with
## a horde of every enemy type around the hero, to see them en masse.

var _main: Node
var _frame := 0
var _max_frames := 60 * 40
var _out := "user://shots"
var _phase := 0
var _wait := 0
const _WALK := ["move_right", "move_down", "move_left", "move_up"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_max_frames = int(float(args[1]) * 60.0)
	DirAccess.make_dir_recursive_absolute(_out)
	var crowd := args.size() > 2 and args[2] == "crowd"
	seed(7)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	# A few items on the ground near the start so the loot look shows up.
	var loot: LootManager = _main.get_node("Loot")
	for r in 4:
		var item := ItemGenerator.generate(5, 0.0)
		item.rarity = r
		loot.drop(item, Vector2(-4.0 + r * 2.6, -3.0))
	if crowd:
		_spawn_crowd.call_deferred()


func _process(_delta: float) -> bool:
	_frame += 1
	var hud: Hud = _main.get_node("Hud")
	var player: Player = _main.get_node("Player")
	player.stats.hp = player.stats.max_hp # keep the bot alive for the pictures

	if _phase == 0:
		# Stand still for a moment at the start, by the loot.
		var heading: String = "" if _frame < 45 else _WALK[(_frame / 200) % _WALK.size()]
		for action: String in _WALK:
			if action == heading:
				Input.action_press(action)
			else:
				Input.action_release(action)
		if hud._upgrade_root.visible:
			if _frame > _max_frames - 120:
				_phase = 1
				_wait = 30
				return false
			hud._choose(_frame % 3)
		if _frame == 45:
			_save("start")
		if _frame % 600 == 0:
			_save("game_%03d" % (_frame / 60))
		if _frame >= _max_frames:
			_save("game_end")
			player.add_xp(player.stats.xp_to_next)
			_phase = 1
			_wait = 30
		return false

	_wait -= 1
	if _wait > 0:
		return false
	match _phase:
		1:
			_save("levelup")
			if hud._upgrade_root.visible:
				hud._choose(0)
			for action: String in _WALK:
				Input.action_release(action)
			var inv: InventoryScreen = _main.get_node("InventoryScreen")
			for k in 9:
				var item := ItemGenerator.generate(8, 1.5)
				if k < 4:
					player.inventory.equip(item)
				else:
					player.inventory.pickup(item)
			_main._open_screen(inv)
			if player.inventory.backpack.size() > 0:
				inv._backpack_list.select(0)
				inv._backpack_list.item_selected.emit(0)
			_phase = 2
			_wait = 20
		2:
			_save("inventory")
			_main.get_node("InventoryScreen").close()
			player.skills.add_points(6)
			_main._open_screen(_main.get_node("SkillTreeScreen"))
			_phase = 3
			_wait = 10
		3:
			_save("skills")
			quit(0)
			return true
	return false


func _spawn_crowd() -> void:
	var counts := {"Grunts": 260, "Brutes": 30, "Runners": 120}
	for swarm_name: String in counts:
		var swarm: EnemySwarm = _main.get_node(swarm_name)
		for k in counts[swarm_name]:
			swarm.spawn(EnemySwarm.random_ring_point(Vector2.ZERO, 7.0, 18.0))


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
