class_name DawnGlow
extends CanvasLayer
## The rising sun's light on the screen (shaders/dawn_glow.gdshader), under
## the HUD. It comes from the corner the scene's sunlight shines from, so the
## glow and the long First Light shadows agree.

var _rect: ColorRect
var _mat: ShaderMaterial
var _dawn := 0.0
var _dawn_target := 0.0


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/dawn_glow.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## Fades the sunrise in (true) or out (false).
func dawn(on: bool) -> void:
	_dawn_target = 1.0 if on else 0.0


func tick(delta: float, first_light: float) -> void:
	_dawn = move_toward(_dawn, _dawn_target, delta * 0.5)
	var first := smoothstep(0.0, 1.0, first_light) * (1.0 - _dawn)
	_rect.visible = first > 0.001 or _dawn > 0.001
	if not _rect.visible:
		return
	var size := _rect.get_viewport_rect().size
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("first_light", first)
	_mat.set_shader_parameter("dawn", smoothstep(0.0, 1.0, _dawn))
