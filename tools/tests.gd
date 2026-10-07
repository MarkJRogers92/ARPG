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
	_run(&"_test_stat_math", _test_stat_math())
	_run(&"_test_remove_source", _test_remove_source())
	_run(&"_test_upgrades", _test_upgrades())
	_run(&"_test_generation", _test_generation())
	_run(&"_test_rarity_distribution", _test_rarity_distribution())
	_run(&"_test_serialization", _test_serialization())
	_run(&"_test_inventory", _test_inventory())
	_run(&"_test_loot", _test_loot())
	_run(&"_test_director", _test_director())
	_run(&"_test_skill_data", _test_skill_data())
	_run(&"_test_skill_tree", _test_skill_tree())
	_run(&"_test_skill_points", _test_skill_points())
	_run(&"_test_new_weapons", _test_new_weapons())
	_run(&"_test_meta_progress", _test_meta_progress())
	_run(&"_test_elite_rate", _test_elite_rate())
	_run(&"_test_legendaries", _test_legendaries())
	_run(&"_test_realms", _test_realms())
	_run(&"_test_realm_progress", _test_realm_progress())
	_run(&"_test_classes_and_settings", _test_classes_and_settings())
	_run(&"_test_sounds", _test_sounds())
	_run(&"_test_asset_props", _test_asset_props())
	_run(&"_test_asset_placement", _test_asset_placement())
	# These need nodes in the running tree, which only exists after this returns.
	_finish.call_deferred()


func _finish() -> void:
	_run(&"_test_elites_and_knockback", _test_elites_and_knockback())
	_run(&"_test_enemy_shots", _test_enemy_shots())
	_run(&"_test_elements", _test_elements())
	_run(&"_test_army", _test_army())
	_run(&"_test_heroes", _test_heroes())
	_run(&"_test_events", _test_events())
	_run(&"_test_obstacles", _test_obstacles())
	_run(&"_test_fixes", _test_fixes())
	_run(&"_test_landmarks", _test_landmarks())
	_run(&"_test_minion_roles", _test_minion_roles())
	_run(&"_test_specialists", _test_specialists())
	_run(&"_test_ferryman", _test_ferryman())
	_run(&"_test_new_tools", _test_new_tools())
	_run(&"_test_final_mechanics", _test_final_mechanics())
	_run(&"_test_replayability", _test_replayability())
	_run(&"_test_rifts", _test_rifts())
	_run(&"_test_dawn", _test_dawn())
	_run(&"_test_veterans", _test_veterans())
	_run(&"_test_evolutions", _test_evolutions())
	_run(&"_test_rival", _test_rival())
	_run(&"_test_ascension", _test_ascension())
	_run(&"_test_stances", _test_stances())
	_run(&"_test_soul_trails_and_death", _test_soul_trails_and_death())
	_run(&"_test_nemesis", _test_nemesis())
	_run(&"_test_slow_motion_ends", _test_slow_motion_ends())
	_run(&"_test_late_leveling", _test_late_leveling())

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED (%d checks)" % _checks)
	else:
		print("%d OF %d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


## A test that hits a script error stops early and returns null instead of
## true: count that as a failure, so a crash can't pass silently.
func _run(test_name: StringName, finished) -> void:
	_checks += 1
	if finished != true:
		_failures += 1
		print("  FAIL: %s stopped early (script error above)" % test_name)


## Deletes the test save and its backup and temp files.
func _wipe_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path + suffix))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL: ", message)


func _near(a: float, b: float, message: String, eps := 0.0001) -> void:
	_check(absf(a - b) <= eps, "%s (got %s, expected %s)" % [message, a, b])


# --- stats -------------------------------------------------------------------

func _test_stat_math() -> bool:
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
	return true



func _test_remove_source() -> bool:
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
	_near(s.regen, PlayerStats.BASE["regen"], "regen from gear:a is gone")

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
	return true



func _test_upgrades() -> bool:
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

	var bolts_before := s.bolt_count
	Upgrades.apply("bolt_count", s)
	_check(s.bolt_count == bolts_before + 1, "multishot adds a bolt")

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
	# (Every weapon is maxed with its catalyst, so the evolutions come first.)
	_check(Upgrades.roll(m)[0]["id"].begins_with(Evolutions.PREFIX), "with everything maxed, an evolution is offered")
	for id: String in Evolutions.DEFS:
		m.upgrade_levels[Evolutions.PREFIX + id] = 1
	var fallback := Upgrades.roll(m)
	_check(fallback.size() == 1 and fallback[0]["id"] == "heal", "empty pool falls back to heal")
	_check(Upgrades.is_exhausted(fallback), "a heal-only roll counts as exhausted")
	_check(not Upgrades.is_exhausted(Upgrades.roll(PlayerStats.new())), "a normal roll is not exhausted")


# --- items -------------------------------------------------------------------
	return true


func _test_generation() -> bool:
	print("item generation")
	var checked := 0
	for slot in ItemData.SLOTS:
		for rarity in [ItemData.Rarity.NORMAL, ItemData.Rarity.MAGIC, ItemData.Rarity.RARE, ItemData.Rarity.LEGENDARY]:
			for ilvl in [1, 10, 30]:
				for n in 25:
					var item := ItemGenerator.generate_with(ilvl, rarity, slot)
					checked += 1
					_validate_item(item, slot, rarity, ilvl)
	_check(checked == 6 * 4 * 3 * 25, "generated every combination")

	# Item level scaling: flat stats grow fully, percentage stats more slowly,
	# and magic find not at all.
	var flat := ItemData.ilvl_scale(21, "max_hp", PlayerStats.Op.ADD)
	var pct := ItemData.ilvl_scale(21, "damage", PlayerStats.Op.INCREASED)
	_near(flat, 1.0 + 0.06 * 20, "flat stats scale at the full rate")
	_near(pct, 1.0 + 0.06 * 0.35 * 20, "percentage stats scale at a reduced rate")
	_check(pct < flat, "percentage stats grow slower than flat ones")
	_near(ItemData.ilvl_scale(60, "magic_find", PlayerStats.Op.ADD), 1.0, "magic find never scales")
	_near(ItemData.ilvl_scale(60, "crit_chance", PlayerStats.Op.ADD), 1.0 + 0.06 * 0.35 * 59, "fractional ADD stats count as percentage")

	# Names: Magic keeps the base name, Rare gets its own.
	var magic := ItemGenerator.generate_with(5, ItemData.Rarity.MAGIC, "weapon")
	_check(magic.name.contains(magic.base_name), "magic name includes the base type ('%s')" % magic.name)
	var rare := ItemGenerator.generate_with(5, ItemData.Rarity.RARE, "weapon")
	_check(not rare.name.contains(rare.base_name) and rare.name.contains(" "), "rare gets a unique name ('%s')" % rare.name)

	# On average, better rarities are stronger.
	var avg := {}
	for rarity in [ItemData.Rarity.NORMAL, ItemData.Rarity.MAGIC, ItemData.Rarity.RARE, ItemData.Rarity.LEGENDARY]:
		var total := 0.0
		for n in 300:
			total += ItemGenerator.generate_with(20, rarity, ItemData.SLOTS.pick_random()).score()
		avg[rarity] = total / 300.0
	_check(avg[0] < avg[1] and avg[1] < avg[2] and avg[2] < avg[3],
			"average score rises with rarity %s" % [avg])
	return true



func _validate_item(item: Item, slot: String, rarity: int, ilvl: int) -> void:
	var tag := "%s %s ilvl %d" % [ItemData.rarity_name(rarity), slot, ilvl]
	_check(item.slot == slot and item.rarity == rarity and item.ilvl == ilvl, "%s: basic fields" % tag)
	_check(item.implicit.size() == 1, "%s: exactly one implicit" % tag)
	_check(item.name != "" and item.base_name != "", "%s: has a name" % tag)

	var rules: Dictionary = ItemData.RARITIES[rarity]
	var pool_size := 0
	for a: Dictionary in ItemData.AFFIXES:
		if slot in a["slots"] and rarity >= a.get("min_rarity", ItemData.Rarity.MAGIC):
			pool_size += 1
	var lo: int = rules["affixes"][0]
	var hi: int = mini(rules["affixes"][1], pool_size)
	_check(item.affixes.size() >= mini(lo, hi) and item.affixes.size() <= hi,
			"%s: affix count %d within [%d, %d]" % [tag, item.affixes.size(), lo, hi])

	var seen_ids := {}
	var seen_stats := {}
	for mod in item.affixes:
		var def := ItemData.affix(mod["id"])
		_check(slot in def["slots"], "%s: affix %s is allowed on this slot" % [tag, mod["id"]])
		_check(rarity >= def.get("min_rarity", ItemData.Rarity.MAGIC), "%s: affix %s meets its min rarity" % [tag, mod["id"]])
		_check(not seen_ids.has(mod["id"]), "%s: no duplicate affix %s" % [tag, mod["id"]])
		seen_ids[mod["id"]] = true
		var key := "%s/%d" % [mod["stat"], mod["op"]]
		_check(not seen_stats.has(key), "%s: no two affixes on %s" % [tag, key])
		seen_stats[key] = true

		var k: float = ItemData.ilvl_scale(ilvl, def["stat"], def["op"]) if def.get("scales", true) else 1.0
		var floor_t: float = rules["luck"]
		var min_v: float = lerpf(def["min"], def["max"], floor_t) * k - def["step"]
		var max_v: float = def["max"] * k + def["step"]
		_check(mod["value"] >= min_v and mod["value"] <= max_v,
				"%s: %s value %s within [%s, %s]" % [tag, mod["id"], mod["value"], min_v, max_v])
	for line in item.description_lines():
		_check(line != "", "%s: modifier has text" % tag)


func _test_rarity_distribution() -> bool:
	print("rarity distribution")
	var n := 40000
	var counts := [0, 0, 0, 0]
	for i in n:
		counts[ItemGenerator.roll_rarity(0.0)] += 1
	var expected := [0.60, 0.30, 0.09, 0.01]
	var tolerance := [0.02, 0.02, 0.012, 0.004]
	for r in 4:
		_near(float(counts[r]) / n, expected[r], "%s share at no magic find" % ItemData.rarity_name(r), tolerance[r])

	var boosted_rare := 0
	for i in n:
		if ItemGenerator.roll_rarity(1.0) >= ItemData.Rarity.RARE:
			boosted_rare += 1
	var base_rare := float(counts[2] + counts[3]) / n
	_check(float(boosted_rare) / n > base_rare * 1.7,
			"magic find 100%% roughly doubles Rare+ (%.3f -> %.3f)" % [base_rare, float(boosted_rare) / n])
	return true



func _test_serialization() -> bool:
	print("serialization")
	for n in 60:
		var item := ItemGenerator.generate(15, 0.5)
		# var_to_str keeps ints as ints, which JSON would not.
		var copy := Item.from_dict(str_to_var(var_to_str(item.to_dict())))
		_check(copy.name == item.name and copy.slot == item.slot and copy.rarity == item.rarity
				and copy.ilvl == item.ilvl and copy.base_name == item.base_name, "basic fields survive a round trip")
		_check(_same_mods(copy.modifiers(), item.modifiers()), "modifiers survive a round trip")
		_check(copy.uid != item.uid, "a copy is a new item")
	return true



func _test_inventory() -> bool:
	print("inventory and stats")
	var s := PlayerStats.new()
	var base := s.values.duplicate()
	var inv := Inventory.new(s)

	var wand_a := _make_item("weapon", [{"stat": "bolt_damage", "op": PlayerStats.Op.ADD, "value": 5.0}])
	var wand_b := _make_item("weapon", [{"stat": "bolt_damage", "op": PlayerStats.Op.INCREASED, "value": 1.0}])
	var cap := _make_item("helm", [{"stat": "max_hp", "op": PlayerStats.Op.ADD, "value": 30.0}])

	_check(inv.pickup(wand_a) == "equipped", "first weapon is worn straight away")
	_near(s.bolt_damage, 15.0, "equipped weapon changes stats")
	_check(inv.pickup(wand_b) == "backpack", "second weapon goes to the backpack")
	_near(s.bolt_damage, 15.0, "backpack items don't count")

	inv.equip(wand_b)
	_near(s.bolt_damage, 20.0, "swapping replaces the old weapon's bonus (not stacked)")
	_check(inv.equipped["weapon"] == wand_b and inv.backpack.has(wand_a) and not inv.backpack.has(wand_b),
			"swap moves the old weapon to the backpack")

	s.hp = s.max_hp
	inv.pickup(cap)
	_near(s.max_hp, 130.0, "helm adds max HP")
	_near(s.hp, 100.0, "equipping +max HP doesn't heal")
	inv.unequip("helm")
	_near(s.max_hp, 100.0, "unequipping removes the bonus")
	_check(inv.backpack.has(cap), "unequipped item lands in the backpack")

	inv.unequip("weapon")
	for stat: String in base:
		_near(s.values[stat], base[stat], "stat '%s' is back to base with nothing equipped" % stat)

	# Backpack capacity.
	var fill := Inventory.new(PlayerStats.new())
	fill.pickup(_make_item("weapon", []))
	for i in Inventory.BACKPACK_SIZE:
		_check(fill.pickup(_make_item("weapon", [])) == "backpack", "backpack slot %d fills" % i)
	_check(fill.pickup(_make_item("weapon", [])) == "full", "a full backpack refuses more")
	_check(fill.backpack.size() == Inventory.BACKPACK_SIZE, "refused item isn't added")

	# Upgrade detection.
	var u := PlayerStats.new()
	var uinv := Inventory.new(u)
	var weak := _make_item("ring", [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.05}])
	var strong := _make_item("ring", [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.30}])
	uinv.pickup(weak)
	uinv.pickup(strong)
	_check(uinv.is_upgrade(strong), "stronger ring is flagged as an upgrade")
	_check(uinv.equip_upgrades() == 1 and uinv.equipped["ring"] == strong, "equip_upgrades swaps in the better ring")
	_check(uinv.equip_upgrades() == 0, "and then there is nothing left to upgrade")
	return true



func _make_item(slot: String, mods: Array) -> Item:
	var item := Item.new()
	item.slot = slot
	item.base_name = "Test"
	item.name = "Test " + slot
	item.implicit.assign(mods)
	return item


## Modifier lists equal, allowing for float noise from text serialization.
func _same_mods(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i]["stat"] != b[i]["stat"] or a[i]["op"] != b[i]["op"]:
			return false
		if absf(a[i]["value"] - b[i]["value"]) > 1e-9:
			return false
	return true


