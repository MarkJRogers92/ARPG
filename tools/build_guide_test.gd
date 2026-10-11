extends SceneTree
## Tests for BuildGuide and BuildGuidePanel.
##
##   godot --headless --path . -s tools/build_guide_test.gd

var _failures := 0
var _checks := 0


func _initialize() -> void:
	MetaProgress.disabled = true
	_run(&"_test_rows_all_classes", _test_rows_all_classes())
	_run(&"_test_readiness", _test_readiness())
	_run(&"_test_snapshot_restrictions", _test_snapshot_restrictions())
	_run(&"_test_class_rank_distinction", _test_class_rank_distinction())
	_run(&"_test_immutability", _test_immutability())
	_run(&"_test_affected_text", _test_affected_text())
	_run(&"_test_invalid_ids", _test_invalid_ids())
	_run(&"_test_exact_preview", _test_exact_preview())
	_run(&"_test_panel_pin_back", _test_panel_pin_back())
	_finish.call_deferred()


func _finish() -> void:
	print("")
	if _failures == 0:
		print("ALL BUILD GUIDE TESTS PASSED (%d checks)" % _checks)
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


func _class_stats(class_id: String) -> PlayerStats:
	var stats := PlayerStats.new()
	var d := HeroClass.data(class_id)
	stats.innate_powers = {}
	for p: String in d["powers"]:
		stats.innate_powers[p] = 1
	stats.powers = stats.innate_powers.duplicate()
	stats.add_mods(HeroClass.SOURCE, d["mods"])
	stats.recalculate()
	return stats


func _apply(stats: PlayerStats, id: String, times: int = 1) -> void:
	for i in times:
		Upgrades.apply(id, stats)


