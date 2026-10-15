extends SceneTree
## Army's mission report: the facts the camp recognizes after a night.
## Real-fixture coverage for the three loss/contribution paths the review found
## missing: an altar sacrifice, a Soulfire blast, and a zero-kill close call.
## Also the merged-soul-entry, dance-credit and dance-boundary invariants where
## the accepted army-first work and upstream Requiem/Danse Macabre meet.

const CampaignArmyStory = preload("res://scripts/campaign/campaign_army_story.gd")

var failed := false

func _initialize() -> void:
	MetaProgress.disabled = true
	seed(12345)
	_run.call_deferred()

func _run() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	var grunt := _make_swarm(Vector2(3, 0))
	grunt.name = "StoryGrunt"
	grunt.spawn(Vector2(5, 0))
	var boss := _make_swarm(Vector2(2, 0))
	boss.boss = true
	boss.step(0.0, Vector2.ZERO)
	var far_ward := _make_swarm(Vector2(20, 0))
	var leash_ward := _make_swarm(Vector2(0, 30))
	var dead_ward := _make_swarm(Vector2(0.5, 0))
	dead_ward.hp[0] = 0
	var swarms: Array[EnemySwarm] = [grunt, boss, far_ward, leash_ward, dead_ward]
	for s in swarms: s.step(0.0, Vector2.ZERO)
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	player.stats.minion_max = 8
	_check(army.has_signal("soul_bound"), "soul_bound signal exists")
	_check(army.has_method("story_report"), "story_report exists")
	_check(army.has_method("set_priority_target"), "priority target setter exists")
	_check(army.story_report().get("raised", -1) == 0, "empty report starts clean")
	var bound: Array[String] = []
	army.soul_bound.connect(func(kind: String) -> void: bound.append(kind))
	var before := army.count
	army.restore([[0, 0]])
	_check(army.count == before + 1 and army.story_report()["raised"] == 0 and bound.is_empty(), "quiet restores do not count rallies or soul bindings")
	army.restore(["bad", ["bad", 0], [0]])
	_check(army.count == before + 1, "malformed restore rows are ignored")
	army._raise(0, false, false)
	_check(army.story_report()["raised"] == 1 and bound.is_empty(), "recruits count as rally, not soul binding")
	_check(army.claim(grunt, 1, true) == 1 and army.story_report()["raised"] == 2 and bound.is_empty(), "beyond-capacity claims count as rallies, not soul bindings")
	army.souls = player.stats.soul_cost - 1
	army._votes[0] = 1
	army.collect_soul(1)
	_check(bound.size() == 1 and army.story_report()["raised"] == 3, "successful soul funded raise emits soul_bound")
	army.credit(3, 60)
	_check(army.story_report()["promotions"] == 1 and army.story_report()["standout"] != null, "promotions and standout recorded")
	var before_replacement := bound.size()
	army.souls = player.stats.soul_cost
	army._votes[0] = 1
	army._remove(0, false)
	_check(bound.size() == before_replacement + 1, "banked souls bind a replacement only after successful raise")
	_check(army.story_report()["kills"] == 60 and army.story_report()["standout"]["kills"] == 60, "mission kills follow the ally across swap removal")
	var campaign_army := Army.new()
	root.add_child(campaign_army)
	campaign_army.setup(player, swarms)
	var veteran_bindings: Array[String] = []
	campaign_army.soul_bound.connect(func(kind: String) -> void: veteran_bindings.append(kind))
	var campaign := {"swarm": grunt.name, "name": "Returned", "deeds": 300, "rank": 1, "campaign_id": "campaign-vet", "elite": 0}
	_check(campaign_army.raise_veteran(campaign) and veteran_bindings.is_empty(), "veteran join is not a fresh soul binding")
	campaign_army.credit(0, 7)
	var report: Dictionary = campaign_army.story_report()
	var standout: Dictionary = report.get("standout", {}) if report.get("standout") is Dictionary else {}
	_check(standout.get("returning", false) and standout.get("kills", -1) == 7 and report["kills"] == 7, "campaign veteran reports only this mission's kills")
	var fallen_index := army.count - 1
	army._rank[fallen_index] = 1
	army._vname[fallen_index] = "Fallen Star"
	army.credit(fallen_index, 70)
	army._remove(fallen_index, true, false)
	report = army.story_report()
	standout = report.get("standout", {}) if report.get("standout") is Dictionary else {}
	_check(report["fallen_veterans"].has("Fallen Star") and standout.get("name", "") == "Fallen Star" and not standout.get("survived", true), "fallen standout remains in report")
	for k in army.count:
		if army._rank[k] > 0 and army._vname[k] != "Fallen Star":
			army.credit(k, 20)
			break
	standout = army.story_report()["standout"]
	_check(standout["survived"] and standout["kills"] == 80, "higher-contribution living veteran outranks fallen standout")
	army._remove(0, false, false)
	_check(army.count == 2 and army._type[0] == 0, "swap removal preserves moved ally")
	army.set_priority_target(grunt)
	army.stance = "swarm"
	army._pos[0] = Vector2.ZERO
	army._find_target(0, Vector2.ZERO, Vector2.ZERO)
	_check(army._target_swarm[0] == swarms.find(grunt) and army._target_id[0] == grunt.ids[0], "nearest priority ward overrides nearer boss")
	grunt.pos[0] = Vector2(20, 0)
	grunt.pos[1] = Vector2(21, 0)
	grunt.step(0.0, Vector2.ZERO)
	army._find_target(0, Vector2.ZERO, Vector2.ZERO)
	_check(army._target_swarm[0] != swarms.find(grunt), "out-of-sight priority is rejected")
	army._pos[0] = Vector2(14, 0)
	grunt.pos[0] = Vector2(29, 0)
	grunt.pos[1] = Vector2(29, 1)
	grunt.step(0.0, Vector2.ZERO)
	army._find_target(0, Vector2(14, 0), Vector2.ZERO)
	_check(army._target_swarm[0] != swarms.find(grunt), "reachable by minion but outside hero leash is rejected")
	army._pos[0] = Vector2(14, 0)
	leash_ward.pos[0] = Vector2(29, 0)
	leash_ward.step(0.0, Vector2.ZERO)
	army.set_priority_target(leash_ward)
	army._find_target(0, Vector2(14, 0), Vector2.ZERO)
	_check(army._target_swarm[0] != swarms.find(leash_ward), "out-of-leash priority is rejected")
	army.set_priority_target(dead_ward)
	army._find_target(0, Vector2.ZERO, Vector2.ZERO)
	_check(army._target_swarm[0] != swarms.find(dead_ward), "dead priority is rejected")
	army._pos[0] = Vector2.ZERO
	army.set_priority_target(grunt)
	grunt.pos[0] = Vector2(3, 0)
	grunt.step(0.0, Vector2.ZERO)
	for st in ["hunt", "guard"]:
		army.stance = st
		army._find_target(0, Vector2.ZERO, Vector2.ZERO)
		_check(army._target_swarm[0] != swarms.find(grunt), "%s ignores optional priority" % st)
	army.set_priority_target(null)
	_check(army._priority_target == null, "priority target clears")
	var vet := Army.new()
	root.add_child(vet)
	vet.setup(player, swarms)
	var empty: Dictionary = vet.story_report()
	var empty_standout: Variant = empty.get("standout")
	var empty_standout_ok := false
	if empty_standout is Dictionary:
		empty_standout_ok = empty_standout.is_empty()
	_check(empty_standout_ok, "no standout is an empty dictionary")
	var normal := vet._raise(0, false, false)
	var normal_story: Dictionary = vet.story_report().get("standout", {}) if vet.story_report().get("standout") is Dictionary else {}
	_check(normal and normal_story.is_empty(), "unnamed army has no fabricated standout")
	army._raise(0, false, false)
	army.stance = "guard"
	army._pos[0] = Vector2.ZERO
	army._max_hp[0] = 1000.0
	army._hp[0] = army._max_hp[0]
	army._hurt[0] = 0.0
	player.stats.minion_hp = 1000.0
	grunt.contact_dps = 3200.0
	grunt.hp[0] = 1.0e9
	grunt.pos[0] = army._pos[0]
	grunt.step(0.0, Vector2.ZERO)
	_check(grunt.contact_load(army._pos[0], 0.45) > 0.0, "test enemy is in real contact range")
	for i in 6: army.step(0.25)
	_check(army._close_call[0] == 1 and army._hp[0] > 0.0, "real contact damage records a close call only while the minion survives")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [vet, campaign_army, army, grunt, boss, far_ward, leash_ward, dead_ward, player]: n.free()
	_test_sacrifice_loss()
	_test_soulfire_kills()
	_test_close_call_report()
	_test_fallen_precedence()
	_test_combined_soul_entry()
	_test_dance_strike_credit()
	_test_dance_contact_and_priority()
	if failed: quit(1)
	else: quit(0)