func _test_loot() -> bool:
	print("loot drops")
	var stats := PlayerStats.new()
	var inv := Inventory.new(stats)
	var loot := LootManager.new()
	var picked: Array = []
	var full_signals := [0]
	loot.item_picked.connect(func(item: Item, result: String) -> void: picked.append([item, result]))
	loot.backpack_full.connect(func() -> void: full_signals[0] += 1)

	var near := _make_item("weapon", [])
	var far := _make_item("helm", [])
	loot.drop(near, Vector2(1, 0))
	loot.drop(far, Vector2(30, 0))
	_check(loot.drops.size() == 2, "two items on the ground")

	loot.step(0.016, Vector2(-30, 0), 3.0, inv)
	_check(picked.is_empty() and loot.drops.size() == 2, "nothing is picked up out of range")

	loot.step(0.016, Vector2(0, 0), 3.0, inv)
	_check(picked.size() == 1 and picked[0][0] == near and picked[0][1] == "equipped", "walking over loot picks it up and wears it")
	_check(loot.drops.size() == 1, "picked-up item leaves the ground")
	_check(inv.equipped.get("weapon") == near, "it ended up in the inventory")

	# A full backpack leaves the item on the ground and warns (rate-limited).
	for i in Inventory.BACKPACK_SIZE:
		inv.backpack.append(_make_item("helm", []))
	var blocked := _make_item("weapon", [])
	var node := loot.drop(blocked, Vector2(0, 0))
	_check(node != null, "drop returns the ground item")
	var before := loot.drops.size()
	loot.step(0.016, Vector2(0, 0), 3.0, inv)
	loot.step(0.016, Vector2(0, 0), 3.0, inv)
	_check(loot.drops.size() == before, "full backpack: the item stays on the ground")
	_check(full_signals[0] == 1, "full backpack: warns once, not every frame (%d)" % full_signals[0])

	# Trimming removes the lowest rarity first.
	var small := LootManager.new()
	small.max_drops = 5
	var legendary := _make_item("ring", [])
	legendary.rarity = ItemData.Rarity.LEGENDARY
	small.drop(legendary, Vector2.ZERO)
	for i in 5:
		small.drop(_make_item("ring", []), Vector2(i, 0))
	_check(small.drops.size() == 5, "drops are capped at max_drops")
	_check(small.drops.any(func(d: LootDrop) -> bool: return d.item == legendary), "the legendary survived the cleanup")

	# Kill drops respect chance.
	var rolls := LootManager.new()
	rolls.budgeted = false
	for i in 50:
		rolls.roll_kill_drop(Vector2.ZERO, 0.0, 0.0, 5, 0.0)
	_check(rolls.drops.is_empty(), "0% chance never drops")
	for i in 10:
		rolls.roll_kill_drop(Vector2.ZERO, 1.0, 0.0, 5, 0.0)
	_check(rolls.drops.size() == 10, "100% chance always drops")
	for d in rolls.drops:
		_check(d.item.ilvl == 5, "dropped items use the given item level")

	# The drop budget: a flood of guaranteed rolls only yields what the tokens allow.
	var budget := LootManager.new()
	budget.drops_per_minute = 6.0
	budget.token_cap = 2.0
	for i in 100:
		budget.roll_kill_drop(Vector2.ZERO, 1.0, 0.0, 5, 0.0)
	_check(budget.drops.size() == 1, "budget: only the starting token's worth drops at once (%d)" % budget.drops.size())
	var inv2 := Inventory.new(PlayerStats.new())
	for i in 600: # 10 seconds at 60 fps = 1 token at 6 drops/minute
		budget.step(1.0 / 60.0, Vector2(999, 999), 3.0, inv2)
	for i in 100:
		budget.roll_kill_drop(Vector2.ZERO, 1.0, 0.0, 5, 0.0)
	_check(budget.drops.size() == 2, "budget: tokens refill with time (%d drops)" % budget.drops.size())
	for i in 6000: # a long quiet stretch must not bank more than the cap
		budget.step(1.0 / 60.0, Vector2(999, 999), 3.0, inv2)
	for i in 100:
		budget.roll_kill_drop(Vector2.ZERO, 1.0, 0.0, 5, 0.0)
	_check(budget.drops.size() == 4, "budget: banked tokens are capped (%d drops)" % budget.drops.size())

	loot.free()
	small.free()
	rolls.free()
	budget.free()
	return true



func _test_director() -> bool:
	print("wave director")
	var grunt := EnemySwarm.new()
	var brute := EnemySwarm.new()
	brute.spawn_start_time = 45.0
	brute.spawn_ramp_seconds = 300.0
	brute.spawn_share = 0.14
	_near(grunt.spawn_weight(0.0), 1.0, "a type with no schedule is always at full weight")
	_near(brute.spawn_weight(0.0), 0.0, "scheduled type is absent before its start time")
	_near(brute.spawn_weight(45.0), 0.0, "weight is 0 exactly at the start time")
	_near(brute.spawn_weight(195.0), 0.07, "weight ramps linearly (half way)")
	_near(brute.spawn_weight(345.0), 0.14, "weight reaches its share at the end of the ramp")
	_near(brute.spawn_weight(5000.0), 0.14, "and stays there")

	var d := WaveDirector.new()
	d.base_rate = 2.0
	d.rate_growth = 0.1
	d.rate_acceleration = 0.0
	d.hp_growth_seconds = 100.0
	d.hp_squared_seconds = 0.0
	d.elapsed = 50.0
	_near(d.spawn_rate(), 7.0, "spawn rate grows with time")
	_near(d.hp_multiplier(), 1.5, "enemy HP multiplier grows with time")
	d.rate_acceleration = 0.001
	d.hp_squared_seconds = 100.0
	_near(d.spawn_rate(), 7.0 + 0.001 * 2500.0, "acceleration adds a squared term to the spawn rate")
	_near(d.hp_multiplier(), 1.5 + 0.25, "squared HP term")
	_check(ItemData.ilvl_for_player_level(1) == 1 and ItemData.ilvl_for_player_level(3) == 2
			and ItemData.ilvl_for_player_level(41) == 21, "item level follows player level at half rate")

	grunt.free()
	brute.free()
	d.free()


# --- skill tree --------------------------------------------------------------
	return true


func _test_skill_data() -> bool:
	print("skill tree data")
	var names := {}
	var positions := {}
	for id: String in SkillData.ids():
		var def: Dictionary = SkillData.NODES[id]
		for link: String in def["links"]:
			_check(SkillData.NODES.has(link), "%s links to a node that exists (%s)" % [id, link])
		_check(not names.has(def["name"]), "%s: unique name '%s'" % [id, def["name"]])
		names[def["name"]] = true
		_check(not positions.has(def["pos"]), "%s: unique grid position %s" % [id, def["pos"]])
		positions[def["pos"]] = true
		_check(SkillData.BRANCHES.has(def["branch"]), "%s: known branch" % id)
		_check(SkillData.cost(id) == SkillData.COSTS[def["tier"]], "%s: cost follows tier" % id)

		var has_downside := false
		var has_upside := false
		for mod: Dictionary in def["mods"]:
			_check(PlayerStats.BASE.has(mod["stat"]), "%s: stat '%s' exists" % [id, mod["stat"]])
			_check(ItemData.STAT_INFO.has(mod["stat"]), "%s: stat '%s' has display info" % [id, mod["stat"]])
			if mod["value"] < 0.0:
				has_downside = true
			else:
				has_upside = true
		if id != SkillData.ROOT:
			_check(not SkillData.description_lines(id).is_empty(), "%s: has tooltip text" % id)
		if def["tier"] == SkillData.Tier.KEYSTONE:
			_check(has_upside and has_downside, "%s: a keystone has both an upside and a downside" % id)
	_check(SkillData.NODES[SkillData.ROOT]["mods"].is_empty(), "the origin grants nothing")

	# Every node is reachable from the origin, and links are symmetric.
	var seen := {SkillData.ROOT: true}
	var frontier: Array = [SkillData.ROOT]
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		for n: String in SkillData.neighbors(current):
			_check(SkillData.neighbors(n).has(current), "link %s <-> %s is symmetric" % [current, n])
			if not seen.has(n):
				seen[n] = true
				frontier.append(n)
	_check(seen.size() == SkillData.NODES.size(), "all %d nodes connect to the origin (%d reachable)" % [SkillData.NODES.size(), seen.size()])
	return true



func _test_skill_tree() -> bool:
	print("skill tree rules")
	var base := PlayerStats.new().values.duplicate()
	var stats := PlayerStats.new()
	var tree := SkillTree.new(stats)

	_check(tree.is_allocated(SkillData.ROOT) and tree.points == 0 and tree.spent() == 0, "starts with only the origin and no points")
	_check(not tree.can_allocate("o1"), "can't allocate without points")
	tree.add_points(10)
	_check(tree.can_allocate("o1"), "can allocate an adjacent node with points")
	_check(not tree.can_allocate("o2"), "can't skip ahead to a node that isn't linked to anything owned")
	_check(tree.allocate("o1") and tree.points == 9, "allocating spends the cost")
	_near(stats.bolt_cooldown, 1.0 / (PlayerStats.BASE["bolt_rate"] * 1.05), "o1 raises bolt speed 5%")
	_check(not tree.allocate("o1"), "can't allocate a node twice")

	_check(tree.allocate("o2"), "o2 is now reachable")
	_check(tree.allocate("o5") and tree.points == 5, "a keystone costs 3")
	_check(stats.bolt_count == int(PlayerStats.BASE["bolt_count"]) + 2, "Arcane Barrage adds 2 bolts")
	_near(stats.bolt_damage, 10.0 * 0.70 * 1.05, "...and reduces bolt damage by 30% (then +5% damage)")

	var poor := SkillTree.new(PlayerStats.new())
	poor.add_points(2)
	poor.allocate("o1")
	poor.allocate("o2")
	_check(not poor.can_allocate("o5") and poor.is_reachable("o5"), "adjacent but unaffordable: reachable yet not allocatable")

	# Refunding.
	_check(not tree.can_refund(SkillData.ROOT), "the origin can't be refunded")
	_check(not tree.can_refund("o1"), "o1 can't go while o2 hangs off it")
	_check(tree.can_refund("o5"), "a leaf can be refunded")
	_check(tree.refund("o5") and tree.points == 8, "refund returns the cost")
	_check(stats.bolt_count == int(PlayerStats.BASE["bolt_count"]), "refunding removes the bonus")
	tree.allocate("o3")
	tree.allocate("o4")
	_check(not tree.can_refund("o2"), "o2 can't go while o3 and o4 depend on it")
	_check(tree.can_refund("o3") and tree.can_refund("o4"), "the two leaves can")

	var before_reset := tree.spent()
	var returned := tree.reset()
	_check(returned == before_reset and tree.spent() == 0, "reset returns everything spent")
	_check(tree.points == 10, "...so all 10 points are back (%d)" % tree.points)
	for stat: String in base:
		_near(stats.values[stat], base[stat], "stat '%s' is exactly back to base after reset" % stat)

	# Property: with unlimited points every node can be allocated, and the tree
	# can then be peeled back to nothing, in any order, restoring stats exactly.
	var big := PlayerStats.new()
	var all := SkillTree.new(big)
	all.add_points(1000)
	var progress := true
	while progress:
		progress = false
		for id: String in SkillData.ids():
			if all.allocate(id):
				progress = true
	_check(all.allocated.size() == SkillData.NODES.size(), "every node can be allocated (%d of %d)" % [all.allocated.size(), SkillData.NODES.size()])
	var total := 0
	for id: String in SkillData.ids():
		if id != SkillData.ROOT:
			total += SkillData.cost(id)
	_check(all.spent() == total and all.points == 1000 - total, "the whole tree costs %d points" % total)

	var steps := 0
	while all.spent() > 0:
		var options: Array[String] = []
		for id: String in all.allocated:
			if all.can_refund(id):
				options.append(id)
		_check(not options.is_empty(), "there is always a node that can be peeled off (%d owned)" % all.allocated.size())
		if options.is_empty():
			break
		all.refund(options.pick_random())
		steps += 1
	_check(all.points == 1000 and steps == SkillData.NODES.size() - 1, "peeled back in %d steps and every point returned" % steps)
	for stat: String in base:
		_near(big.values[stat], base[stat], "stat '%s' exact after random peel-back" % stat)

	# Serialization.
	var s1 := PlayerStats.new()
	var t1 := SkillTree.new(s1)
	t1.add_points(12)
	for id in ["d1", "d2", "d5", "u1", "u2", "u4"]:
		t1.allocate(id)
	var saved: Dictionary = str_to_var(var_to_str(t1.to_dict()))
	var s2 := PlayerStats.new()
	var t2 := SkillTree.new(s2)
	t2.restore(saved)
	_check(t2.points == t1.points and t2.allocated.size() == t1.allocated.size(), "restore brings back points and nodes")
	for stat: String in base:
		_near(s2.values[stat], s1.values[stat], "restored tree gives the same '%s'" % stat)
	return true



func _test_skill_points() -> bool:
	print("earning skill points")
	var p := Player.new()
	p.stats.xp_to_next = p.xp_for_level(p.stats.level)
	var signals: Array[int] = []
	p.skill_points_gained.connect(func(n: int) -> void: signals.append(n))
	p.add_xp(1)
	_check(p.skills.points == 0 and signals.is_empty(), "no point before level 2 (level %d)" % p.stats.level)
	p.add_xp(1_000_000)
	_check(p.skills.points == floori(p.stats.level / 2.0), "one point per 2 levels (level %d -> %d points)" % [p.stats.level, p.skills.points])
	_check(signals.size() == 1 and signals[0] == p.skills.points, "the gain is announced once with the total")

	var q := Player.new()
	q.skill_point_every_levels = 0
	q.stats.xp_to_next = q.xp_for_level(1)
	q.add_xp(1_000_000)
	_check(q.skills.points == 0, "0 turns skill points off")
	p.free()
	q.free()


# --- abilities, enemies, meta progression ----------------------------------------
	return true


func _test_new_weapons() -> bool:
	print("new weapons")
	var s := PlayerStats.new()
	_check(s.lightning_level == 0 and s.orbit_level == 0 and s.nova_level == 0, "new weapons start locked")
	Upgrades.apply("lightning", s)
	_check(s.lightning_level == 1 and s.lightning_chains == 3, "first Chain Lightning rank unlocks it with 3 jumps")
	_near(s.lightning_damage, 16.0, "first rank keeps base lightning damage")
	Upgrades.apply("lightning", s)
	_check(s.lightning_level == 2 and s.lightning_chains == 4, "second rank adds a jump")
	_near(s.lightning_damage, 20.0, "second rank: +25% lightning damage")
	Upgrades.apply("orbit", s)
	_check(s.orbit_level == 1 and s.orbit_count == 2, "Spirit Blades unlock with two blades")
	Upgrades.apply("orbit", s)
	_check(s.orbit_count == 3, "next rank adds a blade")
	Upgrades.apply("nova", s)
	_check(s.nova_level == 1, "Arcane Nova unlocks")
	_near(s.nova_cooldown, 4.0, "nova fires every 4 s at first")
	s.add_mod("t", "damage", PlayerStats.Op.MORE, 1.0)
	s.recalculate()
	_near(s.nova_damage, 48.0, "global damage multiplies the new weapons too")
	for id in ["lightning", "orbit", "nova"]:
		_check(Upgrades.DEFS.has(id) and Hud.CARD_COLORS.has(id), "%s has a level-up card with a color" % id)
	return true



