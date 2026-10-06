extends Node3D
## Follows `target` with a little smoothing. The Camera3D child carries the
## angle and distance, so tweak those in the scene, not here.

@export var target: Node3D
@export var follow_speed := 8.0


func _ready() -> void:
	if target:
		global_position = target.global_position


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
