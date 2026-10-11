extends SceneTree
## Mission rhythm phases and danger/population wave budgets.
##
## Covers: the pure MissionRhythm table at short (300 s) and long (900 s)
## durations; phase transitions firing once each; the reward opportunity firing
## once per mission (and not on resume); elapsed-vs-profile-age; classic pressure
## still adapting while campaign pressure is disabled; role classification;
## classic and campaign total/danger/per-role caps including the populate path;
## no per-frame bypass of the remaining cap; and bounded counts under load.
##
## Headless only: creates real EnemySwarm nodes (as tools/tests.gd does), but
## never steps combat and never touches saved state.

var checks := 0
var failures := 0
var _seen: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _on_phase(phase: Dictionary) -> void:
	_seen.append(phase)


## Builds a real swarm with exports applied before it enters the tree, which is
## when _ready() sizes its arrays.
func _swarm(props: Dictionary) -> EnemySwarm:
	var swarm := EnemySwarm.new()
	for key in props:
		swarm.set(key, props[key])
	root.add_child(swarm)
	return swarm


## A normal, always-available roster: melee fodder, a ranged type, a charger and
## a large brute, all with a live spawn weight.
func _roster() -> Dictionary:
	return {
		"grunt": _swarm({"capacity": 4000, "spawn_share": 1.0}),
		"cultist": _swarm({"capacity": 400, "spawn_share": 1.0, "attack_range": 9.0, "radius": 0.4, "model": "cultist"}),
		"lancer": _swarm({"capacity": 400, "spawn_share": 1.0, "charger": true, "radius": 0.45, "model": "lancer"}),
		"brute": _swarm({"capacity": 400, "spawn_share": 1.0, "radius": 0.8, "model": "brute"}),
	}


func _roster_array(roster: Dictionary) -> Array[EnemySwarm]:
	var out: Array[EnemySwarm] = []
	for key in roster:
		out.append(roster[key])
	return out


func _free_roster(roster: Dictionary) -> void:
	for key in roster:
		(roster[key] as EnemySwarm).free()


