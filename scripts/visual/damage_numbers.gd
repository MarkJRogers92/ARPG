class_name DamageNumbers
extends Node3D
## Floating damage numbers from a fixed pool of labels: when the pool runs
## out, the oldest number is reused, so a huge fight can't create thousands
## of nodes. Crits are bigger, gold and pop; ordinary hits are small and only
## every few are shown (see `normal_every`) so the screen stays readable.

@export var pool_size := 48
## Show one in this many non-crit numbers.
@export var normal_every := 5

var _labels: Array[Label3D] = []
var _age := PackedFloat32Array()
var _vel := PackedVector3Array()
var _next := 0
var _normal_count := 0

const LIFE := 0.8


func _ready() -> void:
	for i in pool_size:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.01
		label.font_size = 40
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0, 0.85)
		label.render_priority = 5
		label.visible = false
		add_child(label)
		_labels.append(label)
	_age.resize(pool_size)
	_vel.resize(pool_size)
	for i in pool_size:
		_age[i] = LIFE


func show_number(at: Vector2, amount: float, crit: bool, color: Color) -> void:
	if not crit:
		_normal_count += 1
		if _normal_count % normal_every != 0:
			return
	var i := _next
	_next = (_next + 1) % pool_size
	var label := _labels[i]
	label.text = str(roundi(amount))
	label.position = Vector3(at.x + randf_range(-0.3, 0.3), 1.8, at.y + randf_range(-0.2, 0.2))
	label.modulate = Color(1.0, 0.82, 0.25) if crit else color
	label.font_size = 64 if crit else 36
	label.scale = Vector3.ONE * (1.6 if crit else 1.0)
	label.visible = true
	_age[i] = 0.0
	_vel[i] = Vector3(randf_range(-0.6, 0.6), 3.2 if crit else 2.4, 0.0)


## A word instead of a number (reactions like "SHATTER"), always shown.
func show_text(at: Vector2, text: String, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % pool_size
	var label := _labels[i]
	label.text = text
	label.position = Vector3(at.x, 2.4, at.y)
	label.modulate = color
	label.font_size = 56
	label.scale = Vector3.ONE * 1.6
	label.visible = true
	_age[i] = 0.0
	_vel[i] = Vector3(0.0, 3.0, 0.0)


func _process(delta: float) -> void:
	for i in pool_size:
		if _age[i] >= LIFE:
			continue
		var label := _labels[i]
		_age[i] += delta
		var t := _age[i] / LIFE
		if t >= 1.0:
			label.visible = false
			continue
		_vel[i].y -= 5.0 * delta
		label.position += _vel[i] * delta
		label.modulate.a = 1.0 - t * t
		# Crits pop: shrink from 1.6x down to normal size quickly.
		if label.font_size > 40:
			label.scale = Vector3.ONE * lerpf(1.6, 1.0, minf(t * 4.0, 1.0))
