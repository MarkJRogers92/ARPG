extends SceneTree
## Focused campaign guidance fixtures; no combat simulation or save access.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	Landmarks.ensure_input()
	var original_interact_events := InputMap.action_get_events("interact").duplicate()
	InputMap.action_erase_events("interact")
	var remapped_key := InputEventKey.new()
	remapped_key.physical_keycode = KEY_Q
	InputMap.action_add_event("interact", remapped_key)
	Controls._tags.clear()
	var remapped_interact := Controls.tag("interact")
	_check(remapped_interact == "[Q]" and CampaignGuidance.contract_action("breach", 1, false, false, false, false).contains("[Q]"),
			"interaction guidance follows a changed key binding")
	InputMap.action_erase_events("interact")
	for event: InputEvent in original_interact_events:
		InputMap.action_add_event("interact", event)
	Controls._tags.clear()
	var interact := Controls.tag("interact")
	_check(CampaignGuidance.contract_action("hunt", 0, false, false, false, false).contains("automatic"),
			"hunt guidance explains automatic extraction")
	_check(CampaignGuidance.contract_action("breach", 1, false, false, false, false).contains(interact),
			"breach guidance uses the current interact key")
	_check(CampaignGuidance.contract_action("breach", 3, false, false, false, false).contains("All seals closed"),
			"breach guidance changes after all seals are closed")
	_check(CampaignGuidance.contract_action("elite_hunt", 0, false, false, false, false).contains("5:00"),
			"elite guidance explains its arrival state")
	_check(CampaignGuidance.contract_action("elite_hunt", 0, true, false, false, false).contains("Defeat"),
			"elite guidance directs the player to the active target")
	_check(CampaignGuidance.contract_action("elite_hunt", 0, true, true, false, false).contains("survive"),
			"elite guidance changes when the target is defeated")
	_check(CampaignGuidance.contract_action("cursed_cache", 0, false, false, false, false).contains(interact),
			"cache guidance uses the remapped interact key")
	_check(CampaignGuidance.contract_action("finale", 0, false, false, false, false).contains("no interaction"),
			"finale guidance explains that the pre-arrival countdown needs no interaction")
	_check(CampaignGuidance.contract_action("finale", 0, false, false, false, true) == "",
			"finale contract guidance clears at guardian arrival")
	_check(CampaignGuidance.guardian_intro("lich").contains("make him invulnerable") and CampaignGuidance.guardian_intro("lich").contains("phylacteries"),
			"Lich arrival explains the phylactery ward")
	_check(CampaignGuidance.guardian_intro("colossus").contains("fracture lines"),
			"Colossus arrival explains fracture lines and exposure")
	_check(CampaignGuidance.guardian_intro("tyrant").contains("Lure each meteor"),
			"Tyrant arrival explains meteor luring")
	_check(CampaignGuidance.guardian_hint("lich", "", 0) == "",
			"Lich guidance stays quiet before the ward")
	_check(CampaignGuidance.guardian_hint("lich", "Soul ward! Shatter the phylacteries (2 left)", 0) == "Soul ward! Shatter the phylacteries (2 left)",
			"Lich guidance preserves the authoritative ward hint and count")
	_check(CampaignGuidance.guardian_hint("colossus", "", 4).contains("Step off"),
			"Colossus hint responds to forming fracture lines")
	_check(CampaignGuidance.guardian_hint("colossus", "EXPOSED!  Double damage", 0) == "EXPOSED!  Double damage",
			"Colossus guidance preserves the authoritative exposed-window hint")
	_check(CampaignGuidance.guardian_hint("tyrant", "Cinder seals shield him (3)  ·  lure his meteors onto them", 0) == "Cinder seals shield him (3)  ·  lure his meteors onto them",
			"Tyrant guidance preserves the authoritative seal count and meteor hint")
	_check(CampaignGuidance.guardian_hint("tyrant", "", 0) == "",
			"Tyrant hint clears after all seals break")
	_check(CampaignGuidance.guardian_intro("unknown") == "" and
			CampaignGuidance.guardian_hint("unknown", "", 0) == "",
			"unknown guardian data yields no invented advice")
	await _test_title_card_positions()
	await _test_objective_prompt_rendering()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 4 and args[0] == "--capture":
		await _capture_guidance(int(args[1]), int(args[2]), args[3], args[4] if args.size() > 4 else "guardian")
	print("CAMPAIGN GUIDANCE TESTS %s (%d checks)" % ["PASSED" if failures == 0 else "FAILED", checks])
	quit(0 if failures == 0 else 1)


