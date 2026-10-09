extends SceneTree
## Focused waystop resolver and persisted-result regression.

var checks := 0
var failures := 0
var save_root := "user://campaign_waystops_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var active_shell: CampaignShell
var capture_prefix := ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="):
			capture_prefix = argument.trim_prefix("--capture-prefix=")
	if not capture_prefix.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("--capture-prefix requires a windowed Godot renderer.")
			quit(2)
			return
		if not capture_prefix.is_absolute_path():
			push_error("--capture-prefix must be an absolute path.")
			quit(2)
			return
		var directory_error := DirAccess.make_dir_recursive_absolute(capture_prefix.get_base_dir())
		if directory_error != OK:
			push_error("Could not create capture directory: %s" % error_string(directory_error))
			quit(2)
			return
		root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	CampaignSave.path = save_root + ".save"
	MetaProgress.save_path = save_root + ".meta"
	MetaProgress.disabled = true
	MetaProgress.load_save()
	_test_resolver_table()
	var controller := CampaignController.new()
	root.add_child(controller)
	_check(controller.create("battlemage", 7704101)["ok"], "isolated campaign can be created")
	var start_snapshot := controller.snapshot()
	var unpublished := start_snapshot.duplicate(true)
	unpublished["cleared_nodes"].append(unpublished["graph"]["start"][0])
	CampaignSave.fail_stage = "write"
	_check(not controller._commit(unpublished)["ok"], "failed save does not publish a new clear")
	CampaignSave.fail_stage = ""
	_check(CampaignWaystops.resolve(controller.snapshot())["name"] == "The Last Lantern" and
		CampaignWaystops.resolve(start_snapshot)["name"] == "The Last Lantern",
		"unpublished clear cannot visually advance the saved waystop")
	active_shell = await _test_shell_success_flow(controller)
	controller = active_shell.controller
	_set_biome_stage_three(controller, 0)
	var initial := CampaignWaystops.resolve(controller.snapshot())
	_check(initial["name"] == "Vigil of Ash" and initial["stage"] == 3, "three successful clear records identify the guardian approach")
	var original_state := controller.snapshot()
	var event_snapshot := original_state.duplicate(true)
	event_snapshot["phase"] = "EVENT_PENDING"
	event_snapshot["event"] = {"id": "test_pending", "resolved": false}
	_check(CampaignWaystops.resolve(event_snapshot) == initial and controller.snapshot() == original_state,
		"transient event presentation leaves place identity unchanged and resolver does not mutate state")
	var active_snapshot := original_state.duplicate(true)
	active_snapshot["phase"] = "EXPEDITION_ACTIVE"
	active_snapshot["departure"] = {"node_id": "test"}
	_check(CampaignWaystops.resolve(active_snapshot) == initial, "departure phase does not advance the waystop")

	var boss_node := _finale_node(controller.state)
	var failure_spec := _depart_at_boss(controller, boss_node)
	_check(not failure_spec.is_empty(), "guardian route can be committed")
	if failure_spec.is_empty():
		_finish(controller)
		return
	_check(controller.settle(_result(failure_spec, "failure"))["ok"], "guardian failure settles through controller")
	_check(CampaignWaystops.resolve(controller.snapshot()) == initial, "failure leaves guardian approach unchanged")
	var reloaded := _reload_controller()
	_check(CampaignWaystops.resolve(reloaded.snapshot()) == initial, "failure retains the same shelter after reload")
	_check(reloaded.acknowledge_result()["ok"], "failed result can be acknowledged without moving the shelter")
	var retreat_spec: Dictionary = reloaded.depart()["spec"]
	_check(reloaded.settle(_result(retreat_spec, "retreat"))["ok"], "guardian retreat settles through controller")
	_check(CampaignWaystops.resolve(reloaded.snapshot()) == initial, "retreat leaves guardian approach unchanged")
	var after_retreat := _reload_controller()
	reloaded.free()
	_check(CampaignWaystops.resolve(after_retreat.snapshot()) == initial, "retreat retains the same shelter after reload")
	_check(after_retreat.acknowledge_result()["ok"], "retreat result can be acknowledged")
	var success_spec: Dictionary = after_retreat.depart()["spec"]
	_check(after_retreat.settle(_result(success_spec, "success"))["ok"], "guardian victory settles through controller")
	var next_biome := CampaignWaystops.resolve(after_retreat.snapshot())
	_check(next_biome["name"] == "Whitepass Refuge" and next_biome["biome_index"] == 1 and next_biome["stage"] == 0,
		"guardian victory moves to the next biome's first shelter")
	var after_guardian_reload := _reload_controller()
	after_retreat.free()
	_check(CampaignWaystops.resolve(after_guardian_reload.snapshot()) == next_biome,
		"next-biome arrival identity persists through reload while result is pending")
	_check(after_guardian_reload.acknowledge_result()["ok"], "guardian result can be acknowledged")
	_check(CampaignWaystops.resolve(_reload_controller().snapshot()) == next_biome,
		"acknowledging result does not change the settled shelter")

	_set_biome_stage_three(after_guardian_reload, 2)
	var last_boss := _finale_node(after_guardian_reload.state)
	var final_spec := _depart_at_boss(after_guardian_reload, last_boss)
	_check(after_guardian_reload.settle(_result(final_spec, "success"))["ok"], "last guardian victory settles through controller")
	var dawn := CampaignWaystops.resolve(after_guardian_reload.snapshot())
	_check(dawn["name"] == "Dawn's Rest" and dawn["kind"] == "dawn" and dawn["stage"] == 4,
		"completed campaign resolves to the special dawn waystop")
	var completed_reload := _reload_controller()
	_check(CampaignWaystops.resolve(completed_reload.snapshot()) == dawn,
		"completion identity survives reload")
	completed_reload.free()
	_finish(after_guardian_reload)


