class_name CampaignLoadout
extends RefCounted
## The single source for building a campaign hero before combat starts.


static func apply(player: Player, hero_class: String, loadout: Dictionary, effects: Array) -> void:
	var profile_snapshot: Dictionary = loadout.get("profile_snapshot", {})
	player.stats.add_mods("meta", profile_snapshot.get("mods", []))
	HeroClass.apply(player, hero_class)
	Relics.apply(player, String(profile_snapshot.get("relic", "")), String(profile_snapshot.get("start_weapon", "")))
	player.skill_point_every_levels = 0
	player.stats.level = 1
	player.stats.xp = 0
	player.pending_levels = 0
	var inventory_data: Dictionary = loadout.get("inventory", {})
	if not inventory_data.is_empty():
		player.inventory.restore(inventory_data)
	var talent_data: Dictionary = loadout.get("talents", {"points": 0, "allocated": []})
	player.skills.restore(talent_data)
	var specialization := String(loadout.get("specialization", ""))
	if specialization != "":
		Specializations.apply(player.stats, hero_class, specialization)
	for effect in effects:
		if effect is Dictionary and effect.get("mods", []) is Array:
			player.stats.add_mods("campaign_effects", effect.get("mods", []))
	player.stats.recalculate()
	player.stats.hp = player.stats.max_hp
	player.dead = false


## Builds an isolated starting-build snapshot for the town route preview.
## Item.from_dict assigns runtime-only item uids; this never touches saved state.
static func preview(state: Dictionary) -> Dictionary:
	if not state.get("hero_class", "") is String or not HeroClass.CLASSES.has(state.get("hero_class", "")):
		return {}
	var hero_class: String = state["hero_class"]
	var selected_node := String(state.get("selected_node", ""))
	var graph: Dictionary = state.get("graph", {})
	var nodes: Dictionary = graph.get("nodes", {})
	if selected_node == "" or not nodes.has(selected_node):
		selected_node = ""
	var selected_effects: Array = []
	for effect in state.get("effects", []):
		if effect is Dictionary and effect.get("node_id", "") == selected_node and selected_node != "":
			selected_effects.append(effect.duplicate(true))
	var inventory: Dictionary = CampaignState.combat_inventory(state)
	var loadout := {
		"hero_class": hero_class,
		"profile_snapshot": state["profile_snapshot"].duplicate(true),
		"inventory": inventory,
		"talents": state["talents"].duplicate(true),
		"specialization": String(state.get("specialization", "")),
	}
	var player := Player.new()
	apply(player, hero_class, loadout, selected_effects)
	var stats: PlayerStats = player.stats
	var result := {
		"max_hp": stats.max_hp,
		"armor": stats.armor,
		"move_speed": stats.move_speed,
		"crit_chance": stats.crit_chance,
		"minion_max": stats.minion_max,
		"effect_count": selected_effects.size(),
		"selected_node_id": selected_node,
	}
	if not selected_effects.is_empty():
		result["selected_effect_name"] = _effect_name(selected_effects[0])
	var stat_effect_names: Array[String] = []
	for effect: Dictionary in selected_effects:
		var mods: Variant = effect.get("mods", [])
		if mods is Array and not mods.is_empty():
			stat_effect_names.append(_effect_name(effect))
	result["stat_effect_count"] = stat_effect_names.size()
	result["stat_effect_names"] = stat_effect_names
	if hero_class == "reaper" and stats.powers.has("reaping") and stats.scythe_level > 0:
		result["primary_attack_label"] = "Reaping Scythe"
		result["primary_damage"] = stats.scythe_damage
		result["primary_cooldown"] = stats.scythe_cooldown
	else:
		result["primary_attack_label"] = "Bolts"
		result["primary_damage"] = stats.bolt_damage
		result["primary_cooldown"] = stats.bolt_cooldown
	player.free()
	return result


static func _effect_name(effect: Dictionary) -> String:
	match String(effect.get("id", "")):
		"quiet_bell": return "The Quiet Bell"
		"unfinished": return "Unfinished Business"
		"borrowed_battalion": return "Borrowed Battalion"
		_: return String(effect.get("name", "Campaign contract"))
