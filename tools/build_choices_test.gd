extends SceneTree
## Tests for bounded upgrade rolls and the three rank-one synergy cards.
##
## Run from a QA project with a distinct config/custom_user_dir_name.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	MetaProgress.disabled = true
	seed(2026)

	_run(&"_test_roll_backward_compat", _test_roll_backward_compat())
	_run(&"_test_weighted_favours_owned", _test_weighted_favours_owned())
	_run(&"_test_exploration_possible", _test_exploration_possible())
	_run(&"_test_ready_evolution_first_slot", _test_ready_evolution_first_slot())
	_run(&"_test_banish_and_exhaustion", _test_banish_and_exhaustion())
	_run(&"_test_rng_reproducible", _test_rng_reproducible())
	_run(&"_test_class_seed_comparisons", _test_class_seed_comparisons())

	_finish.call_deferred()


func _finish() -> void:
	_run(&"_test_synergy_relay", _test_synergy_relay())
	_run(&"_test_synergy_escort", _test_synergy_escort())
	_run(&"_test_synergy_wake", _test_synergy_wake())
	_run(&"_test_synergy_save_boundary", _test_synergy_save_boundary())
	_run(&"_test_build_guide_synergy_text", _test_build_guide_synergy_text())
	_run(&"_test_live_pickup_orders_and_removal", _test_live_pickup_orders_and_removal())

	if _player_parent != null and is_instance_valid(_player_parent):
		_player_parent.free()
	print("")
	if _failures == 0:
		print("ALL BUILD CHOICES TESTS PASSED (%d checks)" % _checks)
	else:
		print("%d OF %d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _run(test_name: StringName, finished) -> void:
	_checks += 1
	if finished != true:
		_failures += 1
		print("  FAIL: %s stopped early (script error above)" % test_name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL: ", message)


func _near(a: float, b: float, message: String, eps := 0.0001) -> void:
	_check(absf(a - b) <= eps, "%s (got %s, expected %s)" % [message, a, b])


# --- roll tests --------------------------------------------------------------

func _test_roll_backward_compat() -> bool:
	print("roll backward compatibility")
	var stats := PlayerStats.new()
	var picks := Upgrades.roll(stats, 3)
	_check(picks.size() == 3, "classic 3-arg roll returns 3 cards")
	var ids := picks.map(func(p: Dictionary) -> String: return p["id"])
	_check(ids.size() == Array(ids).filter(func(x: String) -> bool: return ids.count(x) == 1).size(), "no duplicates")
	_check(Upgrades.roll(stats, 0).is_empty(), "n=0 returns empty")
	_check(Upgrades.roll(stats, -1).is_empty(), "negative n returns empty")
	return true


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _test_weighted_favours_owned() -> bool:
	print("weighted roll favours owned weapons and catalysts")
	var stats := PlayerStats.new()
	# Give the hero a modest class-like bump to minion stats so class-loop
	# weighting is exercised, then take a weapon and an evolution catalyst.
	stats.add_mod("class", "minion_damage", PlayerStats.Op.INCREASED, 0.3)
	stats.recalculate()
	Upgrades.apply("lightning", stats)
	Upgrades.apply("ignite", stats)

	var weighted_counts := {}
	var uniform_counts := {}
	var reps := 1200
	for i in reps:
		for c: Dictionary in Upgrades.roll(stats, 3, null, [], _rng(12345 + i), true):
			weighted_counts[c["id"]] = weighted_counts.get(c["id"], 0) + 1
		for c: Dictionary in Upgrades.roll(stats, 3, null, [], _rng(12345 + i), false):
			uniform_counts[c["id"]] = uniform_counts.get(c["id"], 0) + 1

	_check(weighted_counts.get("lightning", 0) > uniform_counts.get("lightning", 0),
		"owned lightning appears more often under weighting")
	# ignite is the catalyst for storm_lord, whose weapon (lightning) is owned.
	_check(weighted_counts.get("ignite", 0) > uniform_counts.get("ignite", 0),
		"catalyst for owned evolving weapon appears more often")
	# legion touches the class-boosted minion_damage stat.
	_check(weighted_counts.get("legion", 0) > uniform_counts.get("legion", 0),
		"card touching class-boosted stat appears more often")
	return true


func _test_exploration_possible() -> bool:
	print("exploration remains possible under weighting")
	var stats := PlayerStats.new()
	Upgrades.apply("lightning", stats)
	var seen := {}
	for i in 1000:
		for c: Dictionary in Upgrades.roll(stats, 3, null, [], _rng(99 + i), true):
			seen[c["id"]] = true
	# With only lightning owned, many other cards should still appear.
	_check(seen.size() >= 12, "weighted roll still shows a broad pool (%d seen)" % seen.size())
	# Cards the hero has no connection to should still appear.
	var unrelated := ["move_speed", "regen", "magnet", "max_hp"]
	for id in unrelated:
		_check(seen.has(id), "unrelated card %s still appears" % id)
	return true


func _test_ready_evolution_first_slot() -> bool:
	print("ready evolution always takes the first slot")
	var stats := PlayerStats.new()
	for i in Upgrades.DEFS["bolt_damage"]["max"]:
		Upgrades.apply("bolt_damage", stats)
	Upgrades.apply("bolt_pierce", stats)
	var picks := Upgrades.roll(stats, 3)
	_check(picks[0]["id"] == Evolutions.PREFIX + "soul_lance", "ready evolution is first")
	# With a forced pool that would otherwise fill the first slot.
	var picks2 := Upgrades.roll(stats, 1)
	_check(picks2[0]["id"] == Evolutions.PREFIX + "soul_lance", "ready evolution replaces first slot when n=1")
	return true


func _test_banish_and_exhaustion() -> bool:
	print("banish excludes regular ids; heal exhaustion still works")
	var stats := PlayerStats.new()
	for i in 200:
		for c: Dictionary in Upgrades.roll(stats, 3, null, ["bolt_damage", "aura"], _rng(777 + i), false):
			_check(c["id"] != "bolt_damage" and c["id"] != "aura", "banished id not offered")

	_check(not Upgrades.is_banishable(Evolutions.PREFIX + "soul_lance"), "evolutions are not banishable")
	_check(not Upgrades.is_banishable("heal"), "heal is not banishable")
	_check(Upgrades.is_banishable("bolt_damage"), "regular upgrade is banishable")
	var locked_card := "deadly_aim"
	_check(Upgrades.DEFS[locked_card].has("unlock"), "test uses a locked card")
	_check(not Upgrades.can_banish(locked_card, stats), "cannot banish a locked card")

	var maxed := PlayerStats.new()
	for id: String in Upgrades.DEFS:
		maxed.upgrade_levels[id] = Upgrades.DEFS[id]["max"]
	for id: String in Evolutions.DEFS:
		maxed.upgrade_levels[Evolutions.PREFIX + id] = 1
	var fallback := Upgrades.roll(maxed, 3, null, ["heal"])
	_check(fallback.size() == 1 and fallback[0]["id"] == "heal", "empty pool falls back to heal")
	_check(Upgrades.is_exhausted(fallback), "heal-only roll is exhausted")
	return true


func _test_rng_reproducible() -> bool:
	print("seeded RNG is reproducible")
	var stats := PlayerStats.new()
	stats.add_mod("class", "minion_damage", PlayerStats.Op.INCREASED, 0.3)
	stats.recalculate()
	Upgrades.apply("lightning", stats)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var first := _roll_ids(Upgrades.roll(stats, 3, null, [], rng, true))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 424242
	var second := _roll_ids(Upgrades.roll(stats, 3, null, [], rng2, true))
	_check(first == second, "same seed produces same roll")

	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 424243
	var third := _roll_ids(Upgrades.roll(stats, 3, null, [], rng3, true))
	_check(third != first or third == [], "different seed produces different roll")
	return true


func _roll_ids(choices: Array) -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in choices:
		out.append(c["id"])
	return out

func _test_class_seed_comparisons() -> bool:
	var owned_cards := {"battlemage": "bolt_damage", "necromancer": "bell", "pyromancer": "trail", "stormcaller": "lightning", "reaper": "scythe"}
	for hero: String in HeroClass.ORDER:
		var player := Player.new()
		HeroClass.apply(player, hero)
		var owned: String = owned_cards[hero]
		Upgrades.apply(owned, player.stats)
		var evo := Evolutions.for_weapon(owned)
		var catalyst: String = evo["catalyst"]
		var weighted := {}
		var uniform := {}
		var seen := {}
		for i in 1200:
			for card: Dictionary in Upgrades.roll(player.stats, 3, {}, [], _rng(38000 + i), true):
				weighted[card["id"]] = weighted.get(card["id"], 0) + 1
				seen[card["id"]] = true
			for card: Dictionary in Upgrades.roll(player.stats, 3, {}, [], _rng(38000 + i), false): uniform[card["id"]] = uniform.get(card["id"], 0) + 1
		print("SEEDED OFFERS %s · owned %s W%d/U%d · catalyst %s W%d/U%d · variety %d" % [hero, owned, weighted.get(owned, 0), uniform.get(owned, 0), catalyst, weighted.get(catalyst, 0), uniform.get(catalyst, 0), seen.size()])
		_check(weighted.get(owned, 0) > uniform.get(owned, 0), "owned weapon modest support for " + hero)
		_check(weighted.get(catalyst, 0) > uniform.get(catalyst, 0), "owned recipe catalyst support for " + hero)
		_check(seen.size() >= 12 and not seen.has("deadly_aim"), "variety and committed ownership gates for " + hero)
		for id: String in seen: _check(Upgrades._weight_for(id, player.stats) > 0.0 and Upgrades._weight_for(id, player.stats) <= 2.0, "positive bounded offer weights")
		player.free()
	# Two evolutions ready: both choices consume only the supplied RNG.
	var stats := PlayerStats.new()
	for id in ["aura", "lightning"]:
		for i in Upgrades.DEFS[id]["max"]: Upgrades.apply(id, stats)
	Upgrades.apply("frostbite", stats)
	Upgrades.apply("ignite", stats)
	for i in 50:
		var a := _rng(9000 + i)
		var b := _rng(9000 + i)
		seed(i)
		var first := Upgrades.roll(stats, 3, {}, [], a)
		seed(i + 1000)
		var second := Upgrades.roll(stats, 3, {}, [], b)
		_check(first == second and a.state == b.state, "ready-evolution selection uses supplied seeded RNG")
	return true

func _test_live_pickup_orders_and_removal() -> bool:
	for id: String in ["synergy_relay", "synergy_escort", "synergy_wake"]:
		for card_first: bool in [true, false]:
			var player := _make_player()
			var stats := player.stats
			var syn := BuildSynergies.new()
			var swarm := _make_swarm()
			if card_first: Upgrades.apply(id, stats)
			# Simulate removable gear granting counterparts, not another card.
			var fields: Dictionary = {"synergy_relay": {"lightning_level": 1.0, "aura_level": 1.0}, "synergy_escort": {"ignite_chance": 1.0}, "synergy_wake": {"orbit_level": 1.0}}
			for field: String in fields[id]: stats.add_mod("removable", field, PlayerStats.Op.ADD, fields[id][field])
			stats.recalculate()
			if not card_first: Upgrades.apply(id, stats)
			_check(BuildSynergies.live(id, stats), "both pickup orders become live")
			_trigger(id, syn, player, swarm)
			_check(syn.drain().size() == (3 if id == "synergy_wake" else 1), "both orders emit real expected pulses")
			syn.tick(1.0)
			stats.remove_source("removable")
			stats.recalculate()
			_check(not BuildSynergies.live(id, stats) and BuildGuide.affected_text(id, stats).contains("dormant"), "removal disables predicate and preview")
			_trigger(id, syn, player, swarm)
			_check(syn.drain().is_empty(), "lingering enemy status cannot bypass removed counterpart")
			swarm.free()
			player.free()
	return true

func _trigger(id: String, syn: BuildSynergies, player: Player, swarm: EnemySwarm) -> void:
	match id:
		"synergy_relay": syn.on_hit(player, swarm, 0, "Chain Lightning", Elements.LIGHTNING, 20.0)
		"synergy_escort": syn.on_hit(player, swarm, 0, "Soul Army", Elements.NONE, 20.0)
		"synergy_wake": syn.on_dash(player, Vector2.RIGHT)


# --- synergy tests -----------------------------------------------------------

var _player_parent: Node3D

func _make_player() -> Player:
	if _player_parent == null or not is_instance_valid(_player_parent):
		_player_parent = Node3D.new()
		root.add_child(_player_parent)
	var player: Player = load("res://scenes/player.tscn").instantiate()
	_player_parent.add_child(player)
	player.global_position = Vector3.ZERO
	return player


func _make_swarm() -> EnemySwarm:
	var swarm := EnemySwarm.new()
	swarm.pos = PackedVector2Array([Vector2(5.0, 0.0)])
	swarm.hp = PackedFloat32Array([100.0])
	swarm.chill = PackedFloat32Array([2.0])
	swarm.burn = PackedFloat32Array([2.0])
	swarm.radius = 0.45
	swarm.count = 1
	return swarm


func _test_synergy_relay() -> bool:
	print("Frost Relay")
	var player := _make_player()
	var swarm := _make_swarm()
	var syn := BuildSynergies.new()

	# Neither owned nor lightning live: nothing.
	syn.on_hit(player, swarm, 0, "Chain Lightning", Elements.LIGHTNING, 100.0)
	_check(syn.drain().is_empty(), "relay does nothing when not owned")

	# Own the card first, then acquire lightning: live after both are present.
	Upgrades.apply("synergy_relay", player.stats)
	Upgrades.apply("lightning", player.stats)
	Upgrades.apply("aura", player.stats)
	syn.on_hit(player, swarm, 0, "Chain Lightning", Elements.LIGHTNING, 100.0)
	var pulses := syn.drain()
	_check(pulses.size() == 1, "relay queues one frost pulse")
	_check(pulses[0]["element"] == Elements.FROST, "relay element is frost")
	_check(pulses[0]["radius"] == 1.6, "relay radius")
	_near(pulses[0]["damage"], 50.0, "relay damage is 50% of triggering hit")
	_near(pulses[0]["at"].distance_to(Vector2(7.0, 0.0)), 0.0, "relay spawns 2m past target", 0.01)
	_check(pulses[0]["source"] == "Frost Relay", "relay source tag")

	# Cooldown caps repeated triggers.
	syn.on_hit(player, swarm, 0, "Chain Lightning", Elements.LIGHTNING, 100.0)
	_check(syn.drain().is_empty(), "relay respects cooldown")
	syn.tick(0.75)
	syn.on_hit(player, swarm, 0, "Chain Lightning", Elements.LIGHTNING, 100.0)
	_check(syn.drain().size() == 1, "relay fires again after cooldown")

	# Missing chill source: dormant even when owned + lightning.
	var player2 := _make_player()
	Upgrades.apply("synergy_relay", player2.stats)
	Upgrades.apply("lightning", player2.stats)
	var swarm2 := _make_swarm()
	swarm2.chill[0] = 0.0
	var syn2 := BuildSynergies.new()
	syn2.on_hit(player2, swarm2, 0, "Chain Lightning", Elements.LIGHTNING, 100.0)
	_check(syn2.drain().is_empty(), "relay dormant without chill source")

	# Other sources do not trigger relay.
	var player3 := _make_player()
	Upgrades.apply("synergy_relay", player3.stats)
	Upgrades.apply("lightning", player3.stats)
	var syn3 := BuildSynergies.new()
	syn3.on_hit(player3, swarm, 0, "Spirit Blades", Elements.NONE, 100.0)
	_check(syn3.drain().is_empty(), "relay ignores non-chain-lightning hits")
	player.free()
	player2.free()
	player3.free()
	swarm.free()
	swarm2.free()
	return true


func _test_synergy_escort() -> bool:
	print("Soulfire Escort")
	var player := _make_player()
	var swarm := _make_swarm()
	var syn := BuildSynergies.new()

	Upgrades.apply("synergy_escort", player.stats)
	Upgrades.apply("ignite", player.stats)
	syn.on_hit(player, swarm, 0, "Soul Army", Elements.NONE, 100.0)
	var pulses := syn.drain()
	_check(pulses.size() == 1, "escort queues one fire pulse")
	_check(pulses[0]["element"] == Elements.FIRE, "escort element is fire")
	_check(pulses[0]["radius"] == 1.6, "escort radius")
	_near(pulses[0]["damage"], player.stats.minion_damage * 0.35, "escort damage is 35% of minion damage", 0.01)
	_check(pulses[0]["source"] == "Ashen Escort", "escort source tag")

	# Cooldown cap.
	syn.on_hit(player, swarm, 0, "Soul Army", Elements.NONE, 100.0)
	_check(syn.drain().is_empty(), "escort respects cooldown")
	syn.tick(1.0)
	syn.on_hit(player, swarm, 0, "Soul Army", Elements.NONE, 100.0)
	_check(syn.drain().size() == 1, "escort fires again after cooldown")

	# Missing burn source.
	var player2 := _make_player()
	Upgrades.apply("synergy_escort", player2.stats)
	var swarm2 := _make_swarm()
	swarm2.burn[0] = 0.0
	var syn2 := BuildSynergies.new()
	syn2.on_hit(player2, swarm2, 0, "Soul Army", Elements.NONE, 100.0)
	_check(syn2.drain().is_empty(), "escort dormant without burn source")
	player.free()
	player2.free()
	swarm.free()
	swarm2.free()
	return true


func _test_synergy_wake() -> bool:
	print("Blade Wake")
	var player := _make_player()
	var syn := BuildSynergies.new()

	Upgrades.apply("synergy_wake", player.stats)
	Upgrades.apply("orbit", player.stats)
	syn.on_dash(player, Vector2(0, -1))
	var pulses := syn.drain()
	_check(pulses.size() == 3, "wake queues three pulses")
	for i in 3:
		_check(pulses[i]["element"] == Elements.NONE, "wake pulse %d is none-element" % i)
		_check(pulses[i]["radius"] == 0.7, "wake pulse %d radius" % i)
		_near(pulses[i]["damage"], player.stats.orbit_damage * 0.4, "wake pulse %d damage" % i, 0.01)
		_near(pulses[i]["at"].distance_to(Vector2(0.0, -(i + 1.0))), 0.0, "wake pulse %d position" % i, 0.01)

	# Missing blades disables wake.
	var player2 := _make_player()
	Upgrades.apply("synergy_wake", player2.stats)
	syn.on_dash(player2, Vector2(0, -1))
	_check(syn.drain().is_empty(), "wake dormant without spirit blades")

	# Queue cap: many dashes cannot exceed 5 queued pulses.
	var player3 := _make_player()
	Upgrades.apply("synergy_wake", player3.stats)
	Upgrades.apply("orbit", player3.stats)
	for k in 4:
		syn.on_dash(player3, Vector2(0, -1))
	_check(syn.drain().size() == 5, "wake queue capped at 5")
	player.free()
	player2.free()
	player3.free()
	return true


func _test_synergy_save_boundary() -> bool:
	print("synergies activate from upgrade_levels, not innate powers")
	var stats := PlayerStats.new()
	_check(Upgrades.offered("synergy_relay", stats) == false, "relay not offered on fresh stats")
	Upgrades.apply("lightning", stats)
	_check(Upgrades.offered("synergy_relay", stats) == true, "relay offered when lightning level is live")
	Upgrades.apply("aura", stats)
	_check(Upgrades.offered("synergy_relay", stats) == true, "relay offered when chill source is live")

	# Taking the card only changes upgrade_levels; no powers are set.
	Upgrades.apply("synergy_relay", stats)
	_check(stats.upgrade_levels.has("synergy_relay"), "relay rank recorded")
	_check(not stats.powers.has("synergy_relay"), "relay does not add an innate power snapshot")
	return true


func _test_build_guide_synergy_text() -> bool:
	print("BuildGuide synergy text")
	var stats := PlayerStats.new()
	var t := BuildGuide.affected_text("synergy_relay", stats)
	_check(t.contains("Chain Lightning") and t.contains("chill"), "relay text names affected abilities")
	_check(t.contains("0.75") and t.contains("dormant"), "relay text includes cap and dormant state")

	Upgrades.apply("synergy_relay", stats)
	Upgrades.apply("lightning", stats)
	Upgrades.apply("aura", stats)
	var live := BuildGuide.affected_text("synergy_relay", stats)
	_check(live.contains("live"), "relay text reports live state when both constituents present")

	var wake := BuildGuide.affected_text("synergy_wake", PlayerStats.new())
	_check(wake.contains("Spirit Blades") and wake.contains("Dash"), "wake text names affected abilities")
	_check(wake.contains("dormant"), "wake text reports dormant state when not owned")
	return true
