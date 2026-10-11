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
## The "Friendly spell opacity" setting (a saved preference, independent of
## Calm effects and Bold warnings): how strongly the hero's own spell visuals
## (the Frost Aura ring and the hero's bolts) are drawn. 1.0 is the untouched
## look; the floor keeps them visible. Hostile shots, danger warnings and the
## hero/ally markers are never touched.
static var friendly_opacity := 1.0
const FRIENDLY_OPACITY_MIN := 0.15
const FRIENDLY_OPACITY_MAX := 1.0
const FRIENDLY_OPACITY_UNIFORM := "friendly_opacity"
## Friendly-only ShaderMaterials whose shader reads `friendly_opacity`, held as
## WeakRefs so a freed scene (or a discarded material) never leaves a stale
## reference behind (see register_friendly_material / apply_friendly_opacity).
static var _friendly_materials: Array = []
## The dedicated friendly-only bolt material, made on first use (see
## friendly_glow_material). Null after reset().
static var _friendly_glow: ShaderMaterial = null


static func reset() -> void:
	time_effects = false
	_slows.clear()
	Engine.time_scale = 1.0
	fx = null
	numbers = null
	flashes = null
	camera = null
	# Drop the friendly-only material registry and cached bolt material so a
	# freed scene cannot leave a stale material behind (the friendly_opacity
	# setting itself persists; the next scene re-registers and re-applies it).
	_friendly_materials.clear()
	_friendly_glow = null


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


## A safe "Friendly spell opacity": a finite number clamped to
## [FRIENDLY_OPACITY_MIN, FRIENDLY_OPACITY_MAX]. Anything else (NaN, infinity,
## a string, a missing value) falls back to the untouched 1.0, so a corrupt or
## hand-edited save can never push a renderer value out of range.
static func sanitize_friendly_opacity(value) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return FRIENDLY_OPACITY_MAX
	return clampf(float(value), FRIENDLY_OPACITY_MIN, FRIENDLY_OPACITY_MAX)


## Registers a friendly-only material (a ShaderMaterial whose shader reads the
## `friendly_opacity` uniform) to follow the setting. Safe to call repeatedly:
## the same material is only tracked once. The material is applied at once, so
## registration order relative to the setting does not matter.
static func register_friendly_material(material: Material) -> void:
	if material == null:
		return
	for entry: WeakRef in _friendly_materials:
		if entry.get_ref() == material:
			return
	_friendly_materials.append(weakref(material))
	_apply_friendly_material(material)


## Forgets every registered friendly material (used by reset() and tests). The
## `friendly_opacity` value itself is left alone for the next scene to reuse.
static func clear_friendly_materials() -> void:
	_friendly_materials.clear()


## Sets and applies the "Friendly spell opacity" (clamped, finite). Returns the
## value that was actually applied so callers can store/display it.
static func set_friendly_opacity(value) -> float:
	friendly_opacity = sanitize_friendly_opacity(value)
	apply_friendly_opacity()
	return friendly_opacity


## Pushes the current friendly opacity into every registered friendly-only
## material (and drops any whose resource has been freed). Cheap: the registry
## holds only the hero's aura ring and bolt materials. Called automatically by
## set_friendly_opacity; main.apply_settings may also call it after loading a
## saved value.
static func apply_friendly_opacity() -> void:
	var live: Array = []
	for entry: WeakRef in _friendly_materials:
		var material = entry.get_ref()
		if material == null:
			continue
		live.append(entry)
		_apply_friendly_material(material)
	_friendly_materials = live


static func _apply_friendly_material(material) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(FRIENDLY_OPACITY_UNIFORM, friendly_opacity)


## The hero bolts' friendly-only material: a dedicated instance of
## shaders/friendly_glow.gdshader, separate from the shared hostile/hazard glow
## so fading it can never fade a threat. Made once and registered with the
## registry above.
static func friendly_glow_material() -> ShaderMaterial:
	if _friendly_glow == null:
		_friendly_glow = ShaderMaterial.new()
		_friendly_glow.shader = load("res://shaders/friendly_glow.gdshader")
	_friendly_glow.set_shader_parameter(FRIENDLY_OPACITY_UNIFORM, friendly_opacity)
	register_friendly_material(_friendly_glow)
	return _friendly_glow


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
