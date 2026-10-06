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
	_test_generation()
	_test_rarity_distribution()
	_test_serialization()
	_test_inventory()
	_test_loot()
	_test_director()

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
	var fallback := Upgrades.roll(m)
	_check(fallback.size() == 1 and fallback[0]["id"] == "heal", "empty pool falls back to heal")


# --- items -------------------------------------------------------------------

func _test_generation() -> void:
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


func _test_rarity_distribution() -> void:
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


func _test_serialization() -> void:
	print("serialization")
	for n in 60:
		var item := ItemGenerator.generate(15, 0.5)
		# var_to_str keeps ints as ints, which JSON would not.
		var copy := Item.from_dict(str_to_var(var_to_str(item.to_dict())))
		_check(copy.name == item.name and copy.slot == item.slot and copy.rarity == item.rarity
				and copy.ilvl == item.ilvl and copy.base_name == item.base_name, "basic fields survive a round trip")
		_check(_same_mods(copy.modifiers(), item.modifiers()), "modifiers survive a round trip")
		_check(copy.uid != item.uid, "a copy is a new item")


func _test_inventory() -> void:
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


func _test_loot() -> void:
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
	for i in 50:
		rolls.roll_kill_drop(Vector2.ZERO, 0.0, 0.0, 5, 0.0)
	_check(rolls.drops.is_empty(), "0% chance never drops")
	for i in 10:
		rolls.roll_kill_drop(Vector2.ZERO, 1.0, 0.0, 5, 0.0)
	_check(rolls.drops.size() == 10, "100% chance always drops")
	for d in rolls.drops:
		_check(d.item.ilvl == 5, "dropped items use the given item level")

	loot.free()
	small.free()
	rolls.free()


func _test_director() -> void:
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
