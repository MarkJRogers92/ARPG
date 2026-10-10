extends SceneTree
## Full-output parity and bounded runtime chunk-cache lifecycle checks.
## --fingerprints prints a deterministic corpus for cross-revision comparison.

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
	MetaProgress.disabled = true
	if "--fingerprints" in OS.get_cmdline_user_args():
		_print_fingerprints()
		quit()
		return
	await _test_cache()
	Elements.reset()
	Obstacles.clear()
	print("DECOR CACHE: %s (%d checks, %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(1 if failures else 0)

func _print_fingerprints() -> void:
	var decor := WorldDecor.new()
	var records := {}
	for realm: String in Realm.ORDER:
		decor.density = Realm.data(realm)["props"].duplicate(true)
		for mode in [false, true]:
			decor.compositions = mode
			for size in [8.0, 12.0, 20.0]:
				decor.chunk_size = size
				for view in [0, 1, 3]:
					decor.view_chunks = view
					for center in [Vector2i.ZERO, Vector2i(-2, -1), Vector2i(21, -17), Vector2i(24, -16)]:
						for with_fixed in [false, true]:
							decor.fixed = [{"kind": "warden_mausoleum", "at": Vector2(27, 33), "yaw": 0.4, "scale": 0.8},
								{"kind": "rock", "at": Vector2(-9, -7), "yaw": 0.7, "scale": 1.4}] if with_fixed else []
							var result := decor.compute(center)
							var key := "%s/%s/%s/%s/%s/%s" % [realm, mode, size, view, center, with_fixed]
							records[key] = var_to_bytes(result).hex_encode().sha256_text()
	decor.free()
	print("DECOR_FINGERPRINTS " + JSON.stringify(records))

func _test_cache() -> void:
	var decor := WorldDecor.new()
	decor.view_chunks = 3
	root.add_child(decor)
	await process_frame
	_test_global_random(decor)
	for realm: String in Realm.ORDER:
		decor.density = Realm.data(realm)["props"].duplicate(true)
		for mode in [false, true]:
			decor.compositions = mode
			var previous := {}
			for center in [Vector2i(21, -17), Vector2i(22, -17), Vector2i(23, -16), Vector2i(-9, 4), Vector2i(21, -17)]:
				decor.follow((Vector2(center) + Vector2.ONE * 0.5) * decor.chunk_size)
				# Config changes at an unchanged center use the existing explicit API.
				decor.rebuild_now()
				_test_applied(decor, center)
				_check(decor._chunk_cache.size() == 49, "%s/%s cache contains only visible chunks" % [realm, mode])
				for chunk: Vector2i in decor._chunk_cache:
					_check(absi(chunk.x - center.x) <= 3 and absi(chunk.y - center.y) <= 3, "cached chunk lies in current view")
					if previous.has(chunk):
						_check(is_same(previous[chunk], decor._chunk_cache[chunk]), "overlapping view retains the same chunk")
				var identities: Dictionary = decor._chunk_cache.duplicate()
				decor.rebuild_now()
				for chunk: Vector2i in identities:
					_check(is_same(identities[chunk], decor._chunk_cache[chunk]), "same-center rebuild reuses immutable chunk")
				_test_applied(decor, center)
				previous = decor._chunk_cache.duplicate()
	# Nested mutation must invalidate; assignment-only change detection is insufficient.
	decor.density["grass"] = 0.0
	decor.fixed.append({"kind": "warden_mausoleum", "at": Vector2(255, -201), "yaw": 0.2, "scale": 1.0})
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	decor.fixed[0]["at"] = Vector2(267, -201)
	decor.fixed[0]["scale"] = 1.3
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	for view in [0, 1, 5, 3]:
		decor.view_chunks = view
		decor.rebuild_now()
		_test_applied(decor, decor._center)
		_check(decor._chunk_cache.size() == (view * 2 + 1) ** 2, "view changes keep cache bounded")
	for size in [8.0, 20.0, 12.0]:
		decor.chunk_size = size
		decor.follow(Vector2(-7, -11))
		decor.rebuild_now()
		_test_applied(decor, decor._center)
	decor.fixed = []
	decor.density = {}
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	_check(decor.groups.is_empty() and decor.ground_marks.is_empty() and decor.emitters.is_empty()
		and Obstacles.circles.is_empty(), "empty density clears cached scenery and collision")
	decor.density = Realm.data("graveyard")["props"].duplicate(true)
	decor.follow(Vector2(258, -198))
	var expected := decor.compute(decor._center)
	# Public frame state must not alias the private cache's nested containers.
	decor.placed["rock"].clear()
	if not decor.groups.is_empty():
		decor.groups[0]["radius"] = -100.0
	if not decor.ground_marks.is_empty():
		decor.ground_marks[0]["style"] = "corrupt"
	if not Obstacles.circles.is_empty():
		Obstacles.circles[0][0] = Vector2.INF
	if not decor.emitters.is_empty():
		decor.emitters[0][0] = Vector3.INF
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	_check(decor.compute(decor._center) == expected, "runtime mutation cannot corrupt pure placement")
	decor.cache_chunks = false
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	_check(decor._chunk_cache.is_empty(), "disabled cache releases stored chunks")
	decor.cache_chunks = true
	decor.rebuild_now()
	_test_applied(decor, decor._center)
	var ref: WeakRef = weakref(decor)
	decor.queue_free()
	await process_frame
	await process_frame
	_check(ref.get_ref() == null, "cache-owning WorldDecor completes deferred teardown")

func _test_applied(decor: WorldDecor, center: Vector2i) -> void:
	var expected := decor.compute(center)
	_check(decor.placed == expected[0], "cached transforms exactly match pure compute")
	_check(Obstacles.circles == expected[2], "cached collision circles/order match pure compute")
	_check(decor.emitters == expected[3] and decor.groups == expected[4] and decor.ground_marks == expected[5],
		"cached glow, group and mark output matches pure compute")
	for kind: String in Models.PROPS:
		var mm: MultiMesh = decor._layers[kind].multimesh
		_check(mm.instance_count == expected[0][kind].size(), "%s instance count matches" % kind)
		# The headless dummy RenderingServer does not implement instance readback.
		# Native execution additionally checks the actual renderer's stored values.
		if DisplayServer.get_name() == "headless":
			continue
		# Compatibility packs components into 16 bits. Compare against an
		# independent renderer round-trip, not the full-precision source colour.
		var color_reference := MultiMesh.new()
		color_reference.transform_format = MultiMesh.TRANSFORM_3D
		color_reference.use_colors = true
		color_reference.mesh = mm.mesh
		color_reference.instance_count = mm.instance_count
		for i in mm.instance_count:
			color_reference.set_instance_color(i, expected[1][kind][i])
		for i in mm.instance_count:
			_check(mm.get_instance_transform(i).is_equal_approx(expected[0][kind][i]), "%s rendered transform matches" % kind)
			_check(mm.get_instance_color(i) == color_reference.get_instance_color(i), "%s rendered colour matches" % kind)


func _test_global_random(decor: WorldDecor) -> void:
	# Per-chunk RNGs must not consume the gameplay/audio global random stream.
	for mode in [false, true]:
		decor.compositions = mode
		for operation in ["compute", "cold", "crossing"]:
			seed(714)
			var expected := randf()
			seed(714)
			match operation:
				"compute": decor.compute(Vector2i(21, -17))
				"cold":
					decor._chunk_cache.clear()
					decor._center = Vector2i(21, -17)
					decor.rebuild_now()
				"crossing": decor.follow(Vector2(270, -198))
			_check(randf() == expected, "%s/%s placement does not draw from global RNG" % [mode, operation])