func _test_resolver_table() -> void:
	var expected := [
		["The Last Lantern", "Gravediggers' Camp", "Bellwether Crossing", "Vigil of Ash"],
		["Whitepass Refuge", "Sledwright's Rest", "Rimewatch", "Chapel of the Thaw"],
		["Cinderwake Outpost", "Redwake Caravan", "Coalhaven", "Gate of Embers"],
	]
	var ids := {}
	for biome in 3:
		for stage in 4:
			var state := {"biome_index": biome, "cleared_nodes": []}
			for clear in stage:
				state["cleared_nodes"].append("clear_%d" % clear)
			var stop := CampaignWaystops.resolve(state)
			_check(stop["name"] == expected[biome][stage] and stop["stage"] == stage and stop["biome_index"] == biome,
				"biome %d clear count %d resolves to its named waystop" % [biome, stage])
			_check(not ids.has(stop["id"]), "waystop identity is unique across biome stages")
			ids[stop["id"]] = true
	var completed := CampaignWaystops.resolve({"biome_index": 2, "cleared_nodes": [], "completed": true})
	_check(completed["name"] == "Dawn's Rest" and completed["stage"] == 4,
		"completion supersedes the final biome's ordinary waystop")


func _test_shell_success_flow(controller: CampaignController) -> CampaignShell:
	CampaignTown.walk_mode = 1
	controller.free()
	CampaignShell.new_requested = false
	var shell := load("res://scenes/campaign.tscn").instantiate() as CampaignShell
	root.add_child(shell)
	await process_frame
	await process_frame
	var loaded_controller: CampaignController = shell.controller
	var town := shell.get("_view") as CampaignTown
	_check(town != null and town._walk != null and CampaignWaystops.resolve(loaded_controller.snapshot())["name"] == "The Last Lantern",
		"real campaign shell loads the saved opening shelter into a walkable town")
	var route: Dictionary = {}
	for candidate: Dictionary in loaded_controller.available_routes():
		route = candidate
		break
	_check(not route.is_empty(), "opening route fixture has an available mission")
	if route.is_empty():
		return shell
	_check(loaded_controller.choose_route(str(route["id"]))["ok"], "real town commits the selected opening route")
	if loaded_controller.state.get("phase") == "EVENT_PENDING":
		var event: Dictionary = loaded_controller.state.get("event", {})
		var choices: Array = event.get("choices", [])
		var choice_id := "leave"
		var has_leave := false
		for choice: Dictionary in choices:
			if choice.get("id", "") == "leave":
				has_leave = true
				break
		if not has_leave and not choices.is_empty():
			choice_id = str(choices[0].get("id", "gold"))
		_check(loaded_controller.resolve_event(choice_id)["ok"], "road event is resolved through its normal controller call")
	var departure := loaded_controller.depart()
	_check(departure["ok"], "real controller commits departure before Main mounts")
	if not departure["ok"]:
		return shell
	shell.call("_mount_combat", departure["spec"])
	await process_frame
	var main: Node = shell.get("_view")
	var expedition: ExpeditionDirector = main.get("_expedition")
	var spec: Dictionary = departure["spec"]
	expedition.result = {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
		"outcome": "success", "elapsed": float(spec["duration"]),
		"objectives": {"seals": 3, "elite_dead": true, "cache_claimed": true, "boss_dead": true}}
	main.get("_director").elapsed = float(spec["duration"])
	main.call("_finish_expedition_frame")
	main.call("_emit_expedition_result")
	for _frame in 4:
		await process_frame
	town = shell.get("_view") as CampaignTown
	var settled_stop := CampaignWaystops.resolve(loaded_controller.snapshot())
	_check(loaded_controller.state.get("phase") == "RESULT_PENDING" and town != null and town._walk != null and
		settled_stop["name"] == "Gravediggers' Camp" and town._place_header_title.text == str(settled_stop["name"]),
		"saved success mounts the next walkable camp and result panel names that settled destination")
	await _capture_town("result-pending")
	var identity := str(settled_stop["id"])
	var arrived_walk := town._walk
	_check(arrived_walk._waystop_id == identity and is_instance_valid(arrived_walk._destination_world)
		and not arrived_walk._lantern_world.visible,
		"settled success mounts the camp scenery and hides the starting town")
	_check(loaded_controller.acknowledge_result()["ok"] and
		str(CampaignWaystops.resolve(loaded_controller.snapshot())["id"]) == identity,
		"acknowledging the result preserves the settled camp identity")
	_check(town._walk == arrived_walk and arrived_walk._waystop_id == identity,
		"acknowledgment keeps the same physical camp and hero instead of rebuilding the scene")
	await _capture_town("after-acknowledgement")
	var reloaded := _reload_controller()
	_check(str(CampaignWaystops.resolve(reloaded.snapshot())["id"]) == identity,
		"the same camp identity survives a fresh controller reload")
	reloaded.free()
	return shell