## (1) A Soul Altar sacrifice is a real named loss. It must reach the report and
## the existing loss signal exactly once, while staying a non-death: no Soulfire,
## no lifetime/rank/reward change.
func _test_sacrifice_loss() -> void:
	var player := _fresh_player()
	var swarm := _fixture_swarm(Vector2(9, 0))
	var swarms: Array[EnemySwarm] = [swarm]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	player.stats.powers["lich_shroud"] = 1
	var fell: Array = []
	army.veteran_fell.connect(func(n: String, c: int) -> void: fell.append([n, c]))
	_check(army.raise_veteran(_veteran("Altar-Bound", "campaign-altar", swarm)) and army._deeds[0] == 300,
		"the altar fixture deploys a campaign veteran with lifetime deeds")
	army.credit(0, 7)
	_check(army.sacrifice(), "the altar takes the veteran")
	_check(army.count == 0, "the sacrificed minion leaves the army")
	_check(army._soulfire.is_empty(), "a sacrifice is not a combat death: no Soulfire is queued")
	var first: Variant = fell[0] if fell.size() == 1 else null
	_check(first is Array and (first as Array)[0] == "Altar-Bound", "a sacrifice announces the loss exactly once")
	var report: Dictionary = army.story_report()
	var standout := _standout_of(report)
	var fallen: Variant = report.get("fallen_veterans")
	_check(fallen is Array and (fallen as Array).has("Altar-Bound"), "a sacrificed veteran is named among the fallen")
	_check(report.get("kills") == 7, "the sacrificed veteran's mission kills stay in the total")
	_check(standout.get("name", "") == "Altar-Bound" and standout.get("kills", -1) == 7,
		"a sacrificed veteran is the fallen standout with its seven kills")
	_check(standout.get("survived") == false and standout.get("returning") == true,
		"the sacrificed standout reads as a returning veteran that did not survive")
	var text := CampaignArmyStory.summary(report, "failure")
	_check(text.contains("FALLEN ON THE ROAD · Altar-Bound"), "camp names the sacrificed veteran as lost on the road")
	_check(text.contains("cut down 7 enemies this mission") and text.contains("fell on the road"),
		"camp states the sacrifice's deed and its end")

	# An unnamed sacrifice stays nameless: nothing is invented.
	var plain := Army.new()
	root.add_child(plain)
	plain.setup(player, swarms)
	var plain_fell: Array = []
	plain.veteran_fell.connect(func(n: String, c: int) -> void: plain_fell.append([n, c]))
	_check(plain._raise(0, false, false) and plain.sacrifice(), "the altar also takes a common minion")
	var plain_report: Dictionary = plain.story_report()
	var plain_fallen: Variant = plain_report.get("fallen_veterans")
	_check(plain_fell.is_empty() and plain_fallen is Array and (plain_fallen as Array).is_empty()
			and _standout_of(plain_report).is_empty(),
		"an unnamed sacrifice invents no name and no standout")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [plain, army, swarm, player]: n.free()


