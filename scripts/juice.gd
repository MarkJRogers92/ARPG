class_name Juice
extends RefCounted
## One place for game feel that many systems trigger: particles, damage
## numbers, light flashes and screen shake. main.gd fills in the nodes at
## startup; everything here does nothing when they're missing (tests that
## build a Player or a swarm on their own), so callers never need to check.

static var fx: FxSwarm
static var numbers: DamageNumbers
static var flashes: LightFlashes
static var camera: CameraRig


## Whether hit-stop and slow motion may change the game speed (off in tests
## and bots, whose fixed steps would be distorted by it).
static var time_effects := false
static var _slow_until := 0


static func reset() -> void:
	time_effects = false
	Engine.time_scale = 1.0
	fx = null
	numbers = null
	flashes = null
	camera = null


static func burst(at: Vector2, y: float, color: Color, n: int, speed := 4.0, size := 0.35, life := 0.5, upward := 3.0) -> void:
	if fx:
		fx.burst(at, y, color, n, speed, size, life, upward)


static func ring(at: Vector2, color: Color, n: int, speed := 8.0, size := 0.5, life := 0.6) -> void:
	if fx:
		fx.ring(at, color, n, speed, size, life)


static func number(at: Vector2, amount: float, crit := false, color := Color.WHITE) -> void:
	if numbers:
		numbers.show_number(at, amount, crit, color)


static func flash(at: Vector2, color: Color, energy := 4.0, radius := 8.0, time := 0.3) -> void:
	if flashes:
		flashes.flash(at, color, energy, radius, time)


## A tiny freeze on a heavy blow: the game runs at 5% speed for `seconds`
## of real time.
static func hitstop(seconds := 0.05) -> void:
	_slow_for(0.05, seconds)


## Slow motion for `seconds` of real time (the final boss's death).
static func slow_motion(scale: float, seconds: float) -> void:
	_slow_for(scale, seconds)


static func _slow_for(scale: float, seconds: float) -> void:
	if not time_effects:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _slow_until and Engine.time_scale <= scale:
		return
	_slow_until = maxi(_slow_until, until)
	Engine.time_scale = minf(Engine.time_scale, scale)
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _slow_until:
			Engine.time_scale = 1.0)


static func shake(amount: float) -> void:
	if camera:
		camera.shake(amount)