func _test_meta_progress() -> bool:
	print("meta progression")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta.save"
	_wipe_save()
	MetaProgress.load_save()
	_check(MetaProgress.shards == 0 and MetaProgress.rank("vigor") == 0, "no save means a fresh start")
	MetaProgress.add_shards(30)
	_check(MetaProgress.cost("vigor") == 10, "first Vigor rank costs 10")
	_check(MetaProgress.buy("vigor"), "can buy with enough shards")
	_check(MetaProgress.shards == 20 and MetaProgress.rank("vigor") == 1, "buying spends shards and adds a rank")
	_check(MetaProgress.cost("vigor") == 16, "ranks get pricier (10 * 1.6)")
	MetaProgress.load_save()
	_check(MetaProgress.shards == 20 and MetaProgress.rank("vigor") == 1, "progress survives a reload from disk")
	var s := PlayerStats.new()
	MetaProgress.apply(s)
	_near(s.max_hp, 108.0, "a Vigor rank gives +8% max HP")
	_near(s.hp, s.max_hp, "a run starts at full (boosted) HP")
	MetaProgress.apply(s)
	_near(s.max_hp, 108.0, "applying twice doesn't stack")
	MetaProgress.shards = 1000
	while MetaProgress.buy("insight"):
		pass
	_check(MetaProgress.rank("insight") == 3 and MetaProgress.cost("insight") == -1, "upgrades stop at their max rank")
	_check(MetaProgress.rerolls() == 3, "Insight ranks give rerolls")
	_check(MetaProgress.run_bonus(330.0, 450) == 13, "run bonus: 2 per full minute + 1 per 150 kills")
	_wipe_save()
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()
	return true



func _test_elites_and_knockback() -> bool:
	print("elites and knockback")
	var swarm := EnemySwarm.new()
	swarm.capacity = 16
	root.add_child(swarm)
	swarm.spawn(Vector2(1, 0), 1.0, true)
	swarm.spawn(Vector2(0, 2), 1.0)
	_check(swarm.is_elite(0) and not swarm.is_elite(1), "elite flag follows the spawn")
	_near(swarm.hp[0], swarm.max_hp * swarm.elite_hp_mult, "elites have more HP")
	swarm.step(0.0, Vector2.ZERO) # rebuilds the hash; zero time moves nothing
	swarm.knockback(Vector2.ZERO, 4.0, 2.0)
	_check(swarm.pos[1].y > 2.5, "knockback pushes enemies away from the center (y=%.2f)" % swarm.pos[1].y)
	_check(swarm.pos[0].x > 1.0 and swarm.pos[0].x - 1.0 < swarm.pos[1].y - 2.0, "elites are shoved less (they're bigger) (%s, %s)" % [swarm.pos[0], swarm.pos[1]])
	var got := []
	swarm.enemy_died.connect(func(_at: Vector2, xp: int) -> void: got.append(xp))
	swarm.elite_died.connect(func(_at: Vector2) -> void: got.append("elite"))
	swarm.damage(0, 1.0e9)
	_check(got == [swarm.xp_value * swarm.elite_xp_mult, "elite"], "an elite's death gives extra XP and says so (%s)" % [got])
	swarm.knockback_taken = 0.0
	var before := swarm.pos[1]
	swarm.knockback(Vector2.ZERO, 10.0, 5.0)
	_check(swarm.pos[1] == before, "knockback_taken = 0 means immovable (bosses)")
	swarm.free()
	return true



func _test_enemy_shots() -> bool:
	print("enemy shots and dash")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var shots := EnemyShots.new()
	root.add_child(shots)
	shots.spawn(Vector2(0.3, 0), Vector2.RIGHT, 1.0, 10.0)
	shots.step(0.016, player)
	_near(player.stats.hp, player.stats.max_hp - 10.0, "a shot that reaches the hero hurts")
	_check(shots.count == 0, "and is used up")
	player._dash_time = 0.1
	var hp := player.stats.hp
	shots.spawn(Vector2(0.3, 0), Vector2.RIGHT, 1.0, 10.0)
	shots.step(0.016, player)
	player.take_damage(50.0)
	_near(player.stats.hp, hp, "nothing hurts while dashing")
	_check(shots.count == 1, "a dodged shot keeps flying")
	shots.free()
	player.free()
	return true



func _test_elite_rate() -> bool:
	print("elite rate")
	var d := WaveDirector.new()
	_near(d.elite_rate(), 0.0, "no elites at the start")
	d.elapsed = d.elite_start_time + 60.0
	_near(d.elite_rate(), d.elites_per_minute + d.elites_per_minute_growth, "elite rate grows each minute")
	d.elapsed = 100000.0
	_near(d.elite_rate(), d.elites_per_minute_max, "and caps")
	d.free()
	return true



func _test_legendaries() -> bool:
	print("legendary powers")
	for slot in ItemData.SLOTS:
		_check(not ItemData.powers_for(slot).is_empty(), "%s has legendary powers" % slot)
	for id: String in ItemData.POWERS:
		var def: Dictionary = ItemData.POWERS[id]
		_check(def["slot"] in ItemData.SLOTS and def.has("desc") and def.has("name"), "power %s is complete" % id)
		for mod: Dictionary in def.get("mods", []):
			_check(PlayerStats.BASE.has(mod["stat"]) and ItemData.STAT_INFO.has(mod["stat"]), "power %s: stat %s exists" % [id, mod["stat"]])
	for k in 60:
		var slot: String = ItemData.SLOTS[k % ItemData.SLOTS.size()]
		var item := ItemGenerator.generate_with(10, ItemData.Rarity.LEGENDARY, slot)
		_check(item.power != "" and ItemData.POWERS[item.power]["slot"] == slot, "legendary %s gets a %s power" % [item.name, slot])
		_check(not item.name.contains("%"), "legendary name is filled in (%s)" % item.name)
	var rare := ItemGenerator.generate_with(10, ItemData.Rarity.RARE, "ring")
	_check(rare.power == "", "only legendaries have powers")

	var helm := ItemGenerator.generate_with(5, ItemData.Rarity.LEGENDARY, "helm")
	helm.power = "storm_eye"
	var copy := Item.from_dict(helm.to_dict())
	_check(copy.power == "storm_eye", "the power survives serialization")
	var s := PlayerStats.new()
	var inv := Inventory.new(s)
	inv.pickup(helm)
	_check(s.lightning_level == 1 and s.lightning_chains == 5, "a power's stat mods apply when worn (lightning %d, jumps %d)" % [s.lightning_level, s.lightning_chains])
	_check(s.powers.has("storm_eye"), "worn powers are listed in stats.powers")
	inv.unequip("helm")
	_check(s.lightning_level == 0 and not s.powers.has("storm_eye"), "unequipping removes the power and its mods")
	return true



func _test_elements() -> bool:
	print("elements and reactions")
	var swarm := EnemySwarm.new()
	swarm.capacity = 16
	swarm.max_hp = 1000.0
	root.add_child(swarm)
	Elements.swarms = [swarm]
	Elements.player = null
	for k in 4:
		swarm.spawn(Vector2(k * 0.5, 0))
	swarm.step(0.0, Vector2.ZERO)

	Elements.hit(swarm, 0, 10.0, Elements.FROST)
	_check(swarm.chill[0] > 0.0, "frost chills")
	Elements.hit(swarm, 0, 10.0, Elements.FIRE)
	_near(swarm.hp[0], 1000.0 - 10.0 - 10.0 * Elements.MELT_MULT, "fire on a chilled enemy melts (2.5x)")
	_check(swarm.chill[0] == 0.0 and swarm.burn[0] > 0.0, "melting uses up the chill, and the fire then burns")

	Elements.hit(swarm, 1, 10.0, Elements.LIGHTNING)
	_check(swarm.shock[1] > 0.0, "lightning shocks")
	var before := swarm.hp[1]
	Elements.hit(swarm, 1, 10.0)
	_near(before - swarm.hp[1], 10.0 * Elements.SHOCK_BONUS, "shocked enemies take 25% more")

	Elements.hit(swarm, 2, 10.0, Elements.FROST)
	Elements.hit(swarm, 2, 10.0, Elements.LIGHTNING)
	_check(Elements._queue.size() == 1 and Elements._queue[0]["kind"] == "shatter", "lightning on a chilled enemy queues a Shatter")
	var hp3 := swarm.hp[3]
	Elements.flush()
	_check(swarm.hp[3] < hp3 and swarm.chill[3] > 0.0, "the Shatter hurts and chills neighbors")

	var hp0 := swarm.hp[0]
	swarm.step(0.5, Vector2.ZERO)
	_check(swarm.hp[0] < hp0, "burning enemies lose HP over time")

	swarm.spawn(Vector2(5, 5))
	swarm.step(0.0, Vector2.ZERO)
	var i := swarm.count - 1
	Elements.hit(swarm, i, 1.0, Elements.LIGHTNING)
	Elements.hit(swarm, i, 1.0, Elements.FIRE)
	_check(Elements._queue.size() == 1 and Elements._queue[0]["kind"] == "overload", "fire on a shocked enemy queues an Overload")
	Elements.flush()
	Elements.reset()
	swarm.free()
	return true



func _test_army() -> bool:
	print("soul army")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunts := EnemySwarm.new()
	grunts.name = "Grunts"
	grunts.capacity = 8
	root.add_child(grunts)
	var brutes := EnemySwarm.new()
	brutes.name = "Brutes"
	brutes.capacity = 8
	brutes.max_hp = 120.0
	brutes.model = "brute"
	root.add_child(brutes)
	var swarms: Array[EnemySwarm] = [grunts, brutes]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	_check(army.type_index(brutes) == 1, "each enemy type has a minion type")
	_check(Army.soul_value(1, true, false) == 102 and Army.soul_value(0, false, true) == 201, "soul values encode type, elite and boss")

	var cost := player.stats.soul_cost
	for k in cost - 1:
		army.collect_soul(Army.soul_value(1 if k % 3 else 0, false, false))
	_check(army.count == 0 and army.souls == cost - 1, "no minion until enough souls")
	army.collect_soul(Army.soul_value(1, false, false))
	_check(army.count == 1 and army.souls == 0, "a minion rises at %d souls" % cost)
	_check(army._type[0] == 1, "it's the kind most of those souls came from")
	_near(army._hp[0], player.stats.minion_hp * army._types[1]["hp"], "tougher kinds make tougher minions")

	for k in cost:
		army.collect_soul(Army.soul_value(0, false, false))
	_check(army.count == player.stats.minion_max, "the army fills up to minion_max")
	for k in cost:
		army.collect_soul(Army.soul_value(0, false, false))
	_check(army.count == player.stats.minion_max and army.souls == cost, "a full army banks souls instead")
	army.collect_soul(Army.soul_value(1, true, false))
	_check(army.count == player.stats.minion_max and army._elite.slice(0, army.count).has(1), "an elite soul rises at once, replacing a common minion")
	army._remove(0, true)
	_check(army.count == player.stats.minion_max, "when a minion falls, banked souls raise the next")

	var gems := GemSwarm.new()
	root.add_child(gems)
	gems.drop(Vector2(0.1, 0), 7)
	gems.step(0.016, Vector2.ZERO, 3.0)
	_check(gems.collected == PackedInt32Array([7]), "gem swarms report what was collected")
	for n: Node in [gems, army, grunts, brutes, player]:
		n.free()
	return true



func _test_realms() -> bool:
	print("realms")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var models: Array = []
	for m in ["grunt", "brute", "runner", "cultist", "boss", "wraith", "imp", "lich", "colossus", "tyrant", "lancer", "gravedigger"]:
		models.append(m)
	_check(Realm.ORDER.size() == Realm.REALMS.size(), "every realm is in the play order")
	for id: String in Realm.ORDER:
		var d := Realm.data(id)
		for key in ["name", "tagline", "rule", "difficulty", "rate", "ground", "props", "stages", "motes", "hazard", "enemies", "chill_scale", "soul_bonus"]:
			_check(d.has(key), "%s has %s" % [id, key])
		for swarm_name: String in d["enemies"]:
			var e: Dictionary = d["enemies"][swarm_name]
			_check(scene.has_node(swarm_name), "%s: the scene has a %s node" % [id, swarm_name])
			_check(e["model"] in models, "%s: %s uses a real model (%s)" % [id, swarm_name, e["model"]])
			_check(Models.enemy(e["model"], e["color"], 1.0).get_surface_count() == 1, "%s: the %s model builds" % [id, e["model"]])
		for kind: String in d["props"]:
			_check(kind in Models.PROPS, "%s: prop %s exists" % [id, kind])
		_check(d["stages"].size() >= 2 and d["stages"][0]["t"] == 0.0, "%s: lighting starts at t=0" % id)
		_check(d["hazard"] in ["", "graves", "ice", "meteors"], "%s: known hazard" % id)
	scene.free()
	return true



func _test_realm_progress() -> bool:
	print("realm progress")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_realms.save"
	_wipe_save()
	MetaProgress.load_save()
	_check(MetaProgress.is_unlocked("graveyard"), "the first realm is open")
	_check(not MetaProgress.is_unlocked("frozen") and not MetaProgress.is_unlocked("ember"), "later realms start locked")
	MetaProgress.record_win("graveyard")
	_check(MetaProgress.is_won("graveyard") and MetaProgress.is_unlocked("frozen"), "winning a realm opens the next")
	_check(not MetaProgress.is_unlocked("ember"), "but not the one after")
	MetaProgress.record_endless("graveyard", 95.0)
	MetaProgress.record_endless("graveyard", 40.0)
	_near(MetaProgress.endless_best("graveyard"), 95.0, "Endless keeps the best time")
	MetaProgress.load_save()
	_check(MetaProgress.is_won("graveyard") and MetaProgress.endless_best("graveyard") == 95.0, "realm progress survives a reload")
	_wipe_save()
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()
	return true



func _test_classes_and_settings() -> bool:
	print("hero classes and settings")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_classes.save"
	_wipe_save()
	MetaProgress.load_save()
	_check(HeroClass.ORDER.size() == HeroClass.CLASSES.size(), "every class is on the picker")
	for id: String in HeroClass.ORDER:
		var d := HeroClass.data(id)
		for key in ["name", "cost", "desc", "weapon", "accent", "look", "mods", "powers"]:
			_check(d.has(key), "%s has %s" % [id, key])
	_check(MetaProgress.current_class() == "battlemage", "a fresh save plays the Battlemage")
	_check(MetaProgress.class_unlocked("battlemage") and not MetaProgress.class_unlocked("necromancer"), "only the Battlemage starts unlocked")
	MetaProgress.add_shards(35)
	_check(not MetaProgress.unlock_class("pyromancer"), "can't buy a class you can't afford")
	_check(MetaProgress.unlock_class("necromancer") and MetaProgress.shards == 5, "buying the Necromancer spends 30 shards")
	MetaProgress.select_class("necromancer")
	MetaProgress.select_class("stormcaller")
	_check(MetaProgress.current_class() == "necromancer", "locked classes can't be selected")
	_near(MetaProgress.setting("music_volume"), 0.7, "settings have defaults")
	MetaProgress.set_setting("music_volume", 0.25)
	MetaProgress.set_setting("shake", false)
	MetaProgress.load_save()
	_check(MetaProgress.current_class() == "necromancer" and MetaProgress.class_unlocked("necromancer"), "classes survive a reload")
	_check(is_equal_approx(MetaProgress.setting("music_volume"), 0.25) and MetaProgress.setting("shake") == false, "settings survive a reload")
	_wipe_save()
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()
	return true