func _capture_town(label: String) -> void:
	if capture_prefix.is_empty():
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await create_timer(0.2).timeout
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "arrival evidence uses a native 1280 by 720 viewport")
	var path := "%s-%s.png" % [capture_prefix, label]
	_check(image.save_png(path) == OK, "saved rendered waystop evidence to %s" % path)


func _set_biome_stage_three(controller: CampaignController, biome_index: int) -> void:
	var next := controller.state.duplicate(true)
	next["biome_index"] = biome_index
	next["graph"] = CampaignCatalog.route(next["seed"], biome_index)
	var node_id: String = next["graph"]["start"][0]
	var cleared: Array[String] = []
	for _depth in 3:
		cleared.append(node_id)
		node_id = str(next["graph"]["nodes"][node_id]["next"][0])
	next["cleared_nodes"] = cleared
	next["selected_node"] = ""
	next["successful_nodes"] = {}
	next["completed"] = false
	next["phase"] = "TOWN"
	_check(controller._commit(next)["ok"], "stage-three campaign fixture is safely committed")


func _finale_node(state: Dictionary) -> String:
	for id: String in state["graph"]["nodes"]:
		var node: Dictionary = state["graph"]["nodes"][id]
		if node["contract"] == "finale":
			return id
	return ""


func _depart_at_boss(controller: CampaignController, node_id: String) -> Dictionary:
	if controller.state.get("wager", {}).get("status", "") in ["open", "won"] and not controller.take_wager()["ok"]:
		return {}
	if not controller.state.get("veteran_candidate", {}).is_empty() and not controller.decline_veteran()["ok"]:
		return {}
	var route_response := controller.choose_route(node_id)
	if not route_response["ok"]:
		return {}
	var response := controller.depart()
	return response.get("spec", {}) if response.get("ok", false) else {}


func _result(spec: Dictionary, outcome: String) -> Dictionary:
	var result := {
		"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
		"outcome": outcome, "elapsed": float(spec["duration"]),
		"objectives": {"boss_dead": outcome == "success"}, "kills_by": {}, "loose_shards": 0, "report": {},
	}
	if outcome == "success":
		result["inventory"] = spec["starting_loadout"]["inventory"].duplicate(true)
	return result


func _reload_controller() -> CampaignController:
	var controller := CampaignController.new()
	root.add_child(controller)
	_check(controller.load_campaign()["ok"], "fresh controller reloads persisted campaign")
	return controller


func _finish(controller: CampaignController) -> void:
	if is_instance_valid(controller):
		controller.free()
	if is_instance_valid(active_shell):
		active_shell.free()
	CampaignTown.walk_mode = -1
	CampaignSave.fail_stage = ""
	MetaProgress.disabled = false
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.previous", ".save.rollback", ".meta", ".meta.bak", ".meta.tmp", ".meta.previous", ".meta.rollback"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_root + suffix))
	print("CAMPAIGN WAYSTOPS %s (%d checks, %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
