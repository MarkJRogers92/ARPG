class_name BuildGuide
extends RefCounted
## Read-only evolution checklist and affected-upgrade preview.
##
## Uses Evolutions.DEFS and Upgrades.DEFS to show which Soulbound recipes are
## compatible with the current hero, how close each is, and what taking it
## would change.  Never mutates the passed PlayerStats.

const PREFIX := Evolutions.PREFIX


## One row per compatible evolution recipe.  Each dictionary contains:
##   id, name, color, icon,
##   weapon {id, name, rank, max},
##   catalyst {id, name, rank, max},
##   owned (weapon rank > 0), taken, ready, compatible.
static func rows(stats: PlayerStats, unlocked_snapshot: Variant = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stats == null: return out
	var ready_ids := Evolutions.ready(stats)
	for id: String in Evolutions.DEFS:
		var d: Dictionary = Evolutions.DEFS[id]
		var weapon_id: String = d["weapon"]
		var catalyst_id: String = d["catalyst"]
		var weapon_compatible := Upgrades.offered(weapon_id, stats, unlocked_snapshot)
		var catalyst_compatible := Upgrades.offered(catalyst_id, stats, unlocked_snapshot)
		if not weapon_compatible or not catalyst_compatible:
			continue
		var weapon_def: Dictionary = Upgrades.DEFS[weapon_id]
		var catalyst_def: Dictionary = Upgrades.DEFS[catalyst_id]
		var weapon_rank := Upgrades.level_of(weapon_id, stats)
		var catalyst_rank := Upgrades.level_of(catalyst_id, stats)
		var taken := Evolutions.taken(id, stats)
		var ready := id in ready_ids
		out.append({
			"id": id,
			"name": d["name"],
			"color": d.get("color", Color.WHITE),
			"icon": d.get("icon", weapon_id),
			"weapon": {
				"id": weapon_id,
				"name": weapon_def["name"],
				"rank": weapon_rank,
				"max": weapon_def["max"],
			},
			"catalyst": {
				"id": catalyst_id,
				"name": catalyst_def["name"],
				"rank": catalyst_rank,
				"max": catalyst_def["max"],
			},
			"owned": weapon_rank > 0,
			"active_from_class_or_gear": Upgrades.already_active(weapon_id, stats),
			"taken": taken,
			"ready": ready,
			"compatible": true,
		})
	return out


## Human-readable preview of what taking `id` would change.  `id` may be an
## evolution recipe or a regular upgrade card; unknown ids return an empty
## explanation.  Uses the effective values in `stats` and respects
## first_mods / already_active for upgrade cards.
static func affected_text(id: String, stats: PlayerStats) -> String:
	if stats == null: return ""
	if id.begins_with(PREFIX): id = id.trim_prefix(PREFIX)
	if id.begins_with("synergy_"):
		return _synergy_text(id, stats)
	if Evolutions.DEFS.has(id):
		return _evo_text(id, stats)
	if Upgrades.DEFS.has(id):
		return _upgrade_text(id, stats)
	return ""


## Short sentence describing what is still needed for a recipe.
static func goal_summary(recipe_id: String, stats: PlayerStats) -> String:
	if recipe_id.is_empty() or stats == null: return ""
	if not Evolutions.DEFS.has(recipe_id):
		return "Unknown recipe."
	var d: Dictionary = Evolutions.DEFS[recipe_id]
	var weapon_id: String = d["weapon"]
	var catalyst_id: String = d["catalyst"]
	var weapon_rank := Upgrades.level_of(weapon_id, stats)
	var catalyst_rank := Upgrades.level_of(catalyst_id, stats)
	var weapon_max: int = Upgrades.DEFS[weapon_id]["max"]
	var catalyst_name: String = Upgrades.DEFS[catalyst_id]["name"]
	if Evolutions.taken(recipe_id, stats):
		return "%s · Already evolved." % d["name"]
	if weapon_rank >= weapon_max and catalyst_rank >= 1:
		var count := Evolutions.ready(stats).size()
		return "Ready: %s · next level-up." % d["name"] if count == 1 else "Ready: %s · one of %d ready evolutions is randomly offered each level-up." % [d["name"], count]
	var parts: Array[String] = []
	if weapon_rank < weapon_max:
		parts.append("max %s (%d/%d)" % [Upgrades.DEFS[weapon_id]["name"], weapon_rank, weapon_max])
	if catalyst_rank < 1:
		parts.append("take %s once" % catalyst_name)
	return "%s · Need: %s." % [d["name"], " and ".join(parts)]


static func _evo_text(id: String, stats: PlayerStats) -> String:
	var d: Dictionary = Evolutions.DEFS[id]
	if Evolutions.taken(id, stats): return str(d["name"]) + " · Already evolved."
	return _preview(id, stats, d["mods"], PREFIX + id) + "\nRequired catalyst: " + str(Upgrades.DEFS[d["catalyst"]]["name"])


static func _synergy_text(id: String, stats: PlayerStats) -> String:
	if not Upgrades.DEFS.has(id):
		return ""
	var def: Dictionary = Upgrades.DEFS[id]
	var owned := Upgrades.level_of(id, stats) > 0
	var lines: Array[String] = [def["name"]]
	match id:
		"synergy_relay":
			var has_lightning := stats.lightning_level > 0
			var has_chill := stats.aura_level > 0 or stats.wisp_level > 0 or stats.chill_chance > 0.0
			lines.append("Affects: Chain Lightning + a chill source (Frost Aura, Wisp Lantern or Frostbite).")
			lines.append("Trigger: Chain Lightning hits a chilled enemy.")
			lines.append("Effect: frost pulse 1.6 m radius, 2 m past the target, for 50% of the triggering hit's damage.")
			lines.append("Cap: at most one pulse per 0.75 s.")
			if owned and has_lightning and has_chill:
				lines.append("State: live.")
			else:
				lines.append("State: dormant.")
				if not owned:
					lines.append("Not yet taken.")
				if not has_lightning:
					lines.append("Missing: Chain Lightning.")
				if not has_chill:
					lines.append("Missing: a chill source.")
		"synergy_escort":
			var has_burn := stats.ignite_chance > 0.0 or stats.trail_level > 0 or stats.powers.has("pyre")
			lines.append("Affects: Soul Army + a burn source (Kindling or Brimstone Trail).")
			lines.append("Trigger: Soul Army hits a burning enemy.")
			lines.append("Effect: fire pulse 1.6 m radius on the target for 35% of hero minion damage.")
			lines.append("Cap: at most one pulse per 1 s.")
			if BuildSynergies.live(id, stats):
				lines.append("State: live.")
			else:
				lines.append("State: dormant.")
				if not owned:
					lines.append("Not yet taken.")
				if not has_burn:
					lines.append("Missing: a burn source.")
				if stats.minion_max <= 0: lines.append("Missing: Soul Army capacity.")
		"synergy_wake":
			var has_blades := stats.orbit_level > 0
			lines.append("Affects: Dash + Spirit Blades.")
			lines.append("Trigger: successful dash while Spirit Blades are active.")
			lines.append("Effect: 3 none-element pulses 0.7 m radius along the dash path at 1/2/3 m for 40% of orbit damage each.")
			lines.append("Cap: one volley per dash (dash cooldown handles the rate).")
			if owned and has_blades:
				lines.append("State: live.")
			else:
				lines.append("State: dormant.")
				if not owned:
					lines.append("Not yet taken.")
				if not has_blades:
					lines.append("Missing: Spirit Blades.")
	lines.append("Rank one; no stacking. Combat cooldown only; Classic suspend keeps the card, not queued pulses. Campaign kits restart per attempt.")
	return "\n".join(lines)


static func _upgrade_text(id: String, stats: PlayerStats) -> String:
	var def: Dictionary = Upgrades.DEFS[id]
	var lvl := Upgrades.level_of(id, stats)
	if lvl >= def["max"]:
		return def["name"] + " is at max rank."
	var active := Upgrades.already_active(id, stats)
	var use_first := lvl == 0 and def.has("first_mods")
	var mods: Array = def["first_mods"] if use_first else def["mods"]
	if active and def.has("mods"):
		var first_stat: String = def["first_mods"][0]["stat"]
		mods = mods + def["mods"].filter(func(m: Dictionary) -> bool: return m["stat"] != first_stat)
	var text := _preview(id, stats, mods, id)
	if active: text += "\nAbility already active; first card preserves access."
	if def.has("heal"): text += "\nAlso restores %s HP (up to max)." % _fmt(def["heal"])
	return text


## Recalculate a disposable stats copy via the actual upgrade/evolution path.
## This captures integer rounding, caps, class/gear access and Soul Link without
## estimating DPS or changing any live modifiers, HP, powers or rank facts.
static func preview_changes(id: String, stats: PlayerStats) -> Array[Dictionary]:
	if stats == null: return []
	var recipe := id.trim_prefix(PREFIX)
	var actual := PREFIX + recipe if Evolutions.DEFS.has(recipe) else id
	if not Evolutions.DEFS.has(recipe) and not Upgrades.DEFS.has(id): return []
	var after := PlayerStats.new()
	after._mods = stats._mods.duplicate(true)
	after.powers = stats.powers.duplicate(true)
	after.innate_powers = stats.innate_powers.duplicate(true)
	after.upgrade_levels = stats.upgrade_levels.duplicate(true)
	after.hp = stats.hp
	after.recalculate()
	Upgrades.apply(actual, after)
	var out: Array[Dictionary] = []
	for key: String in PlayerStats.BASE:
		var field := _effective_field(key)
		var before_value := _stat_value(field, stats)
		var after_value := _stat_value(field, after)
		if not is_equal_approx(before_value, after_value):
			out.append({"stat": key, "field": field, "before": before_value, "after": after_value})
	return out


static func _preview(id: String, stats: PlayerStats, mods: Array, actual_id: String) -> String:
	var changes := preview_changes(actual_id, stats)
	var lines: Array[String] = [_scope(mods, stats)]
	for mod: Dictionary in mods:
		var key: String = mod["stat"]
		for change: Dictionary in changes:
			if change["stat"] == key:
				lines.append("%s: %s → %s" % [_pretty_stat(change["field"]), _metric_format(key, change["before"]), _metric_format(key, change["after"])])
	if not mods.any(func(mod: Dictionary) -> bool: return mod["stat"] == "minion_damage"):
		for change: Dictionary in changes:
			if change["stat"] == "minion_damage":
				lines.append("Soul Link army damage: %s → %s" % [_fmt(change["before"]), _fmt(change["after"])])
	if Evolutions.DEFS.has(id) and Upgrades.already_active(Evolutions.DEFS[id]["weapon"], stats):
		lines.append("Ability already active from class or gear.")
	return "\n".join(lines)


static func _scope(mods: Array, stats: PlayerStats) -> String:
	var names: Array[String] = []
	var weapons := {"bolt": "Magic Bolt", "aura": "Frost Aura", "lightning": "Chain Lightning", "orbit": "Spirit Blades", "nova": "Arcane Nova", "obol": "Obol", "scythe": "Returning Scythe", "spikes": "Grave Spikes", "wisp": "Wisp Lantern", "trail": "Cinder Trail", "bell": "Funeral Bell"}
	for mod: Dictionary in mods:
		var stat: String = mod["stat"]
		var prefix := stat.get_slice("_", 0)
		var name: String = weapons.get(prefix, "")
		if stat == "damage": name = "All weapons + army + burn/reactions"
		elif prefix == "crit": name = "Hero critical hits / army spell crits"
		elif stat == "reaction_damage": name = "Shatter / Melt / Overload reactions"
		elif stat in ["chill_chance", "ignite_chance"]: name = "Reaper scythes" if stats.powers.has("reaping") else "Magic Bolt"
		elif stat == "burn_dps": name = "Burning enemies"
		elif prefix in ["minion", "soul"]: name = "Soul Army"
		elif name.is_empty(): name = "Hero / pickups"
		if not name in names: names.append(name)
	return "Affects: " + " · ".join(names)


static func _effective_field(stat: String) -> String:
	if stat.ends_with("_rate"): return stat.trim_suffix("_rate") + "_cooldown"
	return stat


static func _metric_format(stat: String, value: float) -> String:
	if stat.ends_with("_chance") or stat == "obol_luck": return String.num(value * 100, 1) + "%"
	if stat.ends_with("_rate") or stat.ends_with("_interval") or stat == "dash_cooldown": return _fmt(value) + " s"
	return _fmt(value)


static func _stat_value(stat: String, stats: PlayerStats) -> float:
	if stat in stats:
		return float(stats.get(stat))
	return float(stats.values.get(stat, 0.0))


static func _pretty_stat(stat: String) -> String:
	var names := {"damage": "Global damage multiplier", "crit_chance": "Crit chance", "reaction_damage": "Reaction multiplier", "chill_chance": "Chill chance", "ignite_chance": "Ignite chance"}
	return names.get(stat, stat.replace("_", " ").capitalize())


static func _fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 2)
