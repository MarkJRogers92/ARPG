extends SceneTree
## Whispered Vows: the two windows, each vow's progress feed, one payout, the
## fail conditions, the requires filter, Daily determinism and campaign gating.
## Headless; never touches saved state.

const REACTIONS := ["shatter", "melt", "overload"]

var checks := 0
var failures := 0
var _kept := []
var _faded := 0
var _whispers := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _make(frost := true, lightning := true, fire := true) -> Vows:
	Elements.reset()
	var stats := PlayerStats.new()
	stats.aura_level = 1 if frost else 0
	stats.lightning_level = 1 if lightning else 0
	stats.ignite_chance = 0.2 if fire else 0.0
	var v := Vows.new()
	root.add_child(v)
	v.setup(stats)
	_kept.clear()
	_faded = 0
	_whispers = 0
	v.kept.connect(func(b: String) -> void: _kept.append(b))
	v.faded.connect(func(_t: String) -> void: _faded += 1)
	v.whispered.connect(func(_a: String, _b: String) -> void: _whispers += 1)
	return v


func _run() -> void:
	_test_schedule()
	_test_resume()
	_test_reactions()
	_test_burst()
	_test_counters()
	_test_elite_dash()
	_test_steady()
	_test_walk()
	_test_pay_once()
	_test_requires()
	_test_determinism()
	_test_campaign_gate()
	Elements.reset()
	print("VOWS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_schedule() -> void:
	var v := _make()
	v.tick(0.1, 10.0, 1.0, Vector2.ZERO)
	check(v.active.is_empty() and _whispers == 0, "nothing is whispered before 0:45")
	v.tick(0.1, 45.0, 1.0, Vector2.ZERO)
	check(not v.active.is_empty() and _whispers == 1, "a vow is whispered at 0:45")
	check(v.hud_text().begins_with("VOW"), "the HUD line shows the vow")
	v.tick(200.0, 245.0, 1.0, Vector2.ZERO)
	check(v.active.is_empty(), "the vow ends once its time is up")
	v.tick(0.1, 300.0, 1.0, Vector2.ZERO)
	check(_whispers == 1, "no whisper between the windows")
	v.tick(0.1, 450.0, 1.0, Vector2.ZERO)
	check(_whispers == 2, "a second vow is whispered at 7:30")
	v.tick(0.1, 451.0, 1.0, Vector2.ZERO)
	check(_whispers == 2 and v.offered == 2, "one vow per window")
	var text := v.report_text()
	check(text == "Vows kept: 0/2" or text == "Vows kept: 1/2", "the report counts offered vows (%s)" % text)
	v.free()


func _test_resume() -> void:
	var v := _make()
	v.resume_at(100.0)
	v.tick(0.1, 100.0, 1.0, Vector2.ZERO)
	check(_whispers == 0 and v.active.is_empty(), "a resume after 0:45 does not re-offer that window")
	v.tick(0.1, 450.0, 1.0, Vector2.ZERO)
	check(_whispers == 1, "the later window still opens after a resume")
	v.free()
	var w := _make()
	w.resume_at(600.0)
	w.tick(0.1, 600.0, 1.0, Vector2.ZERO)
	check(_whispers == 0, "both windows shut after a late resume")
	w.free()


func _test_reactions() -> void:
	for pair in [["shatter", "Shatter"], ["melt", "Melt"], ["overload", "Overload"]]:
		var v := _make()
		Elements.metrics.reaction(pair[1], 0.0, true)  # before the vow: not counted
		v.offer(pair[0], 50.0)
		v.tick(0.1, 51.0, 1.0, Vector2.ZERO)
		check(v.active["progress"] == 0, "%s ignores reactions from before the vow" % pair[0])
		for i in 5:
			Elements.metrics.reaction(pair[1], 0.0, true)
		v.tick(0.1, 52.0, 1.0, Vector2.ZERO)
		check(v.active["progress"] == 5, "%s counts its reaction (%s)" % [pair[0], str(v.active.get("progress"))])
		for i in int(v.active["target"]):
			Elements.metrics.reaction(pair[1], 0.0, true)
		v.tick(0.1, 53.0, 1.0, Vector2.ZERO)
		check(v.active.is_empty() and v.kept_count == 1, "%s is kept at its target" % pair[0])
		v.free()


func _test_burst() -> void:
	var v := _make()
	v.offer("burst", 100.0)
	var target: int = v.active["target"]
	check(target == 12 + int(100.0 / 30.0), "the burst target scales with the hour of the night")
	# Slow kills (one every 5 s) never pile up inside 20 s.
	var t := 100.0
	for i in target:
		t += 5.0
		v.tick(0.0, t, 1.0, Vector2.ZERO)
		v.on_kill()
	check(v.kept_count == 0, "kills spread beyond 20 seconds do not count together")
	v.free()
	var w := _make()
	w.offer("burst", 100.0)
	for i in int(w.active["target"]):
		w.tick(0.0, 101.0, 1.0, Vector2.ZERO)
		w.on_kill()
	check(w.kept_count == 1, "a quick burst of kills keeps the vow")
	w.free()


func _test_counters() -> void:
	var v := _make()
	v.offer("raise", 50.0)
	for i in 3:
		v.on_raise()
	check(v.active["progress"] == 3, "raises are counted")
	v.on_raise()
	check(v.kept_count == 1, "the fourth raise keeps the vow")
	v.free()
	var w := _make()
	w.offer("souls", 50.0)
	for i in 19:
		w.on_soul()
	check(w.active["progress"] == 19 and w.kept_count == 0, "souls are counted")
	w.on_soul()
	check(w.kept_count == 1, "the twentieth soul keeps the vow")
	# Feeds for other vows are ignored.
	w.offer("raise", 60.0)
	w.on_soul()
	w.on_kill()
	w.on_elite()
	check(w.active["progress"] == 0, "a vow only listens to its own feed")
	w.free()


func _test_elite_dash() -> void:
	var v := _make()
	v.offer("elite", 50.0)
	v.on_elite()
	check(v.kept_count == 1, "slaying an elite without dashing keeps the vow")
	v.free()
	var w := _make()
	w.offer("elite", 50.0)
	w.on_dash()
	check(w.active.is_empty() and _faded == 1 and w.kept_count == 0, "dashing breaks the elite vow")
	w.on_elite()
	check(w.kept_count == 0 and w.shards == 0, "a broken vow cannot be kept afterwards")
	w.free()
	var x := _make()
	x.offer("elite", 50.0)
	x.tick(200.0, 250.0, 1.0, Vector2.ZERO)
	check(x.active.is_empty() and _faded == 1 and x.kept_count == 0, "the elite vow fades on timeout")
	x.free()


func _test_steady() -> void:
	var v := _make()
	v.offer("steady", 50.0)
	v.tick(30.0, 80.0, 0.8, Vector2.ZERO)
	check(not v.active.is_empty() and v.kept_count == 0, "still waiting while healthy")
	v.tick(60.0, 140.0, 0.8, Vector2.ZERO)
	check(v.active.is_empty() and v.kept_count == 1, "surviving the whole time above half keeps it")
	v.free()
	var w := _make()
	w.offer("steady", 50.0)
	w.tick(10.0, 60.0, 0.4, Vector2.ZERO)
	check(w.active.is_empty() and _faded == 1 and w.kept_count == 0, "dropping below half fails it")
	w.free()
	var x := _make()
	x.offer("steady", 50.0)
	x.tick(1.0, 51.0, 0.5, Vector2.ZERO)
	check(not x.active.is_empty(), "exactly half health is still above the line")
	x.free()


func _test_walk() -> void:
	var v := _make()
	v.offer("walk", 50.0)
	v.tick(0.0, 50.0, 1.0, Vector2.ZERO)
	var pos := Vector2.ZERO
	for i in 100:
		pos += Vector2(1.0, 0.0)
		v.tick(0.1, 51.0 + i * 0.1, 1.0, pos)
	check(absf(float(v.active["progress"]) - 100.0) < 0.5, "walking is measured in metres (%s)" % str(v.active.get("progress")))
	v.tick(0.1, 70.0, 1.0, pos + Vector2(500.0, 0.0))
	check(float(v.active["progress"]) < 110.0, "a teleport does not count as walking")
	pos += Vector2(500.0, 0.0)
	for i in 150:
		pos += Vector2(1.0, 0.0)
		v.tick(0.1, 71.0 + i * 0.1, 1.0, pos)
	check(v.kept_count == 1, "250 m keeps the walk")
	v.free()


func _test_pay_once() -> void:
	var v := _make()
	v.resume_at(1000.0)  # no scheduled window interferes
	v.offer("souls", 50.0)
	v.on_soul(20)
	check(v.shards == Vows.SHARDS and _kept.size() == 1, "success pays %d shards and a blessing" % Vows.SHARDS)
	check(EventDirector.BLESSINGS.has(_kept[0]), "the blessing is an existing one")
	v.on_soul(20)
	v.tick(1.0, 60.0, 1.0, Vector2.ZERO)
	check(v.shards == Vows.SHARDS and _kept.size() == 1 and v.kept_count == 1, "it pays only once")
	check(v.report_text() == "Vows kept: 1/1", "the report reads kept/offered")
	v.free()
	var w := _make()
	w.offer("souls", 50.0)
	w.tick(500.0, 550.0, 1.0, Vector2.ZERO)
	check(w.shards == 0 and _kept.is_empty() and _faded == 1, "timing out pays nothing and fades softly")
	w.free()


func _test_requires() -> void:
	var v := _make(false, false, false)
	var ids := v.eligible()
	for id in REACTIONS:
		check(not ids.has(id), "no %s vow without the sources" % id)
	check(ids.has("burst") and ids.has("walk") and ids.has("souls") and ids.has("elite"), "plain vows are always on offer")
	v.free()
	var f := _make(true, true, false)
	check(f.eligible().has("shatter") and not f.eligible().has("melt") and not f.eligible().has("overload"), "chill + lightning offers Shatter only")
	f.free()
	var g := _make(true, true, true)
	check(g.eligible().has("shatter") and g.eligible().has("melt") and g.eligible().has("overload"), "all three sources offer every reaction")
	g.free()
	var h := _make(true, true, true)
	h.tick(0.0, 1.0, 0.3, Vector2.ZERO)
	check(not h.eligible().has("steady"), "no 'stay above half' vow to a hero already below it")
	h.free()
	# Whatever is whispered is always something the hero can do.
	for n in 20:
		var w := _make(false, false, false)
		w.rng.seed = n
		w.tick(0.1, 45.0, 1.0, Vector2.ZERO)
		var id: String = w.active.get("id", "")
		check(id != "" and not REACTIONS.has(id), "seed %d offers a possible vow (%s)" % [n, id])
		w.free()


func _sequence(seed_value: int) -> Array:
	var v := _make()
	v.rng.seed = seed_value
	var out := []
	v.tick(0.1, 45.0, 1.0, Vector2.ZERO)
	out.append(v.active.get("id", ""))
	v.on_soul(99)
	v.on_raise()
	v.on_elite()
	v.tick(300.0, 400.0, 1.0, Vector2.ZERO)
	v.tick(0.1, 450.0, 1.0, Vector2.ZERO)
	out.append(v.active.get("id", ""))
	out.append(_kept.duplicate())
	v.free()
	return out


func _test_determinism() -> void:
	check(_sequence(1234) == _sequence(1234), "the same seed whispers the same vows and blessings")
	var differs := false
	for s in range(1, 12):
		if _sequence(s) != _sequence(1234):
			differs = true
	check(differs, "different seeds can whisper different vows")


func _test_campaign_gate() -> void:
	var v := _make()
	v.enabled = false
	v.tick(0.1, 45.0, 1.0, Vector2.ZERO)
	v.tick(0.1, 450.0, 1.0, Vector2.ZERO)
	v.on_soul()
	v.on_dash()
	check(v.active.is_empty() and v.offered == 0 and _whispers == 0, "a disabled Vows node (campaign) never whispers")
	check(v.hud_text() == "" and v.report_text() == "", "and shows nothing")
	v.free()
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	check("_vows.enabled = not _campaign" in src, "main.gd turns Vows off in the campaign")
