extends SceneTree
## Bounded headless CPU benchmark; not a GPU, display, or FPS measurement.
## Use a disposable project/profile: godot --headless --path COPY
## -s tools/decor_benchmark.gd -- --revision=<source commit>
## No pass/fail timing threshold, gameplay changes, or test-runner registration.

const WARM_SAMPLES := 3
const SAMPLES := 30
const CENTERS := [Vector2i(21, -17), Vector2i(24, -16), Vector2i(20, -14)]
const MODES := [false, true]
const BIOMES := ["graveyard", "frozen", "ember"]


func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	MetaProgress.disabled = true
	if "--streaming" in OS.get_cmdline_user_args():
		await _run_streaming()
		return
	var decor := WorldDecor.new()
	if decor.get_property_list().any(func(p: Dictionary) -> bool: return p["name"] == "cache_chunks"):
		decor.set("cache_chunks", false)
	root.add_child(decor)
	await process_frame
	var cases := []
	for biome in BIOMES:
		decor.density = Realm.data(biome)["props"].duplicate(true)
		for chunks in [1, 3, 5]:
			decor.view_chunks = chunks
			var samples := {"compute": {false: [], true: []}, "applied_rebuild": {false: [], true: []}}
			var counts := {}
			# Verify determinism per mode/center, outside all timed regions.
			for mode in MODES:
				decor.compositions = mode
				for center in CENTERS:
					var first: Array = decor.compute(center)
					var second: Array = decor.compute(center)
					if first != second:
						push_error("Non-deterministic decor result: %s/%s/%s" % [biome, mode, center])
						quit(1)
						return
					counts[str(mode) + str(center)] = _counts(first)
			# Warm compute and actual applied rebuild for both paths/caches.
			for i in WARM_SAMPLES:
				for mode in MODES:
					decor.compositions = mode
					var center: Vector2i = CENTERS[i % CENTERS.size()]
					decor.compute(center)
					decor._center = center
					decor.rebuild_now()
			# Timed samples alternate mode order, sampling the same center sequence.
			for i in SAMPLES:
				var center: Vector2i = CENTERS[i % CENTERS.size()]
				var order: Array = MODES.duplicate()
				if i % 2 == 1:
					order.reverse()
				for mode in order:
					decor.compositions = mode
					var start := Time.get_ticks_usec()
					decor.compute(center)
					samples["compute"][mode].append(float(Time.get_ticks_usec() - start) / 1000.0)
					# Force the requested center, then time compute+apply including MultiMesh
					# writes and Obstacles.set_circles, all on the main thread.
					decor._center = center
					start = Time.get_ticks_usec()
					decor.rebuild_now()
					samples["applied_rebuild"][mode].append(float(Time.get_ticks_usec() - start) / 1000.0)
			for metric in ["compute", "applied_rebuild"]:
				for mode in MODES:
					cases.append({"biome": biome, "view_chunks": chunks, "chunk_count": (chunks * 2 + 1) ** 2,
						"path": "composed" if mode else "legacy", "metric": metric,
						"samples": _summary(samples[metric][mode]), "counts_by_center": counts})
	decor.queue_free()
	Elements.reset()
	Obstacles.clear()
	await process_frame
	await process_frame
	var revision := "unknown"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--revision="):
			revision = arg.trim_prefix("--revision=")
	print("BENCHMARK_JSON " + JSON.stringify({"label": "WorldDecor headless CPU benchmark", "engine": Engine.get_version_info(),
		"godot_version": Engine.get_version_info().string, "revision": revision,
		"platform": OS.get_name(), "processor": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"centers": CENTERS.map(func(center: Vector2i) -> Array: return [center.x, center.y]),
		"warm_samples_per_mode_case": WARM_SAMPLES, "timed_samples_per_mode_case": SAMPLES,
		"determinism_cases_passed": BIOMES.size() * 3 * MODES.size() * CENTERS.size(),
		"timing_note": "Headless CPU timing only; not GPU, display, or FPS. Runtime chunk reuse disabled here; use --streaming for boundary-crossing cache measurements. Asset startup excluded; applied rebuild includes compute, CPU-side MultiMesh writes and Obstacles on main thread, not GPU completion. Same seeded centers and realm densities; mode order alternates. Legacy means compositions=false in this revision, not a pre-integration checkout. Each applied sample follows an untimed-for-that-metric compute sample. No enemy/gameplay workload or per-frame budget claim.", "cases": cases}))
	quit()


