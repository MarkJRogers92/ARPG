class_name UiStyle
extends RefCounted
## Shared look for the code-built UI: dark panels with bronze trim. theme()
## styles buttons, lists and text everywhere it's set (the screens set it on
## their root control); the helpers below cover the custom bits.

const GOLD := Color(0.95, 0.78, 0.42)
const BRONZE := Color(0.55, 0.43, 0.26)
const INK := Color(0.055, 0.058, 0.075, 0.97)
const TEXT := Color(0.9, 0.88, 0.84)
const MUTED := Color(0.58, 0.57, 0.6)

static var _theme: Theme


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = BRONZE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	return style


## A flat box: `fill`, a `border` of `width` px and `radius` corners.
static func box(fill: Color, border := Color.TRANSPARENT, width := 0, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


## Outlined label text that stays readable over the game.
static func label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	return label


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16

	var normal := box(Color(0.12, 0.11, 0.12), BRONZE.darkened(0.2), 2, 5)
	normal.set_content_margin_all(8)
	var hover := box(Color(0.17, 0.15, 0.14), GOLD.darkened(0.1), 2, 5)
	hover.set_content_margin_all(8)
	var pressed := box(Color(0.08, 0.07, 0.07), GOLD, 2, 5)
	pressed.set_content_margin_all(8)
	var disabled := box(Color(0.09, 0.09, 0.1, 0.8), Color(0.25, 0.24, 0.24), 2, 5)
	disabled.set_content_margin_all(8)
	var focus := box(Color.TRANSPARENT, GOLD, 2, 6)
	focus.draw_center = false
	focus.set_expand_margin_all(2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.44, 0.44))

	var list := box(Color(0.035, 0.038, 0.05, 0.95), Color(0.22, 0.2, 0.18), 1, 4)
	list.set_content_margin_all(6)
	t.set_stylebox("panel", "ItemList", list)
	t.set_stylebox("focus", "ItemList", focus)
	var selected := box(Color(0.3, 0.23, 0.12, 0.9), GOLD.darkened(0.2), 1, 3)
	t.set_stylebox("selected", "ItemList", selected)
	t.set_stylebox("selected_focus", "ItemList", selected)
	t.set_stylebox("cursor", "ItemList", box(Color.TRANSPARENT, GOLD, 1, 3))
	t.set_stylebox("cursor_unfocused", "ItemList", box(Color.TRANSPARENT, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 3))
	t.set_color("guide_color", "ItemList", Color(1, 1, 1, 0.04))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("icon_margin", "ItemList", 8)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t


## A styled bar. The fill gets a light top edge and dark bottom edge, which
## reads as a bevel without any textures.
static func bar(color: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := box(color, Color.TRANSPARENT, 0, 3)
	fill.border_width_top = maxi(1, int(height * 0.22))
	fill.border_width_bottom = maxi(1, int(height * 0.22))
	fill.border_color = color.lightened(0.35)
	fill.border_blend = true
	var back := box(Color(0.02, 0.02, 0.03, 0.85), Color(0, 0, 0, 0.9), 2, 4)
	back.set_expand_margin_all(2)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	return b