func _test_sounds() -> bool:
	print("sounds")
	for sound: String in Sound.RULES:
		_check(ResourceLoader.exists("res://audio/sfx/%s.wav" % sound), "sound %s has a file" % sound)
		_check(Sound.RULES[sound].size() == 4, "sound %s has a full rule" % sound)
	for id: String in Realm.ORDER:
		for layer in ["calm", "drums"]:
			_check(ResourceLoader.exists("res://audio/music/%s_%s.ogg" % [id, layer]), "%s has %s music" % [id, layer])
	_check(ResourceLoader.exists("res://audio/music/boss.ogg"), "there's boss music")
	return true



func _test_heroes() -> bool:
	print("hero class effects")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var base_minions := player.stats.minion_max
	HeroClass.apply(player, "necromancer")
	_near(player.stats.minion_max, base_minions + 2.0, "the Necromancer commands two more minions")
	_check(player.stats.powers.has("lich_shroud"), "and has the Lich Shroud power")
	_near(player.stats.hp, player.stats.max_hp, "a class starts at full health")
	HeroClass.apply(player, "pyromancer")
	_near(player.stats.minion_max, base_minions, "switching class removes the old bonuses")
	_check(player.stats.powers.has("pyre") and not player.stats.powers.has("lich_shroud"), "and the old powers")
	HeroClass.apply(player, "stormcaller")
	_check(player.stats.lightning_level >= 1, "the Stormcaller starts with Chain Lightning")
	player.free()
	return true



func _test_events() -> bool:
	print("night events")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var director := WaveDirector.new()
	root.add_child(director)
	var loot := LootManager.new()
	root.add_child(loot)
	var gems := GemSwarm.new()
	root.add_child(gems)
	var grunts := EnemySwarm.new()
	grunts.capacity = 32
	root.add_child(grunts)
	var goblins := EnemySwarm.new()
	goblins.capacity = 2
	goblins.flee = true
	goblins.spawn_share = 0.0
	goblins.model = "goblin"
	root.add_child(goblins)
	var swarms: Array[EnemySwarm] = [grunts, goblins]
	director.setup(swarms)
	var events := EventDirector.new()
	root.add_child(events)
	events.setup(director, player, loot, gems, goblins, swarms)
	_check(goblins.spawn_weight(600.0) == 0.0, "the wave director never spawns goblins")

	# Shrines: stand in the circle to charge it, then a blessing for a while.
	events._start_shrine(player.pos2 + Vector2(1, 0))
	_check(events.markers().size() == 1, "a shrine gets a marker")
	var damage_before := player.stats.bolt_damage
	events._events[0]["blessing"] = "Fury"
	for k in 5:
		events._update_events(1.0)
	_check(events._events.is_empty() and events.blessing == "Fury", "standing in a shrine blesses you")
	_check(player.stats.bolt_damage > damage_before * 1.5, "Fury raises damage (%s -> %s)" % [damage_before, player.stats.bolt_damage])
	events._update_blessing(events.blessing_time + 1.0)
	_check(events.blessing == "" and is_equal_approx(player.stats.bolt_damage, damage_before), "the blessing wears off")

	# Goblins: flee from the hero, and pay out when caught.
	goblins.spawn(Vector2(3, 0))
	goblins.step(0.1, player.pos2)
	_check(goblins.pos[0].x > 3.0, "goblins run away (x=%.2f)" % goblins.pos[0].x)
	var drops_before := loot.drops.size()
	goblins.damage(0, 1.0e9)
	_check(events.shards == 3 and loot.drops.size() == drops_before + 3, "a caught goblin drops loot and shards")
	goblins.spawn(Vector2(3, 0))
	events._goblin_left = 0.01
	var died := [0]
	goblins.enemy_died.connect(func(_a: Vector2, _x: int) -> void: died[0] += 1)
	events._update_events(0.1)
	_check(goblins.alive_count() == 0 and died[0] == 0, "an escaped goblin vanishes without a death")

	# Cursed chests: guardians, then a Legendary.
	events._start_chest(player.pos2 + Vector2(1, 0))
	events._update_events(0.1)
	var guards: Array = events._events[0]["guards"]
	_check(guards.size() >= 5, "opening a chest summons its guardians (%d)" % guards.size())
	_check(grunts.is_elite(grunts.count - 1), "the guardians are elites")
	for i in grunts.count:
		grunts.damage(i, 1.0e9)
	var before := loot.drops.size()
	events._update_events(0.1)
	_check(events._events.is_empty() and loot.drops.size() == before + 1, "the curse breaks when they're all dead")
	_check(loot.drops[-1].item.rarity == ItemData.Rarity.LEGENDARY, "and the chest gives a Legendary")

	# Health orbs.
	player.stats.hp = player.stats.max_hp * 0.5
	events.drop_orb(player.pos2 + Vector2(0.5, 0))
	events._update_orbs(0.016)
	_near(player.stats.hp, player.stats.max_hp * 0.75, "a health orb heals a quarter of max HP")
	for n: Node in [events, goblins, grunts, gems, loot, director, player]:
		n.free()
	return true



## Godot XYZ size and emissive surface count, from the art pack's ASSET_CATALOG.json.
const _ASSET_CATALOG := {
	"rune_gravestone": [Vector3(1.021, 1.28, 1.55), 0],
	"soul_brazier": [Vector3(0.84, 1.98, 0.84), 1],
	"ruined_pillar": [Vector3(1.482, 2.105, 1.214), 0],
	"crystal_cluster": [Vector3(1.331, 1.601, 1.179), 1],
	"tome_pedestal": [Vector3(1.145, 1.492, 0.85), 1],
	"barrel": [Vector3(0.858, 1.014, 0.816), 0],
	"crate_stack": [Vector3(1.729, 1.474, 0.948), 0],
	"weapon_rack": [Vector3(1.54, 2.105, 0.71), 0],
	"offering_bowl": [Vector3(2.124, 0.782, 1.5), 0],
	"sarcophagus": [Vector3(1.236, 1.116, 2.04), 0],
	"prison_cage": [Vector3(1.35, 1.663, 1.17), 0],
	"gravedigger_bench": [Vector3(2.995, 2.32, 1.095), 0],
	"lantern_post": [Vector3(2.162, 3.45, 1.3), 1],
	"mausoleum": [Vector3(3.385, 3.625, 3.985), 0],
	"soul_altar": [Vector3(2.12, 1.875, 2.12), 1],
	"broken_archway": [Vector3(3.579, 3.365, 1.028), 0],
	"ruined_wall": [Vector3(2.742, 2.084, 0.844), 0],
	"ruin_corner": [Vector3(2.055, 1.668, 2.06), 0],
	"portcullis": [Vector3(2.85, 2.66, 0.96), 0],
	"guardian_statue": [Vector3(1.978, 1.945, 1.286), 0],
	"soul_obelisk": [Vector3(1.215, 2.72, 0.88), 1],
	"stone_well": [Vector3(1.99, 1.515, 1.523), 0],
	"ritual_door": [Vector3(2.03, 2.32, 0.808), 1],
	"iron_fence": [Vector3(3.96, 2.24, 0.47), 0],
	"bell_gibbet": [Vector3(2.655, 3.115, 1.079), 0],
	"funeral_wagon": [Vector3(2.635, 1.236, 3.556), 0],
	"ossuary_wall": [Vector3(3.5, 2.73, 1.135), 0],
	"winged_memorial": [Vector3(3.24, 2.91, 1.3), 0],
	"snow_boulder": [Vector3(1.826, 1.263, 1.504), 0],
	"frosted_pine": [Vector3(1.657, 2.498, 1.616), 0],
	"ice_stalagmites": [Vector3(1.653, 2.197, 1.329), 0],
	"supply_tripod": [Vector3(2.469, 2.963, 2.198), 0],
	"wind_chime": [Vector3(2.598, 2.82, 1.1), 0],
	"ice_arch": [Vector3(3.186, 2.36, 0.86), 0],
	"watchtower": [Vector3(3.556, 3.945, 2.998), 0],
	"sled": [Vector3(2.306, 1.617, 3.547), 0],
	"ribcage": [Vector3(3.182, 2.137, 4.611), 0],
	"frozen_pond": [Vector3(4.646, 0.767, 3.884), 0],
	"fishing_hut": [Vector3(3.038, 2.859, 2.875), 0],
	"whale_skull": [Vector3(1.93, 1.389, 3.246), 0],
	"obsidian_outcrop": [Vector3(2.052, 2.104, 1.804), 0],
	"brimstone_vent": [Vector3(2.109, 1.129, 1.797), 1],
	"ashen_tree": [Vector3(1.883, 2.929, 1.168), 1],
	"basalt_columns": [Vector3(1.77, 2.06, 0.98), 0],
	"scorched_banner": [Vector3(2.22, 3.44, 1.14), 0],
	"skull_gateway": [Vector3(4.223, 4.938, 1.543), 1],
	"forge": [Vector3(3.659, 3.59, 2.263), 1],
	"cauldron": [Vector3(2.727, 3.336, 2.481), 1],
	"siege_barricade": [Vector3(4.056, 2.564, 1.751), 1],
	"minecart": [Vector3(3.005, 1.522, 2.02), 1],
	"furnace": [Vector3(2.094, 3.22, 2.0), 1],
	"chained_gong": [Vector3(2.76, 3.031, 0.94), 1],
	"treasure_chest": [Vector3(1.667, 1.232, 1.133), 0],
}


func _test_asset_props() -> bool:
	print("imported scenery")
	var listed := Models.PROPS.filter(func(k: String) -> bool: return AssetProps.has(k))
	_check(listed == AssetProps.KINDS.keys(), "Models.PROPS lists every imported kind, in order")
	_check(Models.PROPS.slice(0, 15) == ["grass", "rock", "bush", "mushroom", "bones", "tree", "grave", "pillar",
			"crystal", "pine", "ice", "snowrock", "obsidian", "brimstone", "ashtree"], "code-built kinds keep their order")
	var used := {}
	for realm: String in Realm.ORDER:
		for kind: String in Realm.data(realm)["props"]:
			used[kind] = true
	for kind: String in AssetProps.KINDS.keys() + AssetProps.EVENT_KINDS.keys():
		var d := AssetProps.data(kind)
		_check(ResourceLoader.exists(AssetProps.ROOT % d["path"]), "%s: the GLB is in the project" % kind)
		var mesh := AssetProps.mesh(kind)
		_check(mesh != null and mesh == AssetProps.mesh(kind), "%s: the mesh builds once and is cached" % kind)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		var want: Vector3 = _ASSET_CATALOG[kind][0]
		_check(absf(aabb.position.y) < 0.01, "%s: stands on the ground (min y %.3f)" % [kind, aabb.position.y])
		_check((aabb.size - want).abs().length() < 0.03, "%s: catalog size, no rescale (%s vs %s)" % [kind, aabb.size, want])
		var glowing := 0
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as ShaderMaterial
			_check(m != null, "%s: surface %d has a material" % [kind, s])
			if m == null:
				continue
			if m.get_shader_parameter("flat_glow") > 0.0:
				glowing += 1
			if not d["landmark"]:
				_check(is_equal_approx(m.get_shader_parameter("uv_glow"), 0.0), "%s: UV.x never drives glow" % kind)
			var arrays := mesh.surface_get_arrays(s)
			_check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(),
					"%s: surface %d keeps its vertex colors" % [kind, s])
		_check(glowing == _ASSET_CATALOG[kind][1], "%s: %d glowing surface(s), as authored" % [kind, _ASSET_CATALOG[kind][1]])
		if not AssetProps.has(kind):
			continue
		for key in ["realm", "scale", "yaw", "landmark", "footprint", "shadow", "solid", "fx"]:
			_check(d.has(key), "%s has %s" % [kind, key])
		_check(d["realm"] in Realm.ORDER, "%s: chosen for a real realm" % kind)
		_check(used.has(kind) and Realm.data(d["realm"])["props"].has(kind), "%s: its realm scatters it" % kind)
		_check(d["footprint"] * 2.0 <= 12.0 * 0.6, "%s: footprint fits a chunk" % kind)
		_check((d["fx"] != null) == (glowing > 0), "%s: glowing props (only) give off motes" % kind)
		_check(d["solid"].is_empty() or d["landmark"], "%s: only set pieces are solid" % kind)
		for c: Array in d["solid"]:
			_check(c[2] > 0.2 and Vector2(c[0], c[1]).length() + c[2] <= d["footprint"] + 0.6,
					"%s: collision sits inside the footprint (%s)" % [kind, c])
			# Inside the mesh's ground outline, more or less.
			_check(c[0] - c[2] > aabb.position.x - 0.3 and c[0] + c[2] < aabb.end.x + 0.3 and c[1] - c[2] > aabb.position.z - 0.3 \
					and c[1] + c[2] < aabb.end.z + 0.3, "%s: collision within the model's bounds (%s)" % [kind, c])
	# Arches keep their openings: nothing solid in the middle.
	for kind in ["broken_archway", "ice_arch", "skull_gateway"]:
		_check(not _solid_at(kind, Vector2.ZERO, 0.5), "%s: the opening is passable" % kind)
	for realm: String in Realm.ORDER:
		for kind: String in Realm.data(realm)["props"]:
			_check(kind in Models.PROPS, "%s: %s is a real prop" % [realm, kind])
			if AssetProps.has(kind):
				_check(AssetProps.data(kind)["realm"] == realm, "%s: %s belongs to it" % [realm, kind])
		var landmark_share := 0.0
		for kind: String in Realm.data(realm)["props"]:
			if AssetProps.has(kind) and AssetProps.data(kind)["landmark"]:
				landmark_share += Realm.data(realm)["props"][kind]
		_check(landmark_share > 0.2 and landmark_share <= 0.5, "%s: set pieces in about a third of the chunks (%.2f)" % [realm, landmark_share])
	return true



func _solid_at(kind: String, p: Vector2, radius: float) -> bool:
	for c: Array in AssetProps.data(kind)["solid"]:
		if p.distance_to(Vector2(c[0], c[1])) < c[2] + radius:
			return true
	return false