## Paired cross-revision benchmark for actual chunk-boundary movement. A
## repeated-center benchmark alone would overstate a streaming cache's benefit.
func _run_streaming() -> void:
	var decor := WorldDecor.new()
	root.add_child(decor)
	await process_frame
	var supports_cache: bool = decor.get_property_list().any(func(p: Dictionary) -> bool: return p["name"] == "cache_chunks")
	if supports_cache and "--no-cache" in OS.get_cmdline_user_args():
		decor.set("cache_chunks", false)
	var cases := []
	var views: Array = [3] if "--default-view" in OS.get_cmdline_user_args() else [1, 3, 5]
	for biome in BIOMES:
		decor.density = Realm.data(biome)["props"].duplicate(true)
		for view in views:
			decor.view_chunks = view
			for scenario in ["cold", "repeat", "axis", "diagonal", "teleport"]:
				for i in WARM_SAMPLES:
					_stream_sample(decor, scenario, CENTERS[i % CENTERS.size()], supports_cache)
				var values := []
				for i in SAMPLES:
					values.append(_stream_sample(decor, scenario, CENTERS[i % CENTERS.size()], supports_cache))
				var expected := decor.compute(decor._center)
				if decor.placed != expected[0] or decor.emitters != expected[3] or decor.groups != expected[4] \
						or decor.ground_marks != expected[5] or Obstacles.circles != expected[2]:
					push_error("Streaming benchmark runtime output differs from compute")
					quit(1)
					return
				cases.append({"biome": biome, "view_chunks": view, "scenario": scenario,
					"samples": _summary(values), "counts": _counts(expected)})
	var cache_enabled: bool = bool(decor.get("cache_chunks")) if supports_cache else false
	decor.queue_free()
	Elements.reset()
	Obstacles.clear()
	await process_frame
	await process_frame
	print("STREAM_BENCHMARK_JSON " + JSON.stringify({"engine": Engine.get_version_info()["string"],
		"processor": OS.get_processor_name(), "cache_enabled": cache_enabled,
		"timing_note": "Headless main-thread compute+MultiMesh writes+Obstacles; no GPU/FPS budget claim. Same seeded base centers, density and scenarios before/after. Previous view prepared outside timing; only the target rebuild is timed. Cold and teleport include full-view generation; repeat/axis/diagonal measure view overlap.",
		"warm_samples": WARM_SAMPLES, "samples_per_case": SAMPLES, "cases": cases}))
	quit()


func _stream_sample(decor: WorldDecor, scenario: String, base: Vector2i, supports_cache: bool) -> float:
	var chunks: Dictionary = decor.get("_chunk_cache") if supports_cache else {}
	chunks.clear()
	decor._center = base
	decor.rebuild_now()
	if scenario == "cold":
		chunks.clear()
	var offset: Vector2i = {"cold": Vector2i.ZERO, "repeat": Vector2i.ZERO, "axis": Vector2i(1, 0),
		"diagonal": Vector2i(1, 1), "teleport": Vector2i(50, 50)}[scenario]
	decor._center = base + offset
	var start := Time.get_ticks_usec()
	decor.rebuild_now()
	return float(Time.get_ticks_usec() - start) / 1000.0

func _counts(result: Array) -> Dictionary:
	var prop_counts := {}
	var total := 0
	for kind in result[0]:
		if not result[0][kind].is_empty():
			prop_counts[kind] = result[0][kind].size()
			total += result[0][kind].size()
	return {"groups": result[4].size(), "total_props": total, "prop_counts": prop_counts, "solid_circles": result[2].size()}

func _summary(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var n := sorted.size()
	var middle := floori(n * 0.5)
	var median: float = sorted[middle] if n % 2 else (sorted[middle - 1] + sorted[middle]) * 0.5
	return {"sample_count": n, "median_ms": median, "p95_ms": sorted[ceili(n * 0.95) - 1],
		"max_ms": sorted[-1], "raw_ms": values}
