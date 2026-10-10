extends SceneTree
## Diagnostic experiment, not production cleanup or a leak-free test.
## Run in a disposable project/profile, with --verbose to list shutdown resources:
## godot --headless --path COPY --verbose -s tools/shutdown_cache_probe.gd -- one none
## Fixtures: empty, one, visuals, main. Cleanup: none, meshes, all, all_refs.
## "one" touches one code-built and one imported prop to exercise both caches.
## Every mode releases fixture nodes and waits for deferred deletion first.

var fixture := "one"
var cleanup := "none"
var _nodes: Array[Node] = []
var _node_refs: Array[WeakRef] = []
var _resource_refs: Array[WeakRef] = []
var failures := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		fixture = args[0]
	if args.size() > 1:
		cleanup = args[1]
	if fixture not in ["empty", "one", "visuals", "main"] or cleanup not in ["none", "meshes", "all", "all_refs"]:
		push_error("Usage: shutdown_cache_probe.gd -- empty|one|visuals|main none|meshes|all|all_refs")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	MetaProgress.disabled = true
	_snapshot("empty")
	match fixture:
		"one": _touch_one()
		"visuals": _touch_visuals()
		"main": _touch_main()
	for frame in 8:
		await process_frame
	_track_cached_resources()
	_snapshot("loaded")
	for node: Node in _nodes:
		node.queue_free()
	_nodes.clear()
	for frame in 4:
		await process_frame
	_snapshot("nodes_released")
	if _alive(_node_refs) != 0:
		_fail("fixture node remains alive after deferred deletion")
	match cleanup:
		"meshes":
			Models._meshes.clear()
			AssetProps._meshes.clear()
		"all", "all_refs":
			Models._meshes.clear()
			AssetProps._meshes.clear()
			ObjectiveProps._meshes.clear()
			SpecialistModels._meshes.clear()
			Models._materials.clear()
	if cleanup == "all_refs":
		Elements.reset()
		Juice.reset()
		Obstacles.clear()
	for frame in 4:
		await process_frame
	_snapshot("after_cleanup")
	if cleanup in ["all", "all_refs"] and _alive(_resource_refs) != 0:
		_fail("tracked visual-cache resource survives node and complete visual-cache cleanup")
	print("SHUTDOWN_PROBE_DONE " + JSON.stringify({"fixture": fixture, "cleanup": cleanup,
		"engine": Engine.get_version_info()["string"], "failures": failures,
		"note": "Process exit diagnostics must be inspected separately; clearing these caches is not a production fix."}))
	quit(1 if failures else 0)

func _touch_one() -> void:
	if Models.prop("rock") == null or AssetProps.mesh("warden_gravestone") == null:
		_fail("minimal-prop resources did not build")

func _touch_visuals() -> void:
	_touch_one()
	if AssetProps.mesh("warden_mausoleum") == null or SpecialistModels.mesh("bone_shieldbearer", 1.8) == null:
		_fail("visual resources did not build")
	var holder := Node3D.new()
	root.add_child(holder)
	_nodes.append(holder)
	_node_refs.append(weakref(holder))
	if ObjectiveProps.attach(holder, "seal_1", Color.CYAN) == null:
		_fail("objective prop did not build")

func _touch_main() -> void:
	seed(7)
	Realm.current = "graveyard"
	Realm.in_title = false
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	if main == null:
		_fail("main scene did not instantiate")
		return
	root.add_child(main)
	_nodes.append(main)
	_node_refs.append(weakref(main))
	# Keep this a short lifecycle diagnostic, not a gameplay/balance bot.
	var director := main.get_node("WaveDirector") as WaveDirector
	director.rate_scale = 0.0
	director.elites_per_minute = 0.0
	director.elites_per_minute_growth = 0.0
	(main.get_node("Events") as EventDirector)._timer = 1.0e9
	(main.get_node("Hazards") as HazardDirector).kind = ""

func _track_cached_resources() -> void:
	var seen := {}
	for cache: Dictionary in _cache_maps():
		for resource: Variant in cache.values():
			if resource is Resource and not seen.has(resource.get_instance_id()):
				seen[resource.get_instance_id()] = true
				_resource_refs.append(weakref(resource))

func _snapshot(stage: String) -> void:
	print("SHUTDOWN_PROBE_JSON " + JSON.stringify({"fixture": fixture, "cleanup": cleanup, "stage": stage,
		"cache_sizes": {"models_meshes": Models._meshes.size(), "asset_meshes": AssetProps._meshes.size(),
			"materials": Models._materials.size(), "objective_meshes": ObjectiveProps._meshes.size(),
			"specialist_meshes": SpecialistModels._meshes.size()},
		"tracked_resources_alive": _alive(_resource_refs), "tracked_nodes_alive": _alive(_node_refs),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT)}))

func _cache_maps() -> Array[Dictionary]:
	return [Models._meshes, AssetProps._meshes, Models._materials, ObjectiveProps._meshes, SpecialistModels._meshes]

static func _alive(refs: Array[WeakRef]) -> int:
	var count := 0
	for ref: WeakRef in refs:
		if ref.get_ref() != null:
			count += 1
	return count

func _fail(message: String) -> void:
	failures += 1
	push_error("FAIL: " + message)
