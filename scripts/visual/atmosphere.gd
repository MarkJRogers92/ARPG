class_name Atmosphere
extends Node
## The run's mood, changing with time. Each realm brings its own stages (see
## Realm): the Graveyard goes from warm dusk to cold moonlight to a blood moon,
## the Frozen Wastes into a white-out blizzard, the Ember Rift ever deeper
## red. While a boss is alive everything leans toward red, and winning the
## night (dawn()) fades in a golden sunrise. Drives the sun, ambient light and
## fog.

## Light, ambient and fog at each stage, at these game times (seconds).
var stages: Array = Realm.data("graveyard")["stages"]
const BOSS := {"sun": Color(1.0, 0.35, 0.25), "amb": Color(0.6, 0.25, 0.25), "fog": Color(0.18, 0.03, 0.03)}
const DAWN := {"sun": Color(1.0, 0.86, 0.62), "sun_e": 1.7, "amb": Color(0.78, 0.72, 0.66), "amb_e": 1.0,
		"fog": Color(0.55, 0.48, 0.42), "fog_d": 0.006}

@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D

var _boss := 0.0
var _dawn := 0.0
var _dawn_target := 0.0


## Fades to sunrise (true) or back to the night (false) over a few seconds.
func dawn(on: bool) -> void:
	_dawn_target = 1.0 if on else 0.0


func tick(delta: float, game_time: float, boss_alive: bool) -> void:
	if environment_node == null or sun == null:
		return
	_boss = move_toward(_boss, 1.0 if boss_alive else 0.0, delta * 0.5)
	_dawn = move_toward(_dawn, _dawn_target, delta * 0.35)
	var a: Dictionary = stages[0]
	var b: Dictionary = stages[0]
	for stage: Dictionary in stages:
		if game_time >= stage["t"]:
			a = stage
			b = stage
		else:
			b = stage
			break
	var span: float = b["t"] - a["t"]
	var k := 0.0 if span <= 0.0 else smoothstep(0.0, 1.0, (game_time - a["t"]) / span)
	var boss := _boss * 0.45
	var dawn_k := smoothstep(0.0, 1.0, _dawn)
	var env := environment_node.environment
	sun.light_color = (a["sun"] as Color).lerp(b["sun"], k).lerp(BOSS["sun"], boss).lerp(DAWN["sun"], dawn_k)
	sun.light_energy = lerpf(lerpf(a["sun_e"], b["sun_e"], k), DAWN["sun_e"], dawn_k)
	env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], k).lerp(BOSS["amb"], boss).lerp(DAWN["amb"], dawn_k)
	env.ambient_light_energy = lerpf(lerpf(a["amb_e"], b["amb_e"], k), DAWN["amb_e"], dawn_k)
	env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], k).lerp(BOSS["fog"], boss).lerp(DAWN["fog"], dawn_k)
	env.fog_density = lerpf(lerpf(a.get("fog_d", 0.008), b.get("fog_d", 0.008), k), DAWN["fog_d"], dawn_k)