## (2) A minion-death Soulfire blast is the army's own kill: what it actually
## slays must reach the aggregate total, and a blast that kills nothing must not.
## The kill is never credited to an unrelated surviving slot.
func _test_soulfire_kills() -> void:
	var player := _fresh_player()
	var swarm := _make_swarm(Vector2(0, 0))
	swarm.max_hp = 10.0
	swarm.contact_dps = 40.0
	swarm.hp[0] = 2.0
	var swarms: Array[EnemySwarm] = [swarm]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	player.stats.powers["lich_shroud"] = 1
	_check(army._raise(0, false, false), "the blast fixture raises the minion that will die")
	_check(army.raise_veteran(_veteran("Bystander", "campaign-bystander", swarm)),
		"the blast fixture deploys an unrelated living veteran")
	army._attack[0] = 999.0
	army._attack[1] = 999.0 # neither minion swings: only the contact wound lands
	army._pos[0] = Vector2(0.5, 0)
	army._hp[0] = 0.01
	army._hurt[0] = 0.0
	var kills_before: int = int(army.story_report().get("kills", -1))
	_check(kills_before == 0, "the blast fixture starts with no army kills")
	var deaths_before: int = EnemySwarm.deaths
	army.step(0.0)
	_check(army.count == 1 and army._soulfire.size() == 1, "a real contact death queues one Soulfire blast")
	_check(EnemySwarm.deaths == deaths_before, "the queued blast has not run yet")
	army.flush()
	_check(EnemySwarm.deaths == deaths_before + 1, "the queued blast really slew the enemy")
	_check(int(army.story_report().get("kills", -1)) == kills_before + 1, "a Soulfire kill reaches the mission total")
	_check(army._mission_kills[0] == 0 and army._deeds[0] == 300, "the Soulfire kill is not credited to the living veteran")
	_check(_standout_of(army.story_report()).is_empty(), "a Soulfire kill invents no living standout")
	var quiet_deaths: int = EnemySwarm.deaths
	army.flush()
	_check(EnemySwarm.deaths == quiet_deaths and int(army.story_report().get("kills", -1)) == kills_before + 1,
		"a repeated flush is quiet")

	# A blast on something it cannot kill adds nothing.
	swarm.step(0.0, Vector2.ZERO)
	swarm.spawn(Vector2(0, 0))
	swarm.step(0.0, Vector2.ZERO)
	swarm.hp[0] = 1.0e9
	_check(army._raise(0, false, false), "the blast fixture raises a second minion")
	army._attack[1] = 999.0
	army._pos[1] = Vector2(0.5, 0)
	army._hp[1] = 0.01
	army._hurt[1] = 0.0
	var tanky_kills: int = int(army.story_report().get("kills", -1))
	var tanky_deaths: int = EnemySwarm.deaths
	army.step(0.0)
	army.flush()
	_check(EnemySwarm.deaths == tanky_deaths and int(army.story_report().get("kills", -1)) == tanky_kills,
		"a nonlethal blast adds nothing to the mission total")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [army, swarm, player]: n.free()


