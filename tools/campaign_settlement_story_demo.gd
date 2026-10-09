extends SceneTree
## Safe, direct story sampler. Each selection starts a fresh throwaway campaign
## checkpoint; account progression and the player's normal campaign are untouched.

const Stories = preload("res://scripts/campaign/campaign_stories.gd")

var _picker: CanvasLayer
var _self_test := false
var _demo_save_path := ""

func _initialize() -> void:
	call_deferred("_show_picker")

func _show_picker() -> void:
	MetaProgress.disabled = true
	CampaignTown.walk_mode = 1
	Landmarks.ensure_input()
	Controls.apply()
	var story_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--self-test": _self_test = true
		elif arg.begins_with("--story="): story_id = arg.trim_prefix("--story=")
	if _self_test and story_id == "": story_id = "whitepass"
	if story_id != "":
		var encounter := _encounter(story_id)
		if encounter.is_empty():
			push_error("Unknown story id. Choose mara, whitepass, sledwright, or redwake.")
			quit(2)
			return
		_launch(int(encounter["biome"]), int(encounter["stage"]), story_id)
		if _self_test: _verify_shell.call_deferred(story_id)
		return
	var page := CanvasLayer.new()
	page.name = "SettlementStoryDemoPicker"
	root.add_child(page)
	_picker = page
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.035, 0.052, 0.96)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.theme = UiStyle.theme()
	page.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(500, 0)
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := UiStyle.label(30)
	title.text = "SETTLEMENT STORIES"
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	column.add_child(title)
	var note := UiStyle.label(17)
	note.text = "Choose a stop to walk, speak, and continue into the real campaign scene. Each visit uses a fresh isolated save; account progression is disabled."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	for encounter: Dictionary in [
		{"label": "Mara · Gravediggers' Camp", "story": "mara", "biome": 0, "stage": 1},
		{"label": "Hessa · Whitepass Refuge", "story": "whitepass", "biome": 1, "stage": 0},
		{"label": "Elian · Sledwright's Rest", "story": "sledwright", "biome": 1, "stage": 1},
		{"label": "Juno · Redwake Caravan", "story": "redwake", "biome": 2, "stage": 1},
	]:
		var button := Button.new()
		button.text = str(encounter["label"])
		button.custom_minimum_size.y = 48
		button.pressed.connect(_launch.bind(int(encounter["biome"]), int(encounter["stage"]), str(encounter["story"])))
		column.add_child(button)
	var hint := UiStyle.label(14)
	hint.text = "WASD move · Use interact · Esc back · Save & Leave exits"
	hint.modulate = Color(1, 1, 1, 0.72)
	column.add_child(hint)
	if column.get_child_count() > 2:
		(column.get_child(2) as Button).grab_focus()


func _encounter(story_id: String) -> Dictionary:
	for encounter: Dictionary in [
		{"label": "Mara · Gravediggers' Camp", "story": "mara", "biome": 0, "stage": 1},
		{"label": "Hessa · Whitepass Refuge", "story": "whitepass", "biome": 1, "stage": 0},
		{"label": "Elian · Sledwright's Rest", "story": "sledwright", "biome": 1, "stage": 1},
		{"label": "Juno · Redwake Caravan", "story": "redwake", "biome": 2, "stage": 1},
	]:
		if str(encounter["story"]) == story_id: return encounter
	return {}


func _verify_shell(story_id: String) -> void:
	for _frame in range(5): await process_frame
	var shell := current_scene as CampaignShell
	var ready: bool = shell != null and is_instance_valid(shell.controller) and shell.controller.state.get("phase", "") == "TOWN" and shell._view is CampaignTown
	if ready:
		var expected: String = {"mara": "waystop:hollow_graveyard:1", "whitepass": "waystop:frozen_wastes:0", "sledwright": "waystop:frozen_wastes:1", "redwake": "waystop:ember_rift:1"}[story_id]
		ready = str(CampaignWaystops.resolve(shell.controller.state).get("id", "")) == expected
		ready = ready and CampaignSave.path.begins_with("user://settlement_story_demos/") and MetaProgress.disabled
	if not ready:
		push_error("Direct story demo did not mount its isolated town scene cleanly.")
		quit(1)
		return
	print("SETTLEMENT_STORY_DEMO_SELF_TEST PASSED: %s town mounted from isolated save %s" % [story_id, CampaignSave.path])
	var save_path := CampaignSave.path
	var meta_path := MetaProgress.save_path
	current_scene.free()
	current_scene = null
	for path: String in [save_path, meta_path]:
		var absolute := ProjectSettings.globalize_path(path)
		for suffix in ["", ".bak", ".tmp", ".previous", ".rollback"]:
			if FileAccess.file_exists(absolute + suffix): DirAccess.remove_absolute(absolute + suffix)
	quit(0)

func _launch(biome: int, stage: int, story_id: String) -> void:
	var folder := "user://settlement_story_demos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := "%s/%s-%d.save" % [folder, story_id, Time.get_ticks_usec()]
	_demo_save_path = path
	CampaignSave.path = path
	MetaProgress.save_path = path.trim_suffix(".save") + ".meta"
	MetaProgress.disabled = true
	MetaProgress.load_save()
	var controller := CampaignController.new()
	root.add_child(controller)
	var seed_value := Time.get_ticks_usec()
	var created := controller.create("battlemage", seed_value)
	if not bool(created.get("ok", false)):
		push_error("Could not create the isolated demo checkpoint: " + str(created.get("error", "unknown error")))
		return
	var fixture := controller.snapshot()
	fixture["biome_index"] = biome
	fixture["graph"] = CampaignCatalog.route(seed_value, biome)
	fixture["cleared_nodes"] = []
	if stage > 0:
		var first: String = fixture["graph"]["start"][0]
		fixture["cleared_nodes"].append(first)
		if stage > 1:
			fixture["cleared_nodes"].append(fixture["graph"]["nodes"][first]["next"][0])
	fixture["phase"] = "TOWN"
	fixture["selected_node"] = ""
	fixture["stories"] = Stories.fresh()
	var committed := controller._commit(fixture)
	controller.free()
	if not bool(committed.get("ok", false)):
		push_error("Could not save the isolated demo checkpoint: " + str(committed.get("error", "unknown error")))
		return
	Realm.in_title = false
	Realm.daily = false
	CampaignShell.new_requested = false
	if is_instance_valid(_picker): _picker.visible = false
	var shell := (load("res://scenes/campaign.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	current_scene = shell
