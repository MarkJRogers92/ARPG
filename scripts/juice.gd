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


static func reset() -> void:
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


static func shake(amount: float) -> void:
	if camera:
		camera.shake(amount)
