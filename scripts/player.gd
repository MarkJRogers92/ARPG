class_name Player
extends CharacterBody3D
## The hero: moves with WASD / left stick and attacks on its own. Driven by
## main.gd through tick() and update_weapons() so the frame order stays explicit.
##
## Aiming is twin-stick style: the hero faces and shoots toward the mouse
## cursor (or the right stick), separately from where it walks. Before the
## mouse moves, while the right stick is released after using it, and after
## pressing T, it auto-aims at the nearest enemy instead.

signal leveled_up
## Emitted once when a level-up (or several at once) earned skill points.
signal skill_points_gained(amount: int)
signal died
## Emitted when a volley of bolts fires (for effects).
signal cast
## Emitted on every Frost Aura damage tick.
signal aura_ticked
## Emitted when T switches mouse aiming on or off.
signal mouse_aim_toggled(enabled: bool)
signal dashed

## Dash: a short burst of speed during which nothing can hurt the hero.
const DASH_TIME := 0.2
const DASH_SPEED := 3.4 # times move speed

enum Aim { AUTO, MOUSE, STICK }

## Radius used for enemy contact damage.
const RADIUS := 0.5

@export_group("Leveling")
## XP needed to go from level L to L+1:
##   xp_base + xp_per_level * L + xp_per_level_squared * L^2
##     + xp_late_cubed * max(0, L - xp_late_from)^3
## The last term leaves the early levels alone and slows the late ones.
@export var xp_base := 6.0
@export var xp_per_level := 5.0
@export var xp_per_level_squared := 0.45
@export var xp_late_cubed := 0.06
@export var xp_late_from := 30
## XP from kills is worth this much (main.gd lowers it as the night goes on:
## late-game kill rates are hundreds a second).
var xp_scale := 1.0
## One skill point is earned every this many levels (0 turns skill points off).
@export var skill_point_every_levels := 2

var stats := PlayerStats.new()
var inventory: Inventory
var skills: SkillTree
## Level-ups earned but not yet spent in the upgrade menu.
var pending_levels := 0
var dead := false
## How bolts are aimed right now (see the class notes).
var aim_mode := Aim.AUTO
## When false (T), the mouse doesn't take over aiming.
var mouse_aim_enabled := true
## Ground-plane direction the hero aims in MOUSE / STICK mode.
var aim_dir := Vector2(0, -1)

var _swarms: Array[EnemySwarm] = []
var _projectiles: ProjectileSwarm
var _bolt_timer := 0.0
var _aura_timer := 0.0
## Fractional XP left over from the xp_gain multiplier.
var _xp_carry := 0.0

@onready var _visual: HeroModel = $Visual
@onready var _aura_visual: MeshInstance3D = $AuraVisual
var _aura_pulse := 0.0
var _reticle: MeshInstance3D
var _dash_time := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector2.ZERO
var _lightning: ChainLightning
var _blades: SpiritBlades
var _nova: ArcaneNova
var _obol: Obol
var _scythe: ReapingScythe
## The Funeral Bell (main.gd feeds it kills).
var bell: FuneralBell
var _volleys := 0
## The hero's own statuses (from witch bolts, fireballs and hazards).
var chilled := 0.0
var burning := 0.0
const CHILL_SLOW := 0.6
const BURN_DPS := 5.0
var _storm_tick := 0.0


## Ground-plane position as Vector2(x, z), the space the swarms live in.
var pos2: Vector2:
	get:
		return Vector2(global_position.x, global_position.z)


