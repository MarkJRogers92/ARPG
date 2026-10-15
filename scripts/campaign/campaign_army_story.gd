extends RefCounted
## Camp-return recognition. Turns Army's optional mission report (army.gd
## story_report()) into a short, honest account for the pending-result screen.
## Pure formatting: no rewards, no save writes, no settlement authority.
## A missing, empty, legacy or malformed payload returns "" so the town simply
## renders nothing rather than guessing at deeds.

## Optional payloads are not trusted: bound the copy so a saved file cannot
## stretch the result screen without limit.
const MAX_NAME := 32
const MAX_FALLEN := 4
## No real mission count reaches this; a larger saved float is corrupt, and the
## bound keeps int() off an out-of-range cast.
const MAX_COUNT := 9999


## `value` is result.report.army_story as saved (any Variant), `outcome` is the
## result's outcome ("success", "failure", "retreat").
static func summary(value: Variant, outcome: String) -> String:
	var story: Dictionary = value if value is Dictionary else {}
	var lines: Array[String] = []
	var counts := _counts_line(story)
	if not counts.is_empty():
		lines.append(counts)
	var standout := _standout_line(story.get("standout"))
	if not standout.is_empty():
		lines.append(standout)
	var fallen := _fallen_line(story.get("fallen_veterans"), outcome)
	if not fallen.is_empty():
		lines.append(fallen)
	# Nothing earned this mission: say nothing at all.
	return "\n".join(lines)


static func _counts_line(story: Dictionary) -> String:
	var parts: Array[String] = []
	var raised := _count(story.get("raised"))
	if raised > 0:
		parts.append("%d %s rallied" % [raised, "ally" if raised == 1 else "allies"])
	var kills := _count(story.get("kills"))
	if kills > 0:
		parts.append("%d %s" % [kills, "kill" if kills == 1 else "kills"])
	var promotions := _count(story.get("promotions"))
	if promotions > 0:
		parts.append("%d %s" % [promotions, "promotion" if promotions == 1 else "promotions"])
	return "THE ARMY'S ACCOUNT · " + " · ".join(parts) if not parts.is_empty() else ""


## One named ally with one real deed, in a sentence rather than a stat chain.
## A name alone is not a standout, and every optional field is only read when
## it has the expected type: a malformed flag is omitted, never invented.
static func _standout_line(value: Variant) -> String:
	if not value is Dictionary:
		return ""
	var standout: Dictionary = value
	var name := _name(standout.get("name"))
	if name.is_empty():
		return ""
	var kills := _count(standout.get("kills"))
	var survived: Variant = standout.get("survived")
	var survived_known: bool = survived is bool
	var close_call: bool = survived_known and bool(survived) and _flag(standout, "close_call")
	# Recognition only for an earned deed: kills, or a real survived close call.
	if kills <= 0 and not close_call:
		return ""
	var clauses: Array[String] = []
	if kills > 0:
		clauses.append("cut down %d %s this mission" % [kills, "enemy" if kills == 1 else "enemies"])
	if close_call:
		clauses.append("survived a close call")
	elif survived_known and not bool(survived):
		clauses.append("fell on the road")
	elif survived_known:
		clauses.append("is still standing")
	var origin := ""
	if standout.get("returning") is bool:
		origin = "a returning veteran" if bool(standout["returning"]) else "a newly bound ally"
	var subject := "%s, %s," % [name, origin] if not origin.is_empty() else name
	return "STANDOUT · %s %s." % [subject, " and ".join(clauses)]


## Losses are stated as they happened. An unsettled attempt says the loss
## happened on the road and never that anything was banked from it.
static func _fallen_line(value: Variant, outcome: String) -> String:
	if not value is Array:
		return ""
	var names: Array[String] = []
	var extra := 0
	for entry: Variant in value:
		var fallen := _name(entry)
		if fallen.is_empty():
			continue
		if names.size() < MAX_FALLEN:
			names.append(fallen)
		else:
			extra += 1
	if names.is_empty():
		return ""
	var line := "%s · %s" % ["FALLEN ON THE ROAD" if outcome != "success" else "FALLEN", ", ".join(names)]
	return line + " and %d more" % extra if extra > 0 else line


static func _count(value: Variant) -> int:
	if value is int:
		return maxi(value, 0)
	if value is float:
		# Bound before the cast: int() on a huge or non-finite float is undefined.
		return int(value) if is_finite(value) and value >= 0.0 and value <= float(MAX_COUNT) else 0
	return 0


static func _flag(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key)
	return bool(value) if value is bool else false


static func _name(value: Variant) -> String:
	if not value is String:
		return ""
	var text := (value as String).strip_edges().replace("\n", " ").replace("\t", " ")
	return text.substr(0, MAX_NAME - 1) + "…" if text.length() > MAX_NAME else text
