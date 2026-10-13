class_name GuardianSwarm
extends EnemySwarm
## A bounded animated cohort, retaining EnemySwarm's canonical combat rows.
## Main drives it in the same order as every other swarm. Visuals use stable IDs.

signal sword_contact(enemy_id: int, swing_id: int, damage_applied: float)
const Presentation := preload("res://scripts/pilot/guardian_presentation_one_hand.gd")
const ACTOR := preload("res://assets/meshy_pilot/guardian_one_hand.glb")
const SWORD := preload("res://assets/meshy_pilot/soulforged_one_hand.glb")
const STATUS_SHADER := preload("res://shaders/guardian.gdshader")
const MAX_LIVE := 3
const MAX_CORPSES := 3
const COMBAT_STEP := 1.0 / 120.0
const WALK_REFERENCE_SPEED := 2.2
## The compact sword's actual blade, excluding the hilt (local +Y).
const BLADE_BASE := Vector3(0.0, 0.25, 0.0)
const BLADE_TIP := Vector3(0.0, 0.962, 0.0)
const BLADE_RADIUS := 0.06
const PLAYER_BOTTOM := 0.45
const PLAYER_TOP := 1.25

@export var sword_damage := 12.0
@export var engage_distance := 1.35
@export var recovery_pause := 0.55
@export var stagger_cooldown := 3.0
var player: Player
var visuals: Dictionary = {} # stable enemy ID -> presentation/timers
var corpses: Array[Node3D] = []
var contact_attempts := 0
var _previous_target := Vector2.ZERO
var _have_target := false

func _ready() -> void:
	capacity = mini(capacity, MAX_LIVE)
	# This cohort is explicitly spawned, never silently admitted by the director.
	spawn_share = 0.0
	contact_dps = 0.0
	creature_model = ""
	specialist_model = ""
	super._ready()
	multimesh.visible_instance_count = 0

func spawn(at: Vector2, hp_mult := 1.0, elite := false) -> bool:
	if count >= capacity or count >= MAX_LIVE or hp_mult <= 0.0:
		return false
	var actor := Presentation.new()
	actor.auto_load = false
	actor.auto_advance = false
	add_child(actor)
	var body := ACTOR.instantiate() as Node3D
	var sword := SWORD.instantiate() as Node3D
	if not actor.setup(body, sword):
		push_error(actor.last_error)
		if body.get_parent() == null: body.free()
		if sword.get_parent() == null: sword.free()
		actor.queue_free()
		return false
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2 # Match the other enemies; exclude the hero-only light.
	for material: ShaderMaterial in actor._material_keepalive:
		material.shader = STATUS_SHADER
	if not super.spawn(at, hp_mult, elite):
		actor.queue_free()
		return false
	var i := count - 1
	actor.name = "Guardian_%d" % ids[i]
	actor.position = Vector3(at.x, 0.0, at.y)
	actor.scale = Vector3.ONE * _scale[i]
	visuals[ids[i]] = {"actor": actor, "cooldown": 0.5, "stagger": 0.0, "hit_swing": -1}
	return true

func step(delta: float, target: Vector2) -> void:
	_flush_dead()
	_frame += 1
	var dt := clampf(delta, 0.0, 0.05) if is_finite(delta) else 0.0
	var steps := maxi(1, ceili(dt / COMBAT_STEP))
	var tick := dt / steps
	var from_target := _previous_target if _have_target else target
	for substep in steps:
		var hero_at := from_target.lerp(target, float(substep + 1) / steps)
		for i in count:
			if hp[i] <= 0.0 or not visuals.has(ids[i]): continue
			var entry: Dictionary = visuals[ids[i]]
			var actor: Node3D = entry.actor
			entry.cooldown = maxf(entry.cooldown - tick, 0.0)
			entry.stagger = maxf(entry.stagger - tick, 0.0)
			# Keep status death ahead of this substep's attack: a dead enemy cannot hit.
			if _afflicted[i] == 1:
				_update_status(i, i * MultiMeshUtil.FLOATS_PER_INSTANCE, tick)
			if hp[i] <= 0.0: continue
			var previous_position := pos[i]
			var to := hero_at - pos[i]
			var moving := false
			var mobile: bool = actor.state in [&"Idle", &"Walk"]
			if mobile:
				if to.length_squared() > 0.0001:
					actor.rotation.y = atan2(to.x, to.y)
				if to.length() > engage_distance * _scale[i]:
					var movement := to.normalized() * minf(move_speed * (0.5 if chill[i] > 0.0 else 1.0) * tick, maxf(to.length() - engage_distance * _scale[i], 0.0))
					var next := Obstacles.resolve_slide(pos[i] + movement, radius * _scale[i], movement)
					moving = next.distance_squared_to(pos[i]) > 0.00000001
					pos[i] = next
			actor.position = Vector3(pos[i].x, 0.0, pos[i].y)
			actor.set_locomotion(moving)
			if mobile and not moving and to.length() <= engage_distance * _scale[i] + 0.1 and entry.cooldown <= 0.0 and is_instance_valid(player) and not player.dead:
				if actor.play_attack() > 0:
					entry.cooldown = Presentation.CLIP_SECONDS[&"Attack"] + recovery_pause
			var was_attack: bool = actor.state == &"Attack"
			var before: float = actor.state_elapsed
			var old_blade := blade_segment(actor)
			var animation_dt := tick
			if actor.state == &"Walk" and tick > 0.0:
				animation_dt *= clampf(previous_position.distance_to(pos[i]) / (WALK_REFERENCE_SPEED * tick), 0.0, 2.0)
			actor.advance_presentation(animation_dt)
			if was_attack and actor.state == &"Attack" and before < Presentation.ATTACK_CLOSE and actor.state_elapsed >= Presentation.ATTACK_OPEN:
				var blade := blade_segment(actor)
				if before < Presentation.ATTACK_OPEN: old_blade = blade
				_try_sword_hit(i, entry, old_blade, blade, hero_at)
			_flash[i] = maxf(_flash[i] - tick * 6.0, 0.0)
			_tint_actor(i, actor)
		for actor: Node3D in corpses:
			actor.advance_presentation(tick)
	for index in range(corpses.size() - 1, -1, -1):
		if corpses[index]._death_done:
			var corpse := corpses[index]
			corpses.remove_at(index)
			corpse.queue_free()
	_previous_target = target
	_have_target = true
	grid.rebuild(pos, count)
	# Retain the existing batched grounding shadow, without a duplicate old body.
	for i in count:
		var o := i * MultiMeshUtil.FLOATS_PER_INSTANCE
		_buffer[o + MultiMeshUtil.OFFSET_X] = pos[i].x
		_buffer[o + MultiMeshUtil.OFFSET_Z] = pos[i].y
	multimesh.visible_instance_count = 0
	_shadow.multimesh.visible_instance_count = count
	if count > 0: _shadow.multimesh.buffer = _buffer

