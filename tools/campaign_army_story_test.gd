extends SceneTree
## Camp-return recognition. Checks CampaignArmyStory's pure formatter and a real
## render of the pending-result screen. Pass --capture=<path.png> to save a
## native 720p result fixture for a local visual pass (needs a windowed renderer).

const CampaignArmyStory = preload("res://scripts/campaign/campaign_army_story.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_path := ""
	var width := 1280
	var height := 720
	for arg: String in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--width="):
			width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="):
			height = int(arg.trim_prefix("--height="))
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires a windowed renderer; run this test without --headless.")
		quit(2)
		return
	root.size = Vector2i(width, height)
	_test_earned_account()
	_test_standout_needs_a_deed()
	_test_unsettled_outcomes()
	_test_quiet_and_legacy_payloads()
	_test_malformed_payloads()
	await _test_town_render(capture_path)
	_report()


func _earned() -> Dictionary:
	return {
		"raised": 4,
		"kills": 11,
		"promotions": 1,
		"fallen_veterans": ["Sera", "Kell"],
		"standout": {"name": "Brann", "kills": 6, "rank": 3, "returning": true, "survived": true, "close_call": true},
	}


func _test_earned_account() -> void:
	var success := CampaignArmyStory.summary(_earned(), "success")
	check(success.contains("THE ARMY'S ACCOUNT"), "a won expedition shows the army's account")
	check(success.contains("4 allies rallied"), "allies rallied this mission are counted")
	check(success.contains("11 kills"), "the army's mission kills are counted")
	check(success.contains("1 promotion"), "promotions this mission are counted")
	check(success.contains("STANDOUT · Brann, a returning veteran"), "the returning standout is named with its origin")
	check(success.contains("cut down 6 enemies this mission"), "the standout's own mission kills are stated as a deed")
	check(success.contains("survived a close call"), "a surviving close call is stated")
	check(not success.contains("rank"), "the account stays a sentence, not a stat chain")
	check(success.contains("FALLEN · Sera, Kell"), "named losses are listed")
	check(not success.contains("bank") and not success.contains("reward"), "a won result claims no extra reward")
	var promoted_only := CampaignArmyStory.summary({"kills": 2, "promotions": 2}, "success")
	check(promoted_only == "THE ARMY'S ACCOUNT · 2 kills · 2 promotions", "multiple promotions read in the plural")
	var fresh := _earned()
	fresh["promotions"] = 0
	fresh["fallen_veterans"] = []
	(fresh["standout"] as Dictionary)["returning"] = false
	(fresh["standout"] as Dictionary)["close_call"] = false
	var fresh_text := CampaignArmyStory.summary(fresh, "success")
	check(fresh_text.contains("a newly bound ally"), "an explicit new ally reads as newly bound")
	check(fresh_text.contains("is still standing"), "a standout that survived unhurt is still standing")
	check(not fresh_text.contains("returning"), "a new ally is not called a returning veteran")
	check(not fresh_text.contains("FALLEN"), "no loss line prints when nobody was lost")
	var lost := _earned()
	lost["fallen_veterans"] = []
	(lost["standout"] as Dictionary)["survived"] = false
	(lost["standout"] as Dictionary)["close_call"] = false
	var lost_text := CampaignArmyStory.summary(lost, "success")
	check(lost_text.contains("fell on the road"), "a standout that died is stated as fallen")
	check(not lost_text.contains("forever") and not lost_text.contains("erased"), "a loss is never claimed to be erased")
	var single := CampaignArmyStory.summary({"standout": {"name": "Ivo", "kills": 1, "survived": true}}, "success")
	check(single.contains("cut down 1 enemy this mission"), "a single mission kill reads singular")


## A standout is an earned deed. Missing or wrongly typed optional fields must
## never invent a deed, an origin, a condition or a rank.
func _test_standout_needs_a_deed() -> void:
	check(CampaignArmyStory.summary({"standout": {"name": "Ghost"}}, "success") == "", "a named standout with no mission deed is not invented")
	check(CampaignArmyStory.summary({"standout": {"name": "Ghost", "kills": 0, "survived": true}}, "success") == "",
		"a zero-deed named survivor is not a standout")
	check(CampaignArmyStory.summary({"standout": {"name": "Ghost", "kills": 0, "survived": true, "close_call": "yes"}}, "success") == "",
		"a wrongly typed close call does not create a deed")
	check(CampaignArmyStory.summary({"standout": {"name": "Ghost", "kills": 0, "survived": "yes", "close_call": true}}, "success") == "",
		"a close call needs an explicit surviving bool")
	var close_call := CampaignArmyStory.summary({"standout": {"name": "Ivo", "kills": 0, "survived": true, "close_call": true}}, "success")
	check(close_call.contains("Ivo survived a close call"), "a zero-kill genuine close call is a real deed")
	check(not close_call.contains("newly bound") and not close_call.contains("returning"), "an unknown origin is not invented")
	var kills_only := CampaignArmyStory.summary({"standout": {"name": "Brann", "kills": 3}}, "success")
	check(kills_only.contains("Brann cut down 3 enemies this mission"), "a standout with only kills reads as one sentence")
	check(not kills_only.contains("still standing") and not kills_only.contains("fell"), "a missing survived flag states no condition")
	var typed_survived := CampaignArmyStory.summary({"standout": {"name": "Brann", "kills": 3, "survived": "yes"}}, "success")
	check(not typed_survived.contains("still standing") and not typed_survived.contains("fell"), "a wrongly typed survived flag states no condition")
	var unknown_origin := CampaignArmyStory.summary({"standout": {"name": "Brann", "kills": 3, "returning": "yes"}}, "success")
	check(not unknown_origin.contains("newly bound") and not unknown_origin.contains("returning veteran"),
		"an unknown origin is omitted, not invented as new")
	var absurd_rank := CampaignArmyStory.summary({"standout": {"name": "Brann", "kills": 3, "rank": 100000000, "survived": true}}, "success")
	check(not absurd_rank.contains("rank"), "an absurd rank is never printed as a real rank")
	var typed_rank := CampaignArmyStory.summary({"standout": {"name": "Brann", "kills": 3, "rank": "three"}}, "success")
	check(not typed_rank.contains("rank"), "a wrongly typed rank is ignored")


func _test_unsettled_outcomes() -> void:
	for outcome in ["failure", "retreat"]:
		var text := CampaignArmyStory.summary(_earned(), outcome)
		check(text.contains("STANDOUT · Brann"), "%s still tells the veteran's story" % outcome)
		check(text.contains("FALLEN ON THE ROAD"), "%s marks the loss as happening on the road" % outcome)
		check(not text.contains("bank"), "%s never claims the army was banked" % outcome)
		check(not text.contains("reward"), "%s never claims a reward" % outcome)
		check(not text.contains("forever") and not text.contains("erased"), "%s never claims the loss is erased" % outcome)


func _test_quiet_and_legacy_payloads() -> void:
	check(CampaignArmyStory.summary(null, "success") == "", "a missing army_story says nothing")
	check(CampaignArmyStory.summary({}, "failure") == "", "an empty army_story says nothing")
	check(CampaignArmyStory.summary({"raised": 0, "kills": 0, "promotions": 0, "fallen_veterans": [], "standout": {}}, "retreat") == "",
		"zero deeds say nothing on a retreat")
	check(CampaignArmyStory.summary({"summary": "The road is clear."}, "success") == "", "a legacy report summary is not an army story")
	check(CampaignArmyStory.summary("The road is clear.", "success") == "", "a legacy string payload says nothing")
	check(CampaignArmyStory.summary([1, 2], "success") == "", "an unexpected array payload says nothing")
	check(CampaignArmyStory.summary({"kills": 1}, "success") == "THE ARMY'S ACCOUNT · 1 kill", "one kill reads as a single kill")


func _test_malformed_payloads() -> void:
	check(CampaignArmyStory.summary({"raised": -3, "kills": -1, "promotions": -2}, "success") == "", "negative counts are ignored")
	check(CampaignArmyStory.summary({"raised": 2, "kills": INF, "promotions": NAN}, "success") == "THE ARMY'S ACCOUNT · 2 allies rallied",
		"non-finite counts are ignored")
	check(CampaignArmyStory.summary({"raised": "three", "kills": {}, "promotions": null, "fallen_veterans": "Sera", "standout": "Brann"}, "success") == "",
		"wrongly typed fields are ignored")
	check(CampaignArmyStory.summary({"kills": 3, "standout": {"name": 7, "kills": "many", "survived": "no"}}, "success") == "THE ARMY'S ACCOUNT · 3 kills",
		"a standout without a usable name is dropped")
	check(CampaignArmyStory.summary({"kills": 3, "standout": {"name": "", "kills": 5}}, "success") == "THE ARMY'S ACCOUNT · 3 kills",
		"an empty standout name is dropped")
	check(CampaignArmyStory.summary({"kills": 5.9}, "success") == "THE ARMY'S ACCOUNT · 5 kills", "a float count is floored")
	check(CampaignArmyStory.summary({"kills": 1.0e30}, "success") == "", "an absurd finite float count is ignored rather than cast")
	var long_text := CampaignArmyStory.summary({"standout": {"name": "Z".repeat(600), "kills": 2, "survived": true}}, "success")
	check(long_text.length() < 200, "an overlong name is bounded")
	check(not long_text.contains("Z".repeat(100)), "an overlong name is not printed in full")
	check(long_text.contains("…"), "an overlong name is visibly shortened")
	var many: Dictionary = {"fallen_veterans": []}
	for i in 500:
		many["fallen_veterans"].append("Name%d" % i)
	var many_text := CampaignArmyStory.summary(many, "failure")
	check(many_text.length() < 300, "an overlong loss list is bounded")
	check(many_text.contains("more"), "an overlong loss list counts the rest")


func _test_town_render(capture_path: String) -> void:
	var token := "army-story-%d" % Time.get_ticks_usec()
	CampaignSave.path = "user://%s.save" % token
	MetaProgress.save_path = "user://%s.meta" % token
	MetaProgress.disabled = true
	Landmarks.ensure_input()
	Controls.apply()
	var controller := CampaignController.new()
	root.add_child(controller)
	check(controller.create("battlemage", 712008).get("ok", false), "isolated campaign creates for the render check")
	var town := CampaignTown.new()
	root.add_child(town)
	town.setup(controller)
	await process_frame
	var state := controller.snapshot()
	state["phase"] = "RESULT_PENDING"
	state["result"] = {
		"outcome": "success", "elapsed": 300.0, "gold": 100, "shard_conversion": 5, "talent_points": 1,
		"report": {"summary": "The road is clear.", "army_story": _earned()},
	}
	town._on_changed(state)
	await process_frame
	var rendered := _content_copy(town)
	check(rendered.contains("THE ARMY'S ACCOUNT"), "the pending result screen renders the army account")
	check(rendered.contains("STANDOUT · Brann"), "the pending result screen names the standout for the player")
	check(rendered.contains("FALLEN · Sera, Kell"), "the pending result screen names the losses")
	if not capture_path.is_empty():
		for _frame in 6:
			await process_frame
		var viewport_texture := root.get_texture()
		check(viewport_texture != null, "capture has a viewport texture")
		if viewport_texture != null:
			var save_error := viewport_texture.get_image().save_png(capture_path)
			check(save_error == OK, "720p result fixture saves (%s)" % error_string(save_error))
	var bare := controller.snapshot()
	bare["phase"] = "RESULT_PENDING"
	bare["result"] = {"outcome": "failure", "elapsed": 90.0, "report": {"summary": "The attempt ended."}}
	town._on_changed(bare)
	await process_frame
	check(not _content_copy(town).contains("ARMY'S ACCOUNT"), "a legacy result without army_story renders no army account")
	town.queue_free()
	controller.queue_free()
	await process_frame


func _content_copy(town: CampaignTown) -> String:
	var text: Array[String] = []
	for child: Node in town._content.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label:
			text.append((child as Label).text)
	return "\n".join(text)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _report() -> void:
	if failures.is_empty():
		print("CAMPAIGN_ARMY_STORY_OK")
		quit(0)
	else:
		print("CAMPAIGN_ARMY_STORY_FAILED %d" % failures.size())
		quit(1)
