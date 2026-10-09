class_name CampaignStories
extends RefCounted
## Authored settlement encounter facts and safe, bounded saved outcomes.

const IDS := ["lantern_recovery", "whitepass_aid", "sledwright_repair", "redwake_trade"]
const KNOWN := ["lantern_recovery", "whitepass_aid", "sledwright_repair", "redwake_trade"]
const MODS := {
	"whitepass_draught": [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.08}],
	"whitepass_signal": [{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.08}],
	"sledwright_iron": [{"stat": "move_speed", "op": PlayerStats.Op.INCREASED, "value": 0.08}],
	"sledwright_canvas": [{"stat": "armor", "op": PlayerStats.Op.INCREASED, "value": 0.10}],
}

static func fresh() -> Dictionary:
	return {
		"lantern_recovery": {"status": "offered", "recovered": false, "reward_paid": false},
		"whitepass_aid": {"choice": "", "boon": ""},
		"sledwright_repair": {"choice": "", "boon": ""},
		"redwake_trade": {"status": "open", "stake": 0, "chance": 0, "won": false, "net": 0},
	}


static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "Invalid settlement story record."
	if value.size() != KNOWN.size(): return "Settlement story history is incomplete."
	for key in value:
		if not IDS.has(key) or not value[key] is Dictionary:
			return "Unknown settlement story."
	var lantern: Variant = value.get("lantern_recovery", {"status": "offered", "recovered": false, "reward_paid": false})
	if not lantern is Dictionary or not _has_fields(lantern, ["status", "recovered", "reward_paid"]) or not _only_fields(lantern, ["status", "recovered", "reward_paid"]) or not lantern["status"] in ["offered", "accepted", "declined", "missed", "complete"] \
			or not lantern["recovered"] is bool or not lantern["reward_paid"] is bool:
		return "Invalid lantern recovery state."
	if lantern["status"] == "complete" and (not lantern["recovered"] or not lantern["reward_paid"]) or lantern["reward_paid"] and (lantern["status"] != "complete" or not lantern["recovered"]):
		return "Completed lantern recovery has no recovered lantern."
	var whitepass: Variant = value.get("whitepass_aid", {"choice": "", "boon": ""})
	if not whitepass is Dictionary or not _has_fields(whitepass, ["choice", "boon"]) or not _only_fields(whitepass, ["choice", "boon"]) or not _valid_choice(whitepass, {"donate": "whitepass_draught", "signal": "whitepass_signal"}, true):
		return "Invalid Whitepass story choice."
	var sledwright: Variant = value.get("sledwright_repair", {"choice": "", "boon": ""})
	if not sledwright is Dictionary or not _has_fields(sledwright, ["choice", "boon"]) or not _only_fields(sledwright, ["choice", "boon"]) or not _valid_choice(sledwright, {"iron": "sledwright_iron", "canvas": "sledwright_canvas"}, true):
		return "Invalid sledwright story choice."
	var redwake: Variant = value.get("redwake_trade", {"status": "open", "stake": 0, "chance": 0, "won": false, "net": 0})
	if not redwake is Dictionary or not _has_fields(redwake, ["status", "stake", "chance", "won", "net"]) or not _only_fields(redwake, ["status", "stake", "chance", "won", "net"]) or not redwake["status"] in ["open", "declined", "played"] \
			or not redwake["stake"] is int or not redwake["chance"] is int \
			or not redwake["won"] is bool or not redwake["net"] is int:
		return "Invalid Redwake trade record."
	if redwake["status"] == "played":
		if redwake["stake"] != 15 or redwake["chance"] != 60 or redwake["net"] != (17 if redwake["won"] else -15):
			return "Invalid committed Redwake trade result."
	elif redwake["stake"] != 0 or redwake["chance"] != 0 or redwake["won"] or redwake["net"] != 0:
		return "Unplayed Redwake trade has a result."
	return ""


static func _valid_choice(record: Variant, choices: Dictionary, allow_decline := false) -> bool:
	if not record is Dictionary or not record.get("choice", "") is String or not record.get("boon", "") is String:
		return false
	var choice := str(record.get("choice", ""))
	var boon := str(record.get("boon", ""))
	if choice == "" or (choice == "declined" and allow_decline): return boon == ""
	return choices.has(choice) and boon == choices[choice]


static func _has_fields(record: Dictionary, fields: Array) -> bool:
	for field in fields:
		if not record.has(field): return false
	return true


static func _only_fields(record: Dictionary, fields: Array) -> bool:
	for key in record:
		if not fields.has(key): return false
	return true
