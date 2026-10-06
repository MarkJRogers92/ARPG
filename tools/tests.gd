extends SceneTree
## Headless unit tests for the stat, upgrade and item systems.
##
##   godot --headless --path . -s tools/tests.gd
##
## Exit code is 0 when everything passes, 1 otherwise.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	seed(12345) # tests that touch randomness are deterministic
	_test_stat_math()
	_test_remove_source()
	_test_upgrades()

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED (%d checks)" % _checks)
	else:
		print("%d OF %d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL: ", message)


func _near(a: float, b: float, message: String, eps := 0.0001) -> void:
	_check(absf(a - b) <= eps, "%s (got %s, expected %s)" % [message, a, b])


# --- stats -------------------------------------------------------------------

func _test_stat_math() -> void:
	print("stat math")
	var s := PlayerStats.new()
	_near(s.bolt_damage, 10.0, "base bolt damage")
	_near(s.bolt_cooldown, 0.5, "base cooldown is 1 / rate")
	_near(s.hp, s.max_hp, "starts at full HP")

	# (base + ADD) * (1 + sum INCREASED) * product(1 + MORE)
	s.add_mod("t", "bolt_damage", PlayerStats.Op.ADD, 5.0)
	s.add_mod("t", "bolt_damage", PlayerStats.Op.INCREASED, 0.25)
	s.add_mod("t", "bolt_damage", PlayerStats.Op.INCREASED, 0.25)
	s.add_mod("t", "bolt_damage", PlayerStats.Op.MORE, 0.25)
	s.add_mod("t", "bolt_damage", PlayerStats.Op.MORE, 0.10)
	s.recalculate()
	_near(s.bolt_damage, (10.0 + 5.0) * 1.5 * 1.25 * 1.10, "ADD, then summed INCREASED, then multiplied MORE")

	# The global damage stat scales every weapon.
	var g := PlayerStats.new()
	g.add_mod("t", "damage", PlayerStats.Op.INCREASED, 0.2)
	g.recalculate()
	_near(g.bolt_damage, 12.0, "global damage scales bolts")
	_near(g.aura_damage, 6.0, "global damage scales the aura")

	var a := PlayerStats.new()
	a.add_mod("t", "armor", PlayerStats.Op.ADD, 100.0)
	a.recalculate()
	_near(a.damage_taken_factor(), 0.5, "100 armor halves damage")

	var c := PlayerStats.new()
	c.add_mod("t", "crit_chance", PlayerStats.Op.ADD, 5.0)
	c.recalculate()
	_near(c.crit_chance, 1.0, "crit chance is clamped to 100%")

	var r := PlayerStats.new()
	r.add_mod("t", "bolt_rate", PlayerStats.Op.INCREASED, 1.0)
	r.recalculate()
	_near(r.bolt_cooldown, 0.25, "doubling rate halves the cooldown")


func _test_remove_source() -> void:
	print("removing a modifier source")
	var s := PlayerStats.new()
	var before := s.values.duplicate()
	s.add_mod("gear:a", "max_hp", PlayerStats.Op.ADD, 50.0)
	s.add_mod("gear:a", "regen", PlayerStats.Op.ADD, 2.0)
	s.add_mod("gear:b", "max_hp", PlayerStats.Op.INCREASED, 0.5)
	s.recalculate()
	_near(s.max_hp, (100.0 + 50.0) * 1.5, "both sources apply")

	_check(s.remove_source("gear:a") == 2, "removing gear:a removes its 2 mods")
	s.recalculate()
	_near(s.max_hp, 150.0, "gear:b still applies alone")
	_near(s.regen, 0.0, "regen from gear:a is gone")

	s.remove_source("gear:b")
	s.recalculate()
	for stat: String in before:
		_near(s.values[stat], before[stat], "stat '%s' returns exactly to base" % stat)

	var h := PlayerStats.new()
	h.add_mod("x", "max_hp", PlayerStats.Op.ADD, 100.0)
	h.recalculate()
	h.hp = 200.0
	h.remove_source("x")
	h.recalculate()
	_near(h.hp, 100.0, "HP is clamped when max HP drops")


func _test_upgrades() -> void:
	print("upgrades")
	var s := PlayerStats.new()
	Upgrades.apply("bolt_damage", s)
	Upgrades.apply("bolt_damage", s)
	_near(s.bolt_damage, 10.0 * 1.25 * 1.25, "damage upgrade stacks multiplicatively")
	_check(Upgrades.level_of("bolt_damage", s) == 2, "level tracked")

	Upgrades.apply("aura", s)
	_check(s.aura_level == 1, "first aura level unlocks it")
	_near(s.aura_radius, 3.5, "first aura level doesn't change radius")
	Upgrades.apply("aura", s)
	_check(s.aura_level == 2, "second aura level")
	_near(s.aura_radius, 3.5 * 1.15, "later aura levels grow radius")

	Upgrades.apply("bolt_count", s)
	_check(s.bolt_count == 2, "multishot adds a bolt")

	var v := PlayerStats.new()
	v.hp = 50.0
	Upgrades.apply("max_hp", v)
	_near(v.max_hp, 125.0, "vitality raises max HP")
	_near(v.hp, 75.0, "vitality heals 25")

	var m := PlayerStats.new()
	for i in 20:
		var picks := Upgrades.roll(m)
		var ids := picks.map(func(p: Dictionary) -> String: return p["id"])
		_check(picks.size() == 3, "roll offers 3 choices")
		_check(ids.size() == Array(ids).filter(func(x: String) -> bool: return ids.count(x) == 1).size(), "no duplicate choices")
	# Max everything out: the pool should fall back to the heal.
	for id: String in Upgrades.DEFS:
		m.upgrade_levels[id] = Upgrades.DEFS[id]["max"]
	var fallback := Upgrades.roll(m)
	_check(fallback.size() == 1 and fallback[0]["id"] == "heal", "empty pool falls back to heal")
