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
	var total := 0.0
	for k: String in taken:
		total += taken[k]
	var keys := taken.keys()
	keys.sort_custom(func(a, b) -> bool: return taken[a] > taken[b])
	var out := []
	for k: String in keys:
		if taken[k] > 0.0:
			out.append([k, taken[k], taken[k] / total if total > 0.0 else 0.0])
	return out


## "Slain by a Bone Lancer's charge.  Hurt most by: Ghoul 45%  ·  Meteors 20%..."
## (on a won night, only the second part).
static func summary(taken: Dictionary, last: String, died: bool) -> String:
	var parts := []
	for r: Array in ranked(taken).slice(0, 4):
		parts.append("%s %d%%" % [r[0], roundi(100.0 * r[2])])
	var hurt: String = ("HURT MOST BY:  " + "   ·   ".join(parts)) if not parts.is_empty() else "Untouched all night."
	if died and last != "":
		return "SLAIN BY:  %s\n%s" % [last, hurt]
	return hurt


func _ready() -> void:
	custom_minimum_size = Vector2(520, 44)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_samples(list: Array[Vector3]) -> void:
	samples = list.duplicate()
	visible = samples.size() >= 2
	queue_redraw()


func _draw() -> void:
	if samples.size() < 2:
		return
	var w := size.x
	var h := size.y - 14.0
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.05))
	var t0 := samples[0].x
	var t1 := t0 + 1.0
	for s in samples:
		t0 = minf(t0, s.x)
		t1 = maxf(t1, s.x)
	var top := 1.0
	for s in samples:
		top = maxf(top, s.z)
	var hp := PackedVector2Array()
	var pressure := PackedVector2Array()
	for s in samples:
		var x := clampf((s.x - t0) / (t1 - t0), 0.0, 1.0) * w
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
