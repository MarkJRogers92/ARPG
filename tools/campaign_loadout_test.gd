extends SceneTree
## Captured from the pre-extraction Main assembler and checked through both
## the live entry point and the isolated town preview.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	MetaProgress.disabled = true
	var cases := _fixtures()
	for fixture: Dictionary in cases:
		_test_fixture(fixture)
	print("CAMPAIGN LOADOUT TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)


func _test_fixture(fixture: Dictionary) -> void:
	var state: Dictionary = fixture["state"]
	var before := state.duplicate(true)
	var preview := CampaignLoadout.preview(state)
	_check(preview == CampaignLoadout.preview(state), "%s preview repeats deterministically" % fixture["hero"])
	_check(state == before, "%s preview leaves campaign snapshot unchanged" % fixture["hero"])
	_check(int(preview["effect_count"]) == fixture["effect_count"], "%s preview includes current-node effects only" % fixture["hero"])
	_check(String(preview["selected_node_id"]) == "route", "%s preview reports selected route node" % fixture["hero"])
	_check(String(preview["primary_attack_label"]) == fixture["attack"], "%s preview identifies its actual base attack" % fixture["hero"])
	_check(int(preview["stat_effect_count"]) == fixture["stat_effect_count"], "%s preview counts only current-node stat effects" % fixture["hero"])
	_check(preview["stat_effect_names"] == fixture["stat_effect_names"], "%s preview names current-node stat effects in order" % fixture["hero"])
	for key: String in fixture["expected"]:
		var expected: float = fixture["expected"][key]
		_check(is_equal_approx(float(preview[key]), expected), "%s preview %s matches pre-extraction baseline" % [fixture["hero"], key])
	_check(preview.get("selected_effect_name", "") == fixture["effect_name"], "%s preview names its current route effect" % fixture["hero"])

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	main.set("_hero_class", fixture["hero"])
	main.set("expedition_spec", {"effects": fixture["effects"]})
	main.call("_apply_expedition_loadout_before_tree", fixture["loadout"])
	var player: Player = main.get_node("Player")
	var stats: PlayerStats = player.stats
	for key: String in fixture["expected"]:
		var actual: float = _main_value(stats, key)
		_check(is_equal_approx(actual, fixture["expected"][key]), "%s Main entry point %s matches pre-extraction baseline" % [fixture["hero"], key])
	_check(player.dead == false and is_equal_approx(stats.hp, stats.max_hp), "%s Main entry point starts alive at full health" % fixture["hero"])
	_check(main.get("_campaign_cards") == fixture["loadout"]["profile_snapshot"]["cards"], "%s Main keeps campaign card bookkeeping" % fixture["hero"])
	_check(main.get("_relic") == fixture["loadout"]["profile_snapshot"]["relic"], "%s Main keeps relic bookkeeping" % fixture["hero"])
	_check(main.get("_spec_chosen") == (fixture["loadout"]["specialization"] != ""), "%s Main keeps specialization bookkeeping" % fixture["hero"])
	_check(stats.innate_powers.has(fixture["power"]), "%s shared loadout preserves class/relic power" % fixture["hero"])
	_check(stats.powers.has(fixture["power"]), "%s effective powers retain class/relic power" % fixture["hero"])
	if fixture.has("gear_power"):
		_check(stats.powers.has(fixture["gear_power"]), "%s effective powers include equipped legendary" % fixture["hero"])
	_check(Upgrades.level_of(fixture["start_weapon_id"], stats) == 1, "%s starting weapon has rank one" % fixture["hero"])
	_check(_main_value(stats, fixture["start_weapon_stat"]) == fixture["start_weapon_effective_level"],
		"%s starting weapon and other sources produce the expected effective level" % fixture["hero"])
	if fixture.has("class_weapon_stat"):
		_check(_main_value(stats, fixture["class_weapon_stat"]) == 1.0, "%s class starting weapon unlock remains present" % fixture["hero"])
	_check(player.skills.allocated.has(fixture["skill"]), "%s shared loadout preserves allocated talent" % fixture["hero"])
	_check(player.inventory.equipped.has("weapon") == fixture["has_gear"], "%s shared loadout restores gear" % fixture["hero"])
	main.free()


func _main_value(stats: PlayerStats, key: String) -> float:
	match key:
		"max_hp": return stats.max_hp
		"armor": return stats.armor
		"move_speed": return stats.move_speed
		"crit_chance": return stats.crit_chance
		"minion_max": return float(stats.minion_max)
		"aura_level": return float(stats.aura_level)
		"lightning_level": return float(stats.lightning_level)
		"scythe_level": return float(stats.scythe_level)
		"primary_damage": return stats.scythe_damage if stats.powers.has("reaping") and stats.scythe_level > 0 else stats.bolt_damage
		"primary_cooldown": return stats.scythe_cooldown if stats.powers.has("reaping") and stats.scythe_level > 0 else stats.bolt_cooldown
	return -1.0


func _fixtures() -> Array[Dictionary]:
	var reaper_gear := {"slot":"weapon", "base_name":"Ashen Oath", "name":"Ashen Oath", "rarity":2, "ilvl":9,
		"implicit":[{"stat":"scythe_damage", "op":PlayerStats.Op.INCREASED, "value":0.1}], "affixes":[], "power":"stormcaller"}
	var reaper_loadout := {"hero_class":"reaper", "profile_snapshot":{"mods":[{"stat":"max_hp", "op":PlayerStats.Op.INCREASED, "value":0.2}],
		"relic":"iron_heart", "start_weapon":"lightning", "cards":{"x":2}},
		"inventory":{"equipped":{"weapon":reaper_gear}, "backpack":[]},
		"talents":{"points":2, "allocated":["d1"]}, "specialization":"executioner"}
	var reaper_effect := {"id":"quiet_bell", "node_id":"route", "mods":[{"stat":"armor", "op":PlayerStats.Op.INCREASED, "value":0.25},
		{"stat":"max_hp", "op":PlayerStats.Op.INCREASED, "value":0.1}]}
	var borrowed_effect := {"id":"borrowed_battalion", "node_id":"route", "minions":3}
	var reaper_state := _state("reaper", reaper_loadout, [borrowed_effect, reaper_effect, _off_route_effect()])

	var mage_loadout := {"hero_class":"battlemage", "profile_snapshot":{"mods":[], "relic":"winter_tear", "start_weapon":"aura", "cards":{}},
		"inventory":{"equipped":{}, "backpack":[]}, "talents":{"points":3, "allocated":["a1"]}, "specialization":"sniper"}
	var mage_state := _state("battlemage", mage_loadout, [])

	var necro_loadout := {"hero_class":"necromancer", "profile_snapshot":{"mods":[], "relic":"glass_skull", "start_weapon":"scythe", "cards":{}},
		"inventory":{"equipped":{}, "backpack":[]}, "talents":{"points":3, "allocated":["d1"]}, "specialization":"champions"}
	var necro_state := _state("necromancer", necro_loadout, [])
	return [
		{"hero":"reaper", "state":reaper_state, "loadout":reaper_loadout, "effects":[reaper_effect], "effect_count":2, "effect_name":"Borrowed Battalion",
			"stat_effect_count":1, "stat_effect_names":["The Quiet Bell"],
			"attack":"Reaping Scythe", "power":"reaping", "gear_power":"stormcaller", "start_weapon_id":"lightning", "start_weapon_stat":"lightning_level", "start_weapon_effective_level":1.0, "class_weapon_stat":"scythe_level", "skill":"d1", "has_gear":true,
			"expected":{"max_hp":190.4, "armor":37.5, "move_speed":6.6, "crit_chance":0.15, "minion_max":2.0, "primary_damage":29.376, "primary_cooldown":1.15740740740741}},
		{"hero":"battlemage", "state":mage_state, "loadout":mage_loadout, "effects":[], "effect_count":0, "effect_name":"", "stat_effect_count":0, "stat_effect_names":[],
			"attack":"Bolts", "power":"winter_crown", "start_weapon_id":"aura", "start_weapon_stat":"aura_level", "start_weapon_effective_level":3.0, "skill":"a1", "has_gear":false,
			"expected":{"max_hp":100.0, "armor":0.0, "move_speed":6.0, "crit_chance":0.05, "minion_max":2.0, "primary_damage":14.0, "primary_cooldown":0.454545454545455}},
		{"hero":"necromancer", "state":necro_state, "loadout":necro_loadout, "effects":[], "effect_count":0, "effect_name":"", "stat_effect_count":0, "stat_effect_names":[],
			"attack":"Bolts", "power":"lich_shroud", "start_weapon_id":"scythe", "start_weapon_stat":"scythe_level", "start_weapon_effective_level":1.0, "skill":"d1", "has_gear":false,
			"expected":{"max_hp":74.2, "armor":0.0, "move_speed":6.0, "crit_chance":0.05, "minion_max":3.0, "primary_damage":11.475, "primary_cooldown":0.5}},
	]


func _state(hero: String, loadout: Dictionary, effects: Array) -> Dictionary:
	var state := CampaignState.fresh(hero, 7001, {"mods":[], "relic":"", "start_weapon":"", "rerolls":0, "cards":{}})
	state["profile_snapshot"] = loadout["profile_snapshot"].duplicate(true)
	var campaign_items := {"items":{}, "equipped":{}, "backpack":[], "tray":[]}
	for slot: String in loadout["inventory"]["equipped"]:
		var id := "gear-" + slot
		campaign_items["items"][id] = {"data":loadout["inventory"]["equipped"][slot].duplicate(true)}
		campaign_items["equipped"][slot] = id
	state["inventory"] = campaign_items
	state["talents"] = loadout["talents"].duplicate(true)
	state["specialization"] = loadout["specialization"]
	state["graph"] = {"nodes":{"route":{"id":"route"}}}
	state["selected_node"] = "route"
	state["effects"] = effects.duplicate(true)
	return state


func _off_route_effect() -> Dictionary:
	return {"id":"quiet_bell", "node_id":"other", "mods":[{"stat":"max_hp", "op":PlayerStats.Op.INCREASED, "value":5.0}]}