## (3) A real zero-kill close call has to reach the formatter, and a veteran that
## dies with no mission kill must not.
func _test_close_call_report() -> void:
	var player := _fresh_player()
	var swarm := _make_swarm(Vector2(0, 0))
	swarm.max_hp = 10.0
	swarm.step(0.0, Vector2.ZERO)
	swarm.hp[0] = 1.0e9
	var swarms: Array[EnemySwarm] = [swarm]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	_check(army.raise_veteran(_veteran("Steadfast", "campaign-steadfast", swarm)),
		"the close-call fixture deploys a returning veteran with lifetime deeds")
	army._pos[0] = Vector2(0.5, 0)
	army._hurt[0] = 0.0
	swarm.contact_dps = 100.0
	var ticks := 0
	while army._close_call[0] == 0 and ticks < 60:
		army.step(0.25)
		ticks += 1
	_check(army._close_call[0] == 1 and army._hp[0] > 0.0 and army.count == 1,
		"real contact damage brings the veteran to a close call and it survives")
	var report: Dictionary = army.story_report()
	var standout := _standout_of(report)
	_check(army._mission_kills[0] == 0 and army._deeds[0] == 300, "the close call itself earned no kill and spent no lifetime deed")
	_check(standout.get("name", "") == "Steadfast" and standout.get("kills", -1) == 0,
		"a surviving veteran with no kill but a real close call is the standout")
	_check(standout.get("survived") == true and standout.get("close_call") == true and standout.get("returning") == true,
		"the close-call standout is a returning veteran that survived")
	_check(int(report.get("kills", -1)) == 0, "the close call added no mission kill")
	var text := CampaignArmyStory.summary(report, "success")
	_check(text.contains("STANDOUT · Steadfast, a returning veteran, survived a close call"),
		"camp names the real close call from the army's own report")
	_check(not text.contains("cut down") and not text.contains("300"), "camp states no kill and never reuses a lifetime deed")

	# The same real damage, one tick further: a dead zero-kill veteran is silent.
	for i in 40:
		army.step(0.25)
	_check(army.count == 0, "the veteran eventually falls to the same real damage")
	report = army.story_report()
	var fallen: Variant = report.get("fallen_veterans")
	_check(fallen is Array and (fallen as Array).has("Steadfast"), "the fallen veteran is named among the losses")
	_check(_standout_of(report).is_empty(), "a dead veteran with no mission kill is not a standout")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [army, swarm, player]: n.free()