func _init() -> void:
	inventory = Inventory.new(stats)
	skills = SkillTree.new(stats)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	stats.xp_to_next = xp_for_level(stats.level)
	inventory.changed.connect(_show_weapon)

	# A ring on the ground under the cursor while aiming with the mouse.
	_reticle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.3, 1.3)
	_reticle.mesh = plane
	_reticle.material_override = Models.material("ground_glow", {
		"color": Color(1.0, 0.85, 0.5, 0.7), "ring": 1.0, "pulse_speed": 6.0}, "reticle")
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.top_level = true
	_reticle.visible = false
	add_child(_reticle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_aim_enabled:
		aim_mode = Aim.MOUSE
	elif event.is_action_pressed("toggle_aim"):
		mouse_aim_enabled = not mouse_aim_enabled
		if not mouse_aim_enabled and aim_mode == Aim.MOUSE:
			aim_mode = Aim.AUTO
		mouse_aim_toggled.emit(mouse_aim_enabled)


var _start_weapon := HeroModel.DEFAULT_WEAPON
var _start_accent := HeroModel.DEFAULT_ACCENT


## The class's colors and the weapon it holds before finding one.
func set_class_look(look: Dictionary, weapon: String, accent: Color) -> void:
	_start_weapon = weapon
	_start_accent = accent
	if _visual:
		_visual.set_body(look)
	_show_weapon()


## The model holds the equipped weapon (or the class's starting one).
func _show_weapon() -> void:
	if _visual == null:
		return
	var weapon: Item = inventory.equipped.get("weapon")
	if weapon:
		_visual.set_weapon(weapon.base_name, weapon.color())
	else:
		_visual.set_weapon(_start_weapon, _start_accent)


func xp_for_level(level: int) -> int:
	var late := maxi(level - xp_late_from, 0)
	return int(xp_base + xp_per_level * level + xp_per_level_squared * level * level + xp_late_cubed * late * late * late)


func setup(swarms: Array[EnemySwarm], projectiles: ProjectileSwarm) -> void:
	_swarms = swarms
	_projectiles = projectiles
	_lightning = ChainLightning.new()
	_blades = SpiritBlades.new()
	_nova = ArcaneNova.new()
	_obol = Obol.new()
	_scythe = ReapingScythe.new()
	bell = FuneralBell.new()
	for ability in [_lightning, _blades, _nova, _obol, _scythe, bell]:
		add_child(ability)
		ability.setup(self, swarms)


func is_dashing() -> bool:
	return _dash_time > 0.0


## 0 = dash ready, 1 = just used.
func dash_cooldown_fraction() -> float:
	return clampf(_dash_cooldown / stats.dash_cooldown, 0.0, 1.0)


## Movement and regen. Call before the enemy swarms step.
func tick(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and not dead:
		# Dash where you're walking, or where you're looking when standing still.
		_dash_dir = input.normalized() if input != Vector2.ZERO else _facing()
		_dash_time = DASH_TIME
		_dash_cooldown = stats.dash_cooldown
		dashed.emit()
		Sound.play("dash")
		if stats.powers.has("blinkfire") and _nova:
			_nova.fire()
	chilled = maxf(chilled - delta, 0.0)
	if burning > 0.0:
		burning = maxf(burning - delta, 0.0)
		take_damage(BURN_DPS * delta)
		if Engine.get_process_frames() % 6 == 0:
			Juice.burst(pos2, 1.0, Elements.COLORS[Elements.FIRE], 1, 1.0, 0.35, 0.4, 2.0)
	if chilled > 0.0 and Engine.get_process_frames() % 8 == 0:
		Juice.burst(pos2, 1.2, Elements.COLORS[Elements.FROST], 1, 1.5, 0.3, 0.5, 0.5)
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = Vector3(_dash_dir.x, 0.0, _dash_dir.y) * stats.move_speed * DASH_SPEED
		Juice.burst(pos2, 1.2, Color(0.5, 0.8, 1.0), 2, 1.0, 0.5, 0.35, 0.5)
		_storm_tick -= delta
		if stats.powers.has("stormstride") and _storm_tick <= 0.0:
			# Stormstride: the dash path crackles with lightning.
			_storm_tick = 0.05
			Elements.source = "Stormstride"
			Elements.hit_area(pos2, 1.8, stats.lightning_damage * 0.5, Elements.LIGHTNING)
			Juice.burst(pos2, 0.8, Elements.COLORS[Elements.LIGHTNING], 3, 3.0, 0.4, 0.4, 2.0)
	else:
		velocity = Vector3(input.x, 0.0, input.y) * stats.move_speed * (CHILL_SLOW if chilled > 0.0 else 1.0)
	var before := pos2
	move_and_slide()
	# Solid scenery: slide around it. The move is walked in short steps, so a
	# fast dash (or a long frame) can't pass through a thin obstacle.
	var q := slide_scenery(before, pos2)
	if q != pos2:
		global_position = Vector3(q.x, global_position.y, q.y)
	_update_aim()
	# Face the aim when aiming by hand, otherwise the way you walk.
	var look := aim_dir if aim_mode != Aim.AUTO else input
	if look != Vector2.ZERO:
		# The model faces -Z, so yaw = atan2(-dx, -dz).
		var yaw := atan2(-look.x, -look.y)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-18.0 * delta))
	_visual.set_motion(Vector2(velocity.x, velocity.z), delta)
	stats.hp = minf(stats.max_hp, stats.hp + stats.regen * delta)


func _update_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick != Vector2.ZERO:
		aim_mode = Aim.STICK
		aim_dir = stick.normalized()
	elif aim_mode == Aim.STICK:
		aim_mode = Aim.AUTO # stick released: back to auto-aim
	_reticle.visible = aim_mode == Aim.MOUSE
	if aim_mode != Aim.MOUSE:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Where the cursor's ray meets the ground (y = 0).
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if dir.y > -0.01:
		return
	var hit := from + dir * (-from.y / dir.y)
	_reticle.global_position = Vector3(hit.x, 0.06, hit.z)
	var to := Vector2(hit.x, hit.z) - pos2
	if to.length_squared() > 0.04:
		aim_dir = to.normalized()


## Frost slows the hero for a moment; fire burns for a few seconds.
func afflict(element: int) -> void:
	match element:
		Elements.FROST:
			chilled = maxf(chilled, 0.8)
		Elements.FIRE:
			burning = maxf(burning, 1.5)


