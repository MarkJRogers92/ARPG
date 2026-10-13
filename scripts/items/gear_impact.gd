class_name GearImpact
extends RefCounted
## Character-effective swap comparison. No RNG, live mutation, or DPS prediction.
const ABILITIES := {"aura":"Frost Aura", "lightning":"Chain Lightning", "orbit":"Spirit Blades",
	"nova":"Arcane Nova", "obol":"Obol", "scythe":"Returning Scythe", "spikes":"Grave Spikes",
	"wisp":"Wisp Lantern", "trail":"Cinder Trail", "bell":"Funeral Bell"}
const LOWER_BETTER := ["dash_cooldown","aura_interval","soul_cost","bell_cost"]
const LABELS := {"damage":"Global damage multiplier", "minion_damage":"Soul Link army damage/s",
	"crit_chance":"Crit chance", "crit_mult":"Crit multiplier", "armor_mitigation":"Armor reduction",
	"hp":"Current HP after cap", "regen":"HP regen", "reaction_damage":"Reaction multiplier"}

static func rows(before: PlayerStats, after: PlayerStats) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if before == null or after == null: return out
	for key: String in PlayerStats.BASE:
		var prefix := key.get_slice("_",0)
		var is_level := key.ends_with("_level") and ABILITIES.has(prefix)
		if prefix == "bolt" and before.powers.has("reaping") and after.powers.has("reaping"): continue
		if ABILITIES.has(prefix) and not is_level and after.get(prefix + "_level") <= 0: continue
		var field := key.trim_suffix("_rate") + "_cooldown" if key.ends_with("_rate") else key
		var a := _value(before,field)
		var b := _value(after,field)
		var newly_active: bool = ABILITIES.has(prefix) and not is_level and before.get(prefix + "_level") <= 0 and after.get(prefix + "_level") > 0
		if is_equal_approx(a,b) and not newly_active: continue
		if is_level:
			if (a > 0.0) == (b > 0.0): continue # rank count alone is not an effect
			out.append({"key":key,"label":ABILITIES[prefix],"before":a,"after":b,
				"before_text":"Available" if a > 0.0 else "Unavailable",
				"after_text":"Available" if b > 0.0 else "Unavailable", "gain":b > a})
			continue
		var label: String = LABELS.get(key, field.replace("_"," ").capitalize())
		var lower := key.ends_with("_rate") or key in LOWER_BETTER
		out.append({"key":key,"label":label,"before":a,"after":b,
			"before_text":"Inactive" if newly_active else format_value(key,a),"after_text":format_value(key,b),"gain":true if newly_active else (b < a if lower else b > a)})
		if key == "armor":
			out.append({"key":"armor_mitigation","label":LABELS.armor_mitigation,
				"before":1.0-before.damage_taken_factor(),"after":1.0-after.damage_taken_factor(),
				"before_text":format_value("armor_mitigation",1.0-before.damage_taken_factor()),
				"after_text":format_value("armor_mitigation",1.0-after.damage_taken_factor()),"gain":b > a})
	return out

static func _value(stats: PlayerStats, field: String) -> float:
	return float(stats.get(field)) if field in stats else float(stats.values.get(field,0.0))

static func format_value(key: String, value: float) -> String:
	if key.ends_with("_chance") or key in ["obol_luck","armor_mitigation","magic_find"]:
		return String.num(value * 100.0,2) + "%"
	if key.ends_with("_rate") or key.ends_with("_interval") or key in ["dash_cooldown","trail_life"]:
		return String.num(value,3) + " s"
	if key in ["damage","crit_mult","xp_gain","reaction_damage"]: return "×" + String.num(value,3)
	if key in ["regen","minion_damage","trail_dps","burn_dps"]: return String.num(value,2) + "/s"
	return String.num(value,2)

static func text(before: PlayerStats, after: PlayerStats) -> String:
	if before == null or after == null: return "No preview available."
	var lines: Array[String] = ["[color=#b8c6d0]YOUR BUILD · NOW → AFTER SWAP[/color]"]
	if after.hp < before.hp:
		lines.append("[color=#ffb46b]HP CAP: current health %s → %s[/color]" % [format_value("hp",before.hp),format_value("hp",after.hp)])
	for id: String in before.powers:
		if not after.powers.has(id):
			lines.append("[color=#ffb46b]LOSE POWER: %s[/color]" % _power_description(id))
	for id: String in after.powers:
		if not before.powers.has(id):
			lines.append("[color=#8bdba4]GAIN POWER: %s[/color]" % _power_description(id))
	for id: String in ["synergy_relay", "synergy_escort", "synergy_wake"]:
		var was_ready := BuildSynergies.live(id,before)
		var ready := BuildSynergies.live(id,after)
		if was_ready != ready:
			lines.append("[color=#%s]%s: %s[/color]" % ["8bdba4" if ready else "ffb46b", "LINK REQUIREMENTS MET" if ready else "LINK REQUIREMENTS LOST", Upgrades.DEFS[id]["name"]])
	var changes := rows(before,after)
	if changes.is_empty(): lines.append("No effective numeric changes.")
	for row: Dictionary in changes:
		var color := "8bdba4" if row["gain"] else "ffb46b"
		lines.append("%s: %s → [color=#%s]%s[/color]" % [row["label"],row["before_text"],color,row["after_text"]])
	lines.append("\n[color=#aab7c2]Includes your class, gear, upgrades and active buffs. Effective stats, not predicted DPS. Item rolls shows the original bonuses.[/color]")
	return "\n".join(lines)

static func _power_description(id: String) -> String:
	return str(ItemData.POWERS.get(id,{}).get("desc",id.replace("_"," ").capitalize()))