func _test_asset_placement() -> bool:
	print("imported scenery placement")
	for realm: String in Realm.ORDER:
		var decor := WorldDecor.new()
		var code_only := {}
		for kind: String in Realm.data(realm)["props"]:
			if not AssetProps.has(kind):
				code_only[kind] = Realm.data(realm)["props"][kind]
		decor.density = code_only
		var base: Array = decor.compute(Vector2i(3, -2))
		decor.density = Realm.data(realm)["props"]
		var with: Array = decor.compute(Vector2i(3, -2))
		var again: Array = decor.compute(Vector2i(3, -2))
		_check(with[0] == again[0] and with[1] == again[1] and with[2] == again[2], "%s: the same chunks always grow the same scenery" % realm)
		var assets := []
		var landmarks := []
		for kind: String in AssetProps.KINDS:
			for xf: Transform3D in with[0][kind]:
				var at := Vector2(xf.origin.x, xf.origin.z)
				var fp: float = AssetProps.data(kind)["footprint"]
				assets.append([at, fp])
				if AssetProps.data(kind)["landmark"]:
					landmarks.append([at, fp])
					_check(at.length() >= 2.0 * WorldDecor.ASSET_CLEAR + fp, "%s: set pieces keep away from the start" % realm)
				else:
					_check(at.length() >= WorldDecor.ASSET_CLEAR + fp, "%s: imported props keep the start clear" % realm)
		_check(landmarks.size() >= 5 and assets.size() > 2 * landmarks.size(), "%s: scenery is placed (%d, %d set pieces)" % [realm, assets.size(), landmarks.size()])
		var overlaps := 0
		for i in assets.size():
			for j in range(i + 1, assets.size()):
				if assets[i][0].distance_to(assets[j][0]) < assets[i][1] + assets[j][1] - 0.001:
					overlaps += 1
		_check(overlaps == 0, "%s: imported props never overlap (%d)" % [realm, overlaps])
		_check(with[2].size() > 0, "%s: some set pieces are solid (%d circles)" % [realm, with[2].size()])
		var clear_start := true
		for c: Array in with[2]:
			if c[0].length() < c[1] + 8.0:
				clear_start = false
		_check(clear_start, "%s: nothing solid near the start" % realm)
		if realm != "frozen":
			_check(with[3].size() > 0, "%s: glowing props give off motes (%d)" % [realm, with[3].size()])
		var moved := 0
		for kind: String in code_only:
			var now: Array = with[0][kind]
			for xf: Transform3D in base[0][kind]:
				if xf in now:
					continue
				var under := false
				for l: Array in landmarks:
					if Vector2(xf.origin.x, xf.origin.z).distance_to(l[0]) < l[1]:
						under = true
				if not under:
					moved += 1
			for xf: Transform3D in now:
				for l: Array in landmarks:
					_check(Vector2(xf.origin.x, xf.origin.z).distance_to(l[0]) >= l[1], "%s: nothing grows inside a set piece" % realm)
		_check(moved == 0, "%s: imported scenery moves no code-built prop (%d moved)" % [realm, moved])
		decor.free()
	# Switching realms (the title preview) leaves nothing of the old one behind.
	var decor := WorldDecor.new()
	decor.density = Realm.data("ember")["props"]
	decor.compute(Vector2i.ZERO)
	decor.density = Realm.data("frozen")["props"]
	var after: Array = decor.compute(Vector2i.ZERO)
	for kind: String in Realm.data("ember")["props"]:
		if not Realm.data("frozen")["props"].has(kind):
			_check(after[0][kind].is_empty(), "after switching to frozen, no %s remains" % kind)
	decor.free()
	return true



func _test_obstacles() -> bool:
	print("solid scenery")
	Obstacles.set_circles([[Vector2(5, 0), 1.0], [Vector2(5, 2.4), 1.0]], Rect2(-20, -20, 40, 40))
	_check(Obstacles.near(Vector2(4.5, 0)) and not Obstacles.near(Vector2(-15, -15)), "the flag grid marks the area near obstacles")
	var p := Obstacles.resolve(Vector2(4.6, 0.1), 0.5)
	_near(p.distance_to(Vector2(5, 0)), 1.5, "a body inside is pushed to the edge", 0.01)
	_check(Obstacles.resolve(Vector2(0, 0), 0.5) == Vector2(0, 0), "a body in the open isn't moved")
	var wedged := Obstacles.resolve(Vector2(5.0, 1.2), 0.4)
	_check(not Obstacles.blocked(wedged, 0.39), "a body wedged between two circles gets out (%s)" % wedged)
	# A swarm walking at an obstacle slides around it and never ends up inside.
	var swarm := EnemySwarm.new()
	swarm.capacity = 8
	swarm.move_speed = 4.0
	root.add_child(swarm)
	swarm.spawn(Vector2(0, 0.05))
	var inside := 0
	for k in 120:
		swarm.step(1.0 / 60.0, Vector2(10, 0))
		if Obstacles.blocked(swarm.pos[0], swarm.radius - 0.01):
			inside += 1
	_check(inside == 0, "enemies never stand inside solid scenery (%d frames)" % inside)
	_check(swarm.pos[0].x > 6.0, "and get past it to their target (x=%.2f)" % swarm.pos[0].x)
	swarm.free()
	Obstacles.clear()
	_check(not Obstacles.near(Vector2(5, 0)) and Obstacles.resolve(Vector2(5, 0), 0.5) == Vector2(5, 0), "cleared, nothing blocks")
	return true



func _test_fixes() -> bool:
	print("fixes")
	# Swept bolts: a fast bolt crossing an enemy in one long step still hits it.
	var near := EnemySwarm.new()
	near.capacity = 4
	root.add_child(near)
	var far := EnemySwarm.new()
	far.capacity = 4
	root.add_child(far)
	near.spawn(Vector2(1.5, 0))
	far.spawn(Vector2(2.5, 0))
	near.step(0.0, Vector2(0, -20))
	far.step(0.0, Vector2(0, -20))
	var bolts := ProjectileSwarm.new()
	root.add_child(bolts)
	var swarms: Array[EnemySwarm] = [far, near]
	bolts.spawn(Vector2.ZERO, Vector2.RIGHT, 80.0, 5.0, 0, 1.0)
	bolts.step(0.05, swarms)
	_check(near.hp[0] < near.max_hp and far.hp[0] == far.max_hp,
			"a fast bolt hits the enemy it passed over, the nearest first, across enemy types")
	_check(bolts.count == 0, "and with no pierce it's spent on that first hit")
	for n: Node in [bolts, near, far]:
		n.free()

	# A dash can't pass through a thin obstacle in one long step.
	Obstacles.set_circles([[Vector2.ZERO, 0.35]], Rect2(-10, -10, 20, 20))
	var end := Player.slide_scenery(Vector2(-0.86, 0), Vector2(0.16, 0))
	_check(not Obstacles.blocked(end, Player.RADIUS - 0.01) and (end.x < -0.8 or absf(end.y) > 0.5),
			"a dash goes around a thin post, never through it (%s)" % end)
	var slid := Vector2(-1.5, 0.3)
	var stuck := false
	for k in 20: # walking right at 6 m/s, a frame at a time
		slid = Player.slide_scenery(slid, slid + Vector2(0.1, 0.0))
		stuck = stuck or Obstacles.blocked(slid, Player.RADIUS - 0.01)
	_check(slid.x > 0.4 and not stuck, "walking into it slides around without entering (%s)" % slid)
	Obstacles.clear()

	# A first ability card for an ability you already have improves it.
	var stats := PlayerStats.new()
	stats.add_mods("class", [{"stat": "lightning_level", "op": PlayerStats.Op.ADD, "value": 1.0}])
	stats.recalculate()
	var chains := stats.lightning_chains
	var dmg := stats.lightning_damage
	_check(Upgrades.already_active("lightning", stats), "Stormcaller's lightning counts as already active")
	Upgrades.apply("lightning", stats)
	_check(stats.lightning_chains > chains and stats.lightning_damage > dmg, "so the first Lightning card upgrades it right away")
	stats.remove_source("class")
	stats.recalculate()
	_check(stats.lightning_level >= 1, "and still owns it without the class source")

	# A bound boss isn't pushed out of a full army by an elite.
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunts := EnemySwarm.new()
	grunts.capacity = 4
	root.add_child(grunts)
	var army := Army.new()
	root.add_child(army)
	var army_swarms: Array[EnemySwarm] = [grunts]
	army.setup(player, army_swarms)
	army.collect_soul(Army.soul_value(0, false, true))
	while army.count < player.stats.minion_max:
		army._raise(0, false, false)
	army.collect_soul(Army.soul_value(0, true, false))
	_check(army._elite.slice(0, army.count).has(2), "the bound boss survives an elite joining a full army")
	_check(army._elite.slice(0, army.count).has(1), "and the elite replaced a common minion")
	for n: Node in [army, grunts, player]:
		n.free()

	# The night is won: the dawn sweep can't kill the hero too.
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var hero: Player = main.get_node("Player")
	main._on_final_died(Vector2.ZERO)
	hero.take_damage(1.0e9)
	main._on_player_died()
	_check(main.won and not hero.dead and not main._game_over, "after the final boss falls, the hero can't die")
	main.free()
	Obstacles.clear()
	MetaProgress.disabled = was
	return true



func _test_landmarks() -> bool:
	print("landmarks")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var director := WaveDirector.new()
	root.add_child(director)
	var loot := LootManager.new()
	root.add_child(loot)
	var gems := GemSwarm.new()
	root.add_child(gems)
	var grunts := EnemySwarm.new()
	grunts.capacity = 64
	root.add_child(grunts)
	var goblins := EnemySwarm.new()
	goblins.capacity = 2
	goblins.flee = true
	goblins.spawn_share = 0.0
	root.add_child(goblins)
	var swarms: Array[EnemySwarm] = [grunts, goblins]
	director.setup(swarms)
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	var events := EventDirector.new()
	root.add_child(events)
	events.setup(director, player, loot, gems, goblins, swarms)
	var decor := WorldDecor.new()
	var bank := [20]
	var spend := func(n: int) -> Variant:
		if n == 0:
			return bank[0]
		if bank[0] < n:
			return false
		bank[0] -= n
		return true
	var marks := Landmarks.new()
	root.add_child(marks)
	marks.setup(decor, player, director, loot, army, events, swarms, spend)
	var spots := {"bell_gibbet": Vector2(20, 0), "soul_altar": Vector2(40, 0), "stone_well": Vector2(60, 0),
			"forge": Vector2(80, 0), "cauldron": Vector2(100, 0), "fishing_hut": Vector2(120, 0), "tome_pedestal": Vector2(140, 0)}
	for kind: String in spots:
		decor.placed[kind] = [Transform3D(Basis.IDENTITY, Vector3(spots[kind].x, 0, spots[kind].y))]
	var go := func(kind: String) -> bool:
		player.global_position = Vector3(spots[kind].x, 0, spots[kind].y + AssetProps.data(kind)["footprint"] + 0.8)
		marks._rescan()
		return marks.prompt != "" and marks.use_nearest()

	_check(go.call("bell_gibbet"), "ringing a bell works")
	_check(marks.markers().size() == 1 and grunts.alive_count() >= 4, "and summons champions (%d)" % grunts.alive_count())
	_check(not go.call("bell_gibbet") and marks.is_used("bell_gibbet", spots["bell_gibbet"]), "a bell rings once")
	var drops := loot.drops.size()
	for i in grunts.count:
		grunts.damage(i, 1.0e9)
	marks._update_bells()
	_check(marks.shards == 6 and loot.drops.size() == drops + 2 and marks.markers().is_empty(), "slaying them pays out")

	_check(not go.call("soul_altar"), "the altar needs a minion")
	army._raise(0, false, false)
	var dmg := player.stats.bolt_damage
	_check(go.call("soul_altar") and army.count == 0 and player.stats.bolt_damage > dmg * 1.1, "sacrificing one raises damage")

	_check(go.call("stone_well") and bank[0] == 15, "the well takes 5 shards")

	var weapon := ItemGenerator.generate_with(5, ItemData.Rarity.MAGIC, "weapon")
	player.inventory.pickup(weapon)
	_check(go.call("forge") and bank[0] == 7, "the forge takes 8 shards")
	var reforged: Item = player.inventory.equipped.get("weapon")
	_check(reforged != weapon and reforged.rarity == ItemData.Rarity.MAGIC, "and reforges the weapon at the same rarity")

	_check(not go.call("cauldron"), "the cauldron needs souls")
	army.souls = 6
	_check(go.call("cauldron") and events.blessing != "" and is_equal_approx(events.blessing_left, 45.0) and army.souls == 0,
			"6 souls brew a 45 s blessing")

	player.stats.hp = 10.0
	_check(go.call("fishing_hut") and is_equal_approx(player.stats.hp, player.stats.max_hp), "resting heals to full")

	var hp := player.stats.max_hp
	var points := player.skills.points
	_check(go.call("tome_pedestal") and player.skills.points == points + 1 and player.stats.max_hp < hp, "the tome trades health for a skill point")
	for n: Node in [marks, events, army, grunts, goblins, gems, loot, director, player]:
		n.free()
	decor.free()
	return true



func _test_minion_roles() -> bool:
	print("minion roles")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var want := {"Grunts": "brawler", "Brutes": "bulwark", "Runners": "skirmisher", "Cultists": "caster",
			"Bosses": "tyrant", "FinalBoss": "tyrant", "Goblins": "brawler", "Lancers": "skirmisher", "Gravediggers": "caster"}
	for swarm_name: String in want:
		_check(Army.role_of(scene.get_node(swarm_name)) == want[swarm_name], "%s rise as %ss" % [swarm_name, want[swarm_name]])
	scene.free()
	# A caster minion fights from range.
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var foes := EnemySwarm.new()
	foes.capacity = 4
	foes.move_speed = 0.0
	foes.max_hp = 1000.0
	root.add_child(foes)
	var witches := EnemySwarm.new()
	witches.capacity = 4
	witches.attack_range = 9.0
	root.add_child(witches)
	var swarms: Array[EnemySwarm] = [foes, witches]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.swarms = swarms
	Elements.player = player
	army._raise(1, false, false)
	_check(army.role(0) == "caster", "a witch's soul raises a caster")
	army._pos[0] = Vector2.ZERO
	foes.spawn(Vector2(6, 0))
	for k in 90:
		foes.step(1.0 / 60.0, Vector2(6, 0))
		witches.step(1.0 / 60.0, Vector2(6, 0))
		army.step(1.0 / 60.0)
		Elements.flush()
	_check(foes.hp[0] < 1000.0, "the caster hurts its target")
	_check(army._pos[0].distance_to(foes.pos[0]) > 3.0, "from a distance (%.1f m)" % army._pos[0].distance_to(foes.pos[0]))
	for n: Node in [army, witches, foes, player]:
		n.free()
	return true



