class_name MeshKit
extends RefCounted
## Builds one low-poly mesh out of primitive parts (boxes, spheres, cylinders,
## cones), each with its own color and glow. Every model in the game (hero,
## enemies, items, props) is made this way, so there are no asset files and a
## whole enemy is a single mesh with a single material: exactly what a
## MultiMesh needs.
##
## Per vertex it stores the color (converted to linear) in COLOR and the glow
## amount in UV.x. The shaders in shaders/ read both (see kit.gdshader).
##
##   var kit := MeshKit.new()
##   kit.box(Vector3(1, 2, 1), MeshKit.at(Vector3(0, 1, 0)), Color.RED)
##   kit.sphere(0.4, MeshKit.at(Vector3(0, 2.3, 0)), Color.WHITE, 1.0)
##   var mesh := kit.commit()

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()

## Faceted (flat-shaded) parts when true. Set per kit or pass per part.
var flat := false
## Caps on round parts' detail, for models drawn thousands of times.
var max_segments := 64
var max_rings := 32


## A transform from position, rotation in degrees (applied Y, X, Z) and scale.
static func at(pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	var basis := Basis.from_euler(rot_deg * (PI / 180.0), EULER_ORDER_YXZ).scaled_local(scale)
	return Transform3D(basis, pos)


func box(size: Vector3, xf: Transform3D, color: Color, glow := 0.0, faceted = null) -> MeshKit:
	var m := BoxMesh.new()
	m.size = size
	return add(m, xf, color, glow, true if faceted == null else faceted)


func sphere(radius: float, xf: Transform3D, color: Color, glow := 0.0, segments := 10, rings := 6, faceted = null) -> MeshKit:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = mini(segments, max_segments)
	m.rings = mini(rings, max_rings)
	return add(m, xf, color, glow, faceted)


## A cylinder or (with one radius 0) a cone, centered on its middle.
func cylinder(top: float, bottom: float, height: float, xf: Transform3D, color: Color, glow := 0.0, segments := 10, faceted = null, caps := true) -> MeshKit:
	var m := CylinderMesh.new()
	m.cap_top = caps and top > 0.0
	m.cap_bottom = caps and bottom > 0.0
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = mini(segments, max_segments)
	m.rings = 0
	return add(m, xf, color, glow, faceted)


func capsule(radius: float, height: float, xf: Transform3D, color: Color, glow := 0.0, segments := 10, faceted = null) -> MeshKit:
	if max_rings <= 3:
		# Low detail: a cylinder with pointed ends is a fraction of the triangles.
		var body := maxf(height - radius * 2.0, 0.0) + radius * 0.6
		var tip := radius * 0.7
		cylinder(radius, radius, body, xf, color, glow, segments, faceted, false)
		cylinder(0.0, radius, tip, xf * MeshKit.at(Vector3(0, (body + tip) * 0.5, 0)), color, glow, segments, faceted, false)
		return cylinder(radius, 0.0, tip, xf * MeshKit.at(Vector3(0, -(body + tip) * 0.5, 0)), color, glow, segments, faceted, false)
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = mini(segments, max_segments)
	m.rings = mini(2, max_rings)
	return add(m, xf, color, glow, faceted)


func torus(inner: float, outer: float, xf: Transform3D, color: Color, glow := 0.0, segments := 14, faceted = null) -> MeshKit:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = mini(segments, max_segments * 2)
	m.ring_segments = 6
	return add(m, xf, color, glow, faceted)


## A flat, upward-facing quad (decals, glows). UV.y carries 0..1 across it.
func quad(size: Vector2, xf: Transform3D, color: Color, glow := 0.0) -> MeshKit:
	var m := PlaneMesh.new()
	m.size = size
	return add(m, xf, color, glow, false)


## Appends any primitive mesh's first surface, transformed and colored.
## Avoid negative scales: they flip the triangle winding.
func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color, glow := 0.0, faceted = null) -> MeshKit:
	var use_flat: bool = flat if faceted == null else faceted
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xf.basis.inverse().transposed()
	var linear := color.srgb_to_linear()
	for k in range(0, idx.size(), 3):
		var ia := idx[k]
		var ib := idx[k + 1]
		var ic := idx[k + 2]
		var pa := xf * verts[ia]
		var pb := xf * verts[ib]
		var pc := xf * verts[ic]
		var na := (normal_basis * normals[ia]).normalized()
		var nb := (normal_basis * normals[ib]).normalized()
		var nc := (normal_basis * normals[ic]).normalized()
		var face := (pb - pa).cross(pc - pa)
		if face.length_squared() < 1e-12:
			continue # degenerate (cone tips, pole rows)
		if use_flat:
			face = face.normalized()
			if face.dot(na + nb + nc) < 0.0:
				face = -face
			na = face
			nb = face
			nc = face
		_verts.append(pa)
		_verts.append(pb)
		_verts.append(pc)
		_normals.append(na)
		_normals.append(nb)
		_normals.append(nc)
		for n in 3:
			_colors.append(linear)
		var has_uv := uvs.size() == verts.size()
		_uvs.append(Vector2(glow, uvs[ia].y if has_uv else 0.0))
		_uvs.append(Vector2(glow, uvs[ib].y if has_uv else 0.0))
		_uvs.append(Vector2(glow, uvs[ic].y if has_uv else 0.0))
	return self


## Moves every vertex added so far (e.g. to put a model's feet at y = 0).
func transform_all(xf: Transform3D) -> MeshKit:
	var normal_basis := xf.basis.inverse().transposed()
	for i in _verts.size():
		_verts[i] = xf * _verts[i]
		_normals[i] = (normal_basis * _normals[i]).normalized()
	return self


func vertex_count() -> int:
	return _verts.size()


## Builds the mesh. `material` goes on its only surface if given.
func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh
