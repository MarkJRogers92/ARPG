class_name SkillTree
extends RefCounted
## What the hero has unlocked, and the unspent points. Allocated nodes add their
## modifiers to PlayerStats under the source "skill:<id>", so refunding is exact.
##
## Rules: a node can be allocated when you can pay for it and it's linked to a
## node you already own (the central "origin" is always owned). A node can be
## refunded unless taking it away would cut other owned nodes off from the
## origin: you can always peel the tree back from its tips.

signal changed

var points := 0
## id -> true for every owned node, including the origin.
var allocated := {SkillData.ROOT: true}

var _stats: PlayerStats


func _init(stats: PlayerStats) -> void:
	_stats = stats


func add_points(amount: int) -> void:
	points += amount
	changed.emit()


func is_allocated(id: String) -> bool:
	return allocated.has(id)


## Points spent on nodes (not counting the free origin).
func spent() -> int:
	var total := 0
	for id: String in allocated:
		if id != SkillData.ROOT:
			total += SkillData.cost(id)
	return total


## Whether the node is next to one you own, whatever it costs.
func is_reachable(id: String) -> bool:
	if allocated.has(id):
		return false
	for n: String in SkillData.neighbors(id):
		if allocated.has(n):
			return true
	return false


func can_allocate(id: String) -> bool:
	return is_reachable(id) and points >= SkillData.cost(id)


func allocate(id: String) -> bool:
	if not can_allocate(id):
		return false
	points -= SkillData.cost(id)
	_own(id)
	_stats.recalculate()
	changed.emit()
	return true


func can_refund(id: String) -> bool:
	if id == SkillData.ROOT or not allocated.has(id):
		return false
	# Everything else we own must still be reachable from the origin without it.
	var reached := {SkillData.ROOT: true}
	var frontier: Array[String] = [SkillData.ROOT]
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		for n: String in SkillData.neighbors(current):
			if n != id and allocated.has(n) and not reached.has(n):
				reached[n] = true
				frontier.append(n)
	return reached.size() == allocated.size() - 1


func refund(id: String) -> bool:
	if not can_refund(id):
		return false
	points += SkillData.cost(id)
	allocated.erase(id)
	_stats.remove_source(_source(id))
	_stats.recalculate()
	changed.emit()
	return true


## Refunds everything. Returns the points given back.
func reset() -> int:
	var refunded := spent()
	for id: String in allocated.keys():
		if id != SkillData.ROOT:
			allocated.erase(id)
			_stats.remove_source(_source(id))
	points += refunded
	_stats.recalculate()
	changed.emit()
	return refunded


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for id: String in allocated:
		if id != SkillData.ROOT:
			ids.append(id)
	return {"points": points, "allocated": ids}


## Restores a saved tree (replacing the current one).
func restore(data: Dictionary) -> void:
	for id: String in allocated.keys():
		if id != SkillData.ROOT:
			allocated.erase(id)
			_stats.remove_source(_source(id))
	for id: String in data["allocated"]:
		if SkillData.NODES.has(id):
			_own(id)
	points = data["points"]
	_stats.recalculate()
	changed.emit()


func _own(id: String) -> void:
	allocated[id] = true
	_stats.add_mods(_source(id), SkillData.NODES[id]["mods"])


func _source(id: String) -> String:
	return "skill:" + id