func _test_specialists() -> bool:
	print("lancers and gravediggers")
	var lancers := EnemySwarm.new()
	lancers.capacity = 8
	lancers.charger = true
	lancers.model = "lancer"
	root.add_child(lancers)
	var hits := [0.0]
	lancers.charged_hero.connect(func(dmg: float) -> void: hits[0] += dmg)
	lancers.spawn(Vector2(0, 7))
	lancers._ctime[0] = 0.0
	var hero := Vector2.ZERO
	lancers.step(1.0 / 60.0, hero)
	_check(lancers._cstate[0] == 1 and lancers._telegraph.multimesh.visible_instance_count == 1,
			"a lancer in range winds up and shows its line")
	var start := lancers.pos[0]
	for k in int(lancers.charge_windup * 60.0) - 2:
		lancers.step(1.0 / 60.0, hero)
	_check(lancers.pos[0].distance_to(start) < 0.05, "it holds still while winding up")
	for k in 40:
		lancers.step(1.0 / 60.0, hero)
	_check(lancers._cstate[0] >= 2 and lancers.pos[0].y < 0.0, "then charges straight through where the hero was (y=%.1f)" % lancers.pos[0].y)
	_check(hits[0] == lancers.charge_damage, "and hits a hero who stays in the line, once")
	# Sidestepping: the line is locked when the wind-up starts.
	lancers.free()
	lancers = EnemySwarm.new()
	lancers.capacity = 8
	lancers.charger = true
	root.add_child(lancers)
	var dodged := [0.0]
	lancers.charged_hero.connect(func(dmg: float) -> void: dodged[0] += dmg)
	lancers.spawn(Vector2(0, 7))
	lancers._ctime[0] = 0.0
	lancers.step(1.0 / 60.0, hero)
	for k in 120:
		lancers.step(1.0 / 60.0, Vector2(3.0, 0.0)) # the hero stepped aside
	_check(dodged[0] == 0.0, "a hero who sidesteps the line isn't hit")
	lancers.free()

	var diggers := EnemySwarm.new()
	diggers.capacity = 4
	diggers.raise_interval = 1.0
	diggers.hold_range = 8.0
	root.add_child(diggers)
	var calls := [0]
	diggers.raise_called.connect(func(_at: Vector2) -> void: calls[0] += 1)
	diggers.spawn(Vector2(0, 15))
	for k in 240:
		diggers.step(1.0 / 60.0, Vector2.ZERO)
	_check(calls[0] >= 2, "a gravedigger keeps raising the dead (%d)" % calls[0])
	_check(diggers.pos[0].length() > 7.0, "from a distance (%.1f m)" % diggers.pos[0].length())
	diggers.free()
	var souls := GemSwarm.new()
	root.add_child(souls)
	souls.drop(Vector2(1, 0), 1)
	souls.drop(Vector2(20, 0), 1)
	_check(souls.take_near(Vector2.ZERO, 7.0) == 1 and souls.count == 1, "and eats the souls near it")
	souls.free()
	return true



func _test_ferryman() -> bool:
	print("the Ferryman")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var director := WaveDirector.new()
	root.add_child(director)
	var loot := LootManager.new()
	root.add_child(loot)
	var grunts := EnemySwarm.new()
	grunts.capacity = 32
	root.add_child(grunts)
	var collectors := EnemySwarm.new()
	collectors.capacity = 2
	collectors.captor = true
	collectors.spawn_share = 0.0
	root.add_child(collectors)
	var swarms: Array[EnemySwarm] = [grunts, collectors]
	director.setup(swarms)
	Elements.swarms = swarms
	Elements.player = player
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	var panel := WagerPanel.new()
	root.add_child(panel)
	var ferry := Ferryman.new()
	root.add_child(ferry)
	ferry.setup(player, army, loot, director, collectors, panel)

	# The Obol ricochets between enemies.
	player.setup(swarms, null)
	player.stats.add_mods("test", [{"stat": "obol_level", "op": PlayerStats.Op.ADD, "value": 1.0}])
	player.stats.recalculate()
	for k in 4:
		grunts.spawn(Vector2(3 + k * 2.0, 0))
	grunts.max_hp = 10.0
	for k in grunts.count:
		grunts.hp[k] = 1000.0
	grunts.step(0.0, Vector2(0, -30))
	collectors.step(0.0, Vector2(0, -30))
	for f in 120:
		player._obol.update(1.0 / 60.0)
	var hurt := 0
	for k in grunts.count:
		if grunts.hp[k] < 1000.0:
			hurt += 1
	_check(hurt >= 3, "an Obol coin ricochets through several enemies (%d hit)" % hurt)
	for k in grunts.count:
		grunts.damage(k, 1.0e9)
	grunts.step(0.0, Vector2(0, -30))
	collectors.step(0.0, Vector2(0, -30))
	player.stats.remove_source("test")
	player.stats.recalculate()

	# A visit: take the prize.
	_check(ferry._arrive() and not ferry._visit.is_empty(), "the Ferryman arrives")
	var drops := loot.drops.size()
	ferry._on_chosen("take")
	_check(loot.drops.size() == drops + 1 and ferry._visit.is_empty(), "taking the Rare pays it out and he leaves")
	ferry._on_chosen("take")
	_check(loot.drops.size() == drops + 1, "and only once")

	# Wager twice and win twice: two Legendaries.
	ferry._arrive()
	army._raise(0, false, false)
	_near(ferry.first_odds(), 0.7, "the first wager is posted at 70%")
	ferry._on_chosen("pledge")
	_check(army.count == 0 and army.away.size() == 1, "pledging a minion sends it away")
	_near(ferry.first_odds(), 0.8, "and tilts the coin to 80%")
	ferry._reveal(true, false)
	_check(ferry._visit["stage"] == "double" and (ferry._visit["prizes"][0] as Item).rarity == ItemData.Rarity.LEGENDARY, "a win turns the prize Legendary")
	ferry._reveal(true, true)
	drops = loot.drops.size()
	ferry._on_chosen("take")
	_check(loot.drops.size() == drops + 2, "winning twice pays two Legendaries")
	army.step(61.0)
	_check(army.count == 1 and army.away.is_empty(), "the pledged minion comes back after 60 s")

	# Wager and lose: nothing.
	ferry._arrive()
	ferry._reveal(false, false)
	drops = loot.drops.size()
	ferry._on_chosen("take")
	ferry._on_chosen("leave")
	_check(loot.drops.size() == drops and ferry._visit.is_empty(), "a lost wager pays nothing")

	# Borrowing: power now, a Collector later, minions seized until it dies.
	ferry._arrive()
	var dmg := player.stats.bolt_damage
	ferry._on_chosen("borrow")
	_check(player.stats.bolt_damage > dmg * 1.4, "the loan is +50% damage")
	ferry._update_loan(Ferryman.LOAN_DELAY + 0.1)
	_check(collectors.alive_count() == 1, "and the Debt Collector comes")
	ferry.seize()
	_check(army.count == 0 and army.away.size() == 1, "it seizes a minion")
	army.step(120.0)
	_check(army.count == 0, "which stays gone while it lives")
	collectors.damage(0, 1.0e9)
	army.step(0.1)
	_check(army.count == 1, "and returns when it dies")
	ferry._update_loan(Ferryman.LOAN_TIME)
	_near(player.stats.bolt_damage, dmg, "the loan wears off")
	ferry._close()
	ferry._depart()

	# Side bets on bosses.
	ferry.start_bet("Ogre Warlord")
	drops = loot.drops.size()
	ferry._update_bet(10.0)
	ferry.boss_slain(Vector2.ZERO)
	_check(ferry.shards == 10 and loot.drops.size() == drops + 1, "a boss slain in time wins the bet")
	ferry.start_bet("Ogre Warlord")
	ferry._update_bet(Ferryman.BET_TIME + 1.0)
	ferry.boss_slain(Vector2.ZERO)
	_check(ferry.shards == 10, "a slow kill doesn't")
	get_root().get_tree().paused = false
	for n: Node in [ferry, panel, army, collectors, grunts, loot, director, player]:
		n.free()
	return true



func _test_new_tools() -> bool:
	print("scythe, bell, specializations")
	for hero: String in HeroClass.ORDER:
		var cards := Specializations.cards(hero)
		_check(cards.size() == 3, "%s has three paths" % hero)
		for card: Dictionary in cards:
			var stats := PlayerStats.new()
			stats.recalculate()
			var before := [stats.bolt_damage, stats.minion_max, stats.lightning_chains, stats.aura_level, stats.max_hp]
			_check(Specializations.apply(stats, hero, card["id"].substr(5)), "%s: %s applies" % [hero, card["name"]])
			var after := [stats.bolt_damage, stats.minion_max, stats.lightning_chains, stats.aura_level, stats.max_hp]
			_check(before != after or stats.ignite_chance > 0.0 or stats.chill_chance > 0.0, "%s: %s changes the build" % [hero, card["name"]])
			Specializations.apply(stats, hero, card["id"].substr(5))
			_check(stats.mods_from(Specializations.SOURCE).size() == Specializations.find(hero, card["id"].substr(5))["mods"].size(),
					"%s: picking twice doesn't stack" % card["name"])

	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var foes := EnemySwarm.new()
	foes.capacity = 16
	foes.move_speed = 0.0
	root.add_child(foes)
	var swarms: Array[EnemySwarm] = [foes]
	Elements.swarms = swarms
	Elements.player = player
	player.setup(swarms, null)
	player.stats.add_mods("test", [{"stat": "scythe_level", "op": PlayerStats.Op.ADD, "value": 1.0}])
	player.stats.recalculate()
	foes.spawn(Vector2(4, 0))
	foes.hp[0] = 1000.0
	var hp_log := []
	for f in 150:
		foes.step(1.0 / 60.0, Vector2(0, -20))
		player._scythe.update(1.0 / 60.0)
		Elements.flush()
		if hp_log.is_empty() or hp_log[-1] != foes.hp[0]:
			hp_log.append(foes.hp[0])
	_check(hp_log.size() == 3, "the scythe cuts an enemy on the way out and again on the way back (%s)" % [hp_log])
	if hp_log.size() == 3:
		_check(hp_log[1] - hp_log[2] > (hp_log[0] - hp_log[1]) * 1.3, "and the return cut is harder")
	player.stats.remove_source("test")

	player.stats.add_mods("test", [{"stat": "bell_level", "op": PlayerStats.Op.ADD, "value": 1.0}])
	player.stats.recalculate()
	var bell: FuneralBell = player.bell
	for k in player.stats.bell_cost - 1:
		bell.on_kill(Vector2(2, 0))
	_check(bell.fraction() > 0.9 and bell.fraction() < 1.0, "kills near the hero charge the bell")
	bell.on_kill(Vector2(50, 0))
	_check(bell.charge == player.stats.bell_cost - 1, "kills far away don't")
	foes.spawn(Vector2(3, 0))
	foes.step(0.0, Vector2(0, -20))
	var hp_before := foes.hp[foes.count - 1]
	bell.on_kill(Vector2(2, 0))
	_check(bell.charge == 0.0, "a full bell rings")
	bell.on_kill(Vector2(2, 0))
	_check(bell.charge == 0.0, "and its own kills, that frame, don't refill it")
	Elements.flush()
	_check(foes.hp[foes.count - 1] < hp_before, "the toll hurts what's near")
	player.stats.remove_source("test")
	for n: Node in [foes, player]:
		n.free()
	return true


func _test_final_mechanics() -> bool:
	print("final boss mechanics")
	var was := Realm.current
	for realm: String in ["graveyard", "frozen", "ember"]:
		Realm.current = realm
		var player: Player = load("res://scenes/player.tscn").instantiate()
		root.add_child(player)
		var director := WaveDirector.new()
		root.add_child(director)
		var final := EnemySwarm.new()
		final.capacity = 2
		final.boss = true
		final.max_hp = 1000.0
		final.move_speed = 0.0
		root.add_child(final)
		var wards := EnemySwarm.new()
		wards.capacity = 4
		wards.move_speed = 0.0
		wards.recycle_distance = 400.0
		root.add_child(wards)
		director.setup([final, wards] as Array[EnemySwarm])
		var mech := FinalMechanics.new()
		root.add_child(mech)
		mech.setup(final, wards, player, director)
		final.spawn(Vector2(0, -8))
		mech.tick(0.016)
		match realm:
			"graveyard":
				final.damage(0, 400.0)
				mech.tick(0.016)
				_check(wards.alive_count() == 3 and final.damage_taken == 0.0, "the Lich King wards himself with three phylacteries")
				var hp := final.hp[0]
				final.damage(0, 100.0)
				_check(final.hp[0] == hp, "and takes no damage while they stand")
				for k in wards.count:
					wards.damage(k, 1.0e9)
				wards.step(0.0, Vector2.ZERO)
				mech.tick(0.016)
				_check(final.damage_taken == 1.0, "shattering them breaks the ward")
			"frozen":
				mech._timer = 0.0
				mech.tick(0.016)
				_check(mech._lines.size() == 4, "the Colossus cracks four lines of ice")
				player.global_position = Vector3(30, 0, 30)
				for f in 90:
					mech.tick(1.0 / 60.0)
				_check(final.damage_taken == 2.0, "then he's exposed: double damage")
				for f in int(FinalMechanics.EXPOSED_TIME * 60.0) + 5:
					mech.tick(1.0 / 60.0)
				_check(final.damage_taken == 1.0, "for a few seconds")
			"ember":
				_check(mech.seals_left() == 4 and is_equal_approx(final.damage_taken, 0.25), "four cinder seals shield the Tyrant")
				var seal: Vector2 = mech._seals[0]["at"]
				player.global_position = Vector3(seal.x, 0, seal.y)
				mech._timer = 0.0
				for f in 100:
					mech.tick(1.0 / 60.0)
				_check(mech.seals_left() == 3, "a meteor lured onto a seal breaks it")
		final.damage(0, 1.0e9)
		final.step(0.0, Vector2.ZERO)
		mech.tick(0.016)
		_check(mech.hint == "" and wards.alive_count() == 0 and mech.seals_left() == 0, "%s: everything clears when he dies" % realm)
		for n: Node in [mech, wards, final, director, player]:
			n.free()
	Realm.current = was
	return true


