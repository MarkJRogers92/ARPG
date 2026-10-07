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
	_test_skill_data()
	_test_skill_tree()
	_test_skill_points()
	_test_new_weapons()
	_test_meta_progress()
	_test_elite_rate()
	_test_legendaries()
	_test_realms()
	_test_realm_progress()
	_test_classes_and_settings()
	_test_sounds()
	_test_asset_props()
	_test_asset_placement()
	# These need nodes in the running tree, which only exists after this returns.
	_finish.call_deferred()


func _finish() -> void:
	_test_elites_and_knockback()
	_test_enemy_shots()
	_test_elements()
	_test_army()
	_test_heroes()
	_test_events()

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
	_check(Upgrades.is_exhausted(fallback), "a heal-only roll counts as exhausted")
	_check(not Upgrades.is_exhausted(Upgrades.roll(PlayerStats.new())), "a normal roll is not exhausted")


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


# --- skill tree --------------------------------------------------------------

func _test_skill_data() -> void:
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


func _test_skill_tree() -> void:
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


func _test_skill_points() -> void:
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

func _test_new_weapons() -> void:
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


func _test_meta_progress() -> void:
	print("meta progression")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta.save"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()


func _test_elites_and_knockback() -> void:
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


func _test_enemy_shots() -> void:
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


func _test_elite_rate() -> void:
	print("elite rate")
	var d := WaveDirector.new()
	_near(d.elite_rate(), 0.0, "no elites at the start")
	d.elapsed = d.elite_start_time + 60.0
	_near(d.elite_rate(), d.elites_per_minute + d.elites_per_minute_growth, "elite rate grows each minute")
	d.elapsed = 100000.0
	_near(d.elite_rate(), d.elites_per_minute_max, "and caps")
	d.free()


func _test_legendaries() -> void:
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


func _test_elements() -> void:
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


func _test_army() -> void:
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


func _test_realms() -> void:
	print("realms")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var models: Array = []
	for m in ["grunt", "brute", "runner", "cultist", "boss", "wraith", "imp", "lich", "colossus", "tyrant"]:
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


func _test_realm_progress() -> void:
	print("realm progress")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_realms.save"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()


func _test_classes_and_settings() -> void:
	print("hero classes and settings")
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://test_meta_classes.save"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
	MetaProgress.save_path = "user://meta.save"
	MetaProgress.disabled = was_disabled
	MetaProgress.load_save()


func _test_sounds() -> void:
	print("sounds")
	for sound: String in Sound.RULES:
		_check(ResourceLoader.exists("res://audio/sfx/%s.wav" % sound), "sound %s has a file" % sound)
		_check(Sound.RULES[sound].size() == 4, "sound %s has a full rule" % sound)
	for id: String in Realm.ORDER:
		for layer in ["calm", "drums"]:
			_check(ResourceLoader.exists("res://audio/music/%s_%s.ogg" % [id, layer]), "%s has %s music" % [id, layer])
	_check(ResourceLoader.exists("res://audio/music/boss.ogg"), "there's boss music")


func _test_heroes() -> void:
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


func _test_events() -> void:
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


## Godot XYZ size and emissive surface count, from the art pack's ASSET_CATALOG.json.
const _ASSET_CATALOG := {
	"rune_gravestone": [Vector3(1.021, 1.28, 1.55), 0], "soul_brazier": [Vector3(0.84, 1.98, 0.84), 1],
	"mausoleum": [Vector3(3.385, 3.625, 3.985), 0], "snow_boulder": [Vector3(1.826, 1.263, 1.504), 0],
	"frosted_pine": [Vector3(1.657, 2.498, 1.616), 0], "ice_arch": [Vector3(3.186, 2.36, 0.86), 0],
	"obsidian_outcrop": [Vector3(2.052, 2.104, 1.804), 0], "brimstone_vent": [Vector3(2.109, 1.129, 1.797), 1],
	"skull_gateway": [Vector3(4.223, 4.938, 1.543), 1],
}