func _run() -> void:
	_test_rhythm_table()
	_test_phase_transitions()
	_test_resume_no_reward()
	_test_elapsed_not_age()
	_test_pressure()
	_test_roles_and_spec()
	_test_caps_classic()
	_test_caps_campaign()
	_test_populate_caps()
	_test_no_frame_bypass()
	_test_no_eligible_swarms()
	_test_no_authority_over_clock()
	_test_bounded_load()
	print("MISSION_RHYTHM: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_rhythm_table() -> void:
	var m := MissionRhythm.new()
	check(m.duration == MissionRhythm.DEFAULT_DURATION, "default rhythm is a Classic 900 s night")
	check(m.phase_id_at(0.0) == "opening", "a fresh mission opens")
	check(m.phase_at(0.0).get("label", "") == "Opening", "opening phase carries its label")

	# Short (300 s) contract: boundaries are fractions of its own duration.
	m.setup(300.0, "hunt")
	check(m.phase_id_at(0.0) == "opening", "300 s: opening at 0")
	check(m.phase_id_at(41.9) == "opening", "300 s: still opening just before the boundary")
	check(m.phase_id_at(42.0) == "surge", "300 s: surge at the opening boundary")
	check(m.phase_id_at(179.9) == "surge", "300 s: still surge just before reward")
	check(m.phase_id_at(180.0) == "reward", "300 s: reward at 60%")
	check(m.phase_id_at(221.9) == "reward", "300 s: still reward just before finale")
	check(m.phase_id_at(222.0) == "finale", "300 s: finale at 74%")
	check(m.phase_id_at(300.0) == "finale", "300 s: finale through the end")
	check(m.phase_id_at(3000.0) == "finale", "past the duration the mission settles in the finale")

	# Long (900 s) night: same authored shape, stretched.
	m.setup(900.0, "hunt")
	check(m.phase_id_at(126.0) == "surge", "900 s: surge starts at 14%")
	check(m.phase_id_at(540.0) == "reward", "900 s: reward at 60%")
	check(m.phase_id_at(666.0) == "finale", "900 s: finale at 74%")
	check(m.fraction(450.0) == 0.5, "the fraction is real elapsed over duration")

	# Contract picks the surge role; unknown ids are deterministic and in range.
	check(MissionRhythm.surge_role_for("hunt") == "ranged", "hunt surges ranged")
	check(MissionRhythm.surge_role_for("breach") == "charger", "breach surges chargers")
	check(MissionRhythm.surge_role_for("seal_breach") == "charger", "seal_breach surges chargers")
	check(MissionRhythm.surge_role_for("elite_hunt") == "large", "elite_hunt surges large")
	check(MissionRhythm.surge_role_for("cursed_cache") == "ranged", "cursed_cache surges ranged")
	var unknown_a := MissionRhythm.surge_role_for("totally_new_contract")
	check(unknown_a == MissionRhythm.surge_role_for("totally_new_contract"), "unknown contract role is stable")
	check(unknown_a in ["ranged", "charger", "large"], "unknown contract role stays in the authored set")

	m.setup(900.0, "elite_hunt")
	var surge := m.phase_by_id("surge")
	check(surge["role"] == "large" and surge["bias"].get("large", 0.0) > 1.0, "surge phase biases its contract role")
	check(m.phase_by_id("reward").get("reward_opportunity", false), "reward phase advertises the opportunity")
	check(not m.phase_by_id("opening").get("reward_opportunity", false), "opening carries no reward")
	check(m.reward_phase_id() == "reward", "exactly one authored reward phase")
	check(m.phases().size() == 4, "four authored phases")

	# phases() is a copy: callers can't rewrite the table.
	var copy := m.phases()
	copy[0]["rate_mult"] = 99.0
	check(m.phase_by_id("opening")["rate_mult"] != 99.0, "the phase table cannot be mutated through phases()")


func _test_phase_transitions() -> void:
	var d := WaveDirector.new()
	d.configure_rhythm(300.0, "hunt")
	_seen.clear()
	d.phase_changed.connect(_on_phase)
	var ids: Array[String] = []
	for step_elapsed in [0.0, 10.0, 41.0, 42.0, 100.0, 180.0, 200.0, 222.0, 260.0, 500.0]:
		d.elapsed = step_elapsed
		d.tick(0.0, Vector2.ZERO)
	for phase in _seen:
		ids.append(String(phase.get("id", "")))
	check(ids == ["opening", "surge", "reward", "finale"],
		"each phase fires exactly once per transition (%s)" % [",".join(ids)])
	var reward_times := 0
	for phase in _seen:
		if bool(phase.get("reward_opportunity", false)):
			reward_times += 1
	check(reward_times == 1, "the reward opportunity is offered exactly once per mission (%d)" % reward_times)

	# configure_rhythm clears the bookkeeping, so the next tick re-locks.
	d.configure_rhythm(300.0, "hunt")
	_seen.clear()
	d.elapsed = 0.0
	d.tick(0.0, Vector2.ZERO)
	check(_seen.size() == 1 and String(_seen[0]["id"]) == "opening", "explicit configure re-arms the transition")
	d.phase_changed.disconnect(_on_phase)
	d.free()


func _test_resume_no_reward() -> void:
	var d := WaveDirector.new()
	d.configure_rhythm(300.0, "hunt")
	_seen.clear()
	d.phase_changed.connect(_on_phase)
	d.note_resumed(0.7 * 300.0, true)
	d.tick(0.0, Vector2.ZERO)
	d.elapsed = 0.72 * 300.0
	d.tick(0.0, Vector2.ZERO)
	check(_seen.is_empty(), "a resumed mission inside the reward phase does not replay the transition")
	check(d._reward_announced, "resume settled the reward bookkeeping")
	# A resume before reward keeps the opportunity available.
	var d2 := WaveDirector.new()
	d2.configure_rhythm(300.0, "hunt")
	d2.note_resumed(0.2 * 300.0, false)
	check(not d2._reward_announced, "a resume before reward leaves the opportunity open")
	d2.free()
	d.phase_changed.disconnect(_on_phase)
	d.free()


func _test_elapsed_not_age() -> void:
	var d := WaveDirector.new()
	d.configure_expedition({"age_rate": 2.4, "growth_cap": 420.0})
	check(d.expedition_profile, "expedition profile enabled")
	d.configure_rhythm(300.0, "hunt")
	d.elapsed = 180.0
	check(is_equal_approx(d.profile_age(), 420.0), "profile age is the capped, scaled curve input")
	check(d.current_phase_id() == "reward", "the rhythm follows real elapsed, not capped profile age")
	d.elapsed = 42.0
	check(d.current_phase_id() == "surge", "and tracks each real fraction boundary")
	d.free()


func _test_pressure() -> void:
	var classic := WaveDirector.new()
	classic.elapsed = classic.pressure_start + 60.0
	classic.pressure = 1.0
	classic.update_pressure(1.0, 1.0, 0)
	check(classic.pressure > 1.0, "classic pressure still adapts to an untouched hero")
	classic.free()

	var campaign := WaveDirector.new()
	campaign.configure_expedition({"duration": 300.0, "contract_id": "hunt"})
	campaign.elapsed = 200.0
	campaign.update_pressure(1.0, 1.0, 0)
	check(campaign.pressure == 1.0, "campaign pressure stays disabled exactly as before")
	campaign.free()


func _test_roles_and_spec() -> void:
	var grunt := _swarm({"capacity": 4, "spawn_share": 1.0})
	var cultist := _swarm({"capacity": 4, "spawn_share": 1.0, "attack_range": 9.0})
	var lancer := _swarm({"capacity": 4, "spawn_share": 1.0, "charger": true})
	var brute := _swarm({"capacity": 4, "spawn_share": 1.0, "radius": 0.8, "model": "brute"})
	var small_colossus := _swarm({"capacity": 4, "spawn_share": 1.0, "radius": 0.3, "model": "colossus"})
	var charger_ranged := _swarm({"capacity": 4, "spawn_share": 1.0, "charger": true, "attack_range": 9.0})
	var event_only := _swarm({"capacity": 4, "spawn_share": 0.0, "attack_range": 9.0})
	var boss := _swarm({"capacity": 4, "spawn_share": 0.0, "boss": true})

	check(WaveDirector.danger_role_of(grunt) == WaveDirector.FODDER, "ordinary melee is fodder")
	check(WaveDirector.danger_role_of(cultist) == WaveDirector.DANGER_RANGED, "attack_range reads as ranged")
	check(WaveDirector.danger_role_of(lancer) == WaveDirector.DANGER_CHARGER, "charger flag reads as charger")
	check(WaveDirector.danger_role_of(brute) == WaveDirector.DANGER_LARGE, "a wide brute reads as large")
	check(WaveDirector.danger_role_of(small_colossus) == WaveDirector.DANGER_LARGE, "a large model reads as large at any radius")
	check(WaveDirector.danger_role_of(charger_ranged) == WaveDirector.DANGER_CHARGER, "charger outranks ranged")
	check(WaveDirector.danger_role_of(event_only) == WaveDirector.EXCLUDED, "zero-spawn-weight event-only swarms are excluded")
	check(WaveDirector.danger_role_of(boss) == WaveDirector.EXCLUDED, "bosses are excluded")
	check(WaveDirector.danger_role_of(null) == WaveDirector.EXCLUDED, "null is excluded")

	var classic := WaveDirector.danger_budget_spec(false)
	check(classic["total"] == 700 and classic["danger"] == 70, "classic budget is 700 total / 70 danger")
	check(classic["costs"] == {"ranged": 2, "charger": 2, "large": 3}, "weighted danger costs are ranged 2 / charger 2 / large 3")
	check(classic["role_caps"] == {"ranged": 35, "charger": 35, "large": 23}, "per-role caps derive from the danger cap")
	check(String(classic["summary"]).contains("total=700"), "the helper documents itself")
	var campaign := WaveDirector.danger_budget_spec(true)
	check(campaign["total"] == 240 and campaign["danger"] == 24, "campaign budget is 240 total / 24 danger")
	check(campaign["role_caps"] == {"ranged": 12, "charger": 12, "large": 8}, "campaign per-role caps are tighter")

	for swarm in [grunt, cultist, lancer, brute, small_colossus, charger_ranged, event_only, boss]:
		(swarm as EnemySwarm).free()


func _fill(director: WaveDirector, ticks: int, delta: float) -> void:
	for i in ticks:
		director.tick(delta, Vector2.ZERO)


func _test_caps_classic() -> void:
	var roster := _roster()
	var d := WaveDirector.new()
	d.configure_rhythm(900.0, "hunt")
	d.base_rate = 100000.0
	d.rate_growth = 0.0
	d.rate_acceleration = 0.0
	d.elapsed = 270.0 # surge: full danger budget
	d.setup(_roster_array(roster))
	_fill(d, 220, 0.05)

	check(d.current_phase_id() == "surge", "cap test stays inside the surge phase")
	var totals := d._living_totals()
	check(int(totals["total"]) == 700, "classic population stops at its 700 cap (%d)" % int(totals["total"]))
	check(int(totals["danger"]) <= 70, "classic danger never exceeds 70 (%d)" % int(totals["danger"]))
	check(int(totals["danger"]) >= 66, "danger budget actually saturates (%d)" % int(totals["danger"]))
	var roles: Dictionary = totals["roles"]
	check(int(roles["ranged"]) <= 35, "ranged stays within its role cap (%d)" % int(roles["ranged"]))
	check(int(roles["charger"]) <= 35, "charger stays within its role cap (%d)" % int(roles["charger"]))
	check(int(roles["large"]) <= 23, "large stays within its role cap (%d)" % int(roles["large"]))
	# The danger budget is full, so the last 500-odd actors are fodder.
	check(int(roster["grunt"].alive_count()) > 400, "fodder keeps spawning once the danger budget is full")

	d.free()
	_free_roster(roster)


func _test_caps_campaign() -> void:
	var roster := _roster()
	var d := WaveDirector.new()
	d.configure_expedition({"duration": 300.0, "contract_id": "hunt"})
	check(is_equal_approx(d._rhythm.duration, 300.0), "configure_expedition reads the profile duration")
	d.base_rate = 100000.0
	d.rate_growth = 0.0
	d.rate_acceleration = 0.0
	d.elapsed = 100.0 # surge for a 300 s contract
	d.setup(_roster_array(roster))
	_fill(d, 200, 0.05)

	var totals := d._living_totals()
	check(int(totals["total"]) == 240, "campaign population stops at its 240 cap (%d)" % int(totals["total"]))
	check(int(totals["danger"]) <= 24, "campaign danger never exceeds 24 (%d)" % int(totals["danger"]))
	var roles: Dictionary = totals["roles"]
	check(int(roles["ranged"]) <= 12 and int(roles["charger"]) <= 12 and int(roles["large"]) <= 8,
		"campaign per-role caps hold (%s)" % [roles])

	d.free()
	_free_roster(roster)


func _test_populate_caps() -> void:
	var roster := _roster()
	var d := WaveDirector.new()
	d.configure_rhythm(900.0, "hunt")
	d.elapsed = 270.0
	d.setup(_roster_array(roster))
	d.populate(Vector2.ZERO, 1000)
	var totals := d._living_totals()
	check(int(totals["total"]) == 700, "populate respects the total cap (%d)" % int(totals["total"]))
	check(int(totals["danger"]) <= 70, "populate respects the danger cap (%d)" % int(totals["danger"]))
	d.populate(Vector2.ZERO, 1000)
	check(int(d._living_totals()["total"]) == 700, "a second populate cannot overshoot")
	var before := int(d._living_totals()["total"])
	d.populate(Vector2.ZERO, 0)
	check(int(d._living_totals()["total"]) == before, "populate(n = 0) is a safe no-op")

	d.free()
	_free_roster(roster)


func _test_no_frame_bypass() -> void:
	var roster := _roster()
	var d := WaveDirector.new()
	d.configure_rhythm(900.0, "hunt")
	d.base_rate = 100000.0
	d.rate_growth = 0.0
	d.rate_acceleration = 0.0
	d.elapsed = 270.0
	d.setup(_roster_array(roster))
	# One enormous frame must not dump the whole backlog.
	d.tick(100.0, Vector2.ZERO)
	check(int(d._living_totals()["total"]) <= d.max_spawn_per_frame,
		"a huge delta is bounded by max_spawn_per_frame (%d)" % int(d._living_totals()["total"]))

	# Pre-fill one short of the cap: the next frame may add exactly one.
	var near := _roster()
	var only: EnemySwarm = near["grunt"]
	for i in 699:
		only.spawn(Vector2.ZERO, 1.0)
	var d2 := WaveDirector.new()
	d2.configure_rhythm(900.0, "hunt")
	d2.base_rate = 100000.0
	d2.rate_growth = 0.0
	d2.rate_acceleration = 0.0
	d2.elapsed = 270.0
	var two: Array[EnemySwarm] = [only]
	d2.setup(two)
	var before := only.alive_count()
	d2.tick(100.0, Vector2.ZERO)
	var added := only.alive_count() - before
	check(added == 1, "the remaining-cap guard spends exactly the last slot (%d)" % added)
	check(only.alive_count() <= 700, "the population cap is never exceeded (%d)" % only.alive_count())

	d.free()
	d2.free()
	_free_roster(roster)
	_free_roster(near)


func _test_no_eligible_swarms() -> void:
	var d := WaveDirector.new()
	d.configure_rhythm(300.0, "hunt")
	var empty: Array[EnemySwarm] = []
	d.setup(empty)
	d.tick(0.1, Vector2.ZERO)
	check(int(d._living_totals()["total"]) == 0, "no swarms means no spawns and no crash")

	var event_only := _swarm({"capacity": 10, "spawn_share": 0.0, "attack_range": 9.0})
	var boss := _swarm({"capacity": 4, "spawn_share": 0.0, "boss": true})
	d.setup([event_only, boss] as Array[EnemySwarm])
	d.tick(0.1, Vector2.ZERO)
	check(event_only.alive_count() == 0 and boss.alive_count() == 0,
		"only excluded swarms means the director spawns nothing")
	event_only.free()
	boss.free()
	d.free()


func _test_no_authority_over_clock() -> void:
	var d := WaveDirector.new()
	d.elapsed = 123.0
	d.configure_rhythm(300.0, "hunt")
	check(is_equal_approx(d.elapsed, 123.0), "configuring the rhythm never rewrites the clock")
	d.note_resumed(200.0, true)
	check(is_equal_approx(d.elapsed, 200.0), "resume restores the clock the primary supplied")
	d.free()


func _test_bounded_load() -> void:
	var roster := _roster()
	var d := WaveDirector.new()
	d.configure_rhythm(900.0, "hunt")
	d.base_rate = 100000.0
	d.rate_growth = 0.0
	d.rate_acceleration = 0.0
	d.elapsed = 270.0
	d.setup(_roster_array(roster))
	var started := Time.get_ticks_msec()
	_fill(d, 600, 0.05)
	var spent := Time.get_ticks_msec() - started
	var totals := d._living_totals()
	check(int(totals["total"]) <= 700, "counts stay bounded under load (%d)" % int(totals["total"]))
	check(int(totals["danger"]) <= 70, "danger stays bounded under load (%d)" % int(totals["danger"]))
	check(spent < 15000, "600 frames of budgeted spawning stay cheap (%d ms)" % spent)
	d.free()
	_free_roster(roster)
