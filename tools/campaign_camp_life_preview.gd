extends SceneTree
## Standalone real-shell showcase. It creates a dedicated disposable campaign
## save with one valid first success and never reads/writes campaign.save or
## meta.save. Meta progression delivery is disabled for this showcase process.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var verify_only := "--verify" in OS.get_cmdline_user_args()
	MetaProgress.disabled = true
	CampaignTown.walk_mode = 1
	CampaignSave.path = "user://campaign-camp-life-showcase-%d.save" % Time.get_ticks_usec()
	var seed_controller := CampaignController.new()
	root.add_child(seed_controller)
	var created := seed_controller.create("battlemage", 74101)
	if not bool(created.get("ok", false)):
		_fail("The showcase campaign could not be created: %s" % str(created.get("error", "unknown error")))
		return
	var routes: Array = seed_controller.available_routes()
	if routes.is_empty():
		_fail("The showcase campaign has no opening route.")
		return
	var node_id := str(routes[0].get("id", ""))
	var choice := seed_controller.choose_route(node_id)
	if not bool(choice.get("ok", false)):
		_fail("The showcase route could not be chosen: %s" % str(choice.get("error", "unknown error")))
		return
	if seed_controller.state.get("phase", "") == "EVENT_PENDING":
		var choices: Array = seed_controller.state.get("event", {}).get("choices", [])
		if choices.is_empty():
			_fail("The showcase opening event has no valid choice.")
			return
		var resolved := seed_controller.resolve_event(str(choices[0].get("id", "")))
		if not bool(resolved.get("ok", false)):
			_fail("The showcase event could not be resolved: %s" % str(resolved.get("error", "unknown error")))
			return
	var departure := seed_controller.depart()
	if not bool(departure.get("ok", false)):
		_fail("The showcase departure could not be prepared: %s" % str(departure.get("error", "unknown error")))
		return
	var spec: Dictionary = departure["spec"]
	var objectives := {}
	match str(spec.get("contract_id", "")):
		"breach": objectives["seals"] = 3
		"elite_hunt": objectives["elite_dead"] = true
		"finale": objectives["boss_dead"] = true
	var report := {
		"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
		"outcome": "success", "elapsed": float(spec["duration"]), "objectives": objectives,
		"kills_by": {}, "loose_shards": 0,
		"inventory": spec["starting_loadout"]["inventory"].duplicate(true), "report": {},
	}
	var settled := seed_controller.settle(report)
	if not bool(settled.get("ok", false)):
		_fail("The showcase first success could not be settled: %s" % str(settled.get("error", "unknown error")))
		return
	var acknowledged := seed_controller.acknowledge_result()
	if not bool(acknowledged.get("ok", false)):
		_fail("The showcase result could not be acknowledged: %s" % str(acknowledged.get("error", "unknown error")))
		return
	seed_controller.free()
	print("CAMP_LIFE_SHOWCASE_SAVE: ", CampaignSave.path)
	print("CAMP_LIFE_SHOWCASE_META_PROGRESS_DISABLED: true")
	CampaignShell.new_requested = false
	var shell := CampaignShell.new()
	root.add_child(shell)
	current_scene = shell
	if verify_only:
		await process_frame
		var town := shell._view as CampaignTown
		var valid_town := is_instance_valid(town) and is_instance_valid(town._walk) \
			and str(town._walk._waystop.get("name", "")) == "Gravediggers' Camp" \
			and town._walk._labels.size() == CampaignTown.SERVICES.size()
		if not valid_town:
			_fail("The real campaign shell did not mount Gravediggers' Camp.")
			return
		print("PASS: real shell loaded the isolated first-success campaign and all walk-town services")
		var old_town := town
		var old_controller := shell.controller
		var old_sound := shell._campaign_sound
		var save_and_leave := _find_button(town, "Save & Leave")
		if not is_instance_valid(save_and_leave):
			_fail("The real town did not build its Save & Leave button.")
			return
		save_and_leave.pressed.emit()
		for _frame in 24:
			await process_frame
			if not is_instance_valid(shell):
				break
		var returned_to_title := current_scene != shell and is_instance_valid(current_scene) \
			and current_scene.scene_file_path == "res://scenes/main.tscn" and Realm.in_title
		if not returned_to_title or is_instance_valid(shell) or is_instance_valid(old_town) \
			or is_instance_valid(old_controller) or is_instance_valid(old_sound):
			_fail("Save & Leave did not tear down the campaign shell and return to the title scene.")
			return
		print("PASS: Save & Leave returned to the title scene and freed the campaign shell, town, controller and audio manager")
		print("CAMPAIGN_CAMP_LIFE_SHOWCASE_OK")
		quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
