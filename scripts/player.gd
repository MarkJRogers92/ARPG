class_name Player
extends CharacterBody3D
## The hero: moves with WASD / left stick and auto-attacks. Driven by main.gd
## through tick() and update_weapons() so the frame order stays explicit.

signal leveled_up
signal died

## Radius used for enemy contact damage.
const RADIUS := 0.5

var stats := PlayerStats.new()
## Level-ups earned but not yet spent in the upgrade menu.
var pending_levels := 0
var dead := false

var _swarms: Array[EnemySwarm] = []
var _projectiles: ProjectileSwarm
var _bolt_timer := 0.0
var _aura_timer := 0.0
## Fractional XP left over from the xp_gain multiplier.
var _xp_carry := 0.0

@onready var _visual: Node3D = $Visual
@onready var _aura_visual: MeshInstance3D = $AuraVisual


## Ground-plane position as Vector2(x, z), the space the swarms live in.
var pos2: Vector2:
	get:
		return Vector2(global_position.x, global_position.z)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	stats.xp_to_next = stats.xp_for_level(stats.level)


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
	while stats.xp >= stats.xp_to_next:
		stats.xp -= stats.xp_to_next
		stats.level += 1
		stats.xp_to_next = stats.xp_for_level(stats.level)
		pending_levels += 1
		gained = true
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
	var spread := deg_to_rad(9.0)
	for k in stats.bolt_count:
		var angle := (k - (stats.bolt_count - 1) * 0.5) * spread
		var damage := stats.bolt_damage
		if randf() < stats.crit_chance:
			damage *= stats.crit_mult
		_projectiles.spawn(origin, aim.rotated(angle), stats.bolt_speed,
				damage, stats.bolt_pierce, 1.5)


func _update_aura(delta: float) -> void:
	if stats.aura_level <= 0:
		return
	_aura_visual.visible = true
	_aura_visual.scale = Vector3(stats.aura_radius, 1.0, stats.aura_radius)
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = stats.aura_interval
	var origin := pos2
	for swarm in _swarms:
		swarm.damage_in_radius(origin, stats.aura_radius, stats.aura_damage)
