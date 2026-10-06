class_name Inventory
extends RefCounted
## What the hero is wearing and carrying. Keeps PlayerStats in sync: every
## equipped item contributes its modifiers under the source "gear:<slot>".

signal changed

const BACKPACK_SIZE := 24

## slot -> Item for the slots that are filled.
var equipped := {}
var backpack: Array[Item] = []

var _stats: PlayerStats


func _init(stats: PlayerStats) -> void:
	_stats = stats


func is_full() -> bool:
	return backpack.size() >= BACKPACK_SIZE


## Picks an item up. It's worn straight away if its slot is empty, otherwise it
## goes into the backpack. Returns "equipped", "backpack", or "full" (nothing
## happened, so the caller should leave the item where it was).
func pickup(item: Item) -> String:
	if not equipped.has(item.slot):
		_wear(item)
		changed.emit()
		return "equipped"
	if is_full():
		return "full"
	backpack.append(item)
	changed.emit()
	return "backpack"


## Equips an item from the backpack. Whatever was in that slot takes its place.
func equip(item: Item) -> void:
	var index := backpack.find(item)
	if index < 0:
		return
	backpack.remove_at(index)
	var previous: Item = equipped.get(item.slot)
	if previous:
		backpack.insert(index, previous)
	_wear(item)
	changed.emit()


## Moves a worn item to the backpack. Returns false if there's no room.
func unequip(slot: String) -> bool:
	if not equipped.has(slot) or is_full():
		return false
	backpack.append(equipped[slot])
	equipped.erase(slot)
	_sync(slot)
	changed.emit()
	return true


func discard(item: Item) -> void:
	var index := backpack.find(item)
	if index >= 0:
		backpack.remove_at(index)
		changed.emit()


## Equips every backpack item that likely beats what's worn in its slot (or fills
## an empty slot). Returns how many were swapped in.
func equip_upgrades() -> int:
	var swapped := 0
	for item in backpack.duplicate():
		var current: Item = equipped.get(item.slot)
		if current == null or item.score() > current.score():
			equip(item)
			swapped += 1
	return swapped


## Whether `item` likely beats whatever is worn in its slot.
func is_upgrade(item: Item) -> bool:
	var current: Item = equipped.get(item.slot)
	return current == null or item.score() > current.score()


func _wear(item: Item) -> void:
	equipped[item.slot] = item
	_sync(item.slot)


func _sync(slot: String) -> void:
	var source := "gear:" + slot
	_stats.remove_source(source)
	if equipped.has(slot):
		_stats.add_mods(source, equipped[slot].modifiers())
	_stats.recalculate()
