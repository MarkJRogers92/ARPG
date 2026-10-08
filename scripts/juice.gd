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
## The "Calm effects" setting (photosensitivity): no hit-stop or slow motion,
## dimmer light flashes, a much fainter rift glitch.
static var calm := false
## The "Bold warnings" setting: ground telegraphs drawn brighter and solid
## (see warning_color()).
static var bold_telegraphs := false
## Slow effects in play: [scale, ends at (msec, real time)]. tick() sets the
## game speed from them every frame, so it always returns to normal.
static var _slows: Array = []


static func reset() -> void:
	time_effects = false
	_slows.clear()
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
		flashes.flash(at, color, energy * (0.3 if calm else 1.0), radius, time)


## The color a ground warning (a circle that will hurt, a charge line) is drawn
## in: as given, or, with Bold warnings on, brighter and close to opaque.
static func warning_color(c: Color) -> Color:
	if not bold_telegraphs:
		return c
	return Color(minf(c.r * 1.25 + 0.1, 1.0), minf(c.g * 1.25 + 0.1, 1.0), minf(c.b * 1.25 + 0.1, 1.0), maxf(c.a * 1.8, 0.9))


## A tiny freeze on a heavy blow: the game runs at 5% speed for `seconds`
## of real time.
static func hitstop(seconds := 0.05) -> void:
	_slow_for(0.05, seconds)


## Slow motion for `seconds` of real time (the final boss's death).
static func slow_motion(scale: float, seconds: float) -> void:
	_slow_for(scale, seconds)


static func _slow_for(scale: float, seconds: float) -> void:
	if not time_effects or calm:
		return
	_slows.append([scale, Time.get_ticks_msec() + int(seconds * 1000.0)])
	tick()


## Called every frame (main.gd): the game runs at the slowest effect still in
## play, or at normal speed when none is.
static func tick() -> void:
	var now := Time.get_ticks_msec()
	var scale := 1.0
	var k := _slows.size() - 1
	while k >= 0:
		if now >= int(_slows[k][1]):
			_slows.remove_at(k)
		else:
			scale = minf(scale, float(_slows[k][0]))
		k -= 1
	if not time_effects:
		scale = 1.0
	if Engine.time_scale != scale:
		Engine.time_scale = scale


static func shake(amount: float) -> void:
	if camera:
		camera.shake(amount)