func _test_title_card_positions() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	hud.title_card("Classic Guardian", "The realm's master has arrived.", Color.WHITE)
	_check(hud._title_card.offset_top == -300.0 and hud._title_card.offset_bottom == -190.0,
			"Classic title card keeps its original position")
	var old_tween := hud._title_tween
	await create_timer(0.3).timeout
	hud.title_card("Campaign Guardian", "A mechanic explanation.", Color.WHITE, true)
	_check(hud._title_card.offset_top == -140.0 and hud._title_card.offset_bottom == -70.0 and
		hud._title_main.get_theme_font_size("font_size") == 30,
		"campaign arrival card stays compact above the hero and objective guidance")
	_check(not old_tween.is_running() and hud._title_tween.is_running(),
			"a replacement campaign card cancels the earlier title tween")
	await create_timer(1.2).timeout
	_check(hud._title_main.text == "CAMPAIGN GUARDIAN" and hud._title_card.modulate.a > 0.5,
			"the earlier boss-card fade cannot hide the active campaign card")
	var prior_calm: Variant = MetaProgress.setting("calm")
	MetaProgress.settings["calm"] = true
	hud.title_card("Calm Arrival", "Contract context remains readable.", Color.WHITE, true)
	_check(hud._title_card.scale == Vector2.ONE,
			"calm campaign title cards avoid zoom motion")
	await create_timer(0.2).timeout
	_check(hud._title_card.scale == Vector2.ONE and hud._title_main.text == "CALM ARRIVAL",
			"calm card remains still after its alpha transition")
	MetaProgress.settings["calm"] = prior_calm
	hud.queue_free()
	await process_frame


func _test_objective_prompt_rendering() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var director := ExpeditionDirector.new()
	director.contract_id = "cursed_cache"
	director.cache_enabled = true
	director._player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(director._player)
	director._sites = [Vector2.ZERO]
	var prompt: Dictionary = director.interaction_prompt()
	hud.set_prompt(String(prompt.get("text", "")), prompt.get("color", Color.WHITE))
	_check(hud._prompt_label.visible and hud._prompt_label.text == prompt.get("text", "") and
			hud._prompt_label.get_theme_color("font_color") == prompt.get("color", Color.WHITE),
			"HUD displays the exact objective prompt text and color returned by the director")
	director._player.free()
	director.free()
	hud.queue_free()
	await process_frame


func _capture_guidance(width: int, height: int, output: String, variant: String) -> void:
	root.size = Vector2i(width, height)
	var container := SubViewportContainer.new()
	container.size = Vector2(width, height)
	container.stretch = false
	root.add_child(container)
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	capture_viewport.add_child(Hud.new())
	container.add_child(capture_viewport)
	var hud := capture_viewport.get_child(0) as Hud
	var wave: WaveDirector
	var director: ExpeditionDirector
	if variant == "objective":
		director = ExpeditionDirector.new()
		director.contract_id = "cursed_cache"
		director.cache_enabled = true
		director._player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
		root.add_child(director._player)
		director._sites = [Vector2.ZERO]
		var prompt: Dictionary = director.interaction_prompt()
		hud.set_expedition("Cursed cache: optional  ·  survive to 6:00", "02:18  /  06:00")
		hud.set_campaign_guidance("Optional risk: opening the cache summons guardians.")
		hud.set_prompt(String(prompt.get("text", "")), prompt.get("color", Color.WHITE))
		_check(hud._prompt_label.visible and hud._prompt_label.text == prompt.get("text", "") and
				hud._prompt_label.get_theme_color("font_color") == prompt.get("color", Color.WHITE),
			"720p objective fixture shows the exact director prompt and matching objective color")
	elif variant == "contract":
		hud.set_expedition("Seals: 1 / 3  ·  survive to 6:00", "02:18  /  06:00")
		hud.set_campaign_guidance(CampaignGuidance.contract_action("breach", 1, false, false, false, false))
	elif variant == "seal-deadline":
		wave = WaveDirector.new()
		wave.elapsed = 398.0
		director = ExpeditionDirector.new()
		director.contract_id = "breach"
		var breach: Dictionary = CampaignCatalog.CONTRACTS["breach"]
		director.duration = float(breach["duration"])
		director.deadline = float(breach["deadline"])
		director.seals = 1
		director._wave = wave
		hud.set_expedition(director.objective_text(), director.clock_text(wave.elapsed))
		hud.set_campaign_guidance(director.guidance_text())
	else:
		hud.set_expedition("Defeat the biome guardian", "SLAY THE LICH KING")
		hud.refresh_extras(12, 0.0, "The Lich King", 0.68)
		var mechanic_hint := "Soul ward! Shatter the phylacteries (2 left)"
		hud.set_bet("")
		hud.set_campaign_guidance(CampaignGuidance.guardian_hint("lich", mechanic_hint, 0))
		_check(hud._bet_label.text == "" and hud._campaign_guidance_label.text == mechanic_hint,
				"campaign guardian mechanic uses the new field line and leaves the legacy hint line clear")
	await process_frame
	await process_frame
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var image := capture_viewport.get_texture().get_image()
	if image.is_empty() or image.save_png(output) != OK:
		_check(false, "guidance screenshot saved at %s" % output)
	else:
		print("GUIDANCE SCREENSHOT %dx%d %s" % [width, height, output])
	if variant == "seal-deadline":
		director.free()
		wave.free()
	elif variant == "objective":
		director._player.free()
		director.free()
