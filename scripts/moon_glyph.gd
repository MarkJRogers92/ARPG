class_name MoonGlyph
extends Control
## A small moon disc lit by the phase (age in days of the synodic month).

var age := 0.0:
	set(v):
		age = v
		queue_redraw()
var tint := Color(1.0, 0.95, 0.8)


func _init() -> void:
	custom_minimum_size = Vector2(26, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	draw_circle(c, r, Color(0.16, 0.17, 0.24))
	var phi := TAU * age / MoonPhase.SYNODIC_DAYS
	var waxing := phi <= PI
	var f := phi if waxing else TAU - phi
	var s := 1.0 if waxing else -1.0
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var th := PI * i / steps
		pts.append(c + Vector2(s * r * sin(th), -r * cos(th)))
	for i in steps + 1:
		var th := PI - PI * i / steps
		pts.append(c + Vector2(s * r * cos(f) * sin(th), -r * cos(th)))
	if f > 0.05:
		draw_colored_polygon(pts, tint)
	draw_arc(c, r, 0.0, TAU, 32, Color(tint, 0.5), 1.0)
