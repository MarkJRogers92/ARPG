extends SceneTree
## Geometry, sampling, gameplay-preservation and render-lifecycle checks for authored decor.

const SAMPLE_COUNT := 500
const CHUNK := 12.0
const COMPOSITIONS := preload("res://scripts/visual/decor_compositions.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	_test_layout_contract()
	_test_sampling_and_legacy()
	_test_neighbour_clearance()
	await _test_lifecycle()
	print("DECOR COMPOSITIONS: %s (%d checks, %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(1 if failures else 0)

func _approved_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind: String in AssetProps.KINDS:
		if str(AssetProps.data(kind)["path"]).begins_with("06_approved_collection/"):
			out.append(kind)
	return out

func _test_layout_contract() -> void:
	var approved := _approved_kinds()
	var covered := {}
	var anchors: Array[String] = []
	for kind: String in approved:
		if AssetProps.data(kind)["landmark"]:
			anchors.append(kind)
	_check(approved.size() == 24, "approved collection has 24 kinds")
	for kind in anchors:
		for variant in [0, 1]:
			_test_layout_geometry(kind, variant, covered)
	_check(COMPOSITIONS.layout("not_a_real_prop").is_empty(), "unknown kind returns empty layout")
	for kind in approved:
		_check(covered.has(kind), "%s appears as anchor or companion" % kind)

func _test_layout_geometry(kind: String, variant: int, covered: Dictionary) -> void:
	var layout: Dictionary = COMPOSITIONS.layout(kind, variant)
	_check(not layout.is_empty(), "%s has composition" % kind)
	if layout.is_empty():
		return
	_check(float(layout["radius"]) <= 5.2, "%s radius fits chunk budget" % kind)
	var entries: Array = [{"kind": kind, "at": layout["anchor_at"], "yaw": layout["anchor_yaw"], "scale": 1.0}]
	entries.append_array(layout["members"])
	var footprints: Array[float] = []
	for entry: Dictionary in entries:
		var member_kind: String = entry["kind"]
		covered[member_kind] = true
		var fp: float = float(AssetProps.data(member_kind)["footprint"]) * float(entry.get("scale", 1.0))
		footprints.append(fp)
		_check(Vector2(entry["at"]).length() + fp <= float(layout["radius"]) + 0.001,
			"%s %s fits declared radius" % [kind, member_kind])
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var gap := Vector2(entries[i]["at"]).distance_to(entries[j]["at"]) - footprints[i] - footprints[j]
			_check(gap >= 0.1 - 0.001, "%s entries %s/%s footprint gap %.3f" % [kind, entries[i]["kind"], entries[j]["kind"], gap])
	for i in range(1, entries.size()):
		_check(not Landmarks.USES.has(entries[i]["kind"]), "%s companion is not interactive" % entries[i]["kind"])
	for lane: Dictionary in layout["lanes"]:
		_check(float(lane["width"]) >= 1.8, "%s lane width is playable" % kind)
		var a: Vector2 = lane["a"]
		var b: Vector2 = lane["b"]
		for entry: Dictionary in entries:
			var data: Dictionary = AssetProps.data(entry["kind"])
			var xf := _entry_xform(entry)
			for c: Array in data["solid"]:
				var p3: Vector3 = xf * Vector3(c[0], 0.0, c[1])
				var p := Vector2(p3.x, p3.z)
				var dist := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
				_check(dist >= float(c[2]) + float(lane["width"]) * 0.5 + 0.08 - 0.001,
					"%s declared lane clears %s collision" % [kind, entry["kind"]])
		for j in range(1, entries.size()):
			var ep: Vector2 = entries[j]["at"]
			var clearance := ep.distance_to(Geometry2D.get_closest_point_to_segment(ep, a, b))
			_check(clearance >= footprints[j] + float(lane["width"]) * 0.5 + 0.08 - 0.001,
				"%s lane footprint clearance from %s" % [kind, entries[j]["kind"]])
	for pad: Dictionary in layout["pads"]:
		_check(pad["style"] in ["graveyard", "frozen", "ember"], "%s pad style supported" % kind)

func _entry_xform(entry: Dictionary) -> Transform3D:
	var at: Vector2 = entry["at"]
	return Transform3D(Basis(Vector3.UP, float(entry["yaw"])).scaled(Vector3.ONE * float(entry.get("scale", 1.0))), Vector3(at.x, 0.0, at.y))

func _test_sampling_and_legacy() -> void:
	var approved := _approved_kinds()
	var decor := WorldDecor.new()
	decor.view_chunks = 0
	for realm: String in Realm.ORDER:
		decor.density = Realm.data(realm)["props"].duplicate(true)
		var seen := {}
		for n in SAMPLE_COUNT:
			var chunk := Vector2i(101 + n * 17, -307 - n * 29)
			var result: Array = decor.compute(chunk)
			var again: Array = decor.compute(chunk)
			_check(result == again, "%s sample %d deterministic" % [realm, n])
			decor.compositions = false
			var legacy: Array = decor.compute(chunk)
			decor.compositions = true
			for kind: String in Landmarks.USES:
				_check(legacy[0][kind] == result[0][kind] and legacy[1][kind] == result[1][kind],
					"%s sample %d preserves usable %s exactly" % [realm, n, kind])
			_check(result[4].size() <= 1, "%s sample %d has at most one primary group" % [realm, n])
			for kind in approved:
				if AssetProps.data(kind)["realm"] != realm:
					_check(result[0][kind].is_empty(), "%s excluded from %s" % [kind, realm])
				elif not result[0][kind].is_empty():
					seen[kind] = true
			_check(_asset_placements_clear(result[0]), "%s sample %d assets do not overlap" % [realm, n])
			for kind: String in AssetProps.KINDS:
				for xf: Transform3D in result[0][kind]:
					var p := Vector2(xf.origin.x, xf.origin.z)
					var fp: float = float(AssetProps.data(kind)["footprint"]) * xf.basis.get_scale().x
					var in_group := false
					for group: Dictionary in result[4]:
						if p.distance_to(group["at"]) <= float(group["radius"]) + 0.001:
							in_group = true
							break
					var origin := Vector2(chunk) * CHUNK
					var local := p - origin
					# Legacy footprints already include authored random scale allowance.
					var inset: float = fp if in_group else float(AssetProps.data(kind)["footprint"])
					_check(local.x >= inset - 0.001 and local.y >= inset - 0.001 and local.x <= CHUNK - inset + 0.001 and local.y <= CHUNK - inset + 0.001,
						"%s %s respects chunk inset" % [realm, kind])
					if kind in approved and not AssetProps.data(kind)["landmark"]:
						_check(in_group, "%s approved small prop belongs to a place" % kind)
			Obstacles.set_circles(result[2], Rect2(Vector2(chunk) * CHUNK, Vector2.ONE * CHUNK))
			for group: Dictionary in result[4]:
				var group_local: Vector2 = Vector2(group["at"]) - Vector2(chunk) * CHUNK
				_check(group_local.distance_to(Vector2.ONE * 6.0) <= 0.51,
					"%s group anchor remains near chunk centre" % realm)
				_check(float(group["radius"]) <= 5.2, "%s group radius budget" % realm)
				_check(group_local.x - float(group["radius"]) >= -0.001 and group_local.y - float(group["radius"]) >= -0.001
					and group_local.x + float(group["radius"]) <= CHUNK + 0.001 and group_local.y + float(group["radius"]) <= CHUNK + 0.001,
					"%s declared group circle stays inside chunk" % realm)
				_test_world_lane(group, result[2], realm)
		for kind in approved:
			if AssetProps.data(kind)["realm"] == realm:
				_check(seen.has(kind), "%s appears in distant %s samples" % [kind, realm])
		# All pre-existing interactive placements and shades are byte-for-byte equivalent.
		var chunk := Vector2i(37, -43)
		decor.compositions = false
		var old: Array = decor.compute(chunk)
		decor.compositions = true
		var new: Array = decor.compute(chunk)
		for kind: String in Landmarks.USES:
			_check(old[0][kind] == new[0][kind], "%s interaction transforms unchanged in %s" % [kind, realm])
			_check(old[1][kind] == new[1][kind], "%s interaction colours unchanged in %s" % [kind, realm])
		_check(old[0].keys().size() == new[0].keys().size(), "%s output kind inventory retained" % realm)
	decor.free()
	Obstacles.clear()

func _asset_placements_clear(xforms: Dictionary) -> bool:
	var circles: Array = []
	for kind: String in AssetProps.KINDS:
		for xf: Transform3D in xforms[kind]:
			var p := Vector2(xf.origin.x, xf.origin.z)
			var radius: float = float(AssetProps.data(kind)["footprint"]) * xf.basis.get_scale().x
			for old: Array in circles:
				if p.distance_to(old[0]) < radius + float(old[1]) - 0.001:
					return false
			circles.append([p, radius])
	return true

func _test_neighbour_clearance() -> void:
	var decor := WorldDecor.new()
	decor.view_chunks = 1
	for realm: String in Realm.ORDER:
		decor.density = Realm.data(realm)["props"]
		var groups_seen := 0
		for n in 24:
			var chunk := Vector2i(53 + n * 11, -71 - n * 13)
			var result: Array = decor.compute(chunk)
			_check(_asset_placements_clear(result[0]), "%s neighbour chunks keep imported footprints disjoint" % realm)
			Obstacles.set_circles(result[2], Rect2(Vector2(chunk - Vector2i.ONE) * CHUNK, Vector2.ONE * CHUNK * 3.0))
			for group: Dictionary in result[4]:
				groups_seen += 1
				_test_world_lane(group, result[2], realm + " neighbours")
		_check(groups_seen > 0, "%s neighbour sampling actually produces groups" % realm)
	decor.free()
	Obstacles.clear()

func _test_world_lane(group: Dictionary, solids: Array, realm: String) -> void:
	for lane: Dictionary in group["lanes"]:
		var a: Vector2 = lane["a"]
		var b: Vector2 = lane["b"]
		var width: float = lane["width"]
		for circle: Array in solids:
			var center: Vector2 = circle[0]
			var dist := center.distance_to(Geometry2D.get_closest_point_to_segment(center, a, b))
			_check(dist >= float(circle[1]) + width * 0.5 + 0.08 - 0.001, "%s world lane avoids collision circles" % realm)
		for body_radius in [0.5, 1.0]:
			if width * 0.5 < body_radius + 0.08:
				continue
			for step in 13:
				var p := a.lerp(b, float(step) / 12.0)
				_check(not Obstacles.blocked(p, body_radius), "%s lane admits radius %.1f along entire approach" % [realm, body_radius])
		var p := a
		for step in 60:
			var next := a.lerp(b, float(step + 1) / 60.0)
			p = Player.slide_scenery(p, next)
			_check(p.distance_to(next) < 0.001, "%s player traverses authored approach without detouring" % realm)

func _test_lifecycle() -> void:
	print("authored decor frame lifecycle")
	var decor := WorldDecor.new()
	decor.view_chunks = 0
	decor.density = {"warden_mausoleum": 1.0, "warden_gravestone": 0.1, "warden_soul_lantern": 0.1,
		"warden_soul_brazier": 0.1, "warden_reliquary_chest": 0.1, "warden_broken_obelisk": 0.1}
	root.add_child(decor)
	decor.follow(Vector2(30, 30))
	await process_frame
	await process_frame
	_check(not decor.groups.is_empty(), "graveyard density builds authored group")
	_check(not decor.ground_marks.is_empty(), "group builds ground marks")
	if not decor.groups.is_empty():
		for mark: Dictionary in decor.ground_marks:
			var mm: MultiMesh = decor._ground_layers[mark["style"]].multimesh
			var count := 0
			for candidate: Dictionary in decor.ground_marks:
				if candidate["style"] == mark["style"]:
					count += 1
			_check(mm.instance_count == count, "%s ground MultiMesh count matches marks" % mark["style"])
	decor.density = Realm.data("frozen")["props"]
	decor.follow(Vector2(42, 30))
	await process_frame
	await process_frame
	_check(decor._ground_layers["graveyard"].multimesh.instance_count == 0, "graveyard marks clear on biome switch")
	decor.density = Realm.data("ember")["props"]
	decor.follow(Vector2(54, 30))
	await process_frame
	await process_frame
	_check(decor._ground_layers["frozen"].multimesh.instance_count == 0, "frozen marks clear on biome switch")
	decor.density = {}
	decor.rebuild_now()
	await process_frame
	await process_frame
	_check(decor.groups.is_empty() and decor.ground_marks.is_empty(), "empty density clears groups and marks")
	_check(decor.emitters.is_empty() and Obstacles.circles.is_empty(), "empty density clears emitters and obstacles")
	for style: String in decor._ground_layers:
		_check(decor._ground_layers[style].multimesh.instance_count == 0, "%s ground MultiMesh clears" % style)
	decor.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(decor), "WorldDecor deferred cleanup completes")
	Obstacles.clear()
