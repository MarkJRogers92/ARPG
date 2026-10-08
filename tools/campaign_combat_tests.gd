extends SceneTree
## Fast regression probes for mission outcome arbitration. This isolates the
## director's frame boundary rules from long natural-combat balance runs.

class CampaignCombatTestRoot extends Node3D:
	var _campaign_final_boss_dead := false

class LandmarkInteractionProbe extends Landmarks:
	var used := false

	func use_nearest() -> bool:
		used = true
		return true

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)


func _prompt_player(at := Vector2.ZERO) -> Player:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate() as Player
	root.add_child(player)
	player.position = Vector3(at.x, 0.0, at.y)
	return player


func _clear_prompt_visuals(director: ExpeditionDirector) -> void:
	for visual: Node3D in director._visuals:
		visual.free()
	director._visuals.clear()


func _director(contract: String, mission_duration: float, mission_deadline: float) -> ExpeditionDirector:
	var director := ExpeditionDirector.new()
	director.contract_id = contract
	director.duration = mission_duration
	director.deadline = mission_deadline
	director.spec = {"campaign_id": "test", "node_id": "test-node", "attempt_id": "test-attempt"}
	return director


func _run() -> void:
	await _test_objective_prompts()
	await _test_objective_feedback()
	await _test_elite_feedback_signal_first()
	_test_breach_boundaries()
	_test_breach_deadline_feedback()
	_test_elite_boundaries()
	_test_marked_elite_marker_tracks_target()
	await _test_borrowed_battalion_schedule()
	_test_finale_and_death_priority()
	print("CAMPAIGN COMBAT TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)


func _test_objective_feedback() -> void:
	var hud := Hud.new()
	hud.name = "Hud"
	var main := Node3D.new()
	main.name = "FeedbackOwner"
	root.add_child(main)
	main.add_child(hud)
	await process_frame
	var director := _director("breach", 360.0, 420.0)
	director._main = main
	main.add_child(director)
	director._sites = [Vector2.ZERO, Vector2.ONE, Vector2(2.0, 2.0)]
	for _i in 3:
		var visual := Node3D.new()
		director._visuals.append(visual)
		main.add_child(visual)
	director._site_claimed = [true, true, false]
	director.seals = 2
	director._complete_site(2)
	_check(director.seals == 3 and hud._toasts.get_child_count() == 1 and
		String((hud._toasts.get_child(0) as Label).text).contains("All seals closed"),
		"third seal gives one readable extraction acknowledgement")
	director._complete_site(2)
	_check(director.seals == 3 and hud._toasts.get_child_count() == 1,
		"repeated site completion does not duplicate the objective acknowledgement")
	main.free()


func _test_elite_feedback_signal_first() -> void:
	var hud := Hud.new()
	hud.name = "Hud"
	var main := Node3D.new()
	main.name = "EliteFeedbackOwner"
	main.add_child(hud)
	root.add_child(main)
	await process_frame
	var director := _director("elite_hunt", 300.0, 420.0)
	director._main = main
	main.add_child(director)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate() as Player
	main.add_child(player)
	director._player = player
	var wave := WaveDirector.new()
	director.add_child(wave)
	director._wave = wave
	director._elite_spawned = true
	var swarm := EnemySwarm.new()
	swarm.count = 1
	swarm.ids = PackedInt32Array([17])
	swarm.hp = PackedFloat32Array([0.0])
	director._marked_swarm = swarm
	director._marked_id = 17
	main.add_child(swarm)
	director.observe_elite_death(swarm, 17)
	_check(director.elite_dead and hud._toasts.get_child_count() == 1 and
		String((hud._toasts.get_child(0) as Label).text).contains("Marked elite defeated"),
		"marked elite death signal presents one explicit objective acknowledgement")
	director.tick_objectives(0.01)
	_check(director.elite_dead and hud._toasts.get_child_count() == 1,
		"following live objective polling does not repeat the elite acknowledgement")
	main.free()


func _test_objective_prompts() -> void:
	Landmarks.ensure_input()
	var director := _director("breach", 360.0, 420.0)
	var player := _prompt_player()
	director._player = player
	director._sites = [Vector2(5.0, 0.0), Vector2.ZERO, Vector2(2.0, 0.0)]
	director._site_claimed = [true, false, false]
	director._visuals = [Node3D.new(), Node3D.new(), Node3D.new()]
	var wave := WaveDirector.new()
	director._wave = wave
	var prompt := director.interaction_prompt()
	_check(prompt.get("text", "").contains("SEAL 2 / 3") and prompt.get("color") == ExpeditionDirector.OBJECTIVE_COLOR,
			"breach prompt names the nearest incomplete seal at the interaction radius")
	var landmark := LandmarkInteractionProbe.new()
	root.add_child(landmark)
	landmark._player = player
	landmark._near_key = "overlapping-landmark"
	landmark._scan = 0.15
	Input.action_press("interact")
	await process_frame
	_check(Input.is_action_just_pressed("interact"), "objective overlap fixture has a fresh interact press")
	landmark.tick(0.01)
	_check(landmark.used, "an ungated landmark would consume the same fresh interact press")
	landmark.used = false
	landmark.tick(0.01, director.interaction_prompt().is_empty())
	director.tick_objectives(0.01)
	var claimed := 1 if director._site_claimed[1] else -1
	_check(claimed == 1 and director._site_claimed == [true, true, false] and director.seals == 1 and not landmark.used,
			"one interact claims the prompted seal and suppresses an overlapping landmark use")
	_check(director.interaction_prompt().get("text", "").contains("SEAL 3 / 3"),
			"claiming a seal immediately advances the prompt to the next usable seal")
	Input.action_release("interact")
	landmark.free()
	wave.free()
	_clear_prompt_visuals(director)
	director._sites = [Vector2.ZERO]
	director._site_claimed = [false]
	director._visuals = [Node3D.new()]
	player.position = Vector3(2.6, 0.0, 0.0)
	_check(not director.interaction_prompt().is_empty(), "objective prompt includes the exact 2.6-unit boundary")
	player.position = Vector3(2.6001, 0.0, 0.0)
	_check(director.interaction_prompt().is_empty(), "objective prompt hides just beyond the 2.6-unit boundary")
	player.position = Vector3(0.0, 0.0, 0.0)
	_clear_prompt_visuals(director)
	director._sites = [Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]
	director._site_claimed = [false, false]
	director._visuals = [Node3D.new(), Node3D.new()]
	_check(director.interaction_prompt().get("text", "").contains("SEAL 2 / 3"),
			"an exact-distance tie preserves the existing later-site selection")
	player.dead = true
	_check(director.interaction_prompt().is_empty(), "dead players receive no objective prompt")
	player.dead = false
	director.terminal = true
	_check(director.interaction_prompt().is_empty(), "terminal missions receive no objective prompt")
	_clear_prompt_visuals(director)
	director.free()
	player.free()

	for contract in ["elite_hunt", "hunt", "finale"]:
		director = _director(contract, 300.0, 0.0)
		director._player = _prompt_player()
		director._sites = [Vector2.ZERO]
		_check(director.interaction_prompt().is_empty(), "%s does not advertise a non-interactive objective" % contract)
		director._player.free()
		director.free()

	director = _director("seal_breach", 360.0, 420.0)
	director._player = _prompt_player()
	director._sites = [Vector2.ZERO]
	director._site_claimed = [false]
	_check(director.interaction_prompt().get("text", "").contains("SEAL 1 / 3"),
			"seal_breach alias uses the seal interaction prompt")
	director._player.free()
	director.free()

	director = _director("cursed_cache", 360.0, 0.0)
	var cache_player := _prompt_player()
	director._player = cache_player
	director._sites = [Vector2.ZERO]
	director.cache_enabled = true
	var original_events := InputMap.action_get_events("interact").duplicate()
	InputMap.action_erase_events("interact")
	var remapped_key := InputEventKey.new()
	remapped_key.physical_keycode = KEY_Q
	InputMap.action_add_event("interact", remapped_key)
	Controls._tags.clear()
	var cache_prompt := director.interaction_prompt()
	_check(cache_prompt.get("text", "").contains("cursed cache") and cache_prompt.get("text", "").contains("summons guardians") and
			cache_prompt.get("text", "").contains("[Q]") and cache_prompt.get("color") == ExpeditionDirector.CACHE_COLOR,
			"cursed cache prompt explains its optional risk and follows the remapped key")
	InputMap.action_erase_events("interact")
	for event: InputEvent in original_events:
		InputMap.action_add_event("interact", event)
	Controls._tags.clear()
	director.cache_claimed = true
	_check(director.interaction_prompt().is_empty(), "claimed cache prompt is hidden")
	director.free()
	cache_player.free()


func _test_breach_boundaries() -> void:
	var director := _director("breach", 360.0, 420.0)
	director.seals = 2
	_check(director.arbitrate_frame(389.99, false, false) == false, "breach waits until all requirements and 6:00")
	director.seals = 3
	_check(director.arbitrate_frame(390.0, false, false), "breach completes after third seal and survival duration")
	_check(director.result.get("outcome") == "success" and is_equal_approx(director.result.get("elapsed", -1.0), 390.0), "breach records actual completion frame")
	director.free()

	director = _director("breach", 360.0, 420.0)
	director.seals = 3
	_check(director.arbitrate_frame(420.0, false, false), "breach can complete at exact deadline")
	_check(director.result.get("outcome") == "success" and is_equal_approx(director.result.get("elapsed", -1.0), 420.0), "deadline-boundary breach reports 7:00")
	director.free()

	director = _director("breach", 360.0, 420.0)
	director.seals = 3
	_check(director.arbitrate_frame(420.01, false, false), "breach fails after deadline even when seals are complete")
	_check(director.result.get("outcome") == "failure" and is_equal_approx(director.result.get("elapsed", -1.0), 420.0), "late breach is clamped to deadline")
	director.free()

	director = _director("breach", 360.0, 420.0)
	director.seals = 3
	_check(director.arbitrate_frame(360.0, true, false), "player death at success boundary ends mission")
	_check(director.result.get("outcome") == "failure", "death wins breach success tie")
	director.free()

	director = _director("breach", 360.0, 420.0)
	director._site_claimed = [true, false, false]
	director.seals = 1
	_check(director._site_complete(0), "claimed seal site remains completed")
	_check(not director._site_complete(1) and not director._site_complete(2), "one site cannot satisfy or skip the remaining seals")
	director.free()


func _test_breach_deadline_feedback() -> void:
	for contract in ["breach", "seal_breach"]:
		var director := _director(contract, 180.0, 240.0)
		var wave := WaveDirector.new()
		director._wave = wave
		director.seals = 1
		wave.elapsed = 179.0
		_check(director.objective_text().contains("survive to 3:00") and
				director.clock_text(wave.elapsed) == "2:59  /  3:00",
				"%s shows seal work and survival target before duration" % contract)

		wave.elapsed = 180.0
		_check(director.objective_text().contains("close the rest by 4:00") and
				director.clock_text(wave.elapsed) == "SEAL DEADLINE  1:00",
				"%s exposes configured seal deadline at exact duration" % contract)
		wave.elapsed = 240.0
		_check(director.objective_text().contains("close the rest by 4:00") and
				director.clock_text(wave.elapsed) == "SEAL DEADLINE  0:00",
				"%s shows the exact deadline boundary without inventing extra time" % contract)
		_check(not director.arbitrate_frame(240.0, false, false),
				"%s remains active at the exact deadline for its existing arbitration rule" % contract)
		_check(director.arbitrate_frame(240.01, false, false) and
				director.result.get("outcome") == "failure",
				"%s still fails just after the deadline" % contract)
		director.free()
		wave.free()

		director = _director(contract, 180.0, 240.0)
		wave = WaveDirector.new()
		director._wave = wave
		director.seals = 3
		wave.elapsed = 180.0
		_check(director.objective_text() == "All seals closed  ·  survive until extraction" and
				director.clock_text(wave.elapsed) == "3:00  /  3:00" and
				director.arbitrate_frame(180.0, false, false) and
				director.result.get("outcome") == "success",
				"%s preserves completion at duration" % contract)
		director.free()
		wave.free()

		director = _director(contract, 180.0, 240.0)
		director.seals = 3
		_check(director.arbitrate_frame(240.0, false, false) and
				director.result.get("outcome") == "success",
				"%s still succeeds at the exact deadline when seals are complete" % contract)
		director.free()

	var no_deadline := _director("breach", 180.0, 0.0)
	var no_deadline_wave := WaveDirector.new()
	no_deadline._wave = no_deadline_wave
	no_deadline.seals = 1
	no_deadline_wave.elapsed = 180.0
	_check(no_deadline.objective_text().contains("close the remaining marked seals") and
			not no_deadline.objective_text().contains("by 4:00") and
			not no_deadline.clock_text(180.0).contains("DEADLINE"),
			"breach without a configured deadline does not invent one")
	no_deadline.free()
	no_deadline_wave.free()

	var hunt := _director("hunt", 180.0, 0.0)
	_check(hunt.objective_text() == "Survive to 5:00  ·  extraction is automatic" and
			hunt.clock_text(180.0) == "3:00  /  3:00",
			"hunt objective and clock are unchanged")
	hunt.free()

	var elite := _director("elite_hunt", 180.0, 240.0)
	elite._elite_spawned = true
	_check(elite.clock_text(180.0) == "ELITE DEADLINE  1:00",
			"elite deadline clock is unchanged")
	elite.free()


func _test_elite_boundaries() -> void:
	var director := _director("elite_hunt", 300.0, 420.0)
	director._elite_spawned = true
	director.elite_dead = true
	var wave := WaveDirector.new()
	wave.elapsed = 420.0
	director._wave = wave
	_check(director.arbitrate_frame(420.0, false, false), "elite hunt succeeds at deadline when marked target is dead")
	_check(director.result.get("outcome") == "success" and is_equal_approx(director.result.get("elapsed", -1.0), 420.0), "elite result uses actual completion time")
	director.free()
	wave.free()

	director = _director("elite_hunt", 300.0, 420.0)
	director._elite_spawned = true
	wave = WaveDirector.new()
	wave.elapsed = 420.01
	director._wave = wave
	_check(director.arbitrate_frame(420.01, false, false), "living elite fails after deadline")
	_check(director.result.get("outcome") == "failure" and is_equal_approx(director.result.get("elapsed", -1.0), 420.01), "elite failure reports the frame that crossed deadline")
	director.free()
	wave.free()


func _test_marked_elite_marker_tracks_target() -> void:
	var director := _director("elite_hunt", 300.0, 420.0)
	director._elite_spawned = true
	director._sites = [Vector2(2.0, 3.0)]
	var marker := Node3D.new()
	director._visuals = [marker]
	var swarm := EnemySwarm.new()
	swarm.count = 1
	swarm.ids = PackedInt32Array([41])
	swarm.pos = PackedVector2Array([Vector2(17.0, -9.0)])
	swarm.hp = PackedFloat32Array([100.0])
	director._marked_swarm = swarm
	director._marked_id = 41
	director._sync_marked_elite_marker()
	_check(director._sites[0] == Vector2(17.0, -9.0), "elite objective location follows the marked enemy")
	_check(marker.position == Vector3(17.0, 0.0, -9.0), "world beacon follows the marked enemy")
	_check(director.markers().size() == 1 and director.markers()[0]["at"] == Vector2(17.0, -9.0), "edge marker points to the marked enemy")
	swarm.pos[0] = Vector2(-24.0, 11.0)
	director._sync_marked_elite_marker()
	_check(director._sites[0] == Vector2(-24.0, 11.0) and marker.position == Vector3(-24.0, 0.0, 11.0), "world and edge markers track target movement")
	swarm.hp[0] = 0.0
	director._sync_marked_elite_marker()
	_check(not marker.visible and director.markers().is_empty(), "elite marker hides when marked enemy dies")
	director.free()
	marker.free()
	swarm.free()


func _test_borrowed_battalion_schedule() -> void:
	# Structural director probe: the borrowed clause should add one wave at
	# 0:45 and one at 1:30 after guardian arrival, with no duplicate spawns.
	var owner := CampaignCombatTestRoot.new()
	root.add_child(owner)
	var final_swarm := EnemySwarm.new()
	final_swarm.name = "FinalBoss"
	owner.add_child(final_swarm)
	var grunts := EnemySwarm.new()
	grunts.name = "Grunts"
	owner.add_child(grunts)
	await process_frame
	final_swarm.count = 1
	final_swarm.hp[0] = 100.0
	var director := _director("finale", 1200.0, 0.0)
	director.finale = true
	director.spec["clauses"] = ["borrowed_battalion"]
	director._main = owner
	var bosses := BossDirector.new()
	bosses.final_arrived = true
	director._bosses = bosses
	var wave := WaveDirector.new()
	director._wave = wave
	director._tick_ledger(944.99)
	_check(director._ledger_reinforcements == 0, "borrowed battalion waits until 0:45 after guardian arrival")
	director._tick_ledger(945.0)
	_check(director._ledger_reinforcements == 1 and grunts.count == 5, "borrowed battalion sends one five-enemy wave at 0:45")
	director._tick_ledger(950.0)
	_check(director._ledger_reinforcements == 1 and grunts.count == 5, "first borrowed wave is not duplicated")
	director._tick_ledger(989.99)
	_check(director._ledger_reinforcements == 1, "second borrowed wave waits until 1:30")
	director._tick_ledger(990.0)
	_check(director._ledger_reinforcements == 2 and grunts.count == 10, "borrowed battalion sends the second wave at 1:30")
	director._tick_ledger(995.0)
	_check(director._ledger_reinforcements == 2 and grunts.count == 10, "second borrowed wave is not duplicated")
	owner._campaign_final_boss_dead = true
	director._tick_ledger(1100.0)
	_check(director._ledger_reinforcements == 2 and grunts.count == 10, "ledger stops spawning reinforcements after the finale guardian dies")
	director.free()
	bosses.free()
	wave.free()
	owner.free()


func _test_finale_and_death_priority() -> void:
	var director := _director("finale", 1200.0, 0.0)
	director.finale = true
	var bosses := BossDirector.new()
	bosses.final_arrived = false
	director._bosses = bosses
	_check(not director.arbitrate_frame(900.0, false, true), "a pre-arrival corpse observation cannot end the finale")
	bosses.final_arrived = true
	_check(not director.arbitrate_frame(899.99, false, true), "final guardian death before 15:00 does not settle")
	_check(director.arbitrate_frame(900.0, false, true), "actual final guardian death at 15:00 succeeds")
	_check(director.result.get("outcome") == "success" and director.result["objectives"].get("boss_dead", false), "finale reports boss objective")
	director.free()
	bosses.free()

	director = _director("finale", 1200.0, 0.0)
	director.finale = true
	bosses = BossDirector.new()
	bosses.final_arrived = true
	director._bosses = bosses
	_check(director.arbitrate_frame(900.0, true, true), "player death takes priority when guardian dies in same frame")
	_check(director.result.get("outcome") == "failure", "death wins finale boss-death tie")
	director.free()
	bosses.free()
