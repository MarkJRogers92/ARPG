extends SceneTree
## Font shaping contracts: real bundled faces, tabular figures, symbol coverage
## and line metrics. No profile, game state, or external font dependency.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	var faces := [UiStyle.BODY, UiStyle.EMPHASIS, UiStyle.ITALIC, UiStyle.BOLD_ITALIC]
	for face: Font in faces:
		for size: int in [12, 14, 16, 20, 26, 40, 56]:
			var reference := face.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			for digit in 10:
				var width := face.get_string_size(str(digit).repeat(4), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				check(is_equal_approx(width, reference), "tabular figure %d at %d px" % [digit, size])
			check(face.get_height(size) <= float(size) * 1.5, "symbol fallback keeps body line height at %d px" % size)
		for character: String in "·×—“”•…→↯⌖▣▲▶▼◀◆◇◉○●★☆☠♜⚑⚒⚔✓✦✧❄":
			check(face.has_char(character.unicode_at(0)), "bundled glyph " + character)
	var theme := UiStyle.theme()
	check(theme.default_font == UiStyle.BODY, "default reading face")
	check(theme.get_font("bold_font", "RichTextLabel") == UiStyle.EMPHASIS, "true semibold rich text")
	check(theme.get_font("italics_font", "RichTextLabel") == UiStyle.ITALIC, "true italic rich text")
	var heading := UiStyle.heading(30)
	check(heading.get_theme_font("font") == UiStyle.HEADING, "distinct display face")
	heading.free()
	print("TYPOGRAPHY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
