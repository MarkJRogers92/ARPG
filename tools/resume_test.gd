extends SceneTree
## Suspends a real night and resumes it, headless, and checks what came back
## (see RunSave):
##
##   godot --headless --path . --fixed-fps 60 -s tools/resume_test.gd
##
## Exit code 0 on success.

var _main: Node
var _frame := 0
var _failures := 0
var _saved := {}
var _stage := 0


func _initialize() -> void:
	MetaProgress.disabled = true # saved upgrades mustn't change results
	RunSave.path = "user://test_run.save"
	RunSave.clear()
	Realm.current = "frozen"
	Realm.in_title = false
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main # so the scene can reload, like in the game


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", message])


func _process(_delta: float) -> bool:
	_frame += 1
	if _stage == 0 and _frame == 2:
		var player: Player = _main.get_node("Player")
		player.invulnerable = true
		# A night with some history: time, upgrades, a path, gear, skills, an army.
		_main.elapsed = 400.0
		(_main.get_node("WaveDirector") as WaveDirector).elapsed = 400.0
		(_main.get_node("WaveDirector") as WaveDirector).pressure = 2.5
		Upgrades.apply("lightning", player.stats)
		Upgrades.apply("lightning", player.stats)
		Upgrades.apply("bolt_damage", player.stats)
		Specializations.apply(player.stats, "battlemage", "sniper")
		_main._spec_chosen = true
		player.inventory.pickup(ItemGenerator.generate_with(8, ItemData.Rarity.RARE, "weapon"))
		player.inventory.pickup(ItemGenerator.generate_with(8, ItemData.Rarity.MAGIC, "helm"))
		player.inventory.backpack.append(ItemGenerator.generate_with(8, ItemData.Rarity.NORMAL, "ring"))
		player.skills.add_points(3)
		player.stats.level = 17
		player.stats.xp = 12
		player.stats.hp = player.stats.max_hp * 0.5
		var army: Army = _main.get_node("Army")
		army._raise(0, false, false, true)
		army._raise(1, true, false, true)
		army.souls = 7
		_main.kills = 1234
		_main._rerolls = 2
		player.invulnerable = false
		player.take_damage(5.0, "Ice Wraith")
		player.invulnerable = true
	elif _stage == 0 and _frame == 30:
		var player: Player = _main.get_node("Player")
		_check(_main.can_suspend(), "a night in progress can be saved")
		_saved = {
			"bolt": player.stats.bolt_damage, "pierce": player.stats.bolt_pierce, "lightning": player.stats.lightning_level,
			"max_hp": player.stats.max_hp, "weapon": player.inventory.equipped["weapon"].name,
			"backpack": player.inventory.backpack.size(), "points": player.skills.points, "army": (_main.get_node("Army") as Army).count,
			"elapsed": _main.elapsed, "omen": _main.omen,
		}
		_main._suspend()
		_stage = 1
		_frame = 0
	elif _stage == 1 and _frame == 5:
		_check(RunSave.exists(), "Save and quit writes the run slot")
		_check(Realm.in_title, "and goes back to the title")
		var data := RunSave.read()
		_check(data.get("realm") == "frozen" and int(data.get("level", 0)) == 17, "the slot holds the night (%s)" % RunSave.describe(data))
		# What the title screen's Resume button does.
		var title: TitleScreen = current_scene.get_node("TitleScreen")
		title.resume_requested.emit(data)
		_stage = 2
		_frame = 0
	elif _stage == 2 and _frame == 10:
		_main = current_scene
		var player: Player = _main.get_node("Player")
		_check(not RunSave.exists(), "a night resumes once (the slot is cleared)")
		_check(not Realm.in_title and Realm.current == "frozen", "back in the Frozen Wastes")
		_check(absf(_main.elapsed - _saved["elapsed"]) < 1.0, "the clock (%.0f s)" % _main.elapsed)
		_check(absf((_main.get_node("WaveDirector") as WaveDirector).pressure - 2.5) < 0.05, "the pressure")
		_check(player.stats.level == 17 and player.stats.xp == 12, "level and XP")
		_check(absf(player.stats.bolt_damage - _saved["bolt"]) < 0.01, "upgrades, path and gear: bolt damage %.1f" % player.stats.bolt_damage)
		_check(player.stats.bolt_pierce == _saved["pierce"] and player.stats.lightning_level == _saved["lightning"], "pierce and Chain Lightning")
		_check(absf(player.stats.max_hp - _saved["max_hp"]) < 0.01, "max health")
		_check(absf(player.stats.hp / player.stats.max_hp - 0.5) < 0.05 or player.stats.hp < player.stats.max_hp, "and the hero still hurt")
		_check(player.inventory.equipped["weapon"].name == _saved["weapon"] and player.inventory.backpack.size() == _saved["backpack"], "gear and backpack")
		_check(player.skills.points == _saved["points"], "skill points")
		_check((_main.get_node("Army") as Army).count == _saved["army"] and (_main.get_node("Army") as Army).souls == 7, "the army and its souls")
		_check(_main.kills == 1234 and _main._rerolls == 2 and _main._spec_chosen, "kills, rerolls and the chosen path")
		_check(player.damage_taken_by.has("Ice Wraith"), "the end screen's records")
		_check(_main.omen == _saved["omen"], "the night's omen")
		_check(_main._enemy_count() > 20, "a horde fit for the hour (%d)" % _main._enemy_count())
		RunSave.clear()
		print("RESUME TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
	return false
