class_name CameraRig
extends Node3D
## Follows `target` with a little smoothing, and shakes on request. The
## Camera3D child carries the angle and distance, so tweak those in the scene,
## not here.

@export var target: Node3D
@export var follow_speed := 8.0
## Largest shake offset in world units, reached at full trauma.
@export var max_shake := 0.7
## Set false to turn screen shake off.
@export var shake_enabled := true

var _trauma := 0.0
var _time := 0.0
@onready var _camera: Camera3D = get_node_or_null("Camera3D")


func _ready() -> void:
	if target:
		global_position = target.global_position


## Adds shake: 0.1 is a nudge, 0.5 a big hit, 1.0 the most there is.
func shake(amount: float) -> void:
	if shake_enabled:
		_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	if _camera == null:
		return
	_time += delta
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	# Squared trauma feels better: small hits barely move, big ones rattle.
	var s := _trauma * _trauma * max_shake
	_camera.h_offset = s * sin(_time * 47.0) * cos(_time * 13.0)
	_camera.v_offset = s * cos(_time * 41.0) * sin(_time * 17.0)
