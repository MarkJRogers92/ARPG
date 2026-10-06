class_name LightFlashes
extends Node3D
## Short bursts of real light for explosions (novas, boss slams, elite
## deaths): a small pool of OmniLights that light the ground and scenery for
## a moment and fade. The horde is on another render layer and isn't lit by
## them, which keeps a flash cheap however big the crowd.

@export var pool_size := 4

var _lights: Array[OmniLight3D] = []
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _energy := PackedFloat32Array()
var _next := 0


func _ready() -> void:
	for i in pool_size:
		var light := OmniLight3D.new()
		light.visible = false
		light.light_cull_mask = 1
		light.omni_attenuation = 1.6
		add_child(light)
		_lights.append(light)
	_life.resize(pool_size)
	_max.resize(pool_size)
	_energy.resize(pool_size)


func flash(at: Vector2, color: Color, energy: float, radius: float, time: float) -> void:
	var i := _next
	_next = (_next + 1) % pool_size
	var light := _lights[i]
	light.position = Vector3(at.x, 2.0, at.y)
	light.light_color = color
	light.omni_range = radius
	light.light_energy = energy
	light.visible = true
	_life[i] = time
	_max[i] = time
	_energy[i] = energy


func _process(delta: float) -> void:
	for i in pool_size:
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		var light := _lights[i]
		if _life[i] <= 0.0:
			light.visible = false
		else:
			light.light_energy = _energy[i] * _life[i] / _max[i]
