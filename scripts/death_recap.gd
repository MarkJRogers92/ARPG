class_name DeathRecap
extends Control
## "Why I died": the end screen's look back at the night. The hero keeps the
## damage it took by cause (Player.take_damage) and what landed the last blow;
## main.gd samples health and pressure every SAMPLE_EVERY seconds. This node
## draws that timeline (health in red, pressure in violet) and summary()
## turns the causes into a line of text. Cheap during play: one dictionary
## add per hit and one sample every ten seconds.

const SAMPLE_EVERY := 10.0
## The timeline keeps at most this many samples; past that it halves itself
## (every other one dropped), so a long Endless night stays small.
const MAX_SAMPLES := 240
const HP_COLOR := Color(1.0, 0.35, 0.3)
const PRESSURE_COLOR := Color(0.75, 0.55, 1.0)

## [Vector3(time, health 0..1, pressure)]
var samples: Array[Vector3] = []


static func add_sample(list: Array[Vector3], t: float, hp: float, pressure: float) -> void:
	list.append(Vector3(t, clampf(hp, 0.0, 1.0), pressure))
	if list.size() > MAX_SAMPLES:
		var kept: Array[Vector3] = []
		for k in range(0, list.size(), 2):
			kept.append(list[k])
		list.assign(kept)


## The causes, most damage first: [[cause, damage, share 0..1]].
static func ranked(taken: Dictionary) -> Array:
	var clean := {}
	var total := 0.0
	for key: Variant in taken:
		var amount: Variant = taken[key]
		if not key is String or not (amount is int or amount is float) or not is_finite(amount) or amount <= 0.0: continue
		var cause := clean_cause(key)
		clean[cause] = float(clean.get(cause, 0.0)) + float(amount)
		total += float(amount)
	var keys := clean.keys()
	keys.sort_custom(func(a, b) -> bool: return clean[a] > clean[b])
	var out := []
	for key: String in keys: out.append([key, clean[key], clean[key] / total])
	return out


## "Slain by a Bone Lancer's charge.  Hurt most by: Ghoul 45%  ·  Meteors 20%..."
## (on a won night, only the second part).
static func summary(taken: Dictionary, last: String, died: bool) -> String:
	var parts := []
	for r: Array in ranked(taken).slice(0, 4):
		parts.append("%s %d%%" % [r[0], roundi(100.0 * r[2])])
	var hurt: String = ("HURT MOST BY:  " + "   ·   ".join(parts)) if not parts.is_empty() else "Untouched all night."
	if died:
		if parts.is_empty(): hurt = "No incoming damage was recorded."
		return "SLAIN BY:  %s\n%s" % [clean_cause(last), hurt]
	return hurt


func _ready() -> void:
	custom_minimum_size = Vector2(520, 44)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_samples(list: Array[Vector3]) -> void:
	samples = list.duplicate()
	visible = samples.size() >= 2 and samples[-1].x > samples[0].x + 0.001
	queue_redraw()


func _draw() -> void:
	if samples.size() < 2:
		return
	var w := size.x
	var h := size.y - 14.0
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.05))
	var t0 := samples[0].x
	var t1 := t0
	for s in samples:
		t0 = minf(t0, s.x)
		t1 = maxf(t1, s.x)
	var top := 1.0
	for s in samples:
		top = maxf(top, s.z)
	var hp := PackedVector2Array()
	var pressure := PackedVector2Array()
	for s in samples:
		var x := clampf((s.x - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0) * w
		hp.append(Vector2(x, h - s.y * h))
		pressure.append(Vector2(x, h - (s.z - 1.0) / maxf(top - 1.0, 0.001) * h * 0.95))
	if top > 1.0:
		draw_polyline(pressure, PRESSURE_COLOR, 2.0, true)
	draw_polyline(hp, HP_COLOR, 2.0, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, size.y), "health", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HP_COLOR)
	if top > 1.0:
		draw_string(font, Vector2(60, size.y), "pressure (peak %.1f)" % top, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PRESSURE_COLOR)
	draw_string(font, Vector2(w - 60, size.y), "%d:%02d" % [int(t1) / 60, int(t1) % 60], HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(1, 1, 1, 0.6))