## Where a move from `from` to `to` really ends with solid scenery in the way.
static func slide_scenery(from: Vector2, to: Vector2) -> Vector2:
	var moved := to - from
	if Obstacles.width == 0 or not (Obstacles.near(from) or Obstacles.near(to) or Obstacles.near(from + moved * 0.5)):
		return to
	var steps := maxi(1, ceili(moved.length() / 0.3))
	var q := from
	for k in steps:
		q = Obstacles.resolve_slide(q + moved / steps, RADIUS, moved / steps)
	return q


## Set by main once the night is won: nothing can kill the hero during dawn.
var invulnerable := false


func heal(amount: float) -> void:
	if not dead:
		stats.hp = minf(stats.max_hp, stats.hp + amount)


## The ground direction the model is facing.
func _facing() -> Vector2:
	var yaw := _visual.rotation.y if _visual else 0.0
	return Vector2(-sin(yaw), -cos(yaw))


## Auto-attacks. Call after the swarms step so targets are current.
func update_weapons(delta: float) -> void:
	_update_bolt(delta)
	_update_aura(delta)
	if _lightning:
		_lightning.update(delta)
		_blades.update(delta)
		_nova.update(delta)
		_obol.update(delta)
		_scythe.update(delta)


## Damage before armor; armor is applied here.
func take_damage(amount: float) -> void:
	if dead or invulnerable or is_dashing():
		return
	stats.hp -= amount * stats.damage_taken_factor()
	if stats.hp <= 0.0:
		stats.hp = 0.0
		dead = true
		died.emit()


func add_xp(amount: int) -> void:
	var scaled := amount * stats.xp_gain * xp_scale + _xp_carry
	var whole := floori(scaled)
	_xp_carry = scaled - whole
	stats.xp += whole
	var gained := false
	var points := 0
	while stats.xp >= stats.xp_to_next:
		stats.xp -= stats.xp_to_next
		stats.level += 1
		stats.xp_to_next = xp_for_level(stats.level)
		pending_levels += 1
		gained = true
		if skill_point_every_levels > 0 and stats.level % skill_point_every_levels == 0:
			points += 1
	if points > 0:
		skills.add_points(points)
		skill_points_gained.emit(points)
	if gained:
		leveled_up.emit()


func _update_bolt(delta: float) -> void:
	_bolt_timer -= delta
	if _bolt_timer > 0.0:
		return

	var origin := pos2
	var best_d2 := stats.bolt_range * stats.bolt_range
	var target := Vector2.ZERO
	var found := false
	for swarm in _swarms:
		var i := swarm.nearest(origin, stats.bolt_range)
		if i >= 0:
			var d2 := origin.distance_squared_to(swarm.pos[i])
			if d2 < best_d2:
				best_d2 = d2
				target = swarm.pos[i]
				found = true
	if not found:
		_bolt_timer = 0.1 # nothing in range: don't rescan every frame
		return

	_bolt_timer = stats.bolt_cooldown
	var aim := (target - origin).normalized()
	if aim_mode != Aim.AUTO:
		aim = aim_dir # aimed by hand; an enemy in range just means "fire"
	elif velocity.is_zero_approx():
		# Turn to face the target when standing still, so the cast reads.
		_visual.rotation.y = atan2(-aim.x, -aim.y)
	_visual.cast()
	cast.emit()
	Sound.play("bolt_cast")
	_volleys += 1
	if stats.powers.has("heart_of_storms") and _volleys % 6 == 0 and _nova:
		_nova.fire()
	var spread := deg_to_rad(9.0)
	for k in stats.bolt_count:
		var angle := (k - (stats.bolt_count - 1) * 0.5) * spread
		var damage := stats.bolt_damage
		var crit := randf() < stats.crit_chance
		if crit:
			damage *= stats.crit_mult
		_projectiles.spawn(origin, aim.rotated(angle), stats.bolt_speed,
				damage, stats.bolt_pierce, 1.5, crit, _bolt_element())


## Which element the next bolt carries: lightning with a Stormcaller weapon,
## otherwise fire or frost by the ignite / chill chances.
func _bolt_element() -> int:
	if stats.powers.has("stormcaller"):
		return Elements.LIGHTNING
	if randf() < stats.ignite_chance:
		return Elements.FIRE
	if randf() < stats.chill_chance:
		return Elements.FROST
	return Elements.NONE


func _update_aura(delta: float) -> void:
	if stats.aura_level <= 0:
		return
	_aura_visual.visible = true
	_aura_visual.scale = Vector3(stats.aura_radius, 1.0, stats.aura_radius)
	_aura_pulse = maxf(_aura_pulse - delta * 4.0, 0.0)
	(_aura_visual.material_override as ShaderMaterial).set_shader_parameter("pulse", _aura_pulse)
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = stats.aura_interval
	_aura_pulse = 1.0
	aura_ticked.emit()
	# Frost Aura chills what it touches (see Elements).
	Elements.source = "Frost Aura"
	Elements.hit_area(pos2, stats.aura_radius, stats.aura_damage, Elements.FROST)
