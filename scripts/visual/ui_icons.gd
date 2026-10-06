class_name UiIcons
extends Control
## A small vector icon, drawn with canvas calls so it needs no image files.
## Used on the level-up cards. Set `icon` to an upgrade id (see Upgrades.DEFS,
## plus "heal") and `color`.

@export var icon := ""
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	# A medallion behind every icon.
	draw_circle(c, r, Color(color, 0.12))
	draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(color, 0.7), 3.0, true)
	draw_arc(c, r - 7.0, 0.0, TAU, 48, Color(color, 0.18), 1.5, true)
	var s := r * 0.55 # icon half-size
	match icon:
		"bolt_damage":
			_bolt(c, s, color)
		"bolt_rate":
			for k in 3:
				var x := c.x - s * 0.7 + k * s * 0.6
				draw_polyline([Vector2(x, c.y - s * 0.6), Vector2(x + s * 0.45, c.y), Vector2(x, c.y + s * 0.6)], color, 5.0, true)
		"bolt_count":
			for k in 3:
				var a := -0.45 + k * 0.45
				var dir := Vector2.from_angle(a - PI / 2.0)
				var tip := c + Vector2(0, s * 0.8) + dir * s * 1.5
				draw_line(c + Vector2(0, s * 0.8), tip, Color(color, 0.5), 3.0, true)
				draw_circle(tip, s * 0.2, color)
		"bolt_pierce":
			draw_arc(c + Vector2(s * 0.15, 0), s * 0.45, 0.0, TAU, 24, Color(color, 0.6), 3.0, true)
			draw_line(c - Vector2(s * 1.0, 0), c + Vector2(s * 0.95, 0), color, 4.0, true)
			draw_colored_polygon([c + Vector2(s * 1.15, 0), c + Vector2(s * 0.7, -s * 0.3), c + Vector2(s * 0.7, s * 0.3)], color)
		"aura":
			for k in 6:
				var dir := Vector2.from_angle(k * PI / 3.0)
				draw_line(c, c + dir * s, color, 3.0, true)
				var b := c + dir * s * 0.6
				draw_line(b, b + dir.rotated(0.7) * s * 0.3, color, 2.0, true)
				draw_line(b, b + dir.rotated(-0.7) * s * 0.3, color, 2.0, true)
			draw_circle(c, s * 0.15, color)
		"move_speed":
			for k in 3:
				var y := c.y - s * 0.5 + k * s * 0.5
				draw_line(Vector2(c.x - s, y), Vector2(c.x - s * 0.2 + k * s * 0.15, y), Color(color, 0.6), 3.0, true)
			draw_colored_polygon([
				c + Vector2(-s * 0.1, -s * 0.8), c + Vector2(s * 0.35, -s * 0.8), c + Vector2(s * 0.35, s * 0.1),
				c + Vector2(s * 1.0, s * 0.4), c + Vector2(s * 1.0, s * 0.75), c + Vector2(-s * 0.1, s * 0.75)], color)
		"max_hp":
			_heart(c, s, color)
		"regen":
			_heart(c + Vector2(-s * 0.15, 0), s * 0.85, Color(color, 0.55))
			_plus(c + Vector2(s * 0.45, s * 0.35), s * 0.45, color)
		"heal":
			_heart(c, s, color)
			_plus(c + Vector2(0, -s * 0.05), s * 0.35, Color(1, 1, 1, 0.9))
		"magnet":
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.6, 0.0, PI, 24, color, s * 0.38, true)
			for side: float in [-1.0, 1.0]:
				var x := c.x + side * s * 0.6
				draw_line(Vector2(x, c.y - s * 0.1), Vector2(x, c.y - s * 0.75), color, s * 0.38, true)
				draw_line(Vector2(x, c.y - s * 0.6), Vector2(x, c.y - s * 0.9), Color(1, 1, 1, 0.85), s * 0.38, true)
		"lightning":
			draw_polyline([c + Vector2(-s * 0.9, -s * 0.7), c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(-s * 0.45, s * 0.15),
					c + Vector2(s * 0.3, s * 0.75)], color, 5.0, true)
			for p: Vector2 in [Vector2(-0.9, -0.7), Vector2(-0.2, -0.1), Vector2(0.3, 0.75)]:
				draw_circle(c + p * s, s * 0.17, color)
			draw_line(c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(s * 0.8, -s * 0.5), Color(color, 0.6), 3.0, true)
			draw_circle(c + Vector2(s * 0.8, -s * 0.5), s * 0.13, Color(color, 0.8))
		"orbit":
			draw_arc(c, s * 0.75, 0.0, TAU, 32, Color(color, 0.35), 2.0, true)
			draw_circle(c, s * 0.2, Color(1, 1, 1, 0.8))
			for k in 3:
				var dir := Vector2.from_angle(k * TAU / 3.0)
				var tip := c + dir * s * 0.75
				draw_colored_polygon([tip + dir.orthogonal() * s * 0.45, tip + dir * s * 0.15, tip - dir * s * 0.15], color)
		"nova":
			draw_circle(c, s * 0.25, color)
			draw_arc(c, s * 0.55, 0.0, TAU, 32, color, 3.0, true)
			draw_arc(c, s * 0.9, 0.0, TAU, 32, Color(color, 0.5), 2.0, true)
			for k in 8:
				var dir := Vector2.from_angle(k * TAU / 8.0)
				draw_line(c + dir * s * 0.62, c + dir * s * 0.82, color, 2.5, true)
		_:
			draw_circle(c, s * 0.5, color)


func _bolt(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon([
		c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.55, s * 0.12), c + Vector2(-s * 0.02, s * 0.12),
		c + Vector2(-s * 0.3, s), c + Vector2(s * 0.6, -s * 0.2), c + Vector2(s * 0.05, -s * 0.2)], col)


func _heart(c: Vector2, s: float, col: Color) -> void:
	var r := s * 0.48
	draw_circle(c + Vector2(-r * 0.92, -s * 0.25), r, col)
	draw_circle(c + Vector2(r * 0.92, -s * 0.25), r, col)
	draw_colored_polygon([c + Vector2(-s * 0.93, -s * 0.05), c + Vector2(s * 0.93, -s * 0.05), c + Vector2(0, s * 0.9)], col)


func _plus(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c - Vector2(s, s * 0.32), Vector2(s * 2.0, s * 0.64)), col)
	draw_rect(Rect2(c - Vector2(s * 0.32, s), Vector2(s * 0.64, s * 2.0)), col)