## Bounded recent incoming damage, in half-second combat-time buckets.
## A bucket groups repeated contact/burning ticks without inventing individual hits.
const RECENT_SECONDS := 10.0
const RECENT_BUCKET := 0.5
const RECENT_BINS := 21
const RECENT_CAUSES := 16
const OTHER_CAUSES := "Other sources (grouped)"

static func clean_cause(cause: String) -> String:
	var text := cause.strip_edges().replace("\n", " ").replace("\r", " ").left(80)
	return text if not text.is_empty() else "Unknown source"

static func record_recent(history: Array[Dictionary], at: float, cause: String, damage: float) -> void:
	if not is_finite(at) or not is_finite(damage) or damage <= 0.0: return
	at = maxf(at, 0.0)
	var bucket := floorf(at / RECENT_BUCKET) * RECENT_BUCKET
	if history.is_empty() or not is_equal_approx(float(history[-1]["at"]), bucket):
		history.append({"at": bucket, "last_at": at, "damage": {}})
	var row: Dictionary = history[-1]
	var by: Dictionary = row["damage"]
	var source := clean_cause(cause)
	if not by.has(source) and by.size() >= RECENT_CAUSES - 1: source = OTHER_CAUSES
	by[source] = float(by.get(source, 0.0)) + damage
	row["last_at"] = at
	while history.size() > RECENT_BINS or not history.is_empty() and float(history[0]["at"]) < at - RECENT_SECONDS:
		history.pop_front()

static func recent_snapshot(value: Variant, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not value is Array or not is_finite(now): return out
	# Optional save field: malformed/legacy data cannot fabricate damage history.
	for raw: Variant in value.slice(-RECENT_BINS):
		if not raw is Dictionary: continue
		var at: Variant = raw.get("at")
		var last: Variant = raw.get("last_at", at)
		if not (at is float or at is int) or not (last is float or last is int): continue
		if not is_finite(at) or not is_finite(last) or at < 0.0 or at < now - RECENT_SECONDS or last < at or last >= at + RECENT_BUCKET + 0.001 or last > now + 0.001: continue
		var damage: Variant = raw.get("damage")
		if not damage is Dictionary: continue
		var clean := {}
		for key: Variant in damage.keys().slice(0, RECENT_CAUSES):
			var amount: Variant = damage[key]
			if not key is String or not (amount is float or amount is int) or not is_finite(amount) or amount <= 0.0: continue
			var source := clean_cause(key)
			clean[source] = float(clean.get(source, 0.0)) + float(amount)
		if not clean.is_empty(): out.append({"at": float(at), "last_at": float(last), "damage": clean})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return out

static func recent_summary(value: Variant, now: float) -> Dictionary:
	var history := recent_snapshot(value, now)
	if history.is_empty():
		return {"trail": "RECENT DAMAGE · No recent entries available.", "takeaway": ""}
	var totals := {}
	var total := 0.0
	for row: Dictionary in history:
		for cause: String in row["damage"]:
			var amount := float(row["damage"][cause])
			totals[cause] = float(totals.get(cause, 0.0)) + amount
			total += amount
	var strongest: Array = ranked(totals)[0]
	var lines: Array[String] = ["RECENT DAMAGE · %.1f HP lost after armor · 0.5s groups (latest 4 shown)" % total]
	for row: Dictionary in history.slice(-4):
		var parts: Array[String] = []
		var causes := ranked(row["damage"])
		for cause: Array in causes.slice(0, 2): parts.append("%s %.1f HP" % [cause[0], cause[1]])
		if causes.size() > 2:
			var rest := 0.0
			for cause: Array in causes.slice(2): rest += float(cause[1])
			parts.append("%d other sources %.1f HP" % [causes.size() - 2, rest])
		lines.append("%.1fs before end · %s" % [maxf(now - float(row["last_at"]), 0.0), " · ".join(parts)])
	return {"trail": "\n".join(lines), "takeaway": "FOCUS NEXT RUN · %s accounted for %d%% of the recorded recent damage." % [strongest[0], roundi(strongest[2] * 100.0)]}
