class_name Item
extends RefCounted
## One piece of gear. Plain data: it knows its modifiers and how to describe
## and serialize itself, and nothing about where it is (see Inventory).

static var _next_uid := 1

var uid := 0
var slot := "weapon"
var base_name := ""
## Display name. Normal items use the base name; Magic and above get a
## generated one.
var name := ""
var rarity := ItemData.Rarity.NORMAL
var ilvl := 1
## Always-present modifier(s) from the base type, as [{stat, op, value}].
var implicit: Array[Dictionary] = []
## Random modifiers, as [{id, stat, op, value}].
var affixes: Array[Dictionary] = []
## A legendary power id (see ItemData.POWERS), or "" for none.
var power := ""


func _init() -> void:
	uid = _next_uid
	_next_uid += 1


func color() -> Color:
	return ItemData.rarity_color(rarity)


## Every modifier this item grants, ready for PlayerStats.add_mods().
func modifiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(implicit)
	out.append_array(affixes)
	if power != "":
		for mod: Dictionary in ItemData.POWERS[power].get("mods", []):
			out.append(mod)
	return out


func power_text() -> String:
	return ItemData.POWERS[power]["desc"] if power != "" else ""


## Rough total power, used for "likely upgrade" hints and bot decisions.
func score() -> float:
	var total := 0.0
	for mod in implicit + affixes:
		total += ItemData.mod_score(mod)
	# A power is worth a lot more than its numbers say.
	if power != "":
		total += 2.0
	return total


## "Rare Staff, item level 12"
func subtitle() -> String:
	return "%s %s  ·  item level %d" % [ItemData.rarity_name(rarity), base_name, ilvl]


## One line per modifier. Implicit first.
func description_lines() -> Array[String]:
	var lines: Array[String] = []
	for mod in implicit:
		lines.append(ItemData.mod_text(mod))
	for mod in affixes:
		lines.append(ItemData.mod_text(mod))
	return lines


func to_dict() -> Dictionary:
	return {
		"slot": slot, "base_name": base_name, "name": name, "rarity": rarity,
		"ilvl": ilvl, "implicit": implicit, "affixes": affixes, "power": power,
	}


static func from_dict(d: Dictionary) -> Item:
	var item := Item.new()
	item.slot = d["slot"]
	item.base_name = d["base_name"]
	item.name = d["name"]
	item.rarity = d["rarity"]
	item.ilvl = d["ilvl"]
	item.implicit.assign(d["implicit"])
	item.affixes.assign(d["affixes"])
	item.power = d.get("power", "")
	return item