func _ids(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(row["id"])
	return out


func _test_rows_all_classes() -> bool:
	print("rows respect class/reaper compatibility")
	for class_id: String in HeroClass.ORDER:
		var stats := _class_stats(class_id)
		var rows := BuildGuide.rows(stats)
		var reaper := class_id == "reaper"
		for row in rows:
			var weapon_id: String = row["weapon"]["id"]
			var catalyst_id: String = row["catalyst"]["id"]
			_check(Upgrades.offered(weapon_id, stats), "%s weapon %s offered" % [class_id, weapon_id])
			_check(Upgrades.offered(catalyst_id, stats), "%s catalyst %s offered" % [class_id, catalyst_id])
		if reaper:
			_check(not "soul_lance" in _ids(rows), "Reaper cannot see bolt evolution soul_lance")
	return true


func _test_readiness() -> bool:
	print("readiness for every recipe")
	for id: String in Evolutions.DEFS:
		var d: Dictionary = Evolutions.DEFS[id]
		var weapon_id: String = d["weapon"]
		var catalyst_id: String = d["catalyst"]
		var weapon_max: int = Upgrades.DEFS[weapon_id]["max"]

		var fresh := PlayerStats.new()
		var row_fresh: Dictionary = _find_row(BuildGuide.rows(fresh), id)
		_check(row_fresh.is_empty() or not row_fresh["ready"], "%s not ready on fresh stats" % id)

		var weapon_only := PlayerStats.new()
		_apply(weapon_only, weapon_id, weapon_max)
		var row_weapon: Dictionary = _find_row(BuildGuide.rows(weapon_only), id)
		if not row_weapon.is_empty():
			_check(not row_weapon["ready"], "%s not ready without catalyst" % id)
			_check(row_weapon["owned"], "%s weapon owned after maxing" % id)

		var ready_stats := PlayerStats.new()
		_apply(ready_stats, weapon_id, weapon_max)
		_apply(ready_stats, catalyst_id, 1)
		var row_ready: Dictionary = _find_row(BuildGuide.rows(ready_stats), id)
		_check(not row_ready.is_empty(), "%s row exists when maxed+catalyst" % id)
		_check(row_ready["ready"], "%s ready when maxed+catalyst" % id)
		_check(id in Evolutions.ready(ready_stats), "%s matches Evolutions.ready" % id)

		var taken_stats := PlayerStats.new()
		_apply(taken_stats, weapon_id, weapon_max)
		_apply(taken_stats, catalyst_id, 1)
		Upgrades.apply(Evolutions.PREFIX + id, taken_stats)
		var row_taken: Dictionary = _find_row(BuildGuide.rows(taken_stats), id)
		if not row_taken.is_empty():
			_check(row_taken["taken"], "%s marked taken after applying" % id)
			_check(not row_taken["ready"], "%s not ready after taken" % id)
	return true


func _test_snapshot_restrictions() -> bool:
	print("snapshot passed through to offered checks")
	# None of the evolution ingredients have unlocks, so the snapshot should not
	# filter them out; verify it is still forwarded without errors.
	var stats := PlayerStats.new()
	var rows_default := BuildGuide.rows(stats)
	var rows_snapshot := BuildGuide.rows(stats, {"bolt_pierce": false})
	_check(rows_default.size() == rows_snapshot.size(), "irrelevant snapshot does not change rows")
	# For a card that would be locked, offered honors the snapshot.
	_check(Upgrades.offered("deadly_aim", stats, {"deadly_aim": false}) == false, "snapshot can lock a card")
	_check(Upgrades.offered("deadly_aim", stats, {"deadly_aim": true}) == true, "snapshot can unlock a card")
	return true


func _test_class_rank_distinction() -> bool:
	print("class/item ability level does not count as card rank")
	var storm := _class_stats("stormcaller")
	_check(storm.lightning_level >= 1, "Stormcaller has lightning from class")
	_check(Upgrades.level_of("lightning", storm) == 0, "class lightning does not count as card rank")
	var row: Dictionary = _find_row(BuildGuide.rows(storm), "storm_lord")
	if not row.is_empty():
		_check(row["weapon"]["rank"] == 0, "storm_lord weapon rank is 0 from class alone")

	var reaper := _class_stats("reaper")
	_check(reaper.scythe_level >= 1, "Reaper has scythe from class")
	_check(Upgrades.level_of("scythe", reaper) == 0, "class scythe does not count as card rank")
	var row2: Dictionary = _find_row(BuildGuide.rows(reaper), "deaths_harvest")
	if not row2.is_empty():
		_check(row2["weapon"]["rank"] == 0, "deaths_harvest weapon rank is 0 from class alone")
	return true


func _test_immutability() -> bool:
	print("BuildGuide never mutates stats")
	var stats := _class_stats("battlemage")
	_apply(stats, "bolt_damage", 3)
	var before := stats.upgrade_levels.duplicate()
	var before_hp := stats.hp
	BuildGuide.rows(stats)
	BuildGuide.affected_text("soul_lance", stats)
	BuildGuide.goal_summary("soul_lance", stats)
	_check(stats.upgrade_levels == before, "upgrade_levels unchanged")
	_check(is_equal_approx(stats.hp, before_hp), "hp unchanged")
	return true


func _test_affected_text() -> bool:
	print("affected preview accuracy")
	var stats := PlayerStats.new()
	var soul := BuildGuide.affected_text("soul_lance", stats)
	_check(soul.contains("Magic Bolt") and soul.contains("→"), "soul_lance includes affected ability and actual before/after")
	_check(soul.contains("Pierce"), "soul_lance mentions Pierce")

	var zero := BuildGuide.affected_text("absolute_zero", stats)
	_check(zero.contains("Radius") and zero.contains("Damage"), "absolute_zero mentions affected stats")

	var storm := _class_stats("stormcaller")
	var storm_text := BuildGuide.affected_text("storm_lord", storm)
	_check(storm_text.contains("already active"), "storm_lord notes class-granted lightning")

	var frost := BuildGuide.affected_text("frostbite", stats)
	_check(frost.contains("Chill chance") and frost.contains("Magic Bolt"), "first frostbite upgrade affects bolt chill chance")
	_apply(stats, "frostbite")
	_check(BuildGuide.affected_text("frostbite", stats).contains("Shatter / Melt / Overload"), "later Frostbite affects all three reactions, not bolt damage")

	var aura := BuildGuide.affected_text("aura", stats)
	_check(aura.contains("Frost Aura") or aura.contains("radius") or aura.contains("damage"), "aura upgrade preview is specific")

	var after_frostbite := PlayerStats.new()
	_apply(after_frostbite, "frostbite", 1)
	var abs_zero_frost := BuildGuide.affected_text("absolute_zero", after_frostbite)
	_check(abs_zero_frost.contains("Frostbite") or abs_zero_frost.contains("Shatter"), "absolute_zero mentions Frostbite reactions")
	return true


func _test_exact_preview() -> bool:
	for class_id: String in HeroClass.ORDER:
		for id: String in Upgrades.DEFS:
			for rank in [0, 1]:
				var before := _class_stats(class_id)
				if rank == 1: Upgrades.apply(id, before)
				before.add_mod("test", "damage", PlayerStats.Op.MORE, 0.25)
				before.recalculate()
				var saved := var_to_str([before._mods, before.upgrade_levels, before.values, before.powers, before.hp])
				var actual := _class_stats(class_id)
				if rank == 1: Upgrades.apply(id, actual)
				actual.add_mod("test", "damage", PlayerStats.Op.MORE, 0.25)
				actual.recalculate()
				Upgrades.apply(id, actual)
				var changes := BuildGuide.preview_changes(id, before)
				for change: Dictionary in changes:
					_check(is_equal_approx(change["before"], BuildGuide._stat_value(change["field"], before)), "preview starts at actual effective stat")
					_check(is_equal_approx(change["after"], BuildGuide._stat_value(change["field"], actual)), "preview matches actual upgrade path across classes/ranks")
				_check(var_to_str([before._mods, before.upgrade_levels, before.values, before.powers, before.hp]) == saved, "preview preserves all live stats/mods/powers")
				_check(not BuildGuide.affected_text(id, before).is_empty(), "every real upgrade has a readable affected preview")
	_check(BuildGuide.goal_summary("", PlayerStats.new()) == "", "unpinned goal is hidden, not unknown")
	_check(BuildGuide.rows(null).is_empty() and BuildGuide.affected_text("aura", null) == "", "null stats are safe")
	_check(BuildGuide.affected_text("evo:soul_lance", PlayerStats.new()) == BuildGuide.affected_text("soul_lance", PlayerStats.new()), "offered prefixed evolution card uses same preview")
	var ready := PlayerStats.new()
	_apply(ready, "bolt_damage", Upgrades.DEFS["bolt_damage"]["max"])
	_apply(ready, "bolt_pierce")
	_check(BuildGuide.goal_summary("soul_lance", ready).contains("next level-up"), "only ready recipe is guaranteed next roll")
	_apply(ready, "aura", Upgrades.DEFS["aura"]["max"])
	_apply(ready, "frostbite")
	_check(BuildGuide.goal_summary("soul_lance", ready).contains("one of 2"), "multiple ready recipes disclose random selection")
	Evolutions.apply("soul_lance", ready)
	_check(BuildGuide.affected_text("soul_lance", ready).contains("Already evolved") and not BuildGuide.affected_text("soul_lance", ready).contains("→"), "taken recipe never previews a second application")
	var gear := PlayerStats.new()
	gear.add_mod("gear", "aura_level", PlayerStats.Op.ADD, 1)
	gear.recalculate()
	_check(_find_row(BuildGuide.rows(gear), "absolute_zero")["weapon"]["rank"] == 0, "item access is not a card rank")
	return true


func _test_invalid_ids() -> bool:
	print("invalid ids handled gracefully")
	var stats := PlayerStats.new()
	_check(BuildGuide.affected_text("not_a_recipe", stats) == "", "unknown evolution/upgrade returns empty")
	_check(BuildGuide.goal_summary("not_a_recipe", stats) == "Unknown recipe.", "unknown recipe summary")
	return true


func _test_panel_pin_back() -> bool:
	print("BuildGuidePanel pin, unpin and back signals")
	var panel := BuildGuidePanel.new()
	root.add_child(panel)

	var stats := PlayerStats.new()
	panel.present(stats)

	var pinned: Array[String] = []
	var backed: Array[bool] = [false]
	panel.goal_changed.connect(func(id: String) -> void: pinned.append(id))
	panel.back_requested.connect(func() -> void: backed[0] = true)

	panel._set_pinned("soul_lance")
	_check(pinned.has("soul_lance"), "pin emits goal_changed")

	panel._set_pinned("")
	_check(pinned.has(""), "unpin emits empty goal_changed")

	panel._set_pinned("absolute_zero")
	_check(pinned.has("absolute_zero"), "pin emits goal_changed")

	panel._back.pressed.emit()
	_check(backed[0], "back button emits back_requested")

	# Presenting new stats should not restore a saved pin.
	panel.present(stats)
	_check(panel._pinned_id == "", "present without pinned_id clears pin")

	panel.queue_free()
	return true


func _find_row(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if row["id"] == id:
			return row
	return {}