## A stronger mission contribution — even a dead one — outranks a living close
## call, and a named veteran with no deed at all is nothing to recognize.
func _test_fallen_precedence() -> void:
	var player := _fresh_player()
	var swarm := _fixture_swarm(Vector2(9, 0))
	var swarms: Array[EnemySwarm] = [swarm]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	_check(army.raise_veteran(_veteran("Fallen Five", "campaign-five", swarm)),
		"the precedence fixture deploys its first veteran")
	army.credit(0, 5)
	_check(army.raise_veteran(_veteran("Hale", "campaign-hale", swarm)),
		"the precedence fixture deploys a living veteran")
	army._close_call[1] = 1 # the real contact path for this flag is covered above
	army._remove(0, true, false)
	var report: Dictionary = army.story_report()
	var standout := _standout_of(report)
	_check(standout.get("name", "") == "Fallen Five" and standout.get("kills", -1) == 5 and standout.get("survived") == false,
		"a fallen veteran with five kills outranks a living zero-kill close call")
	_check(standout.get("close_call") == false, "the fallen standout keeps its own record, not the living one's")
	var text := CampaignArmyStory.summary(report, "success")
	_check(text.contains("cut down 5 enemies this mission") and text.contains("fell on the road"),
		"camp states the fallen veteran's deed")
	_check(not text.contains("close call"), "a stronger fallen record is not replaced by a living close call")
	var quiet := Army.new()
	root.add_child(quiet)
	quiet.setup(player, swarms)
	_check(quiet.raise_veteran(_veteran("Quiet", "campaign-quiet", swarm))
			and _standout_of(quiet.story_report()).is_empty(),
		"a named veteran with no deed and no close call is not a standout")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [quiet, army, swarm, player]: n.free()


## story_report's standout, whatever the fix's state: a missing or wrongly typed
## value must fail a check, never abort the coroutine on a missing key.
func _standout_of(report: Dictionary) -> Dictionary:
	var value: Variant = report.get("standout")
	return value if value is Dictionary else {}


