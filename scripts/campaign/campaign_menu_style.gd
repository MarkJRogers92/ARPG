extends RefCounted
## Local campaign presentation palette. This deliberately duplicates the shared
## game theme before applying overrides so campaign menus cannot mutate UiStyle.

const INK := Color("111923")
const SURFACE := Color("19232e")
const SURFACE_RAISED := Color("202c38")
const BRONZE := Color("75654b")
const BRONZE_SOFT := Color("554d42")
const GOLD := Color("d8b56c")
const SOUL := Color("88b8c1")
const TEXT := Color("e1e3df")
const MUTED := Color("a4adb2")
const DISABLED := Color("737c81")


static func make_theme(base_theme: Theme) -> Theme:
	var local_theme := base_theme.duplicate(true) as Theme
	local_theme.set_color("font_color", "Button", TEXT)
	local_theme.set_color("font_hover_color", "Button", Color.WHITE)
	local_theme.set_color("font_pressed_color", "Button", GOLD)
	local_theme.set_color("font_disabled_color", "Button", DISABLED)
	local_theme.set_color("font_focus_color", "Button", Color.WHITE)
	local_theme.set_stylebox("normal", "Button", button_box(SURFACE, BRONZE_SOFT, 1))
	local_theme.set_stylebox("hover", "Button", button_box(SURFACE_RAISED, SOUL, 1))
	local_theme.set_stylebox("pressed", "Button", button_box(Color("273844"), GOLD, 1))
	local_theme.set_stylebox("disabled", "Button", button_box(Color("171d24"), Color("343a3c"), 1))
	local_theme.set_stylebox("focus", "Button", button_box(Color(0, 0, 0, 0), SOUL, 2))
	local_theme.set_stylebox("normal", "OptionButton", button_box(SURFACE, BRONZE_SOFT, 1))
	local_theme.set_stylebox("hover", "OptionButton", button_box(SURFACE_RAISED, SOUL, 1))
	local_theme.set_stylebox("pressed", "OptionButton", button_box(Color("273844"), GOLD, 1))
	local_theme.set_stylebox("disabled", "OptionButton", button_box(Color("171d24"), Color("343a3c"), 1))
	local_theme.set_stylebox("focus", "OptionButton", button_box(Color(0, 0, 0, 0), SOUL, 2))
	return local_theme


static func panel(fill: Color = INK, edge: Color = BRONZE_SOFT, width: int = 1, radius: int = 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func service_box(active: bool) -> StyleBoxFlat:
	return button_box(Color("202a32") if active else Color("111923"), SOUL if active else Color("3b444a"), 1)


static func primary_box() -> StyleBoxFlat:
	return button_box(Color("5d4a2a"), GOLD, 1)


static func quiet_box() -> StyleBoxFlat:
	return button_box(Color("18212a"), Color("56616a"), 1)


static func label(font_size: int) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	return result


static func button_box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(5)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box
