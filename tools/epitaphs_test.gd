extends SceneTree
## Epitaphs: recording on death, the per-realm cap, the three-night life,
## claiming once, persistence, old saves and campaign/Daily gating.
##
##   godot --headless --path . -s tools/epitaphs_test.gd
##
## Uses its own meta save path and never touches the real one.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _fresh() -> void:
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://epitaphs_test.save"
	for suffix in ["", ".tmp", ".bak", ".rollback"]:
		DirAccess.remove_absolute(MetaProgress.save_path + suffix)
	MetaProgress.load_save()
	MetaProgress.epitaphs = []


func _run() -> void:
	_fresh()
	check(Epitaphs.allowed(false, false), "classic records")
	check(not Epitaphs.allowed(true, false) and not Epitaphs.allowed(false, true), "campaign and Daily are gated off")

	var e := Epitaphs.record("graveyard", Vector2(300, 0), "battlemage", 34, 702.0, "Plague Bloater", 58)
	check(MetaProgress.epitaphs.size() == 1 and e["nights_left"] == 3, "recorded with three nights")
	check(Vector2(e["x"], e["z"]).length() <= Epitaphs.MAX_DISTANCE + 0.01, "far deaths clamp to 55 m")
	var near := Epitaphs.record("graveyard", Vector2(10, -4), "reaper", 5, 60.0, "Ghoul", 2)
	check(is_equal_approx(near["x"], 10.0) and is_equal_approx(near["z"], -4.0), "near deaths keep their spot")
	var text := Epitaphs.tale_text(e)
	check(text[0] == "HERE FELL A BATTLEMAGE" and text[1] == "Level 34 · 11:42 · slain by Plague Bloater", "title card text: %s / %s" % [text[0], text[1]])

	# persisted, and reloaded
	MetaProgress.load_save()
	check(MetaProgress.epitaphs.size() == 2 and MetaProgress.epitaphs[0]["killer"] == "Plague Bloater", "epitaphs persist")

	# cap of four per realm, oldest dropped, other realms untouched
	Epitaphs.record("frozen", Vector2.ZERO, "battlemage", 1, 1.0, "X", 0)
	for k in 5:
		Epitaphs.record("graveyard", Vector2(k, 0), "battlemage", 10 + k, 10.0, "Y", 0)
	var mine := Epitaphs.in_realm("graveyard")
	check(mine.size() == 4, "at most four per realm (%d)" % mine.size())
	check(int(mine[0]["level"]) == 11 and int(mine[3]["level"]) == 14, "oldest dropped")
	check(Epitaphs.in_realm("frozen").size() == 1, "other realms unaffected")

	# three nights, spawned each time, expiring after the third
	_fresh()
	Epitaphs.record("graveyard", Vector2(5, 5), "battlemage", 9, 99.0, "Z", 4)
	for night in 3:
		var stand := Epitaphs.begin_night("graveyard")
		check(stand.size() == 1, "night %d: grave stands" % (night + 1))
	check(Epitaphs.in_realm("graveyard").is_empty(), "gone after the third night")
	check(Epitaphs.begin_night("graveyard").is_empty(), "nothing on the fourth")
	Epitaphs.record("graveyard", Vector2(5, 5), "battlemage", 9, 99.0, "Z", 4)
	Epitaphs.begin_night("frozen")
	check(int(Epitaphs.in_realm("graveyard")[0]["nights_left"]) == 3, "other realm's night doesn't age it")

	Elements.reset()
	var player := Player.new()
	player.stats = PlayerStats.new()
	Elements.player = player
	var grunts := EnemySwarm.new()
	grunts.capacity = 4
	root.add_child(grunts)
	var swarms: Array[EnemySwarm] = [grunts]
	Elements.swarms = swarms
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	player.stats.add_mod("test", "soul_cost", PlayerStats.Op.ADD, 100000.0) # no minion is raised (the hero is not in a tree here)
	player.stats.recalculate()
	var base_damage: float = player.stats.values["damage"]
	var node := Epitaphs.new()
	root.add_child(node)
	node.setup(player, army)
	var titles: Array = []
	node.tale.connect(func(t: String, s: String, _c: Color) -> void: titles.append([t, s]))
	_fresh()
	Epitaphs.record("graveyard", Vector2(5, 5), "battlemage", 9, 99.0, "Z", 100)
	Epitaphs.record("graveyard", Vector2(-5, 5), "necromancer", 3, 30.0, "Q", 7)
	node.spawn(Epitaphs.begin_night("graveyard"))
	check(node.grave_count() == 2, "two graves spawn")
	var before := army.souls
	check(node.claim(0), "claim works")
	var after := army.souls
	check(after - before == Epitaphs.REWARD_SOULS, "min(souls, 30) restored (%d)" % (after - before))
	check(titles.size() == 1 and titles[0][0] == "HERE FELL A BATTLEMAGE", "title card shown")
	check(is_equal_approx(player.stats.values["damage"] / base_damage, 1.08), "vengeance +8%%")
	check(node.grave_count() == 1, "grave consumed")
	check(not node.claim(5), "no claim out of range")
	check(node.claim(0), "second grave claimed")
	check(is_equal_approx(player.stats.values["damage"] / base_damage, 1.16), "vengeance stacks to +16%%")
	check(Epitaphs.in_realm("graveyard").is_empty(), "removed from meta")
	MetaProgress.load_save()
	check(MetaProgress.epitaphs.is_empty(), "removal persists")

	# a small grave pays only what the hero had
	_fresh()
	Epitaphs.record("graveyard", Vector2(5, 5), "battlemage", 9, 99.0, "Z", 7)
	node.spawn(Epitaphs.begin_night("graveyard"))
	var s0 := army.souls
	node.claim(0)
	check(army.souls - s0 == 7, "small grave pays its souls (%d)" % (army.souls - s0))

	# old saves with no field, and malformed entries
	_fresh()
	CampaignSave.atomic_write(MetaProgress.save_path, {"version": 3, "shards": 5, "ranks": {}, "bestiary": {}}, "", MetaProgress._valid_snapshot)
	MetaProgress.load_save()
	check(MetaProgress.epitaphs.is_empty() and MetaProgress.shards == 5, "old save loads without the field")
	check(Epitaphs.clean({"realm": 1}).is_empty() and Epitaphs.clean("x").is_empty(), "malformed entries dropped")

	for suffix in ["", ".tmp", ".bak", ".rollback"]:
		DirAccess.remove_absolute(MetaProgress.save_path + suffix)
	Elements.reset()
	for n: Node in [node, army, grunts, player]:
		root.remove_child(n) if n.get_parent() != null else null
		n.free()
	print("epitaphs: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
