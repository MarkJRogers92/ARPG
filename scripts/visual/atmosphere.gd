class_name Atmosphere
extends Node
## The run's mood, changing with time: a warm dusk at the start, cold
## moonlight by the middle of the run and a red blood moon late on, which
## reads as "it's getting serious". While a boss is alive everything leans
## further toward red. Drives the sun, ambient light and fog.

## Light, ambient and fog at each stage, at these game times (seconds).
const STAGES := [
	{"t": 0.0, "sun": Color(1.0, 0.9, 0.76), "sun_e": 1.25, "amb": Color(0.42, 0.48, 0.7), "amb_e": 0.75, "fog": Color(0.07, 0.09, 0.13)},
	{"t": 240.0, "sun": Color(0.62, 0.72, 1.0), "sun_e": 1.0, "amb": Color(0.3, 0.38, 0.68), "amb_e": 0.65, "fog": Color(0.04, 0.06, 0.13)},
	{"t": 540.0, "sun": Color(1.0, 0.42, 0.32), "sun_e": 1.1, "amb": Color(0.55, 0.28, 0.32), "amb_e": 0.65, "fog": Color(0.16, 0.04, 0.05)},
]
const BOSS := {"sun": Color(1.0, 0.35, 0.25), "amb": Color(0.6, 0.25, 0.25), "fog": Color(0.18, 0.03, 0.03)}

@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D

var _boss := 0.0


func tick(delta: float, game_time: float, boss_alive: bool) -> void:
	if environment_node == null or sun == null:
		return
	_boss = move_toward(_boss, 1.0 if boss_alive else 0.0, delta * 0.5)
	var a: Dictionary = STAGES[0]
	var b: Dictionary = STAGES[0]
	for stage: Dictionary in STAGES:
		if game_time >= stage["t"]:
			a = stage
			b = stage
		else:
			b = stage
			break
	var span: float = b["t"] - a["t"]
	var k := 0.0 if span <= 0.0 else smoothstep(0.0, 1.0, (game_time - a["t"]) / span)
	var boss := _boss * 0.45
	var env := environment_node.environment
	sun.light_color = (a["sun"] as Color).lerp(b["sun"], k).lerp(BOSS["sun"], boss)
	sun.light_energy = lerpf(a["sun_e"], b["sun_e"], k)
	env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], k).lerp(BOSS["amb"], boss)
	env.ambient_light_energy = lerpf(a["amb_e"], b["amb_e"], k)
	env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], k).lerp(BOSS["fog"], boss)
