extends SceneTree
## Fast regression probes for mission outcome arbitration. This isolates the
## director's frame boundary rules from long natural-combat balance runs.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)


func _director(contract: String, mission_duration: float, mission_deadline: float) -> ExpeditionDirector:
	var director := ExpeditionDirector.new()
	director.contract_id = contract
	director.duration = mission_duration
	director.deadline = mission_deadline
	director.spec = {"campaign_id": "test", "node_id": "test-node", "attempt_id": "test-attempt"}
	return director


func _run() -> void:
	_test_breach_boundaries()
	_test_elite_boundaries()
	_test_finale_and_death_priority()
	print("CAMPAIGN COMBAT TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)


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
