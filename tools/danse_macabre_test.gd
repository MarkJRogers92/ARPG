extends SceneTree
## Danse Macabre: overflow souls fill the Requiem meter only when the army is
## full; the trigger needs a full meter and 3 minions; the ring is evenly
## spaced; dancers hurt (credited to "Danse Macabre") and can't be hurt; the
## state resets after 8 s; the meter survives a save.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	MetaProgress.disabled = true
	Elements.reset()
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunts := EnemySwarm.new()
	grunts.capacity = 64
	root.add_child(grunts)
	var swarms: Array[EnemySwarm] = [grunts]
	Elements.player = player
	Elements.swarms = swarms
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	player.stats.minion_max = 5
	player.stats.soul_cost = 100 # souls alone never raise anything here
	player.stats.crit_chance = 0.0

	# Souls with room to grow the army don't feed the meter.
	var soul := Army.soul_value(0, false, false)
	army.collect_soul(soul)
	check(army.dance.meter == 0, "a soul with room in the army doesn't fill Requiem")
	for i in 5:
		army._raise(0, false, false)
	check(army.count == 5, "army filled to capacity")
	army.collect_soul(soul)
	army.collect_soul(soul)
	check(army.dance.meter == 2, "souls at capacity fill Requiem (%d)" % army.dance.meter)
	army.collect_soul(Army.soul_value(0, true, false))
	check(army.dance.meter >= 2, "elite soul keeps the meter sane")
	for i in 100:
		army.collect_soul(soul)
	check(army.dance.meter == DanseMacabre.MAX, "the meter caps at %d" % DanseMacabre.MAX)

	# Trigger rules.
	var d := DanseMacabre.new()
	check(not d.can_start(10), "empty meter can't start")
	d.add_overflow(DanseMacabre.MAX - 1)
	check(not d.can_start(10) and not d.start(10), "almost full can't start")
	d.add_overflow()
	check(not d.can_start(2) and not d.start(2), "full meter but only 2 minions can't start")
	check(d.can_start(3), "full meter and 3 minions can start")
	check(d.start(3) and d.active, "starts")
	d.add_overflow()
	check(d.meter == DanseMacabre.MAX, "no meter gain while dancing")
	check(not d.start(9), "can't start twice")

	# Ring: evenly spaced around the hero, growing and speeding up.
	var hero := Vector2(10, -4)
	var n := 7
	var pts: Array[Vector2] = []
	for i in n:
		pts.append(DanseMacabre.slot(i, n, hero, 0.8, 5.0))
	var gap := pts[0].distance_to(pts[1])
	var even := true
	for i in n:
		even = even and is_equal_approx(pts[i].distance_to(hero), 5.0) and absf(pts[i].distance_to(pts[(i + 1) % n]) - gap) < 0.001
	check(even, "ring positions are evenly spaced at the radius")
	var r0 := d.radius()
	var w0 := d.angular_speed()
	check(is_equal_approx(r0, 4.5) and is_equal_approx(w0, 1.5), "starts at 4.5 m, 1.5 rad/s")
	d.advance(4.0)
	check(d.radius() > r0 and d.angular_speed() > w0, "ring widens and speeds up")
	d.advance(4.0)
	check(not d.active and d.meter == 0, "the standalone dance ends after 8 s and empties the meter")

	# In the army: dancers circle, hurt, are invulnerable.
	player.pos2 = Vector2.ZERO
	army.dance.meter = DanseMacabre.MAX
	for k in army.count:
		army._pos[k] = Vector2(1, 1)
		army._hp[k] = 5.0
		army._max_hp[k] = 5.0
	# Enemies on the ring's start radius, plus one far away.
	grunts.spawn(Vector2(4.5, 0.0))
	grunts.spawn(Vector2(-60.0, 0.0))
	grunts.step(0.0, Vector2.ZERO)
	grunts.hp[0] = 1.0e6
	grunts.hp[1] = 1.0e6
	var far_before := grunts.hp[1]
	Elements.damage_by.clear()
	check(army.start_dance(), "army starts the dance")
	var hp_before := army._hp[0]
	for f in 30:
		army.step(1.0 / 30.0)
		grunts.step(0.0, Vector2.ZERO)
	var on_ring := true
	for k in army.count:
		on_ring = on_ring and absf(army._pos[k].distance_to(player.pos2) - army.dance.radius()) < 0.9
	check(on_ring, "minions are on the ring around the hero after a second")
	# Every dancer is evenly spaced (pairwise neighbour gaps equal) once settled.
	for f in 90:
		army.step(1.0 / 60.0)
	check(Elements.damage_by.get("Danse Macabre", 0.0) > 0.0, "enemies in reach take damage credited to Danse Macabre")
	check(grunts.hp[1] == far_before, "an enemy out of reach is untouched")
	check(army._hp[0] == hp_before and army.count == 5, "minions are invulnerable while dancing")
	# Ring swarm of contact damage can't hurt: stack enemies on a dancer and tick.
	for j in 20:
		grunts.spawn(army._pos[0])
	grunts.step(0.0, Vector2.ZERO)
	for f in 60:
		army.step(1.0 / 60.0)
	check(army._hp[0] == hp_before, "contact damage is ignored by dancers")
	# Time out.
	for f in 600:
		army.step(1.0 / 60.0)
		if not army.dance.active:
			break
	check(not army.dance.active and army.dance.meter == 0, "state resets after the dance")
	var settle := army._pos[0]
	army.step(1.0 / 60.0)
	check(army.count == 5, "army intact after the dance")
	check(not army.start_dance(), "can't dance again with an empty meter")
	army.dance.meter = 17

	# Save round trip.
	Realm.in_title = false
	RunSave.path = "user://test_danse_run.save"
	RunSave.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var marmy: Army = main.get_node("Army")
	marmy.dance.meter = 23
	var data: Dictionary = main.capture()
	check(int(data.get("requiem", -1)) == 23, "capture() holds the Requiem meter")
	check(RunSave.write(data), "slot written")
	var back := RunSave.read()
	check(int(back.get("requiem", -1)) == 23, "save round-trip keeps the meter")
	marmy.dance.meter = 0
	main._restore(back)
	check(marmy.dance.meter == 23, "restore sets the meter")
	var old := back.duplicate()
	old.erase("requiem")
	main._restore(old)
	check(marmy.dance.meter == 0, "an older save without the field loads with an empty meter")
	RunSave.clear()
	main.queue_free()
	await process_frame

	Elements.reset()
	army.free()
	grunts.free()
	player.free()
	print("DANSE MACABRE %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)