func _test_replayability() -> bool:
	print("pacts, omens, bestiary, daily, report")
	_near(RunModifiers.shard_mult([], ""), 1.0, "no pacts, no omen: normal shards")
	_near(RunModifiers.shard_mult(["swarm", "bleak"], "midas"), (1.0 + 0.25 * 3) * 1.5, "heat 3 and Midas stack")
	_check(RunModifiers.OMEN_ORDER.size() == RunModifiers.OMENS.size() and RunModifiers.PACT_ORDER.size() == RunModifiers.PACTS.size(), "every omen and pact is listed")
	_check(RunModifiers.roll_omen(0.0) == RunModifiers.OMEN_ORDER[0] and RunModifiers.roll_omen(0.9999) == RunModifiers.OMEN_ORDER[-1], "omen picks cover the list")
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	for omen: String in RunModifiers.OMEN_ORDER:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		var director: WaveDirector = main.get_node("WaveDirector")
		var rate := director.rate_scale
		RunModifiers.apply(main, RunModifiers.PACT_ORDER, omen)
		var hero: Player = main.get_node("Player")
		_check(director.rate_scale >= rate * 1.1 and hero.stats.regen <= 0.0 and is_equal_approx(hero.stats.hp, hero.stats.max_hp),
				"%s with every pact applies" % omen)
		main.free()
	Obstacles.clear()
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_replay.save"
	for f in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path + f))
	MetaProgress.load_save()
	_check(not MetaProgress.any_won(), "pacts start locked")
	var starred := MetaProgress.record_kills({"Ghoul": 120, "Ogre": 5})
	_check(starred == ["Ghoul"] and MetaProgress.stars("Ghoul") == 1 and MetaProgress.total_stars() == 1, "100 kills of a kind earn a star")
	var stats := PlayerStats.new()
	var base := stats.bolt_damage
	MetaProgress.apply(stats)
	_check(stats.bolt_damage > base, "and each star is a little permanent damage")
	MetaProgress.set_pacts(["hide", "wrath"])
	_check(MetaProgress.record_daily("2026-10-08", 500) and not MetaProgress.record_daily("2026-10-08", 300), "the daily keeps the best")
	MetaProgress.load_save()
	_check(MetaProgress.bestiary.get("Ghoul", 0) == 120 and MetaProgress.pacts == ["hide", "wrath"] and MetaProgress.daily.get("2026-10-08") == 500,
			"bestiary, pacts and daily bests survive a reload")
	MetaProgress.save()
	# A corrupted save falls back to the backup.
	var f := FileAccess.open(MetaProgress.save_path, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	MetaProgress.load_save()
	_check(MetaProgress.bestiary.get("Ghoul", 0) == 120, "a broken save falls back to the backup")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path + suffix))
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was
	MetaProgress.load_save()
	var pick := Realm.daily_pick(["graveyard", "frozen"])
	_check(pick == Realm.daily_pick(["graveyard", "frozen"]), "the daily pick is the same all day")

	# Damage is credited to whoever dealt it, and never more than the enemy had.
	var foes := EnemySwarm.new()
	foes.capacity = 4
	root.add_child(foes)
	foes.spawn(Vector2.ZERO)
	foes.hp[0] = 50.0
	Elements.damage_by.clear()
	Elements.source = "Obol"
	Elements.hit(foes, 0, 30.0)
	Elements.source = "Magic Bolt"
	Elements.hit(foes, 0, 999.0)
	_check(is_equal_approx(Elements.damage_by.get("Obol", 0.0), 30.0) and is_equal_approx(Elements.damage_by.get("Magic Bolt", 0.0), 20.0),
			"the run report credits real damage by source (%s)" % [Elements.damage_by])
	foes.free()
	return true


func _test_rifts() -> bool:
	print("rifts")
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var rift: RiftDirector = main._rift
	var hero: Player = main.get_node("Player")
	var grunts: EnemySwarm = main.get_node("Grunts")
	for f in 5:
		main._process(1.0 / 60.0)
	hero.global_position = Vector3(12, 0, 7)
	grunts.spawn(Vector2(15, 7))
	var foe_at := grunts.pos[grunts.count - 1]
	var hp := hero.stats.hp
	var clock: float = main.elapsed
	_check(rift.can_open(), "a rift can open early in the night")
	rift.enter_market()
	_check(rift.in_market() and hero.pos2.distance_to(RiftDirector.MARKET_AT) < 1.0, "the market takes the hero far away")
	_check(not grunts.visible, "and hides the horde")
	for f in 120:
		main._process(1.0 / 60.0)
	_check(main.elapsed == clock and grunts.pos[grunts.count - 1] == foe_at, "the realm holds still (clock and horde)")
	main._run_shards = 20
	_check(rift.buy("rare") and main._run_shards == 12, "the Bone Merchant sells a Rare for 8 shards")
	_check(not rift.buy("rare"), "once per visit")
	var rerolls: int = main._rerolls
	_check(rift.buy("rerolls") and main._rerolls == rerolls + 2, "the Fortune Teller sells rerolls")
	_check(not rift.buy("elixir") or main._run_shards >= 0, "can't spend shards you don't have")
	rift.leave_market()
	_check(not rift.in_market() and hero.pos2.distance_to(Vector2(12, 7)) < 1.0 and grunts.visible, "leaving puts the hero back where they were")
	_check(hero.invulnerable, "with a moment's grace")
	_near(hero.stats.hp, hp, "and nothing else changed", 5.0)
	for f in 120:
		main._process(1.0 / 60.0)
	_check(not hero.invulnerable and main.elapsed > clock, "then the night goes on")
	rift.enter_market()
	rift._market["left"] = 0.01
	main._process(1.0 / 60.0)
	_check(not rift.in_market(), "the market fades on its own")
	rift.start_glitch()
	_check(rift.glitching(), "the glitch starts")
	var drops := (main.get_node("Loot") as LootManager).drops.size()
	rift.glitch_left = 0.01
	rift.tick(0.02)
	_check(not rift.glitching() and (main.get_node("Loot") as LootManager).drops.size() == drops + 2, "and surviving it leaves a gift")
	main.free()
	Obstacles.clear()
	MetaProgress.disabled = was
	return true


func _test_dawn() -> bool:
	print("dawn")
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var director: WaveDirector = main.get_node("WaveDirector")
	var bosses: BossDirector = main.get_node("BossDirector")
	var atmosphere: Atmosphere = main.get_node("Atmosphere")
	var sun: DirectionalLight3D = main.get_node("Sun")
	_check(main.first_light() == 0.0 and main.night_progress() == 0.0, "no First Light at dusk")
	director.elapsed = bosses.run_length - main.get_script().FIRST_LIGHT * 0.5
	_check(absf(main.first_light() - 0.5) < 0.01, "First Light rises over the last minutes (%.2f)" % main.first_light())
	_check(absf(main.night_progress() - (1.0 - main.get_script().FIRST_LIGHT * 0.5 / bosses.run_length)) < 0.01, "the night's arc follows the clock")
	atmosphere.first_light = 0.0
	atmosphere.tick(0.016, 0.0, false)
	var high := sun.basis.z.y
	atmosphere.first_light = 1.0
	atmosphere.tick(0.016, 0.0, false)
	var low := sun.basis.z.y
	_check(high > 0.6 and low < high * 0.5 and low > 0.1, "the sun sinks toward the horizon before dawn (%.2f -> %.2f)" % [high, low])

	# The sunrise front spreads from the final boss and burns the horde.
	var grunts: EnemySwarm = main.get_node("Grunts")
	grunts.spawn(Vector2(3, 0), 1.0)
	grunts.spawn(Vector2(40, 0), 1.0)
	var kills_before: int = main.kills
	main._on_final_died(Vector2.ZERO)
	_check(main.first_light() == 1.0, "full light once the night is won")
	main._sweep_horde(1.0)
	_check(grunts.hp[0] <= 0.0 and grunts.hp[1] > 0.0, "the light reaches the near enemy first")
	main._sweep_horde(main.get_script().DAWN_SWEEP)
	_check(grunts.alive_count() == 0, "and the whole horde is ash when the sweep ends")
	_check(main.kills == kills_before, "the sunrise's kills give no rewards")
	_check(main._dawn_front == null, "the light front is cleaned up")
	paused = false
	main.free()
	Obstacles.clear()
	MetaProgress.disabled = was
	return true


func _test_veterans() -> bool:
	print("veterans and the Crypt")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunts := EnemySwarm.new()
	grunts.capacity = 16
	grunts.max_hp = 10.0
	root.add_child(grunts)
	var brutes := EnemySwarm.new()
	brutes.capacity = 4
	brutes.max_hp = 80.0
	root.add_child(brutes)
	var army := Army.new()
	root.add_child(army)
	var army_swarms: Array[EnemySwarm] = [grunts, brutes]
	army.setup(player, army_swarms)
	Elements.swarms = army_swarms
	var said := []
	army.promoted.connect(func(text: String) -> void: said.append(text))
	var fell := []
	army.veteran_fell.connect(func(n: String, c: int) -> void: fell.append([n, c]))

	army._raise(0, false, false)
	var hp0 := army._max_hp[0]
	army.credit(0, Army.RANKS[1]["kills"] - 1)
	_check(army._rank[0] == 0 and said.is_empty(), "no name before enough kills")
	army.credit(0, 1)
	_check(army._rank[0] == 1 and army._vname[0] != "" and said.size() == 1, "enough kills earn a name and the Veteran rank")
	_near(army._max_hp[0], hp0 * Army.RANKS[1]["power"], "a veteran can take more")
	_check(army._tag[0] != null and (army._tag[0] as Label3D).text.contains(army._vname[0]), "and wears its name over its head")
	army.credit(0, Army.RANKS[3]["kills"])
	_check(army._rank[0] == 3 and said.size() == 3, "kills keep promoting it, up to Legend")
	_near(army._max_hp[0], hp0 * Army.RANKS[3]["power"], "each rank's toughness replaces the last")

	# Kills in a fight are credited to the minion that made them.
	var deaths := EnemySwarm.deaths
	army._raise(0, false, false)
	var k := army.count - 1
	army._pos[k] = player.pos2 + Vector2(1, 0)
	for i in 6:
		grunts.spawn(player.pos2 + Vector2(1.6, 0), 1.0)
	for i in grunts.count:
		grunts.hp[i] = 0.5
	var before := army._deeds[k]
	for f in 60:
		grunts.step(1.0 / 60.0, player.pos2)
		brutes.step(1.0 / 60.0, player.pos2)
		army.step(1.0 / 60.0)
	_check(EnemySwarm.deaths > deaths and army._deeds[0] + army._deeds[k] - before - Army.RANKS[3]["kills"] > 0,
			"kills in a fight count toward the minions' deeds")

	# A champion pushing out a common spares the veteran.
	while army.count > 0:
		army._remove(0, false, false)
	player.stats.minion_max = 2
	army._raise(0, false, false)
	army.credit(0, Army.RANKS[1]["kills"])
	var vet_name := army._vname[0]
	army._raise(0, false, false)
	army._raise(0, true, false)
	_check(army.count == 2 and army._vname.slice(0, 2).has(vet_name), "a champion takes a common minion's place, not a veteran's")

	# The record round-trips through the Crypt and back into the army.
	var rec := army.veterans()[0]
	_check(rec["name"] == vet_name and rec["swarm"] == String(grunts.name) and rec["rank"] == 1, "a veteran's record keeps who it is")
	var vet_slot: int = rec["slot"]
	army._remove(vet_slot, true)
	_check(fell.size() == 1 and fell[0][0] == vet_name and fell[0][1] == -1, "a named veteran's death is announced")
	var was := MetaProgress.disabled
	var was_path := MetaProgress.save_path
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_crypt.save"
	_wipe_save()
	MetaProgress.load_save()
	var id := MetaProgress.entomb(rec)
	_check(id > 0 and MetaProgress.crypt.size() == 1 and MetaProgress.crypt_chosen == id, "the first veteran laid to rest is chosen to rise")
	MetaProgress.load_save()
	_check(MetaProgress.chosen_veteran().get("name", "") == vet_name, "the Crypt is saved")
	_check(army.raise_veteran(MetaProgress.chosen_veteran()), "a veteran rises from the Crypt")
	var j := army.count - 1
	_check(army._vname[j] == vet_name and army._rank[j] == 1 and army._crypt[j] == id, "as itself, with its rank and Crypt id")
	var back: Dictionary = army.veterans().filter(func(v: Dictionary) -> bool: return v["crypt"] == id)[0]
	back["deeds"] += 10
	_check(MetaProgress.entomb(back) == id and MetaProgress.crypt.size() == 1 and MetaProgress.crypt[0]["nights"] == 2,
			"it goes back to rest with its new deeds, not as a copy")
	for n in 3:
		var other := rec.duplicate()
		other["crypt"] = -1
		other["name"] = "Other %d" % n
		other["deeds"] = 1000 + n
		MetaProgress.entomb(other)
	_check(MetaProgress.crypt.size() == MetaProgress.CRYPT_SIZE and MetaProgress.crypt.all(func(v: Dictionary) -> bool: return v["name"] != vet_name),
			"a full Crypt keeps the greatest")
	var keep: int = MetaProgress.crypt[0]["id"]
	MetaProgress.choose_veteran(keep)
	MetaProgress.crypt_fell(keep)
	_check(MetaProgress.crypt.size() == MetaProgress.CRYPT_SIZE - 1 and MetaProgress.fallen[0]["id"] == keep and MetaProgress.crypt_chosen == -1,
			"a Crypt veteran that falls is gone, and remembered")
	_wipe_save()
	MetaProgress.save_path = was_path
	MetaProgress.disabled = was
	MetaProgress.load_save()
	Elements.swarms = []
	for n: Node in [army, brutes, grunts, player]:
		n.free()
	return true


func _test_evolutions() -> bool:
	print("weapon evolutions")
	for id: String in Evolutions.DEFS:
		var d: Dictionary = Evolutions.DEFS[id]
		_check(Upgrades.DEFS.has(d["weapon"]) and Upgrades.DEFS.has(d["catalyst"]), "%s names real upgrades" % id)
		for m: Dictionary in d["mods"]:
			_check(PlayerStats.BASE.has(m["stat"]), "%s changes a real stat (%s)" % [id, m["stat"]])
	var stats := PlayerStats.new()
	_check(Evolutions.ready(stats).is_empty(), "nothing evolves at the start")
	for n in Upgrades.DEFS["scythe"]["max"]:
		Upgrades.apply("scythe", stats)
	_check(Evolutions.ready(stats).is_empty(), "a maxed weapon needs its catalyst")
	var seen_hint := false
	var s2 := PlayerStats.new()
	for n in Upgrades.DEFS["scythe"]["max"] - 2:
		Upgrades.apply("scythe", s2)
	for k in 40:
		for c: Dictionary in Upgrades.roll(s2, 20):
			if c["id"] == "scythe" and String(c["desc"]).contains("Death's Harvest"):
				seen_hint = true
	_check(seen_hint, "a weapon card near max names its evolution")
	Upgrades.apply("harvest", stats)
	_check(Evolutions.ready(stats) == ["deaths_harvest"], "max weapon + catalyst: ready to evolve")
	var cards := Upgrades.roll(stats)
	_check(cards[0]["id"] == "evo:deaths_harvest" and cards[0].get("tag", "") == "EVOLUTION" and cards.size() == 3,
			"the evolution takes the first card")
	var dmg := stats.scythe_damage
	var count := stats.scythe_count
	Upgrades.apply("evo:deaths_harvest", stats)
	_check(stats.scythe_count == count + 2 and stats.scythe_damage > dmg * 1.7, "evolving makes the weapon much stronger")
	_check(Evolutions.ready(stats).is_empty() and not Upgrades.roll(stats).any(func(c: Dictionary) -> bool: return c["id"].begins_with("evo:")),
			"each evolution happens once")
	return true


