extends SceneTree
## Army's mission report: the facts the camp recognizes after a night.
## Real-fixture coverage for the three loss/contribution paths the review found
## missing: an altar sacrifice, a Soulfire blast, and a zero-kill close call.

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
