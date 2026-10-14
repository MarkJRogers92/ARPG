class_name Atmosphere
extends Node
## The run's mood, changing with time. Each realm brings its own stages (see
## Realm): the Graveyard goes from warm dusk to cold moonlight to a blood moon,
## the Frozen Wastes into a white-out blizzard, the Ember Rift ever deeper
## red. While a boss is alive everything leans toward red, and winning the
## night (dawn()) fades in a golden sunrise. Drives the sun, ambient light and
## fog.
##
## First Light: over the last minutes before dawn (`first_light` 0..1, set by
## main.gd) the sun sinks toward the horizon, so shadows stretch out long, and
## the light warms to rose-gold. When the night is won it climbs again.

## Light, ambient and fog at each stage, at these game times (seconds).
var stages: Array = Realm.data("graveyard")["stages"]
const BOSS := {"sun": Color(1.0, 0.35, 0.25), "amb": Color(0.6, 0.25, 0.25), "fog": Color(0.18, 0.03, 0.03)}
const FIRST := {"sun": Color(1.0, 0.62, 0.46), "amb": Color(0.56, 0.42, 0.55), "fog": Color(0.3, 0.15, 0.17)}
const DAWN := {"sun": Color(1.0, 0.86, 0.62), "sun_e": 1.7, "amb": Color(0.78, 0.72, 0.66), "amb_e": 1.0,
		"fog": Color(0.55, 0.48, 0.42), "fog_d": 0.006}

@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D

## 0 through most of the night, rising to 1 as dawn nears.
var first_light := 0.0
## The night's light, scaled (the New Moon dims it; see MoonPhase). Dawn is unaffected.
var light_scale := 1.0

var _boss := 0.0
var _grade: GradePass
var _grade_base := {}
var _sun_high: Basis
var _sun_low: Basis
var _sun_risen: Basis
var _sun_ready := false
var _dawn := 0.0
var _dawn_target := 0.0


func _ready() -> void:
	# The post grade is a CanvasLayer below the HUD; it can live under this node.
	_grade = GradePass.new()
	add_child(_grade)
	if not _grade_base.is_empty():
		_grade.apply(_grade_base)


## A realm's grade (see Realm._LOOKS): tonemap, exposure, glow, height fog and
## the post pass's split-toning/edge/grain.
func set_look(look: Dictionary) -> void:
	var e: Dictionary = look["env"]
	if environment_node != null:
		var env := environment_node.environment
		env.tonemap_mode = e["tonemap"]
		env.tonemap_exposure = e["exposure"]
		env.tonemap_white = e["white"]
		env.adjustment_enabled = true
		env.adjustment_contrast = e["contrast"]
		env.adjustment_saturation = e["saturation"]
		env.glow_enabled = true
		env.glow_intensity = e["glow"]
		env.glow_bloom = e["bloom"]
		env.glow_hdr_threshold = e["threshold"]
		env.fog_height = e["fog_height"]
		env.fog_height_density = e["fog_height_density"]
		env.fog_sky_affect = 0.0
	_grade_base = look["grade"]
	if _grade != null:
		_grade.apply(_grade_base)


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
	var first := smoothstep(0.0, 1.0, first_light) * 0.55 * (1.0 - dawn_k)
	var env := environment_node.environment
	sun.light_color = (a["sun"] as Color).lerp(b["sun"], k).lerp(FIRST["sun"], first).lerp(BOSS["sun"], boss).lerp(DAWN["sun"], dawn_k)
	sun.light_energy = lerpf(lerpf(a["sun_e"], b["sun_e"], k) * light_scale, DAWN["sun_e"], dawn_k)
	env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], k).lerp(FIRST["amb"], first).lerp(BOSS["amb"], boss).lerp(DAWN["amb"], dawn_k)
	env.ambient_light_energy = lerpf(lerpf(a["amb_e"], b["amb_e"], k) * light_scale, DAWN["amb_e"], dawn_k)
	env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], k).lerp(FIRST["fog"], first).lerp(BOSS["fog"], boss).lerp(DAWN["fog"], dawn_k)
	_tune_grade(boss, dawn_k)
	_tilt_sun(smoothstep(0.0, 1.0, first_light), dawn_k)
	env.fog_density = lerpf(lerpf(a.get("fog_d", 0.008), b.get("fog_d", 0.008), k), DAWN["fog_d"], dawn_k)


## The post grade leans red with the boss and goes warm and open at dawn.
func _tune_grade(boss: float, dawn_k: float) -> void:
	if _grade == null or _grade_base.is_empty():
		return
	var edge: Color = _grade_base["edge_color"]
	_grade.set_param("edge_color", edge.lerp(Color(0.12, 0.01, 0.01), boss).lerp(Color(0.22, 0.12, 0.08), dawn_k))
	_grade.set_param("split", float(_grade_base["split"]) * (1.0 - 0.35 * dawn_k))
	_grade.set_param("edge", float(_grade_base["edge"]) * (1.0 - 0.3 * dawn_k))


## The sun's angle: as set in the scene, low on the horizon for First Light,
## and partway up again once dawn has broken. Same compass direction, so the
## shadows only stretch and shrink.
func _tilt_sun(low: float, risen: float) -> void:
	if not _sun_ready:
		_sun_ready = true
		_sun_high = sun.basis.orthonormalized()
		var down := -_sun_high.z
		var flat := Vector2(down.x, down.z).normalized()
		_sun_low = _sun_basis(flat, deg_to_rad(16.0))
		_sun_risen = _sun_basis(flat, deg_to_rad(32.0))
	sun.basis = _sun_high.slerp(_sun_low, low).orthonormalized().slerp(_sun_risen, risen)


static func _sun_basis(flat: Vector2, elevation: float) -> Basis:
	var dir := Vector3(flat.x * cos(elevation), -sin(elevation), flat.y * cos(elevation))
	return Basis.looking_at(dir, Vector3.UP).orthonormalized()
