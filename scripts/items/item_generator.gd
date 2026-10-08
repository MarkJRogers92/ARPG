class_name ItemGenerator
extends RefCounted
## Rolls random items. Uses the global random number generator, so call
## seed() first if you need reproducible results (the unit tests do).


## A random item. `quality` pushes the rarity roll toward better results; it
## combines the player's magic find with the enemy's own bonus (0 = none,
## 0.5 = +50% weight on magic, +100% on rare, +150% on legendary, ...).
static func generate(ilvl: int, quality := 0.0, rng: RandomNumberGenerator = null) -> Item:
	return generate_with(ilvl, roll_rarity(quality, rng), _pick(ItemData.SLOTS, rng), rng)


## An item with a fixed rarity and slot (tests, bots, and debug tools use this).
static func generate_with(ilvl: int, rarity: int, slot: String, rng: RandomNumberGenerator = null) -> Item:
	var item := Item.new()
	item.slot = slot
	item.ilvl = maxi(ilvl, 1)
	item.rarity = rarity

	var base: Dictionary = _pick(ItemData.BASES[slot], rng)
	item.base_name = base["name"]
	for mod: Dictionary in base["implicit"]:
		var scale := ItemData.ilvl_scale(item.ilvl, mod["stat"], mod["op"])
		item.implicit.append({
			"stat": mod["stat"], "op": mod["op"],
			"value": _round_like(mod["value"] * scale, mod["value"]),
		})

	var rules: Dictionary = ItemData.RARITIES[rarity]
	var count: int = _range(rules["affixes"][0], rules["affixes"][1], rng)
	item.affixes = _roll_affixes(item, count, rules["luck"], rng)
	if rarity == ItemData.Rarity.LEGENDARY:
		var powers := ItemData.powers_for(slot)
		if not powers.is_empty():
			item.power = _pick(powers, rng)
	item.name = _make_name(item, rng)
	return item


static func roll_rarity(quality := 0.0, rng: RandomNumberGenerator = null) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for r: Dictionary in ItemData.RARITIES:
		var w: float = r["weight"] * (1.0 + quality * r["mf_scale"])
		weights.append(w)
		total += w
	var pick := _float(rng) * total
	for i in weights.size():
		pick -= weights[i]
		if pick < 0.0:
			return i
	return ItemData.Rarity.NORMAL


static func _roll_affixes(item: Item, count: int, luck: float, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for a: Dictionary in ItemData.AFFIXES:
		if item.slot in a["slots"] and item.rarity >= a.get("min_rarity", ItemData.Rarity.MAGIC):
			pool.append(a)

	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		var a := _pick_weighted(pool, rng)
		pool.erase(a)
		# One affix per stat+op combination, so an item never stacks two
		# flavors of the same bonus.
		pool = pool.filter(func(o: Dictionary) -> bool: return o["stat"] != a["stat"] or o["op"] != a["op"])

		var t := lerpf(luck, 1.0, _float(rng))
		var value: float = lerpf(a["min"], a["max"], t)
		if a.get("scales", true):
			value *= ItemData.ilvl_scale(item.ilvl, a["stat"], a["op"])
		out.append({
			"id": a["id"], "stat": a["stat"], "op": a["op"],
			"value": snappedf(value, a["step"]),
		})
	return out


static func _pick_weighted(pool: Array[Dictionary], rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0.0
	for a in pool:
		total += a["weight"]
	var pick := _float(rng) * total
	for a in pool:
		pick -= a["weight"]
		if pick < 0.0:
			return a
	return pool[-1]


## Scaled implicits keep roughly the precision of their unscaled value.
static func _round_like(value: float, unscaled: float) -> float:
	var step := 0.01 if unscaled < 1.0 else 0.1
	return snappedf(value, step)


static func _make_name(item: Item, rng: RandomNumberGenerator = null) -> String:
	if item.power != "":
		var pattern: String = ItemData.POWERS[item.power]["name"]
		return pattern % item.base_name if pattern.contains("%s") else pattern
	match item.rarity:
		ItemData.Rarity.NORMAL:
			return item.base_name
		ItemData.Rarity.MAGIC:
			var first: Dictionary = ItemData.affix(item.affixes[0]["id"])
			if item.affixes.size() == 1:
				# One affix: randomly a prefix or a suffix.
				if _float(rng) < 0.5:
					return "%s %s" % [first["prefix"], item.base_name]
				return "%s %s" % [item.base_name, first["suffix"]]
			var second: Dictionary = ItemData.affix(item.affixes[1]["id"])
			return "%s %s %s" % [first["prefix"], item.base_name, second["suffix"]]
		_:
			var adjective: String = _pick(ItemData.RARE_ADJECTIVES, rng)
			var noun: String = _pick(ItemData.RARE_NOUNS[item.slot], rng)
			return "%s %s" % [adjective, noun]


static func _float(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()

static func _range(low: int, high: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(low, high) if rng else randi_range(low, high)

static func _pick(values: Array, rng: RandomNumberGenerator) -> Variant:
	return values[_range(0, values.size() - 1, rng)]