func _test_asset_props() -> void:
	print("imported scenery")
	var listed := Models.PROPS.filter(func(k: String) -> bool: return AssetProps.has(k))
	_check(listed == AssetProps.KINDS.keys(), "Models.PROPS lists every imported kind, in order (%s)" % [listed])
	_check(Models.PROPS.slice(0, 15) == ["grass", "rock", "bush", "mushroom", "bones", "tree", "grave", "pillar",
			"crystal", "pine", "ice", "snowrock", "obsidian", "brimstone", "ashtree"], "code-built kinds keep their order")
	for kind: String in AssetProps.KINDS:
		var d := AssetProps.data(kind)
		_check(ResourceLoader.exists(AssetProps.ROOT % d["path"]), "%s: the GLB is in the project" % kind)
		_check(d["realm"] in Realm.ORDER, "%s: chosen for a real realm" % kind)
		for key in ["scale", "yaw", "landmark", "footprint", "shadow"]:
			_check(d.has(key), "%s has %s" % [kind, key])
		var mesh := Models.prop(kind)
		_check(mesh != null and mesh == Models.prop(kind), "%s: the mesh builds once and is cached" % kind)
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
			var flat: float = m.get_shader_parameter("flat_glow")
			if flat > 0.0:
				glowing += 1
			if not d["landmark"]:
				_check(is_equal_approx(m.get_shader_parameter("uv_glow"), 0.0), "%s: UV.x never drives glow" % kind)
			var arrays := mesh.surface_get_arrays(s)
			_check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(),
					"%s: surface %d keeps its vertex colors" % [kind, s])
		_check(glowing == _ASSET_CATALOG[kind][1], "%s: %d glowing surface(s), as authored" % [kind, _ASSET_CATALOG[kind][1]])
		_check(d["footprint"] * 2.0 <= 12.0 * 0.6, "%s: footprint fits a chunk" % kind)
	for realm: String in AssetProps.PROPOSED:
		_check(realm in Realm.ORDER, "proposed densities for a real realm")
		for kind: String in AssetProps.PROPOSED[realm]:
			_check(AssetProps.has(kind) and AssetProps.data(kind)["realm"] == realm, "%s: proposed for its own realm" % kind)
	for realm: String in Realm.ORDER:
		for kind: String in Realm.data(realm)["props"]:
			_check(not AssetProps.has(kind), "stage 1: %s doesn't scatter imported %s yet" % [realm, kind])


func _test_asset_placement() -> void:
	print("imported scenery placement")
	for realm: String in Realm.ORDER:
		var decor := WorldDecor.new()
		decor.density = Realm.data(realm)["props"]
		var base: Array = decor.compute(Vector2i(3, -2))
		var d: Dictionary = Realm.data(realm)["props"].duplicate()
		var boosted: Dictionary = AssetProps.PROPOSED[realm].duplicate()
		for kind: String in boosted:
			boosted[kind] = minf(boosted[kind] * 4.0, 1.0 if AssetProps.data(kind)["landmark"] else 3.0)
		d.merge(boosted)
		decor.density = d
		var with: Array = decor.compute(Vector2i(3, -2))
		var again: Array = decor.compute(Vector2i(3, -2))
		_check(with[0] == again[0] and with[1] == again[1], "%s: the same chunks always grow the same scenery" % realm)
		var assets := []
		var landmarks := []
		for kind: String in AssetProps.KINDS:
			for xf: Transform3D in with[0][kind]:
				var at := Vector2(xf.origin.x, xf.origin.z)
				var fp: float = AssetProps.data(kind)["footprint"]
				assets.append([at, fp])
				if AssetProps.data(kind)["landmark"]:
					landmarks.append([at, fp])
					_check(at.length() >= 2.0 * WorldDecor.ASSET_CLEAR + fp, "%s: landmarks keep away from the start" % realm)
				else:
					_check(at.length() >= WorldDecor.ASSET_CLEAR + fp, "%s: imported props keep the start clear" % realm)
		_check(landmarks.size() > 0 and assets.size() > landmarks.size(), "%s: the boosted densities place props (%d, %d landmarks)" % [realm, assets.size(), landmarks.size()])
		var overlaps := 0
		for i in assets.size():
			for j in range(i + 1, assets.size()):
				if assets[i][0].distance_to(assets[j][0]) < assets[i][1] + assets[j][1] - 0.001:
					overlaps += 1
		_check(overlaps == 0, "%s: imported props never overlap (%d)" % [realm, overlaps])
		# Code-built props: the same ones in the same places, minus any under a landmark.
		var moved := 0
		var hidden := 0
		for kind: String in Models.PROPS:
			if AssetProps.has(kind):
				continue
			var now: Array = with[0][kind]
			for xf: Transform3D in base[0][kind]:
				if xf in now:
					continue
				var at := Vector2(xf.origin.x, xf.origin.z)
				var under := false
				for l: Array in landmarks:
					if at.distance_to(l[0]) < l[1]:
						under = true
				if under:
					hidden += 1
				else:
					moved += 1
			for xf: Transform3D in now:
				for l: Array in landmarks:
					_check(Vector2(xf.origin.x, xf.origin.z).distance_to(l[0]) >= l[1], "%s: nothing grows inside a landmark" % realm)
		_check(moved == 0, "%s: adding imported scenery moves no existing prop (%d moved, %d under landmarks)" % [realm, moved, hidden])
		decor.free()
	# Switching realms (the title preview) leaves nothing of the old one behind.
	var decor := WorldDecor.new()
	var d: Dictionary = Realm.data("ember")["props"].duplicate()
	d.merge(AssetProps.PROPOSED["ember"])
	decor.density = d
	decor.compute(Vector2i.ZERO)
	decor.density = Realm.data("frozen")["props"]
	var after: Array = decor.compute(Vector2i.ZERO)
	for kind: String in ["obsidian", "brimstone", "ashtree", "obsidian_outcrop", "brimstone_vent", "skull_gateway"]:
		_check(after[0][kind].is_empty(), "after switching to frozen, no %s remains" % kind)
	decor.free()
