class_name MultiMeshUtil
extends RefCounted
## Helpers for the "array-simulated swarm drawn by one MultiMesh" pattern used
## by enemies, projectiles and gems.
##
## Each instance is 12 floats (a row-major 3x4 transform). Swarms keep one flat
## PackedFloat32Array and only rewrite the x and z translation every frame, then
## hand the whole buffer to the MultiMesh in one call. That is far cheaper than
## calling set_instance_transform() per instance from GDScript.

const FLOATS_PER_INSTANCE := 12
const OFFSET_X := 3
const OFFSET_Y := 7
const OFFSET_Z := 11


## A buffer of `capacity` identity transforms, all at height `y`.
static func make_buffer(capacity: int, y: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(capacity * FLOATS_PER_INSTANCE)
	for i in capacity:
		var o := i * FLOATS_PER_INSTANCE
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
		buf[o + OFFSET_Y] = y
	return buf


## Configures `node` to draw up to `capacity` instances of `mesh`.
static func setup(node: MultiMeshInstance3D, mesh: Mesh, capacity: int, color: Color, emissive := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emissive > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emissive
	mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Instances live all over the world while the node sits at the origin, so
	# give it a huge bounds or it gets frustum-culled when the origin is offscreen.
	node.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 40, 20000))
