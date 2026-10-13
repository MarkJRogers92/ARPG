class_name RunUi
extends RefCounted
## Run-facing presentation only. Existing Godot font and campaign palette.
const INK := Color("10161d")
const SURFACE := Color("192129")
const EDGE := Color("655c4d")
const TEXT := Color("e8e3d7")
const MUTED := Color("b5b4ab")
const GOLD := Color("d5b879")
const SOUL := Color("99c7c0")
const GAIN := Color("a5cfaa")
const LOSS := Color("e0a18f")
static func panel(pad:=16, accent: Color=EDGE) -> StyleBoxFlat:
	var b:=UiStyle.box(INK,accent,1,4)
	b.content_margin_left=pad;b.content_margin_right=pad;b.content_margin_top=pad;b.content_margin_bottom=pad
	return b
static func label(size: int, color: Color=TEXT) -> Label:
	var l:=Label.new();l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_outline_color",Color(0.02,0.025,0.03,0.85));l.add_theme_constant_override("outline_size",2)
	return l
static func theme() -> Theme:
	var t:=preload("res://scripts/campaign/campaign_menu_style.gd").make_theme(UiStyle.theme())
	t.default_font_size=15
	t.set_color("font_color","Label",TEXT);t.set_color("default_color","RichTextLabel",TEXT)
	t.set_color("font_color","ItemList",TEXT)
	t.set_stylebox("panel","ItemList",panel(8,Color("384047")))
	t.set_stylebox("panel","TabContainer",panel(10,Color("384047")))
	t.set_stylebox("tab_selected","TabBar",panel(10,GOLD))
	t.set_stylebox("tab_unselected","TabBar",panel(10,Color("384047")))
	t.set_color("font_selected_color","TabBar",TEXT);t.set_color("font_unselected_color","TabBar",MUTED)
	return t
static func frame_label(l: Label, accent: Color=EDGE, pad:=10) -> void:
	var b:=panel(pad,Color("384047"));b.border_color=accent;b.border_width_left=3
	l.add_theme_stylebox_override("normal",b)
	l.add_theme_constant_override("outline_size",0)
	l.add_theme_color_override("font_color",TEXT)
