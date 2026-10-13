extends "res://scripts/pilot/guardian_presentation.gd"
## One-hand-only flat-ground presentation candidate. Original adapter preserved.
## Never translates the model root. Walk exits may correct only leg bones.
const FootContact := preload("res://scripts/pilot/guardian_foot_contact.gd")
const POSE_SOURCE: StringName = &"_guardian_interrupted_pose"
@export var contact_correction_enabled := true
var foot_contact: RefCounted
var _contact_elapsed := 0.0
var _contact_epoch := 0

func setup(actor: Node3D, sword: Node3D = null) -> bool:
	if not super.setup(actor, sword):
		return false
	foot_contact = FootContact.new()
	if not foot_contact.setup(skeleton, model):
		last_error = "Foot contact setup failed: " + str(foot_contact.failures)
		return false
	return true

func _enter_state(next: StringName) -> void:
	if _has_pose and (_blend_active or state in [&"Attack", &"Hit"]):
		_capture_interrupted_source()
	var correct: bool = contact_correction_enabled and foot_contact != null and (state == &"Walk" or foot_contact.active) and next in [&"Idle", &"Attack", &"Hit", &"Death"]
	if correct:
		foot_contact.begin()
		_contact_elapsed = 0.0
		_contact_epoch += 1
	elif foot_contact != null:
		foot_contact.active = false
	super._enter_state(next)
	if correct and state == next:
		foot_contact.apply(0.0)

func advance_presentation(delta: float) -> void:
	var epoch := _contact_epoch
	super.advance_presentation(delta)
	if not is_finite(delta) or delta <= 0.0:
		return
	if foot_contact != null and foot_contact.active:
		if epoch == _contact_epoch:
			_contact_elapsed = minf(_contact_elapsed + delta, TRANSITION_BLEND)
		foot_contact.apply(_contact_elapsed / TRANSITION_BLEND)

func _capture_interrupted_source() -> void:
	# Nested blends reused a clip source and moved the handle84mm instantly.
	# A interrupted fast Attack also must not keep swinging under the Hit blend.
	# Freeze the displayed pose as this actor's source; shared clips stay intact.
	skeleton.force_update_all_bone_transforms()
	var snapshot := Animation.new()
	snapshot.length = TRANSITION_BLEND
	var animation_root := animator.get_node(animator.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var path := NodePath(skeleton_path + ":" + skeleton.get_bone_name(bone))
		var position_track := snapshot.add_track(Animation.TYPE_POSITION_3D)
		snapshot.track_set_path(position_track, path)
		snapshot.position_track_insert_key(position_track, 0.0, skeleton.get_bone_pose_position(bone))
		var rotation_track := snapshot.add_track(Animation.TYPE_ROTATION_3D)
		snapshot.track_set_path(rotation_track, path)
		snapshot.rotation_track_insert_key(rotation_track, 0.0, skeleton.get_bone_pose_rotation(bone))
		var scale_track := snapshot.add_track(Animation.TYPE_SCALE_3D)
		snapshot.track_set_path(scale_track, path)
		snapshot.scale_track_insert_key(scale_track, 0.0, skeleton.get_bone_pose_scale(bone))
	animator.stop(true)
	var library := animator.get_animation_library(&"")
	if library.has_animation(POSE_SOURCE):
		library.remove_animation(POSE_SOURCE)
	library.add_animation(POSE_SOURCE, snapshot)
	animator.play(POSE_SOURCE, 0.0)
	animator.advance(0.0)
	skeleton.force_update_all_bone_transforms()

func _update_transition_lift(delta: float) -> void:
	model.position = _model_rest_position
	_blend_start_lift = 0.0
	if _blend_active:
		_blend_elapsed = minf(_blend_elapsed + delta, TRANSITION_BLEND)
		if _blend_elapsed >= TRANSITION_BLEND:
			_blend_active = false
