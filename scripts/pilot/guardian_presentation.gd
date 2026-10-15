extends Node3D
## Isolated, node-based presentation pilot. Never applies damage or joins a swarm.
## The owner supplies movement/facing and decides when to request each action.

signal state_changed(previous: StringName, current: StringName)
## Exactly one true edge per accepted swing; false closes it, including interrupts.
## These are presentation cues. Gameplay must own hit tests and damage deduplication.
signal attack_window_changed(swing_id: int, active: bool)
signal death_finished

const MODEL_PATH := "res://assets/meshy_pilot/guardian_one_hand.glb"
const WEAPON_PATH := "res://assets/meshy_pilot/soulforged_one_hand.glb"
const CLIP_SECONDS := {&"Idle": 2.0, &"Walk": 31.0 / 30.0, &"Attack": 1.20, &"Hit": 0.40, &"Death": 1.40}
const ATTACK_OPEN := 0.40
const ATTACK_CLOSE := 0.70
const ATTACK_TIMING := {"duration": 1.20, "active_start": ATTACK_OPEN, "active_end": ATTACK_CLOSE, "recovery_end": 1.20}
const HAND_BONE := "RightHand"
const GRIP_BONE := "SwordGrip"
const TRANSITION_BLEND := 0.10
const MAX_TRANSITION_LIFT := 0.075
const KIT_SHADER := preload("res://shaders/kit.gdshader")

@export var auto_load := true
@export var auto_advance := true
## Adjust in the fixture after checking the actual grip; sword blade is local +Y.
@export var grip_position := Vector3.ZERO
@export var grip_rotation_degrees := Vector3.ZERO

var state: StringName = &"Idle"
var last_error := ""
var initialized := false
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var weapon_socket: BoneAttachment3D
var weapon_grip: Node3D
var state_elapsed := 0.0
var swing_id := 0
var window_active := false
var _locomotion: StringName = &"Idle"
var _generation := 0
var _death_done := false
var _has_pose := false
var _model_rest_position := Vector3.ZERO
var _blend_active := false
var _blend_elapsed := 0.0
var _blend_start_lift := 0.0
## Keep overrides alive through child MeshInstance3D destruction. Godot's dummy
## renderer otherwise queries an already-freed material RID during respawn.
var _material_keepalive: Array[ShaderMaterial] = []


func _ready() -> void:
	if auto_load and not initialized:
		load_pilot_assets()


func load_pilot_assets() -> bool:
	if initialized:
		return true
	for path: String in [MODEL_PATH, WEAPON_PATH]:
		if not ResourceLoader.exists(path):
			last_error = "Missing pilot asset: " + path
			return false
	var actor := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var sword := (load(WEAPON_PATH) as PackedScene).instantiate() as Node3D
	if setup(actor, sword):
		return true
	actor.free()
	sword.free()
	return false


## Takes ownership only on success. The supplied nodes must be unparented.
## Validation rejects missing clips/hand bones and executable animation tracks.
func setup(actor: Node3D, sword: Node3D = null) -> bool:
	if initialized or actor == null or actor.get_parent() != null or (sword != null and sword.get_parent() != null):
		last_error = "Setup requires a fresh adapter and unparented asset instances."
		return false
	var bones := actor.find_children("*", "Skeleton3D", true, false)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if bones.size() != 1 or players.size() != 1:
		last_error = "Expected exactly one Skeleton3D and one AnimationPlayer."
		return false
	var candidate_skeleton := bones[0] as Skeleton3D
	var candidate_player := players[0] as AnimationPlayer
	if candidate_skeleton.find_bone(HAND_BONE) < 0:
		last_error = "Missing RightHand weapon bone."
		return false
	for clip: StringName in CLIP_SECONDS:
		if not candidate_player.has_animation(clip):
			last_error = "Missing required clip: " + str(clip)
			return false
		var animation := candidate_player.get_animation(clip)
		if absf(animation.length - float(CLIP_SECONDS[clip])) > 0.047:
			last_error = "Unexpected clip duration: %s = %.4f s" % [clip, animation.length]
			return false
		for track in animation.get_track_count():
			if animation.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				last_error = "Pilot clips must contain only skeletal transform tracks: " + str(clip)
				return false
	model = actor
	_model_rest_position = model.position
	skeleton = candidate_skeleton
	animator = candidate_player
	# Imported libraries may be shared between instances. Never mutate the source.
	for library_name: StringName in animator.get_animation_library_list():
		var local_library := animator.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		animator.remove_animation_library(library_name)
		animator.add_animation_library(library_name, local_library)
	for clip: StringName in CLIP_SECONDS:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in [&"Idle", &"Walk"] else Animation.LOOP_NONE
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.active = true
	animator.stop()
	animator.autoplay = ""
	_material_keepalive.append_array(apply_project_materials(model))
	add_child(model)
	weapon_socket = BoneAttachment3D.new()
	weapon_socket.name = "GuardianRightHandAttachment"
	skeleton.add_child(weapon_socket)
	weapon_socket.bone_name = GRIP_BONE if skeleton.find_bone(GRIP_BONE) >= 0 else HAND_BONE
	weapon_socket.override_pose = false
	weapon_grip = Node3D.new()
	weapon_grip.name = "GripAdjustment"
	weapon_socket.add_child(weapon_grip)
	weapon_grip.position = grip_position
	weapon_grip.rotation_degrees = grip_rotation_degrees
	if sword != null:
		weapon_grip.add_child(sword)
		_material_keepalive.append_array(apply_project_materials(sword))
	initialized = true
	last_error = ""
	_enter_state(&"Idle")
	return true