## The merged soul entry: the accepted soul-funded binding and upstream Requiem
## overflow have to coexist on one pickup, and a protected named army must not
## be displaced for a champion soul.
func _test_combined_soul_entry() -> void:
	var player := _fresh_player()
	player.stats.soul_cost = 3
	var grunt := _fixture_swarm(Vector2(9, 0))
	var tyrant := _fixture_swarm(Vector2(9, 3))
	tyrant.boss = true
	tyrant.step(0.0, Vector2.ZERO)
	var swarms: Array[EnemySwarm] = [grunt, tyrant]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	var bound: Array[String] = []
	var rallies: Array[String] = []
	army.soul_bound.connect(func(kind: String) -> void: bound.append(kind))
	army.raised.connect(func(kind: String) -> void: rallies.append(kind))

	# A pickup with room binds once and never feeds Requiem.
	army.souls = player.stats.soul_cost - 1
	army._votes[0] = 1
	army.collect_soul(1)
	_check(army.count == 1 and bound.size() == 1 and rallies.size() == 1,
		"a normal soul with room binds exactly once")
	_check(int(army.story_report().get("raised", -1)) == 1 and army.dance.meter == 0,
		"the binding counts as one rally and charges no Requiem")

	# The same pickup at capacity banks its soul and charges the meter.
	player.stats.minion_max = 1
	var souls_before := army.souls
	var meter_before := army.dance.meter
	army.collect_soul(1)
	_check(army.count == 1 and army.souls == souls_before + 1, "a pickup at capacity still banks its soul")
	_check(army.dance.meter == meter_before + 1, "and charges one Requiem point")

	# A successful champion binding is still exactly one binding.
	player.stats.minion_max = 4
	army.collect_soul(101)
	_check(bound.size() == 2 and rallies.size() == 2 and army._elite[army.count - 1] == 1,
		"a successful elite binding emits soul_bound once")
	var boss_army := Army.new()
	root.add_child(boss_army)
	boss_army.setup(player, swarms)
	var boss_bound: Array[String] = []
	boss_army.soul_bound.connect(func(kind: String) -> void: boss_bound.append(kind))
	boss_army.collect_soul(202)
	_check(boss_bound.size() == 1 and boss_army.count == 1 and boss_army._elite[0] == 2,
		"a successful boss binding emits soul_bound once")
	_check(boss_army.dance.meter == 0, "a successful boss binding charges no Requiem")

	# A rejected champion binding against a protected named army overflows
	# instead: meter up, no signal, no rally, no displacement.
	var protected := Army.new()
	root.add_child(protected)
	protected.setup(player, swarms)
	player.stats.minion_max = 1
	_check(protected.raise_veteran(_veteran("Protected", "campaign-protected", grunt)),
		"the protected fixture deploys a named veteran")
	var protected_bound: Array[String] = []
	var protected_rallies: Array[String] = []
	protected.soul_bound.connect(func(kind: String) -> void: protected_bound.append(kind))
	protected.raised.connect(func(kind: String) -> void: protected_rallies.append(kind))
	var protected_meter := protected.dance.meter
	var protected_rallies_before := protected_rallies.size()
	var protected_raised := int(protected.story_report().get("raised", -1))
	protected.collect_soul(101)
	_check(protected.dance.meter == protected_meter + 1, "a rejected elite binding charges the Requiem meter")
	_check(protected_bound.is_empty() and protected_rallies.size() == protected_rallies_before
			and int(protected.story_report().get("raised", -1)) == protected_raised,
		"a rejected elite binding emits no binding and no rally")
	protected.collect_soul(201)
	_check(protected.dance.meter == protected_meter + 2, "a rejected boss binding charges the meter too")
	_check(protected_bound.is_empty() and protected_rallies.size() == protected_rallies_before,
		"and the rejected boss binding emits nothing either")
	_check(protected.count == 1 and protected._rank[0] == 1 and protected._vname[0] == "Protected",
		"the protected veteran is neither displaced nor renamed")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [protected, boss_army, army, tyrant, grunt, player]: n.free()


