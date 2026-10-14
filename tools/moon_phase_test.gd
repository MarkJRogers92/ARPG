extends SceneTree
## The real moon: known dates, effects, stacking, Daily determinism, the
## Campaign untouched, the run save.
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _near(a: float, b: float, message: String) -> void:
	_check(absf(a - b) < 0.001, "%s (%f vs %f)" % [message, a, b])


func _unix(date: String) -> float:
	return float(Time.get_unix_time_from_datetime_string(date))


func _night(daily := false, spec := {}) -> Node:
	Elements.player = null
	Elements.swarms = []
	Realm.in_title = false
	Realm.daily = daily
	var main: Node = load("res://scenes/main.tscn").instantiate()
	if not spec.is_empty():
		main.set("expedition_spec", spec)
	root.add_child(main)
	return main


func _run() -> void:
	var was_disabled := MetaProgress.disabled
	MetaProgress.disabled = true
	Obstacles.clear()
	# Known dates: new moon 2024-01-11 11:57 UTC, full moon 2024-01-25 17:54 UTC.
	_near(MoonPhase.age_days(_unix("2000-01-06T18:14:00")), 0.0, "the reference new moon has age 0")
	_check(MoonPhase.phase_for(_unix("2024-01-11T11:57:00")) == "new", "2024-01-11 is a new moon")
	_check(MoonPhase.phase_for(_unix("2024-01-25T17:54:00")) == "full", "2024-01-25 is a full moon")
	_check(MoonPhase.phase_for(_unix("2024-01-17T12:00:00")) == "waxing", "2024-01-17 (after the new moon) waxes")
	_check(MoonPhase.phase_for(_unix("2024-02-01T00:00:00")) == "waning", "2024-02-01 (after the full moon) wanes")
	_check(MoonPhase.phase_for(_unix("1999-12-01T00:00:00")) != "", "dates before the reference work")
	_check(MoonPhase.age_days(_unix("1990-05-05T00:00:00")) >= 0.0, "ages are never negative")
	_check(MoonPhase.PHASES.size() == MoonPhase.ORDER.size(), "every phase is listed")
	_near(MoonPhase.shard_mult("new"), 1.2, "New Moon: +20% shards")
	_near(MoonPhase.shard_mult("full"), 1.0, "Full Moon: no shard bonus")
	_near(RunModifiers.shard_mult(["swarm"], "midas", 2, "new"), 1.25 * 1.5 * 1.2 * 1.2, "moon shards stack with heat, Midas and Ascension")
	_check(MoonPhase.night_phase(false) == "", "bots and tests default to no moon")
	MoonPhase.override = "bogus"
	_check(MoonPhase.night_phase(false) == "", "an unknown override is no moon")
	MoonPhase.override = "full"
	_check(MoonPhase.night_phase(true) == "full", "the override wins, even for the Daily")
	MoonPhase.override = ""
	# The Daily reads the date, not the clock.
	MetaProgress.disabled = false
	_check(fmod(MoonPhase.night_unix(true), 86400.0) == 0.0, "the Daily's moon is read at 00:00 UTC")
	_check(MoonPhase.night_phase(true) == MoonPhase.phase_for(_unix(Realm.today())), "the Daily's phase is that date's")
	MetaProgress.disabled = true

	# Effects, one phase at a time, and stacking with omen, pacts and Ascension.
	var base := _night()
	var base_hero: Player = base.get_node("Player")
	var base_elites := (base.get_node("WaveDirector") as WaveDirector).elites_per_minute
	_near((base.get_node("Atmosphere") as Atmosphere).light_scale, 1.0, "no moon, no dimming")
	_check(base.moon == "", "a bot night has no moon")
	var base_xp := base_hero.stats.xp_gain
	var base_soul := base_hero.stats.soul_chance
	var base_mf := base_hero.stats.magic_find
	base.free()
	MoonPhase.override = "new"
	var m := _night()
	_near((m.get_node("Atmosphere") as Atmosphere).light_scale, 0.75, "New Moon dims the night 25%")
	_near((m.get_node("WaveDirector") as WaveDirector).elites_per_minute, base_elites * 1.25, "New Moon: 25% more elites")
	_check(m.moon == "new", "the night remembers its moon")
	m.free()
	MoonPhase.override = "waxing"
	m = _night()
	_near((m.get_node("Player") as Player).stats.xp_gain, base_xp * 1.1, "Waxing Moon: +10% XP")
	m.free()
	MoonPhase.override = "waning"
	m = _night()
	_near((m.get_node("Player") as Player).stats.magic_find, base_mf + 0.15, "Waning Moon: +15% magic find")
	m.free()
	MoonPhase.override = "full"
	m = _night()
	_near((m.get_node("Player") as Player).stats.soul_chance, base_soul * 1.3, "Full Moon: +30% soul chance")
	# Stacking: Soul Tide (double souls) + a pact + Ascension, then the moon again (idempotent).
	var hero: Player = m.get_node("Player")
	RunModifiers.apply(m, ["swarm"], "soul_tide", 3)
	MoonPhase.apply(m, "full")
	MoonPhase.apply(m, "full")
	_near(hero.stats.soul_chance, base_soul * 2.0 * 1.3, "Full Moon stacks with Soul Tide, and applying twice does not double it")
	MoonPhase.apply(m, "")
	_near(hero.stats.soul_chance, base_soul * 2.0, "clearing the moon removes only the moon")
	_near((m.get_node("Atmosphere") as Atmosphere).light_scale, 1.0, "and its dimming")
	m.free()

	# Campaign runs are untouched.
	MoonPhase.override = "new"
	var camp := _night(false, {"effects": []})
	_check(camp.moon == "" and absf((camp.get_node("Atmosphere") as Atmosphere).light_scale - 1.0) < 0.001, "the campaign never gets a moon")
	camp.free()

	# Save round-trip: tonight's moon survives to tomorrow.
	MoonPhase.override = "waning"
	var n := _night()
	var data: Dictionary = n.capture()
	_check(data.get("moon") == "waning", "the snapshot holds the moon")
	RunSave.path = "user://test_moon_run.save"
	RunSave.clear()
	_check(RunSave.write(data), "the snapshot is written")
	var back := RunSave.read()
	_check(back.get("moon") == "waning", "the moon reads back")
	n.free()
	MoonPhase.override = "full"
	RunSave.pending = back
	var r := _night()
	_check(r.moon == "waning", "a resumed night keeps its own moon, not today's")
	_near((r.get_node("Player") as Player).stats.magic_find, base_mf + 0.15, "and its effect")
	r.free()
	var old := back.duplicate()
	old.erase("moon")
	RunSave.pending = old
	var o := _night()
	_check(o.moon == "", "an old save without a moon resumes with none")
	o.free()
	RunSave.pending = {}
	RunSave.clear()

	MoonPhase.override = ""
	Realm.daily = false
	MetaProgress.disabled = was_disabled
	Obstacles.clear()
	print("MOON PHASE TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)