static func blade_segment(actor: Node3D) -> PackedVector3Array:
	actor.skeleton.force_update_all_bone_transforms()
	# Query the evaluated bone directly; BoneAttachment notifications can lag an
	# explicit animation tick until the scene-tree update later in the frame.
	var grip: int = actor.skeleton.find_bone("SwordGrip")
	var pose: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(grip)
	return PackedVector3Array([pose * BLADE_BASE, pose * BLADE_TIP])

static func blade_hits_player(old: PackedVector3Array, blade: PackedVector3Array, at: Vector2, hero_radius := Player.RADIUS) -> bool:
	var bottom := Vector3(at.x, PLAYER_BOTTOM, at.y)
	var top := Vector3(at.x, PLAYER_TOP, at.y)
	# A 120 Hz blade sample plus base/mid/tip sweeps against the upright hero
	# capsule. This is the real blade, not an invisible radial contact attack.
	var segments := [[blade[0], blade[1]], [old[0], blade[0]], [old[1], blade[1]], [(old[0]+old[1])*0.5, (blade[0]+blade[1])*0.5]]
	for segment: Array in segments:
		var nearest := Geometry3D.get_closest_points_between_segments(segment[0], segment[1], bottom, top)
		if nearest[0].distance_squared_to(nearest[1]) <= pow(hero_radius + BLADE_RADIUS, 2): return true
	return false

func _try_sword_hit(i: int, entry: Dictionary, old: PackedVector3Array, blade: PackedVector3Array, hero_at: Vector2) -> void:
	var actor: Node3D = entry.actor
	if not is_instance_valid(player) or player.dead or entry.hit_swing == actor.swing_id: return
	if not blade_hits_player(old, blade, hero_at): return
	# Consume even an invulnerable/dashing contact: one attempt per accepted swing.
	entry.hit_swing = actor.swing_id
	contact_attempts += 1
	var hp_before := player.stats.hp
	player.take_damage(sword_damage * (1.5 if _elite[i] == 1 else 1.0), display_name)
	sword_contact.emit(ids[i], actor.swing_id, maxf(hp_before - player.stats.hp, 0.0))

func damage(i: int, amount: float) -> bool:
	if i < 0 or i >= count or hp[i] <= 0.0: return false
	var killed := super.damage(i, amount)
	if not killed and amount > 0.0 and visuals.has(ids[i]):
		var entry: Dictionary = visuals[ids[i]]
		if entry.stagger <= 0.0 and entry.actor.play_hit(): entry.stagger = stagger_cooldown
	return killed

func _die(i: int) -> void:
	if visuals.has(ids[i]):
		var actor: Node3D = visuals[ids[i]].actor
		visuals.erase(ids[i])
		actor.position = Vector3(pos[i].x, 0.0, pos[i].y)
		actor.play_death()
		for material: ShaderMaterial in actor._material_keepalive:
			material.set_shader_parameter("hit_flash", 0.0)
		if corpses.size() >= MAX_CORPSES:
			var oldest := corpses.pop_front() as Node3D
			oldest.queue_free()
		corpses.append(actor)
	super._die(i)

func despawn_all() -> void:
	for entry: Dictionary in visuals.values(): entry.actor.queue_free()
	visuals.clear()
	for actor: Node3D in corpses: actor.queue_free()
	corpses.clear()
	_have_target = false
	super.despawn_all()

func _tint_actor(i: int, actor: Node3D) -> void:
	var tint := Color.WHITE
	if chill[i] > 0.0: tint = tint.lerp(Color(0.4, 0.75, 1.0), 0.55)
	if shock[i] > 0.0: tint = tint.lerp(Color(1.0, 0.5, 1.0), 0.35)
	if burn[i] > 0.0: tint = tint.lerp(Color(1.0, 0.45, 0.18), 0.3)
	for material: ShaderMaterial in actor._material_keepalive:
		material.set_shader_parameter("status_tint", tint)
		material.set_shader_parameter("hit_flash", _flash[i])
