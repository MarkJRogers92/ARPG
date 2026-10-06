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

enum Aim { AUTO, MOUSE, STICK }

## Radius used for enemy contact damage.
const RADIUS := 0.5

@export_group("Leveling")
## XP needed to go from level L to L+1:
##   xp_base + xp_per_level * L + xp_per_level_squared * L^2
@export var xp_base := 6.0
@export var xp_per_level := 5.0
@export var xp_per_level_squared := 0.45
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


## The model holds the equipped weapon (or the starting staff).
func _show_weapon() -> void:
	if _visual == null:
		return
	var weapon: Item = inventory.equipped.get("weapon")
	if weapon:
		_visual.set_weapon(weapon.base_name, weapon.color())
	else:
		_visual.set_weapon(HeroModel.DEFAULT_WEAPON, HeroModel.DEFAULT_ACCENT)


func xp_for_level(level: int) -> int:
	return int(xp_base + xp_per_level * level + xp_per_level_squared * level * level)


func setup(swarms: Array[EnemySwarm], projectiles: ProjectileSwarm) -> void:
	_swarms = swarms
	_projectiles = projectiles


## Movement and regen. Call before the enemy swarms step.
func tick(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = Vector3(input.x, 0.0, input.y) * stats.move_speed
	move_and_slide()
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


## Auto-attacks. Call after the swarms step so targets are current.
func update_weapons(delta: float) -> void:
	_update_bolt(delta)
	_update_aura(delta)


## Damage before armor; armor is applied here.
func take_damage(amount: float) -> void:
	if dead:
		return
	stats.hp -= amount * stats.damage_taken_factor()
	if stats.hp <= 0.0:
		stats.hp = 0.0
		dead = true
		died.emit()


func add_xp(amount: int) -> void:
	var scaled := amount * stats.xp_gain + _xp_carry
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
	var spread := deg_to_rad(9.0)
	for k in stats.bolt_count:
		var angle := (k - (stats.bolt_count - 1) * 0.5) * spread
		var damage := stats.bolt_damage
		var crit := randf() < stats.crit_chance
		if crit:
			damage *= stats.crit_mult
		_projectiles.spawn(origin, aim.rotated(angle), stats.bolt_speed,
				damage, stats.bolt_pierce, 1.5, crit)


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
	var origin := pos2
	for swarm in _swarms:
		swarm.damage_in_radius(origin, stats.aura_radius, stats.aura_damage)
