extends SceneTree
## Existing legality, conditional themed membership and deterministic fallback.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _run() -> void:
	for theme: String in RewardPools.THEMES:
		check(not RewardPools.selection_text(theme).is_empty(), "selection policy visible")
		for slot: String in ItemData.SLOTS:
			for rarity in 4:
				var candidates := RewardPools.affix_candidates(slot, rarity, theme, true)
				for seed_value in 30:
					var rng := _rng(seed_value + 101)
					var item := ItemGenerator.generate_with(12, rarity, slot, rng, theme)
					var other := _rng(seed_value + 101)
					check(item.to_dict() == ItemGenerator.generate_with(12, rarity, slot, other, theme).to_dict() and rng.state == other.state, "same seed, theme, state")
					check(CampaignState.validate_item(item.to_dict()) == "" and item.name != "", "legal nonempty item")
					var used := {}
					var matching := false
					for mod: Dictionary in item.affixes:
						var affix := ItemData.affix(mod["id"])
						var key := "%s:%d" % [mod["stat"], mod["op"]]
						check(not used.has(key), "one stat/op per item")
						used[key] = true
						check(slot in affix["slots"] and rarity >= affix.get("min_rarity", ItemData.Rarity.MAGIC), "slot/rarity-compatible affix")
						check(not affix.has("theme") or affix["theme"] == theme, "no other source-only affix leaks")
						if mod["stat"] in RewardPools.THEMES[theme]["stats"]: matching = true
					if rarity != ItemData.Rarity.NORMAL and not candidates.is_empty(): check(matching, "eligible themed affix selected first")
					if rarity == ItemData.Rarity.LEGENDARY:
						check(item.power in RewardPools.power_candidates(slot, theme), "conditional themed power or legal fallback")
						check(item.power == "" or ItemData.POWERS[item.power]["slot"] == slot, "slot-compatible power")
					if rarity == ItemData.Rarity.NORMAL: check(item.affixes.is_empty(), "normal rarity unchanged")
	# Unknown themes have exactly the broad RNG path, including random names.
	for slot: String in ItemData.SLOTS:
		for rarity in 4:
			for seed_value in 20:
				var generic := _rng(seed_value + 71)
				var unknown := _rng(seed_value + 71)
				var a := ItemGenerator.generate_with(5, rarity, slot, generic)
				var b := ItemGenerator.generate_with(5, rarity, slot, unknown, "unknown")
				check(a.to_dict() == b.to_dict() and generic.state == unknown.state, "unknown theme is generic without extra RNG")
				for mod: Dictionary in a.affixes: check(not ItemData.affix(mod["id"]).has("theme"), "generic enemy drops unchanged membership")
	var spent := {}
	for affix: Dictionary in RewardPools.affix_candidates("boots", ItemData.Rarity.MAGIC, "mobility", true): spent["%s:%d" % [affix["stat"], affix["op"]]] = true
	check(RewardPools.affix_candidates("boots", ItemData.Rarity.MAGIC, "mobility", true, spent).is_empty(), "exhausted themed target empty")
	check(not RewardPools.affix_candidates("boots", ItemData.Rarity.MAGIC, "mobility", false, spent).is_empty(), "exhausted theme retains broad legal fallback")
	check(RewardPools.affix_candidates("weapon", ItemData.Rarity.MAGIC, "mobility", true).is_empty(), "incompatible slot exposes fallback")
	var before := RewardPools.affix_candidates("chest", ItemData.Rarity.MAGIC, "army", true).duplicate(true)
	for i in 30: ItemGenerator.generate_with(3, ItemData.Rarity.MAGIC, "chest", _rng(i), "army")
	check(before == RewardPools.affix_candidates("chest", ItemData.Rarity.MAGIC, "army", true), "no cross-copy depletion")
	print("REWARD POOLS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)
