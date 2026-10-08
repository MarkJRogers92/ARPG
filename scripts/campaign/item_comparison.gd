class_name ItemComparison
extends RefCounted
## Read-only, item-local modifier comparison. This deliberately does not score
## an item or predict the character's complete derived stats.


static func modifiers(data: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var all_modifiers: Array = []
	all_modifiers.append_array(data.get("implicit", []))
	all_modifiers.append_array(data.get("affixes", []))
	var power_id := str(data.get("power", ""))
	if not power_id.is_empty() and ItemData.POWERS.has(power_id):
		all_modifiers.append_array(ItemData.POWERS[power_id].get("mods", []))
	for value: Variant in all_modifiers:
		if not value is Dictionary:
			continue
		var modifier: Dictionary = value
		var stat := str(modifier.get("stat", ""))
		var op_value: Variant = modifier.get("op", -1)
		if stat.is_empty() or not (op_value is int or op_value is float):
			continue
		var op := int(op_value)
		var key := "%s:%d" % [stat, op]
		var amount := float(modifier.get("value", 0.0))
		if op == PlayerStats.Op.MORE:
			# MORE modifiers multiply with one another, so store their combined
			# item-local factor as an equivalent single percentage.
			var factor := 1.0 + float(totals.get(key, 0.0))
			totals[key] = factor * (1.0 + amount) - 1.0
		else:
			totals[key] = float(totals.get(key, 0.0)) + amount
	return totals


static func rows(current_data: Dictionary, offered_data: Dictionary) -> Array[Dictionary]:
	var current := modifiers(current_data)
	var offered := modifiers(offered_data)
	var keys: Array = current.keys()
	for key: Variant in offered.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var out: Array[Dictionary] = []
	for key_value: Variant in keys:
		var parts := str(key_value).split(":", false, 2)
		if parts.size() != 2:
			continue
		var stat := str(parts[0])
		var op := int(parts[1])
		var now := float(current.get(key_value, 0.0))
		var next := float(offered.get(key_value, 0.0))
		out.append({"stat": stat, "op": op, "current": now, "offered": next})
	return out


static func format_value(stat: String, op: int, value: float) -> String:
	var label := "Added" if op == PlayerStats.Op.ADD else ("Increased" if op == PlayerStats.Op.INCREASED else "More")
	return "%s · %s" % [label, ItemData.mod_text({"stat": stat, "op": op, "value": value})]