func _test_rival() -> bool:
	print("rival necromancer")
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	for ending in ["slain", "escaped"]:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		var rival: RivalDirector = main._rival
		var swarm: EnemySwarm = main.get_node("Rival")
		var thralls: EnemySwarm = main.get_node("Thralls")
		var hero: Player = main.get_node("Player")
		var army: Army = main.get_node("Army")
		var souls: GemSwarm = main.get_node("Souls")
		rival.arrive()
		_check(swarm.alive_count() == 1 and thralls.alive_count() == 3 and rival.active() and rival.rival_name != "",
				"the rival arrives with a few thralls (%s)" % ending)
		var at := swarm.pos[0]
		for k in 5:
			souls.drop(at + Vector2(1, 0), 1)
		rival.tick(0.016)
		_check(rival.stolen == 5, "it steals the souls lying near it")
		_check(thralls.alive_count() >= 4, "stolen souls raise more thralls")
		army.souls = 5
		hero.global_position = Vector3(at.x + 3.0, 0, at.y)
		hero.pos2 = at + Vector2(3, 0)
		rival._drain = 0.0
		rival._blink = 99.0
		rival.tick(0.016)
		_check(army.souls == 5 - RivalDirector.DRAIN_AMOUNT and rival.stolen == 5 + RivalDirector.DRAIN_AMOUNT, "and drains the hero's banked souls when close")
		rival._blink = 0.0
		rival.tick(0.016)
		_check(swarm.pos[0].distance_to(hero.pos2) >= 9.0, "it blinks away when the hero closes in")
		_check(rival.hint.contains(rival.rival_name.to_upper()) and rival.markers().size() == 1, "the HUD tracks it")
		if ending == "slain":
			var before := army.count
			var loot: LootManager = main.get_node("Loot")
			var drops := loot.get_child_count()
			swarm.damage(0, 1.0e12)
			_check(rival.defeated and not rival.active() and rival.hint == "", "killing the rival ends its hunt")
			_check(army.count >= before + 3, "its thralls and shade join the army, past its size (%d -> %d)" % [before, army.count])
			_check(thralls.alive_count() == 0, "the rest of its thralls fade")
			_check(loot.get_child_count() > drops, "and it leaves loot")
		else:
			rival._left = 0.01
			rival.tick(0.05)
			_check(swarm.alive_count() == 0 and thralls.alive_count() == 0 and not rival.defeated and not rival.active(),
					"if not killed in time, it escapes and its thralls fade")
		main.free()
		Obstacles.clear()
	MetaProgress.disabled = was
	return true


func _test_ascension() -> bool:
	print("ascension and pressure")
	_near(RunModifiers.shard_mult([], "", 3), 1.3, "each Ascension level adds 10% shards")
	_check(RunModifiers.ASCENSION.size() == RunModifiers.ASCENSION_MAX, "every Ascension level has a rule")
	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var director: WaveDirector = main.get_node("WaveDirector")
	var final: EnemySwarm = main.get_node("FinalBoss")
	var hero: Player = main.get_node("Player")
	var hp_scale := director.hp_scale
	var ramp := director.pressure_ramp
	var final_hp := final.max_hp
	var regen := hero.stats.regen
	RunModifiers.apply(main, [], "", RunModifiers.ASCENSION_MAX)
	_check(director.hp_scale > hp_scale * 1.19 and is_equal_approx(final.max_hp, final_hp * 2.0), "Ascension 10 stacks every rule")
	_near(hero.stats.regen, regen * 0.5, "including half regeneration")
	_near(director.pressure_ramp, ramp * (1.0 + RunModifiers.ASCENSION_PRESSURE * RunModifiers.ASCENSION_MAX), "and lets pressure climb faster")
	director.pressure_ramp = ramp
	RunModifiers.apply(main, [], "", 0)
	_near(hero.stats.regen, regen, "the stat rules come off again")

	# Pressure builds while the hero dominates and eases when they're hurt.
	director.pressure = 1.0
	director.elapsed = 10.0
	director.update_pressure(5.0, 1.0, 0)
	_check(director.pressure == 1.0, "no pressure early in the night")
	director.elapsed = director.pressure_start + 600.0
	var hp1 := director.hp_multiplier()
	director.update_pressure(20.0, 1.0, 0)
	_check(director.pressure > 1.2 and director.hp_multiplier() > hp1 * 1.2, "a dominant hero raises the pressure (%.2f)" % director.pressure)
	var p := director.pressure
	director.update_pressure(5.0, 1.0, 10000)
	var with_crowd := director.pressure - p
	p = director.pressure
	director.update_pressure(5.0, 1.0, 0)
	_check(with_crowd > 0.0 and director.pressure - p > with_crowd * 1.9, "an unhurt hero builds it anyway, twice as fast with the field cleared")
	p = director.pressure
	director.update_pressure(5.0, 0.85, 0)
	_check(director.pressure == p, "a scratched hero holds it steady")
	director.update_pressure(5.0, 0.3, 0)
	_check(director.pressure < p, "a hurting hero lowers it")
	director.update_pressure(9999.0, 1.0, 0)
	_check(director.pressure == director.pressure_cap() and director.pressure_cap() > 5.0, "pressure is capped (%.1f)" % director.pressure_cap())
	director.elapsed = director.pressure_start + 60.0
	director.update_pressure(9999.0, 1.0, 0)
	_check(director.pressure <= 1.0 + director.pressure_ramp + 0.001, "and the cap grows with the night")
	director.update_pressure(9999.0, 0.1, 0)
	_check(director.pressure == 1.0, "and never drops below the plain curve")
	main.free()
	Obstacles.clear()

	MetaProgress.disabled = false
	var was_path := MetaProgress.save_path
	MetaProgress.save_path = "user://test_meta_ascension.save"
	_wipe_save()
	MetaProgress.load_save()
	_check(MetaProgress.ascension_unlocked == 0, "Ascension starts locked")
	MetaProgress.set_ascension(3)
	_check(MetaProgress.ascension == 0, "a locked level can't be chosen")
	_check(MetaProgress.record_ascension_win(0) and MetaProgress.ascension_unlocked == 1, "winning opens the next level")
	_check(not MetaProgress.record_ascension_win(0), "winning below the top doesn't open more")
	MetaProgress.set_ascension(1)
	MetaProgress.load_save()
	_check(MetaProgress.ascension == 1 and MetaProgress.ascension_unlocked == 1, "the choice is saved")
	_wipe_save()
	MetaProgress.save_path = was_path
	MetaProgress.disabled = was
	MetaProgress.load_save()
	return true


func _test_stances() -> bool:
	print("army stances")
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunts := EnemySwarm.new()
	grunts.capacity = 8
	grunts.move_speed = 0.0
	root.add_child(grunts)
	var army := Army.new()
	root.add_child(army)
	var army_swarms: Array[EnemySwarm] = [grunts]
	army.setup(player, army_swarms)
	var told := []
	army.stance_changed.connect(func(st: String) -> void: told.append(st))
	_check(army.stance == "hunt", "the army starts out hunting")
	army.cycle_stance()
	_check(army.stance == "guard" and told == ["guard"], "the stance cycles to Guard")
	army.cycle_stance()
	army.cycle_stance()
	_check(army.stance == "hunt", "and around back to Hunt")
	army._raise(0, false, false)
	army._pos[0] = player.pos2
	grunts.spawn(player.pos2 + Vector2(9, 0), 1.0) # 9 m out: Hunt's reach, not Guard's
	grunts.spawn(player.pos2 + Vector2(-4, 0), 1.0, true) # an elite, nearer the hero
	grunts.spawn(player.pos2 + Vector2(2.5, 0), 1.0)
	grunts.step(0.016, player.pos2)
	army.cycle_stance("guard")
	army._find_target(0, player.pos2 + Vector2(7, 0), player.pos2)
	_check(army._target_id[0] < 0 or grunts.pos[army._target_index[0]].distance_to(player.pos2) <= Army.STANCES["guard"]["leash"],
			"guarding minions only fight what's near the hero")
	army.cycle_stance("hunt")
	army._find_target(0, player.pos2 + Vector2(7, 0), player.pos2)
	_check(army._target_id[0] >= 0 and army._target_index[0] == 0, "hunting minions take the nearest prey")
	army.cycle_stance("swarm")
	army._find_target(0, player.pos2 + Vector2(1, 0), player.pos2)
	_check(army._target_id[0] >= 0 and army._target_index[0] == 1, "swarming minions go for the elite first")
	for n: Node in [army, grunts, player]:
		n.free()
	return true


func _test_soul_trails_and_death() -> bool:
	print("soul trails and the hero's death")
	var w := Wisps.new()
	root.add_child(w)
	w.chance = 1.0
	for k in 10:
		w.from_kill(Vector2(8, 0))
	_check(w.heads == 10, "kills send wisps")
	var trails := false
	for f in 240:
		w.step(1.0 / 60.0, Vector2.ZERO)
		if w.count > w.heads:
			trails = true
	_check(trails, "wisps leave trails")
	_check(w.heads == 0, "every wisp reaches the hero within a few seconds")
	w.max_heads = 5
	for k in 20:
		w.from_kill(Vector2(8, 0))
	_check(w.heads == 5, "the number of wisps is capped")
	w.clear()
	w.scatter(Vector2.ZERO, 30)
	_check(w.heads == 30, "a fallen hero's souls scatter")
	for f in 240:
		w.step(1.0 / 60.0, Vector2.ZERO)
	_check(w.count == 0, "and fade away")
	w.free()

	var was := MetaProgress.disabled
	MetaProgress.disabled = true
	Realm.in_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var hud: Hud = main.get_node("Hud")
	var army: Army = main.get_node("Army")
	army._raise(0, false, false)
	main._on_player_died()
	_check(main._game_over and main._dying > 0.0 and not hud._game_over_root.visible, "the hero's death plays out before the end screen")
	for f in 400:
		main._death_frame(1.0 / 60.0)
		if hud._game_over_root.visible:
			break
	_check(hud._game_over_root.visible and main._dying == 0.0, "then the end screen shows")
	Engine.time_scale = 1.0
	main.free()
	Obstacles.clear()
	MetaProgress.disabled = was
	return true


func _test_nemesis() -> bool:
	print("the nemesis")
	var was := MetaProgress.disabled
	var was_path := MetaProgress.save_path
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_nemesis.save"
	_wipe_save()
	MetaProgress.load_save()
	Realm.in_title = false
	# Night one: a new rival escapes.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	MetaProgress.disabled = false # (main's setup leaves it as it found it)
	var rival: RivalDirector = main._rival
	var swarm: EnemySwarm = main.get_node("Rival")
	var thralls: EnemySwarm = main.get_node("Thralls")
	rival.arrive()
	var first_hp := swarm.hp[0]
	var first_name := rival.rival_name
	_check(rival.rank == 0, "the first rival is no one's nemesis yet")
	rival.stolen = 12
	rival._left = 0.01
	rival.tick(0.05)
	_check(MetaProgress.nemesis.get("name", "") == first_name and MetaProgress.nemesis["rank"] == 1 and MetaProgress.nemesis["stolen"] == 12,
			"an escaped rival becomes a nemesis")
	main.free()
	Obstacles.clear()
	MetaProgress.load_save()
	_check(MetaProgress.nemesis.get("rank", 0) == 1, "the nemesis is saved")

	# Night two: it returns stronger, and the hero falls while it's about.
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	rival = main._rival
	swarm = main.get_node("Rival")
	thralls = main.get_node("Thralls")
	rival.arrive()
	_check(rival.rival_name == first_name and rival.rank == 1, "the nemesis returns by name")
	_check(swarm.hp[0] > first_hp * 1.3 and thralls.alive_count() == 4, "a rank tougher, with more thralls")
	rival.hero_fell()
	_check(MetaProgress.nemesis["rank"] == 2 and MetaProgress.nemesis["escapes"] == 2, "outliving the hero ranks it up too")
	main.free()
	Obstacles.clear()

	# Night three: put down for good.
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	rival = main._rival
	swarm = main.get_node("Rival")
	var loot: LootManager = main.get_node("Loot")
	rival.arrive()
	_check(rival.rank == 2, "it keeps climbing")
	var drops := loot.get_child_count()
	var shards: int = main._run_shards
	swarm.damage(0, 1.0e12)
	_check(main._run_shards - shards == RivalDirector.SHARDS * 3, "a nemesis pays shards per rank")
	_check(loot.get_child_count() - drops >= 3, "and a Legendary per rank")
	_check(MetaProgress.nemesis.is_empty() and MetaProgress.nemeses_slain == 1, "and is gone for good")
	main.free()
	Obstacles.clear()
	_wipe_save()
	MetaProgress.save_path = was_path
	MetaProgress.disabled = was
	MetaProgress.load_save()
	return true


func _test_slow_motion_ends() -> bool:
	print("slow motion always ends")
	var was := Juice.time_effects
	Juice.time_effects = true
	Juice.slow_motion(0.3, 0.2)
	_near(Engine.time_scale, 0.3, "slow motion slows the game")
	Juice.hitstop(0.05)
	_near(Engine.time_scale, 0.05, "a hit-stop inside it freezes for a moment")
	OS.delay_msec(70)
	Juice.tick()
	_near(Engine.time_scale, 0.3, "then the slow motion carries on, not stuck at the hit-stop")
	OS.delay_msec(160)
	Juice.tick()
	_near(Engine.time_scale, 1.0, "and the game returns to full speed when it ends")
	for k in 50:
		Juice.hitstop(0.001 * k)
	OS.delay_msec(60)
	Juice.tick()
	_near(Engine.time_scale, 1.0, "even after a flurry of overlapping hit-stops")
	Juice.time_effects = was
	Juice.tick()
	return true


func _test_late_leveling() -> bool:
	print("late-game leveling")
	var p: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	_check(p.xp_for_level(10) == int(6 + 5 * 10 + 0.45 * 100), "early levels cost what they always did")
	var plain := int(6 + 5 * 60 + 0.45 * 3600)
	_check(p.xp_for_level(60) > plain * 2, "late levels cost much more (%d vs %d)" % [p.xp_for_level(60), plain])
	var main_script: GDScript = load("res://scripts/main.gd")
	_near(main_script.xp_scale_at(0.0), 1.0, "kills are worth full XP early")
	_near(main_script.xp_scale_at(300.0), 1.0, "...through the first five minutes")
	_near(main_script.xp_scale_at(420.0), 0.5, "half by 7:00")
	_check(main_script.xp_scale_at(900.0) < 0.2, "and under a fifth by dawn")
	p.xp_scale = 0.5
	var before := p.stats.xp
	p.add_xp(4)
	_check(p.stats.xp - before == roundi(4 * p.stats.xp_gain * 0.5), "the hero takes XP at the current scale")
	p.free()
	return true
