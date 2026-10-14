class_name GradePass
extends CanvasLayer
## A cheap full-screen grade (shaders/grade.gdshader) drawn under the HUD:
## split-toning, painted edge falloff and light grain. Atmosphere feeds it each
## realm's look (Realm "grade") and eases it for boss red and dawn.

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	name = "GradePass"
	layer = 0 # below the HUD (layer 1) so the UI is never tinted
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/grade.gdshader")
	_rect.material = _mat
	add_child(_rect)


## Sets any of the shader's uniforms from a dictionary.
func apply(params: Dictionary) -> void:
	for k: String in params:
		_mat.set_shader_parameter(k, params[k])


func set_param(key: String, value: Variant) -> void:
	_mat.set_shader_parameter(key, value)
