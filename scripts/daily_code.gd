class_name DailyCode
extends RefCounted
## A short code for a Daily Night result, to share with friends:
##
##   SB-20261008-K1234-T1432-W-REA-7Q2F
##
## date, kills, seconds survived, W(on) or L(ost), the hero (first three
## letters of its id) and a base-36 checksum over the rest, so a typo or an
## edited number is caught. The night's seed isn't written out: it comes from
## the date (Realm.daily_pick), and the checksum is salted with it.

const PREFIX := "SB"
const _DIGITS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const _CHECK_MOD := 1679616 # 36^4: four base-36 characters


## The code for a result. `date` is "YYYY-MM-DD", like Realm.today().
static func encode(date: String, kills: int, seconds: int, won: bool, hero: String) -> String:
	var body := "%s-%s-K%d-T%d-%s-%s" % [PREFIX, date.replace("-", ""), maxi(kills, 0), maxi(seconds, 0),
			"W" if won else "L", hero.substr(0, 3).to_upper()]
	return body + "-" + _checksum(body, date)


## The parts of a code: {"date", "seed", "kills", "seconds", "won", "class"},
## or {} if it's malformed or its checksum doesn't match. Case and stray
## spaces are forgiven.
static func decode(code: String) -> Dictionary:
	code = code.strip_edges().to_upper().replace(" ", "")
	var parts := code.split("-")
	if parts.size() != 7 or parts[0] != PREFIX:
		return {}
	var d := parts[1]
	if d.length() != 8 or not d.is_valid_int():
		return {}
	var month := d.substr(4, 2).to_int()
	var day := d.substr(6, 2).to_int()
	if month < 1 or month > 12 or day < 1 or day > 31:
		return {}
	var kills := _number(parts[2], "K")
	var seconds := _number(parts[3], "T")
	if kills < 0 or seconds < 0 or not parts[4] in ["W", "L"]:
		return {}
	var hero := ""
	for id: String in HeroClass.ORDER:
		if id.substr(0, 3).to_upper() == parts[5]:
			hero = id
	if hero == "":
		return {}
	var date := "%s-%s-%s" % [d.substr(0, 4), d.substr(4, 2), d.substr(6, 2)]
	var body := "-".join(parts.slice(0, 6))
	if parts[6] != _checksum(body, date):
		return {}
	return {"date": date, "seed": hash(date), "kills": kills, "seconds": seconds,
			"won": parts[4] == "W", "class": hero}


## "K123" -> 123 (up to 9 digits); -1 if it isn't one.
static func _number(part: String, letter: String) -> int:
	var digits := part.substr(1)
	if not part.begins_with(letter) or digits.is_empty() or digits.length() > 9:
		return -1
	for c in digits:
		if not c in "0123456789":
			return -1
	return digits.to_int()


## A polynomial hash of the code, salted with the day's seed, in base 36.
static func _checksum(body: String, date: String) -> String:
	var h := (hash(date) & 0xffffff) % _CHECK_MOD
	for c in body.to_utf8_buffer():
		h = (h * 31 + c + 7) % _CHECK_MOD
	var out := ""
	for i in 4:
		out = _DIGITS[h % 36] + out
		h /= 36
	return out
