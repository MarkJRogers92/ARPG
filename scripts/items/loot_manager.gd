class_name LootManager
extends Node3D
## Spawns loot when enemies die and hands it to the inventory when the hero
## walks over it. Items that can't be picked up (full backpack) stay on the
## ground until there's room.

## Emitted when an item is picked up. `result` is "equipped" or "backpack".
signal item_picked(item: Item, result: String)
## Emitted (rate-limited) when the hero walks over loot but the backpack is full.
signal backpack_full

## Drops are rationed so a huge late-game kill rate can't flood the ground. A
## drop needs a token; tokens refill at `drops_per_minute`, up to `token_cap`.
## Enemy types still decide *which* kills drop (their loot_chance), the budget
## only decides how many in total. Turn off to drop on every successful roll.
@export var budgeted := true
@export var drops_per_minute := 3.0
@export var token_cap := 2.0

## Ground items beyond this are cleaned up, lowest rarity (then oldest) first.
@export var max_drops := 40
## Items are collected within max(min_pickup_radius, pickup_radius * pickup_factor).
@export var min_pickup_radius := 1.8
@export var pickup_factor := 0.6

var drops: Array[LootDrop] = []

var _full_cooldown := 0.0
var _tokens := 1.0


## Maybe drop an item where an enemy died. `chance` and `quality` come from the
## enemy type; the hero's magic find adds to quality.
func roll_kill_drop(at: Vector2, chance: float, quality: float, ilvl: int, magic_find: float) -> void:
	if randf() >= chance:
		return
	if budgeted:
		if _tokens < 1.0:
			return
		_tokens -= 1.0
	drop(ItemGenerator.generate(ilvl, quality + magic_find), at)


func drop(item: Item, at: Vector2) -> LootDrop:
	var scatter := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.8)
	var node := LootDrop.new()
	node.setup(item, at + scatter)
	if item.rarity == ItemData.Rarity.LEGENDARY:
		Sound.play("legendary")
	elif item.rarity == ItemData.Rarity.RARE:
		Sound.play("loot")
	add_child(node)
	drops.append(node)
	_trim()
	return node


## Picks up whatever the hero is standing near.
func step(delta: float, hero: Vector2, pickup_radius: float, inventory: Inventory) -> void:
	_full_cooldown -= delta
	_tokens = minf(_tokens + drops_per_minute / 60.0 * delta, token_cap)
	var reach := maxf(min_pickup_radius, pickup_radius * pickup_factor)
	var reach_sq := reach * reach
	var i := drops.size() - 1
	while i >= 0:
		var node := drops[i]
		if hero.distance_squared_to(node.pos2) <= reach_sq:
			var result := inventory.pickup(node.item)
			if result == "full":
				if _full_cooldown <= 0.0:
					_full_cooldown = 4.0
					backpack_full.emit()
			else:
				item_picked.emit(node.item, result)
				drops.remove_at(i)
				node.queue_free()
		i -= 1


func _trim() -> void:
	while drops.size() > max_drops:
		var victim := 0
		for i in drops.size():
			if drops[i].item.rarity < drops[victim].item.rarity:
				victim = i
		drops[victim].queue_free()
		drops.remove_at(victim)
