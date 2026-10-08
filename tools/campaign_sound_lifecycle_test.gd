extends SceneTree
## Isolated CampaignShell audio lifetime check across repeated real departures
## and returns. It never reads or writes the default campaign save.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var token := "campaign-sound-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	Controls.apply()
	CampaignTown.walk_mode = 1
	CampaignShell.new_requested = true
	var shell := (load("res://scenes/campaign.tscn") as PackedScene).instantiate() as CampaignShell
	root.add_child(shell)
	for _frame in 4:
		await process_frame
	check(shell.controller != null and not shell.controller.state.is_empty(), "shell starts a campaign in isolated storage")
	check(Sound.instance == shell._campaign_sound and shell._campaign_sound._calm.playing,
		"town owns a bus-aware ambient music player")
	var routes: Array = shell.controller.available_routes()
	if routes.is_empty():
		check(false, "campaign exposes an initial route")
		_report()
		return
	var chosen := shell.controller.choose_route(str(routes[0].get("id", "")))
	check(bool(chosen.get("ok", false)), "the first route commits")
	if shell.controller.state.get("phase") == "EVENT_PENDING":
		check(_resolve_event(shell.controller), "the first road event resolves")
	for cycle in 2:
		var departure := shell.controller.depart()
		check(bool(departure.get("ok", false)), "departure %d succeeds" % (cycle + 1))
		if not departure.get("ok", false):
			break
		var spec: Dictionary = departure.get("spec", {})
		shell._mount_combat(spec)
		for _frame in 3:
			await process_frame
		check(Sound.instance != shell._campaign_sound and Sound.instance._calm.playing,
			"combat %d owns active realm music" % (cycle + 1))
		await create_timer(0.72).timeout
		check(not shell._campaign_sound._music_on and shell._campaign_sound._calm.volume_db <= -40.0
			and shell._campaign_sound._drums.volume_db <= -40.0 and shell._campaign_sound._boss.volume_db <= -40.0,
			"town music layers fade below audibility during combat %d" % (cycle + 1))
		var combat: Node = shell.get("_view")
		var director: ExpeditionDirector = combat.get("_expedition")
		director.result = {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"],
			"attempt_id": spec["attempt_id"], "outcome": "retreat", "elapsed": 12.0,
			"objectives": {"seals": 0, "elite_dead": false, "cache_claimed": false, "boss_dead": false}}
		combat.call("_finish_expedition_frame")
		var hud: Hud = combat.get("_hud")
		check(hud._title_main.text == "WITHDRAWAL" and hud._title_sub.text.contains("You withdrew; the route remains committed"),
			"retreat return card keeps the committed route without claiming a payout")
		combat.call("_emit_expedition_result")
		for _frame in 4:
			await process_frame
		check(shell.controller.state.get("phase") == "RESULT_PENDING" and Sound.instance == shell._campaign_sound,
			"return %d restores town audio beside the saved result panel" % (cycle + 1))
		check(shell._campaign_sound._music_on and shell._campaign_sound._calm.playing,
			"return %d resumes the same realm after its prior fade" % (cycle + 1))
		await create_timer(0.15).timeout
		check(shell._campaign_sound._calm.volume_db > -40.0,
			"return %d crossfades town music back in" % (cycle + 1))
		check(bool(shell.controller.acknowledge_result().get("ok", false)), "result %d acknowledges" % (cycle + 1))
		await process_frame
	shell._campaign_sound.stop_music(0.05)
	shell.free()
	_report()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _resolve_event(controller: CampaignController) -> bool:
	var event: Dictionary = controller.state.get("event", {})
	var choices: Array = event.get("choices", [])
	for choice: Dictionary in choices:
		var response := controller.resolve_event(str(choice.get("id", "")))
		if response.get("ok", false):
			return true
	return false


func _report() -> void:
	if failures.is_empty():
		print("CAMPAIGN_SOUND_LIFECYCLE_OK")
		quit(0)
	else:
		print("CAMPAIGN_SOUND_LIFECYCLE_FAILED %d" % failures.size())
		quit(1)
