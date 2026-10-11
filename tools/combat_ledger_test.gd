extends SceneTree
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
	var ledger := CombatLedger.new()
	ledger.tick(10.0, ["Magic Bolt"])
	ledger.tick(5.0, ["Magic Bolt", "Chain Lightning"])
	ledger.record("Magic Bolt", 15.0, "a")
	ledger.record("Magic Bolt", 15.0, "a")
	ledger.record("Chain Lightning", 20.0, "a")
	ledger.record("Magic Bolt", 0.0, "b")
	ledger.record("Magic Bolt", -2.0, "c")
	var report := ledger.report()
	check(report["total"] == 50.0, "real positive damage only")
	check(ledger.sources["Magic Bolt"]["hits"] == 2 and ledger.sources["Magic Bolt"]["targets"].size() == 1, "repeated same target counts once; hit count real")
	check(ledger.sources["Chain Lightning"]["active_seconds"] == 5.0, "late ability denominator not whole run")
	check(report["rows"][0]["dps"] == 2.0, "DPS is damage/availability time")
	ledger.tick(4.0, [])
	check(ledger.sources["Magic Bolt"]["active_seconds"] == 15.0, "unequipped ability time stops")
	var suspended := ledger.snapshot()
	var resumed := CombatLedger.new()
	resumed.restore(suspended)
	check(resumed.report()["total"] == report["total"] and resumed.epoch > ledger.epoch, "resume keeps totals and avoids recycled target IDs")
	resumed.tick(1.0, ["Chain Lightning"])
	check(resumed.sources["Chain Lightning"]["active_seconds"] == 6.0, "resume denominator continues")
	var legacy := CombatLedger.new()
	legacy.restore({}, {"Magic Bolt": 50.0})
	check(legacy.report()["rows"][0]["dps"] < 0.0 and not legacy.report()["rows"][0]["measured"], "no fabricated legacy denominator")
	check(CombatLedger.summary(report).contains("available combat seconds"), "denominator visible")
	check(not "Burning" in CombatLedger.available(PlayerStats.new(), 0) and not "Reactions" in CombatLedger.available(PlayerStats.new(), 0), "unavailable status sources do not claim whole-run active time")
	var swarm := EnemySwarm.new()
	swarm.name = "MetricsSwarm"
	swarm.capacity = 32
	root.add_child(swarm)
	var player := Player.new()
	player.stats = PlayerStats.new()
	Elements.reset()
	Elements.player = player
	Elements.swarms = [swarm]
	player.stats.crit_chance = 0.0
	player.stats.ignite_chance = 0.0
	player.stats.chill_chance = 0.0
	swarm.spawn(Vector2.ZERO)
	swarm.step(0.0, Vector2.ZERO)
	swarm.hp[0] = 5.0
	Elements.source = "Magic Bolt"
	Elements.hit(swarm, 0, 30.0)
	check(is_equal_approx(Elements.damage_by["Magic Bolt"], 5.0), "overkill clamped to actual HP")
	swarm.spawn(Vector2(1.0, 0.0))
	swarm.step(0.0, Vector2.ZERO)
	swarm.hp[0] = 10.0
	swarm.chill[0] = 2.0
	Elements.source = "Magic Bolt"
	Elements.hit(swarm, 0, 20.0, Elements.FIRE)
	var melt_bonus := 10.0 * (1.0 - 1.0 / Elements.MELT_MULT)
	check(is_equal_approx(Elements.damage_by["Reactions"], melt_bonus), "Melt proportional extra damage; no fabricated overkill")
	check(is_equal_approx(Elements.damage_by["Magic Bolt"], 15.0 - melt_bonus), "Melt base remains weapon source")
	check(is_equal_approx(Elements.metrics.report()["total"], 15.0), "split Melt sums once")
	check(Elements.metrics.reactions["Melt"]["triggers"] == 1 and is_equal_approx(Elements.metrics.reactions["Melt"]["damage"], melt_bonus), "Melt measured separately")
	# Queue one Shatter; explosion damages only living targets and is explicitly
	# credited as a reaction instead of relabeling the triggering lightning hit.
	swarm.spawn(Vector2.ZERO)
	swarm.spawn(Vector2(0.5, 0.0))
	swarm.step(0.0, Vector2.ZERO)
	for i in swarm.count: swarm.hp[i] = 100.0
	swarm.chill[0] = 2.0
	Elements.source = "Chain Lightning"
	Elements.hit(swarm, 0, 10.0, Elements.LIGHTNING)
	Elements.flush()
	check(Elements.metrics.reactions.has("Shatter") and Elements.metrics.reactions["Shatter"]["triggers"] == 1, "queued Shatter trigger accounted")
	check(Elements.metrics.reactions["Shatter"]["damage"] > 0.0, "real Shatter damage recorded")
	check(is_equal_approx(Elements.metrics.report()["total"], _sum(Elements.damage_by)), "all damage channels reconcile")
	# Subsequent Shock and shield multipliers affect base and Melt bonus equally;
	# proportional attribution still holds and preserves the old gameplay roll.
	swarm.chill[0] = 2.0
	swarm.shock[0] = 2.0
	swarm.direct_taken = 0.5
	swarm.hp[0] = 100.0
	var old_reactions := float(Elements.damage_by["Reactions"])
	var old_bolt := float(Elements.damage_by["Magic Bolt"])
	Elements.source = "Magic Bolt"
	Elements.hit(swarm, 0, 10.0, Elements.FIRE)
	var base := 10.0 * Elements.SHOCK_BONUS * 0.5
	check(is_equal_approx(Elements.damage_by["Magic Bolt"] - old_bolt, base) and is_equal_approx(Elements.damage_by["Reactions"] - old_reactions, base * (Elements.MELT_MULT - 1.0)), "Melt attribution remains correct with subsequent multiplicative modifiers")
	var incidental := CombatLedger.new()
	incidental.tick(0.1, [])
	incidental.record("Lingering", 2.0, "one")
	incidental.record("Lingering", 2.0, "two")
	check(incidental.sources["Lingering"]["active_seconds"] == 0.1, "outside-availability hits count one real combat frame, not one per target")
	Elements.reset()
	Elements.player = null
	Elements.swarms.clear()
	swarm.free()
	player.free()
	print("COMBAT LEDGER %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)

func _sum(data: Dictionary) -> float:
	var total := 0.0
	for value: float in data.values(): total += value
	return total
