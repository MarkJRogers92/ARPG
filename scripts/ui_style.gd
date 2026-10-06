class_name UiStyle
extends RefCounted
## Shared look for the code-built UI panels.


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	style.border_color = Color(0.35, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


## Outlined label text that stays readable over the game.
static func label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label
