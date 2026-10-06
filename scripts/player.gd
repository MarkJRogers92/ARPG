class_name Player
extends CharacterBody3D
## The hero: moves with WASD / left stick and auto-attacks. Driven by main.gd
## through tick() and update_weapons() so the frame order stays explicit.

signal leveled_up
## Emitted once when a level-up (or several at once) earned skill points.
signal skill_points_gained(amount: int)
signal died
## Emitted when a volley of bolts fires (for effects).
signal cast
## Emitted on every Frost Aura damage tick.
signal aura_ticked

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

var _swarms: Array[EnemySwarm] = []
var _projectiles: ProjectileSwarm
var _bolt_timer := 0.0
var _aura_timer := 0.0
## Fractional XP left over from the xp_gain multiplier.
var _xp_carry := 0.0

@onready var _visual: HeroModel = $Visual
@onready var _aura_visual: MeshInstance3D = $AuraVisual
var _aura_pulse := 0.0


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
	if input != Vector2.ZERO:
		# The model faces -Z, so yaw = atan2(-dx, -dz).
		var yaw := atan2(-input.x, -input.y)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-14.0 * delta))
	_visual.set_motion(Vector2(velocity.x, velocity.z).length(), delta)
	stats.hp = minf(stats.max_hp, stats.hp + stats.regen * delta)


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
	# Turn to face the target when standing still, so the cast reads.
	if velocity.is_zero_approx():
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
