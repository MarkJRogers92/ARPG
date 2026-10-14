extends SceneTree
## Hungering gear: roll rate, feeding rules, one-time awakening, persistence.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

## A seeded item of `rarity` forced to hunger.
func _hungry(rarity: int, slot := "weapon", ilvl := 1) -> Item:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var item := ItemGenerator.generate_with(ilvl, rarity, slot, rng)
	item.hunger_need = 0
	while item.hunger_need == 0:
		Hunger.roll(item, rng)
	return item

func _run() -> void:
	# Roll rate over a seeded sample; legendary and normal never hunger; seeds repeat.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var hungry := 0
	var n := 4000
	for i in n:
		var item := ItemGenerator.generate_with(10, ItemData.Rarity.MAGIC if i % 2 == 0 else ItemData.Rarity.RARE, "ring", rng)
		if item.hungering():
			hungry += 1
			var base: int = Hunger.NEED[item.rarity]
			check(item.hunger_need == roundi(base * (1.0 + 10 / 40.0)) and item.hunger_fed == 0, "need scales with rarity and ilvl")
	var rate := float(hungry) / n
	check(absf(rate - Hunger.CHANCE) < 0.025, "roll rate near %.2f (got %.3f)" % [Hunger.CHANCE, rate])
	for i in 300:
		check(not ItemGenerator.generate_with(10, ItemData.Rarity.LEGENDARY, "ring", rng).hungering(), "legendary never hungers")
		check(not ItemGenerator.generate_with(10, ItemData.Rarity.NORMAL, "ring", rng).hungering(), "normal never hungers")
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	var same := true
	for i in 50:
		same = same and ItemGenerator.generate_with(8, ItemData.Rarity.RARE, "helm", a).to_dict() == ItemGenerator.generate_with(8, ItemData.Rarity.RARE, "helm", b).to_dict()
	check(same and a.state == b.state, "seeded generation is deterministic")

	# Feeding: only equipped items, with elite/boss weights.
	var stats := PlayerStats.new()
	var inv := Inventory.new(stats)
	var worn := _hungry(ItemData.Rarity.MAGIC, "weapon")
	var helm := _hungry(ItemData.Rarity.MAGIC, "helm")
	inv.pickup(worn)
	inv.pickup(helm)
	var spare := _hungry(ItemData.Rarity.MAGIC, "helm")
	inv.pickup(spare)
	check(inv.backpack.has(spare), "spare is in the backpack")
	Hunger.feed(inv, 1)
	check(worn.hunger_fed == 1 and helm.hunger_fed == 1 and spare.hunger_fed == 0, "only equipped items feed")
	Hunger.feed(inv, Hunger.ELITE_WEIGHT)
	Hunger.feed(inv, Hunger.BOSS_WEIGHT)
	check(worn.hunger_fed == 61, "elite 10 and boss 50 weights (got %d)" % worn.hunger_fed)

	# Awakening: exactly once, stats applied, rarity up, prefix, extra affix in top half.
	var before_affixes := worn.affixes.size()
	var before_name := worn.name
	var campaign_before := worn.to_dict().duplicate(true)
	var awakened := Hunger.feed(inv, worn.hunger_need)
	check(awakened.size() == 2 and worn in awakened, "both worn items awaken")
	check(worn.rarity == ItemData.Rarity.RARE and worn.affixes.size() == before_affixes + 1, "magic became rare with one more affix")
	check(worn.name == "Sated " + before_name and not worn.hungering() and worn.hunger_fed == 0, "named Sated, no longer hungering")
	var extra: Dictionary = worn.affixes[-1]
	var def := ItemData.affix(extra["id"])
	var scale := ItemData.ilvl_scale(worn.ilvl, extra["stat"], extra["op"]) if def.get("scales", true) else 1.0
	var lo := lerpf(def["min"], def["max"], 0.5) * scale
	check(float(extra["value"]) >= snappedf(lo, def["step"]) - 0.0001, "extra affix rolled in the top half")
	var synced := stats._mods.filter(func(m: Dictionary) -> bool: return m["source"] == "gear:weapon" and m["stat"] == extra["stat"] and m["op"] == extra["op"] and m["value"] == extra["value"])
	check(not synced.is_empty(), "stats synced immediately with the new affix")
	var again := Hunger.feed(inv, 100000)
	check(again.is_empty() and worn.affixes.size() == before_affixes + 1 and worn.name == "Sated " + before_name, "awakens exactly once")
	check(Hunger.valid_progress(campaign_before, worn.to_dict()), "campaign reconcile accepts a legitimate awakening")

	# Rare -> Legendary without a power; everything that reads power copes.
	var rare := _hungry(ItemData.Rarity.RARE, "amulet", 20)
	check(rare.hunger_need == roundi(800 * 1.5), "rare need 800 x (1 + 20/40)")
	var inv2 := Inventory.new(PlayerStats.new())
	inv2.pickup(rare)
	var count := rare.affixes.size()
	Hunger.feed(inv2, rare.hunger_need)
	check(rare.rarity == ItemData.Rarity.LEGENDARY and rare.power == "" and rare.affixes.size() == count + 1, "rare becomes powerless legendary")
	check(rare.power_text() == "" and rare.score() > 0.0 and rare.subtitle().contains("Legendary") and rare.modifiers().size() >= count, "powerless legendary is safe to describe and score")
	check(not Item.from_dict(rare.to_dict()).hungering(), "sated item does not hunger on load")

	# Text helpers and feeding progress for the campaign reconcile.
	var t := _hungry(ItemData.Rarity.RARE, "ring", 1)
	t.hunger_need = 800
	t.hunger_fed = 312
	check(t.hunger_text() == "Hungering — 312/800 souls" and t.hunger_bar(10).length() == 10, "tooltip text and bar")
	var banked := t.to_dict().duplicate(true)
	t.hunger_fed = 500
	check(Hunger.valid_progress(banked, t.to_dict()), "campaign reconcile accepts more souls fed")
	var cheat := t.to_dict().duplicate(true)
	cheat["rarity"] = 3
	check(not Hunger.valid_progress(banked, cheat), "campaign reconcile rejects other changes")
	t.hunger_fed = 312

	# Serialization: item, inventory, run-save file, campaign validation and combat inventory.
	var copy := Item.from_dict(str_to_var(var_to_str(t.to_dict())))
	check(copy.hunger_need == 800 and copy.hunger_fed == 312, "item round trip")
	var plain := ItemGenerator.generate_with(5, ItemData.Rarity.NORMAL, "ring")
	check(not plain.to_dict().has("hunger_need"), "non-hungering items keep the legacy dict")
	var old := plain.to_dict()
	old.erase("campaign_id")
	check(not Item.from_dict(old).hungering(), "old dict without hunger fields loads")
	var inv3 := Inventory.new(PlayerStats.new())
	inv3.pickup(t)
	var inv4 := Inventory.new(PlayerStats.new())
	inv4.restore(str_to_var(var_to_str(inv3.to_dict())))
	check((inv4.equipped["ring"] as Item).hunger_fed == 312, "inventory dict round trip")
	RunSave.path = "user://test_hunger_run.save"
	RunSave.clear()
	RunSave.write({"elapsed": 12.0, "gear": {"ring": t.to_dict()}, "backpack": []})
	var disk := RunSave.read()
	if not disk.is_empty():
		check(Item.from_dict(disk["gear"]["ring"]).hunger_fed == 312, "run save round trip")
	RunSave.clear()
	check(CampaignState.validate_item(t.to_dict()) == "", "campaign accepts hungering item records")
	var record := t.to_dict().duplicate(true)
	record["campaign_id"] = "c:item:1"
	var state := {"inventory": {"equipped": {"ring": "c:item:1"}, "backpack": [], "items": {"c:item:1": {"data": record}}}}
	var combat := CampaignState.combat_inventory(state)
	var fresh := Inventory.new(PlayerStats.new())
	fresh.restore(combat)
	check((fresh.equipped["ring"] as Item).hunger_fed == 312, "campaign combat inventory keeps hunger")

	print("hunger_test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