## The merged dance strike: one real strike credits its own dancer's counters,
## the army total and a promotion exactly once, under the Danse Macabre label.
func _test_dance_strike_credit() -> void:
	var player := _fresh_player()
	var swarm := _make_swarm(Vector2(0, 0))
	swarm.max_hp = 10.0
	swarm.hp[0] = 1.0
	var swarms: Array[EnemySwarm] = [swarm]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	var rising := _veteran("Rising", "campaign-rising", swarm)
	rising["deeds"] = Army.RANKS[2]["kills"] - 1
	_check(army.raise_veteran(rising) and army._rank[0] == 1 and army._deeds[0] == Army.RANKS[2]["kills"] - 1,
		"the dancer is a returning veteran one kill below promotion")
	_check(army._raise(0, false, false) and army._raise(0, false, false), "the dance fixture raises two more minions")
	var promotions: Array[String] = []
	army.promoted.connect(func(text: String) -> void: promotions.append(text))
	army.dance.meter = DanseMacabre.MAX
	_check(army.start_dance(), "a full Requiem meter starts the dance")
	_check(army._target_id[0] == -1, "the dance clears the dancers' target ids")
	# One real tick: the ring advances, then the strike lands. Put a killable
	# enemy where dancer 0 will be, using the same public slot maths.
	var hero: Vector2 = player.pos2
	var step := DanseMacabre.TICK
	var angle := DanseMacabre.SPEED_START * step
	var ring := DanseMacabre.RADIUS_START + (DanseMacabre.RADIUS_END - DanseMacabre.RADIUS_START) * (step / DanseMacabre.DURATION)
	swarm.pos[0] = DanseMacabre.slot(0, army.count, hero, angle, ring)
	swarm.step(0.0, hero)
	army._pos[0] = hero
	var ledger_before: float = float(Elements.damage_by.get(DanseMacabre.SOURCE, 0.0))
	var kills_before: int = int(army.story_report().get("kills", -1))
	army.step(step)
	_check(army._mission_kills[0] == 1 and army._deeds[0] == Army.RANKS[2]["kills"],
		"the strike credits the dancer's own mission and lifetime kills")
	_check(int(army.story_report().get("kills", -1)) == kills_before + 1,
		"the dance kill reaches the army total exactly once")
	_check(army._rank[0] == 2 and int(army.story_report().get("promotions", -1)) == 1 and promotions.size() == 1,
		"the strike promotes its dancer exactly once")
	_check(float(Elements.damage_by.get(DanseMacabre.SOURCE, 0.0)) > ledger_before,
		"the strike's damage is credited to Danse Macabre")
	_check(Elements.source == "Soul Army", "the damage source is restored after the strike")
	var standout := _standout_of(army.story_report())
	_check(standout.get("name", "") == "Rising" and standout.get("kills", -1) == 1 and standout.get("returning") == true,
		"the standout states this mission's one kill, not the old deeds")
	Elements.player = null
	Elements.swarms = []
	for n: Node in [army, swarm, player]: n.free()


