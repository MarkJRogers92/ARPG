extends RefCounted
## Presentation only. Threats use a dark keyline rather than additive glow;
## their meshes, materials and actor markers never participate in collision.

static func warning_material(color: Color, ring := 1.0, strip := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/danger_warning.gdshader")
	mat.set_shader_parameter("color", Juice.warning_color(color))
	mat.set_shader_parameter("ring", ring)
	mat.set_shader_parameter("strip", strip)
	# Filled countdowns must not cover the outer warning's keyline.
	mat.render_priority = 8 if ring > 0.5 or strip else 7
	return mat


static func ally_marker_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/actor_marker.gdshader")
	mat.render_priority = 2
	return mat


static func hostile_shot_mesh() -> ArrayMesh:
	# A solid pointed bead, not a transparent comet like the hero's bolts.
	# The bright face and dark edge stay distinct even against snow or lava.
	var k := MeshKit.new()
	k.sphere(0.28, MeshKit.at(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 1.25)), Color.WHITE, 1.0, 8, 4)
	k.cylinder(0.0, 0.17, 0.4, MeshKit.at(Vector3(0, 0, 0.38), Vector3(-90, 0, 0)), Color.WHITE, 0.0, 6)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/hostile_shot.gdshader")
	return k.commit(mat)
