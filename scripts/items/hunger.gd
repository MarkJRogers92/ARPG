class_name Hunger
extends RefCounted
## Hungering gear: some Magic and Rare drops feed on the dead while worn and
## awaken once they have eaten enough. Data and rules only; Item stores the
## counters and main.gd calls feed() from the central kill path.

## Chance a freshly generated Magic or Rare item hungers (Legendary and Normal never do).
const CHANCE := 0.12
## Souls needed at item level 0, by rarity. Scaled by 1 + ilvl / ILVL_DIVISOR.
const NEED := {ItemData.Rarity.MAGIC: 400, ItemData.Rarity.RARE: 800}
const ILVL_DIVISOR := 40.0
## What one kill is worth (the elite and boss weights are the total per kill).
const KILL_WEIGHT := 1
const ELITE_WEIGHT := 10
const BOSS_WEIGHT := 50
const PREFIX := "Sated "

static var _none: Array[Item] = []


## Maybe makes `item` hunger. Draws from the generator's RNG so seeded runs stay deterministic.
static func roll(item: Item, rng: RandomNumberGenerator = null) -> void:
	if not NEED.has(item.rarity):
		return
	var draw := rng.randf() if rng else randf()
	if draw >= CHANCE:
		return
	item.hunger_need = roundi(NEED[item.rarity] * (1.0 + item.ilvl / ILVL_DIVISOR))
	item.hunger_fed = 0


## Feeds every worn hungering item. Returns the items that awakened (a shared
## empty array when none did, so a normal kill allocates nothing).
static func feed(inventory: Inventory, amount: int, rng: RandomNumberGenerator = null) -> Array[Item]:
	var awakened := _none
	for slot: String in ItemData.SLOTS:
		var item: Item = inventory.equipped.get(slot)
		if item == null or item.hunger_need <= 0:
			continue
		item.hunger_fed += amount
		if item.hunger_fed >= item.hunger_need:
			if awakened.is_empty():
				awakened = []
			awaken(item, rng)
			awakened.append(item)
	# Stats change after the loop so each awakening resyncs once.
	for item in awakened:
		inventory.replace_worn(item)
	return awakened


## One extra affix, one rarity step up (Rare becomes Legendary without a power;
## every power check already treats "" as none), and the "Sated " prefix.
## Only fires once: the counters clear. Caller re-syncs stats if the item is worn.
static func awaken(item: Item, rng: RandomNumberGenerator = null) -> void:
	if item.hunger_need <= 0:
		return
	item.hunger_need = 0
	item.hunger_fed = 0
	var next := mini(item.rarity + 1, ItemData.Rarity.LEGENDARY)
	ItemGenerator.add_affix(item, next, rng)
	item.rarity = next
	item.name = PREFIX + item.name


## Campaign reconciliation: is `after` the banked `before` record plus only
## legitimate hunger progress (more souls fed, or exactly one awakening)?
static func valid_progress(before: Dictionary, after: Dictionary) -> bool:
	for key in ["slot", "base_name", "ilvl", "implicit", "power", "campaign_id"]:
		if before.get(key, "") != after.get(key, ""):
			return false
	var need := int(before.get("hunger_need", 0))
	if need <= 0:
		return false
	var fed := int(before.get("hunger_fed", 0))
	if int(after.get("hunger_need", 0)) == need:
		var now := int(after.get("hunger_fed", 0))
		return now >= fed and now <= need and before["name"] == after["name"] and before["rarity"] == after["rarity"] and before["affixes"] == after["affixes"]
	# Awakened: counters gone, one rarity step up, old affixes kept plus at most one new one.
	var grown: Array = after["affixes"]
	var old_affixes: Array = before["affixes"]
	return not after.has("hunger_need") and int(after["rarity"]) == mini(int(before["rarity"]) + 1, ItemData.Rarity.LEGENDARY) \
			and str(after["name"]) == PREFIX + str(before["name"]) \
			and (grown.size() == old_affixes.size() + 1 or grown.size() == old_affixes.size()) and grown.slice(0, old_affixes.size()) == old_affixes
