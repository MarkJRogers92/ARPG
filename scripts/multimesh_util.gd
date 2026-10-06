class_name MultiMeshUtil
extends RefCounted
## Helpers for the "array-simulated swarm drawn by one MultiMesh" pattern used
## by enemies, projectiles, gems and effects.
##
## Each instance is 20 floats: a row-major 3x4 transform (12), a color (4) and
## custom data (4). Swarms keep one flat PackedFloat32Array and only rewrite
## what changed (usually the x and z translation) every frame, then hand the
## whole buffer to the MultiMesh in one call. That is far cheaper than calling
## set_instance_transform() per instance from GDScript.
##
## The color and custom slots are free for each swarm's shader to use; see the
## swarm scripts for what they put there.

const FLOATS_PER_INSTANCE := 20
const OFFSET_X := 3
const OFFSET_Y := 7
const OFFSET_Z := 11
const OFFSET_COLOR := 12
const OFFSET_CUSTOM := 16


## A buffer of `capacity` identity transforms, all at height `y`, white, with
## zeroed custom data.
static func make_buffer(capacity: int, y: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(capacity * FLOATS_PER_INSTANCE)
	for i in capacity:
		var o := i * FLOATS_PER_INSTANCE
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
		buf[o + OFFSET_Y] = y
		for c in 4:
			buf[o + OFFSET_COLOR + c] = 1.0
	return buf


## Writes a yaw rotation (and uniform scale) into instance `o`'s basis so the
## model's -Z faces `dir` (a normalized ground-plane direction).
static func set_facing(buf: PackedFloat32Array, o: int, dir: Vector2, scale := 1.0) -> void:
	# Yaw t with sin t = -dir.x and cos t = -dir.y turns -Z onto (dir.x, 0, dir.y).
	var c := -dir.y * scale
	var s := -dir.x * scale
	buf[o] = c
	buf[o + 2] = s
	buf[o + 5] = scale
	buf[o + 8] = -s
	buf[o + 10] = c


## Copies instance `src`'s whole slice over instance `dst` (for swap-removes).
static func copy_instance(buf: PackedFloat32Array, dst: int, src: int) -> void:
	var o := dst * FLOATS_PER_INSTANCE
	var q := src * FLOATS_PER_INSTANCE
	for k in FLOATS_PER_INSTANCE:
		buf[o + k] = buf[q + k]


## Configures `node` to draw up to `capacity` instances of `mesh` with
## `material` (a shader that reads INSTANCE_CUSTOM / COLOR as it likes).
static func setup(node: MultiMeshInstance3D, mesh: Mesh, capacity: int, material: Material) -> void:
	mesh.surface_set_material(0, material)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Instances live all over the world while the node sits at the origin, so
	# give it a huge bounds or it gets frustum-culled when the origin is offscreen.
	node.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 40, 20000))


## A second MultiMesh child drawing `mesh` for the same instances, fed the same
## buffer (e.g. blob shadows under every enemy). Returns the child.
static func add_layer(node: MultiMeshInstance3D, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var layer := MultiMeshInstance3D.new()
	setup(layer, mesh, node.multimesh.instance_count, material)
	node.add_child(layer)
	return layer