## Matches the project's vertex-color/rim lighting without applying its custom
## UV2 rigid-joint deformation on top of genuine skinning. UV is not glow data.
static func apply_project_materials(node: Node3D) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	for child: MeshInstance3D in meshes:
		if child.mesh == null:
			continue
		for surface in child.mesh.get_surface_count():
			var imported := child.mesh.surface_get_material(surface) as BaseMaterial3D
			var mat := ShaderMaterial.new()
			mat.shader = KIT_SHADER
			mat.set_shader_parameter("uv_glow", 0.0)
			mat.set_shader_parameter("flat_glow", 0.72 if imported != null and imported.emission_enabled else 0.0)
			mat.set_shader_parameter("rim_strength", 0.45)
			child.set_surface_override_material(surface, mat)
			materials.append(mat)
	return materials


func set_locomotion(moving: bool) -> void:
	if not initialized or state == &"Death":
		return
	_locomotion = &"Walk" if moving else &"Idle"
	if state in [&"Idle", &"Walk"] and state != _locomotion:
		_enter_state(_locomotion)


## Repeated requests while attacking or recoiling are ignored, never restarted.
## A positive ID identifies an accepted swing; -1 means the request was rejected.
func play_attack() -> int:
	if not initialized or state not in [&"Idle", &"Walk"]:
		return -1
	swing_id += 1
	_enter_state(&"Attack")
	return swing_id


func play_hit() -> bool:
	if not initialized or state in [&"Death", &"Hit"]:
		return false
	_enter_state(&"Hit")
	return true


## Terminal. Respawn/pooling must create a fresh presentation; no implicit revive.
func play_death() -> bool:
	if not initialized or state == &"Death":
		return false
	_enter_state(&"Death")
	return true


func _enter_state(next: StringName) -> void:
	var previous := state
	state = next
	state_elapsed = 0.0
	_generation += 1
	var generation := _generation
	_set_window(false)
	if generation != _generation:
		return
	var imported_duration := animator.get_animation(next).length
	# Export rounding is tolerated by validation; authored action windows stay exact.
	var speed := imported_duration / float(CLIP_SECONDS[next])
	# A just-finished one-shot is no longer playing, but still has a pose to blend.
	_blend_active = _has_pose
	_blend_elapsed = 0.0
	_blend_start_lift = clampf(model.position.y - _model_rest_position.y, 0.0, MAX_TRANSITION_LIFT)
	animator.play(next, TRANSITION_BLEND if _blend_active else 0.0, speed)
	animator.advance(0.0)
	_has_pose = true
	_update_transition_lift(0.0)
	state_changed.emit(previous, next)


func _process(delta: float) -> void:
	if auto_advance:
		advance_presentation(delta)


## Use either automatic processing or explicit owner ticks, never both.
## Large deltas still emit each crossed window edge once, in order.
func advance_presentation(delta: float) -> void:
	if not initialized or not is_finite(delta) or delta <= 0.0 or _death_done:
		return
	var generation := _generation
	var before := state_elapsed
	state_elapsed += delta
	animator.advance(delta)
	# Godot evaluates a crossfade using its preceding blend time. A zero-time
	# refresh applies the current weight, including a tick larger than the blend.
	animator.advance(0.0)
	_update_transition_lift(delta)
	if state == &"Attack":
		if before < ATTACK_OPEN and state_elapsed >= ATTACK_OPEN:
			_set_window(true)
			if generation != _generation:
				return
		if before < ATTACK_CLOSE and state_elapsed >= ATTACK_CLOSE:
			_set_window(false)
			if generation != _generation:
				return
	if state in [&"Attack", &"Hit"] and state_elapsed >= float(CLIP_SECONDS[state]):
		_enter_state(_locomotion)
	elif state == &"Death" and state_elapsed >= float(CLIP_SECONDS[&"Death"]):
		state_elapsed = float(CLIP_SECONDS[&"Death"])
		animator.seek(animator.get_animation(&"Death").length, true)
		animator.pause()
		_death_done = true
		death_finished.emit()


## Authored clips are grounded, but interpolated local joint poses can dip.
## Apply a bounded 75 mm presentation-only envelope, never move the actor/body.
func _update_transition_lift(delta: float) -> void:
	if not _blend_active:
		model.position = _model_rest_position
		return
	_blend_elapsed = minf(_blend_elapsed + delta, TRANSITION_BLEND)
	var t := _blend_elapsed / TRANSITION_BLEND
	if t >= 1.0:
		_blend_active = false
		model.position = _model_rest_position
		return
	var envelope := MAX_TRANSITION_LIFT * sin(PI * t) if t > 0.0 else 0.0
	var carry := _blend_start_lift * (1.0 - t)
	model.position = _model_rest_position + Vector3.UP * minf(carry + envelope, MAX_TRANSITION_LIFT)


func _set_window(active: bool) -> void:
	if window_active == active:
		return
	window_active = active
	attack_window_changed.emit(swing_id, active)


func _exit_tree() -> void:
	_set_window(false)