## The merged dance boundary: real contact during the dance costs no HP and
## invents no close call, and ordinary targeting resumes with the ward link
## either intact or cleared, while normal contact resumes after expiry.
func _test_dance_contact_and_priority() -> void:
	var player := _fresh_player()
	player.stats.minion_max = 4
	var near := _make_swarm(Vector2(2, 0))
	near.max_hp = 10.0
	near.radius = 3.0
	near.contact_dps = 1000.0
	near.hp[0] = 1.0e9
	near.step(0.0, Vector2.ZERO)
	var ward := _fixture_swarm(Vector2(5, 0))
	ward.hp[0] = 1.0e9
	var swarms: Array[EnemySwarm] = [near, ward]
	var army := Army.new()
	root.add_child(army)
	army.setup(player, swarms)
	Elements.player = player
	Elements.swarms = swarms
	army.stance = "swarm"
	var raised := true
	for i in 3:
		raised = army._raise(0, false, false) and raised
	_check(raised and army.count == 3, "the dance fixture raises three minions")
	army.set_priority_target(ward)
	army._pos[0] = Vector2(4, 0)
	army._find_target(0, Vector2(4, 0), Vector2.ZERO)
	_check(army._target_swarm[0] == swarms.find(ward), "the ward is a reachable priority before the dance")

	var hero: Vector2 = player.pos2
	var step := DanseMacabre.TICK
	var angle := DanseMacabre.SPEED_START * step
	var ring := DanseMacabre.RADIUS_START + (DanseMacabre.RADIUS_END - DanseMacabre.RADIUS_START) * (step / DanseMacabre.DURATION)
	army.dance.meter = DanseMacabre.MAX
	_check(army.start_dance(), "the dance starts with a full meter and three minions")
	_check(army._target_id[0] == -1, "the dance clears the dancers' target ids")
	army._hp[0] = army._max_hp[0] * 0.1
	army._close_call[0] = 0
	army._pos[0] = hero
	near.pos[0] = DanseMacabre.slot(0, army.count, hero, angle, ring)
	near.step(0.0, hero)
	var hp_before: float = army._hp[0]
	army.step(step)
	_check(near.contact_load(army._pos[0], near.radius) > 0.0, "the dancer really is in enemy contact while dancing")
	_check(army.dance.active and army._hp[0] == hp_before and army._close_call[0] == 0,
		"dancing through real contact loses no HP and invents no close call")

	# Expiry: a still-valid ward is reacquired by ordinary targeting.
	near.contact_dps = 0.0
	var frames := 0
	while army.dance.active and frames < 80:
		army.step(step)
		frames += 1
	_check(not army.dance.active and frames < 80, "the dance ends on its own")
	_check(army.dance.meter == 0, "the spent Requiem meter is empty")
	near.pos[0] = Vector2(3, 0)
	ward.pos[0] = Vector2(6, 0)
	near.step(0.0, hero)
	ward.step(0.0, hero)
	army._pos[0] = Vector2(4, 0)
	army._retarget[0] = 0.0
	army.step(step)
	_check(army._target_swarm[0] == swarms.find(ward), "ordinary AI reacquires the still-valid ward after the dance")
	_check(army.stance == "swarm" and army._priority_target == ward, "the dance clears neither the ward nor the stance")

	# A ward cleared mid-dance stays cleared after it.
	army.dance.meter = DanseMacabre.MAX
	_check(army.start_dance(), "a second dance starts")
	army.set_priority_target(null)
	_check(army._priority_target == null, "the ward link is cleared during the dance")
	frames = 0
	while army.dance.active and frames < 80:
		army.step(step)
		frames += 1
	_check(not army.dance.active, "the second dance ends on its own")
	_check(army._priority_target == null and army.stance == "swarm", "the dance restores no cleared ward and changes no stance")
	near.pos[0] = Vector2(2, 0)
	ward.pos[0] = Vector2(5, 0)
	near.step(0.0, hero)
	ward.step(0.0, hero)
	army._pos[0] = Vector2(1, 0)
	army._retarget[0] = 0.0
	army.step(step)
	_check(army._target_swarm[0] == swarms.find(near), "ordinary AI picks the nearest enemy once the ward is cleared")

	# The dance is over: the same enemy can wound again. The other minions wait
	# clear of it, so the loss is unambiguous.
	near.contact_dps = 1000.0
	for j in range(1, army.count):
		army._pos[j] = Vector2(0, 20)
	army._pos[0] = near.pos[0]
	army._hp[0] = army._max_hp[0] * 0.1
	army._hurt[0] = 0.0
	army.step(step)
	_check(army.count == 2, "normal contact damage resumes once the dance ends (count=%d)" % army.count)
	Elements.player = null
	Elements.swarms = []
	for n: Node in [army, ward, near, player]: n.free()


func _fresh_player() -> Player:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.stats.minion_max = 4
	player.stats.minion_hp = 100.0
	player.stats.minion_damage = 10.0
	return player


func _fixture_swarm(at: Vector2) -> EnemySwarm:
	var swarm := _make_swarm(at)
	swarm.max_hp = 10.0
	swarm.step(0.0, Vector2.ZERO)
	return swarm


func _veteran(vet_name: String, campaign_id: String, swarm: EnemySwarm) -> Dictionary:
	return {"swarm": swarm.name, "name": vet_name, "deeds": 300, "rank": 1, "campaign_id": campaign_id, "elite": 0}

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: " + message)

func _make_swarm(at: Vector2) -> EnemySwarm:
	var swarm := EnemySwarm.new()
	swarm.capacity = 8
	root.add_child(swarm)
	swarm.spawn(at)
	swarm.step(0.0, Vector2.ZERO)
	return swarm
