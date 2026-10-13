extends SceneTree
## Try-on must match actual equip math, with no live state / item identity changes.
var checks := 0
var failures := 0
var main: Node
var output := ""
func _initialize() -> void:
	MetaProgress.disabled = true
	MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
	RunSave.path = "user://gear-impact-test.run"; RunSave.pending = {}
	Realm.in_title = false; Realm.daily = false
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1; push_error("FAIL: " + message)
func _state(s: PlayerStats) -> Dictionary:
	var d := {"mods":s._mods.duplicate(true),"powers":s.powers.duplicate(true),"innate":s.innate_powers.duplicate(true),"ranks":s.upgrade_levels.duplicate(true),"hp":s.hp}
	for key: String in PlayerStats.BASE:
		var field := key.trim_suffix("_rate") + "_cooldown" if key.ends_with("_rate") else key
		d[field] = GearImpact._value(s,field)
	return d
func _unit() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 931744
	for trial in 96:
		var stats := PlayerStats.new()
		var hero: Dictionary = HeroClass.CLASSES[HeroClass.ORDER[trial % HeroClass.ORDER.size()]]
		stats.add_mods("class",hero["mods"])
		for power: String in hero["powers"]: stats.innate_powers[power] = 1
		stats.add_mod("cap-fixture","crit_chance",PlayerStats.Op.ADD,0.99)
		stats.add_mod("cap-fixture","orbit_count",PlayerStats.Op.ADD,11.8)
		stats.add_mod("buff-fixture","armor",PlayerStats.Op.ADD,150)
		Upgrades.apply("aura",stats)
		var inventory := Inventory.new(stats)
		for slot: String in ItemData.SLOTS:
			inventory.pickup(ItemGenerator.generate_with(1+trial/4,trial%4,slot,rng))
		var candidate := ItemGenerator.generate_with(1+trial, (trial+1)%4,ItemData.SLOTS[trial%6],rng)
		inventory.pickup(candidate)
		stats.hp = stats.max_hp * 0.93
		var state := _state(stats)
		var items := inventory.to_dict().duplicate(true)
		var next_uid := Item._next_uid
		var signals := [0]
		inventory.changed.connect(func() -> void: signals[0] += 1)
		var predicted := inventory.preview_swap(candidate.slot,candidate)
		GearImpact.text(stats,predicted)
		check(_state(stats) == state and inventory.to_dict() == items and Item._next_uid == next_uid and signals[0] == 0, "preview never mutates live state, items, IDs or emits changes")
		inventory.equip(candidate)
		check(_state(stats) == _state(predicted), "swap preview matches actual equip across generated slots/rarities/caps/buffs")
		predicted = inventory.preview_swap(candidate.slot)
		inventory.unequip(candidate.slot)
		check(_state(stats) == _state(predicted), "removal preview matches actual unequip")
	var stats := PlayerStats.new()
	stats.innate_powers["stormstride"] = 1
	var inventory := Inventory.new(stats)
	var boots := Item.new(); boots.slot = "boots"; boots.power = "stormstride"
	inventory.pickup(boots)
	var preview := inventory.preview_swap("boots")
	check(preview.powers.has("stormstride") and not GearImpact.text(stats,preview).contains("LOSE POWER"), "removing duplicate gear power retains the innate effect")
	check(inventory.preview_swap("weapon",boots) == null and inventory.preview_swap("invalid") == null, "invalid slots/cross-slot previews are rejected")
	stats.add_mod("crit-cap","crit_chance",PlayerStats.Op.ADD,10.0); stats.recalculate()
	var ring := Item.new(); ring.slot = "ring"; ring.implicit.assign([{"stat":"crit_chance","op":PlayerStats.Op.ADD,"value":0.25}])
	preview = inventory.preview_swap("ring",ring)
	check(GearImpact.rows(stats,preview).all(func(row: Dictionary) -> bool:return row["key"] != "crit_chance"), "capped crit cannot display a fake effective gain")
	var neutral := Item.new();neutral.slot = "boots"
	preview = inventory.preview_swap("boots",neutral)
	var dash: Array = GearImpact.rows(stats,preview).filter(func(row: Dictionary) -> bool:return row["key"] == "dash_cooldown")
	check(dash.size() == 1 and not dash[0]["gain"], "slower dash cooldown is shown as a loss")
	stats=PlayerStats.new();inventory=Inventory.new(stats)
	Upgrades.apply("lightning",stats);stats.upgrade_levels["synergy_relay"]=1
	var helm:=Item.new();helm.slot="helm";helm.power="winter_crown";inventory.pickup(helm)
	preview=inventory.preview_swap("helm")
	check(GearImpact.text(stats,preview).contains("Link requirements lost") and GearImpact.text(stats,preview).contains("Frost Relay"), "gear removal warns when an owned link loses prerequisites")
	inventory.unequip("helm");preview=inventory.preview_swap("helm",helm)
	check(GearImpact.text(stats,preview).contains("Link ready"), "returning the gear shows restored owned-link prerequisites")
	stats.innate_powers["reaping"]=1;inventory.refresh_powers()
	var wand:=Item.new();wand.slot="weapon";wand.implicit.assign([{"stat":"bolt_damage","op":PlayerStats.Op.ADD,"value":4.0}])
	preview=inventory.preview_swap("weapon",wand)
	check(GearImpact.rows(stats,preview).all(func(row:Dictionary)->bool:return not String(row["key"]).begins_with("bolt_")), "Reaper preview hides a main attack the class does not fire")
	seed(88441);var expected_rng:=randi();seed(88441)
	var start:=Time.get_ticks_usec()
	for i in 1000:GearImpact.text(stats,inventory.preview_swap("helm",helm))
	print("GEAR PREVIEW 1000 iterations ms: ",float(Time.get_ticks_usec()-start)/1000.0)
	check(randi()==expected_rng,"repeated previews never consume gameplay RNG")

func _action(name: String) -> void:
	var ev := InputEventAction.new();ev.action=name;ev.pressed=true
	Input.parse_input_event(ev);await process_frame
	ev=InputEventAction.new();ev.action=name;ev.pressed=false
	Input.parse_input_event(ev);await process_frame
func _capture(name: String) -> void:
	if output == "": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"rendered "+name)
func _run() -> void:
	_unit()
	seed(77818)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main.set_process(false);await process_frame
	var player: Player = main._player
	var inventory := player.inventory
	var screen: InventoryScreen = main._inventory_screen
	var old := Item.new();old.slot="helm";old.name="Gravekeeper Cap";old.base_name="Cap";old.rarity=ItemData.Rarity.MAGIC
	old.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":60.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":20.0}])
	var candidate := Item.new();candidate.slot="helm";candidate.name="Eye of the Storm";candidate.base_name="Circlet";candidate.rarity=ItemData.Rarity.LEGENDARY;candidate.power="storm_eye"
	candidate.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":20.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":5.0}])
	inventory.pickup(old);player.stats.hp=145.0
	main._loot.drop(candidate,player.pos2)
	main._process(0.0)
	check(inventory.backpack.has(candidate) and inventory.equipped["helm"]==old,"real ground pickup carries occupied-slot candidate without silently equipping")
	await _action("inventory")
	check(paused and screen.is_open(),"normal inventory action pauses combat")
	screen._backpack_list.select(0);screen._backpack_list.item_selected.emit(0)
	check(screen._impact.text.contains("Chain Lightning") and screen._impact.text.contains("Unavailable") and screen._impact.text.contains("Health reduced on equip"),"preview exposes gained ability and real current-HP clamp")
	check(screen._impact.get_parsed_text().to_lower().contains("lightning damage") and screen._impact.get_parsed_text().contains("Inactive") and screen._impact.get_parsed_text().to_lower().contains("lightning chains"), "new ability does not imply previously active damage or chains")
	check(player.stats.hp==145.0 and player.stats.lightning_level==0,"browsing cannot heal/harm/grant the ability")
	await _capture("gear_impact_preview")
	check(screen._equip_button.get_global_rect().end.y <= root.get_visible_rect().size.y-8,"equip action stays on-screen")
	check(screen._detail_tabs.current_tab==0,"Build impact is immediately visible")
	screen._detail_tabs.get_tab_bar().grab_focus()
	await _action("ui_right")
	check(screen._detail_tabs.current_tab==1 and screen._details.is_visible_in_tree(),"keyboard/controller action switches to original item rolls")
	await _capture("gear_item_rolls")
	await _action("ui_left")
	check(screen._detail_tabs.current_tab==0,"tab navigation returns to impact")
	screen._impact.grab_focus()
	for i in 8: await _action("ui_down")
	check(screen._impact.get_v_scroll_bar().value > 0,"keyboard scroll reaches long build effects")
	await _action("ui_cancel")
	check(not paused and not screen.is_open() and inventory.equipped["helm"]==old,"canceling comparison resumes without any swap")
	for i in 2:
		await _action("inventory");await _action("ui_cancel")
	check(not paused and player.stats.hp==145.0,"repeated open/cancel is read-only")
	await _action("inventory")
	screen._backpack_list.item_selected.emit(0)
	var predicted := inventory.preview_swap("helm",candidate)
	screen._equip_button.pressed.emit()
	check(_state(player.stats)==_state(predicted) and player.stats.hp==120.0 and player.stats.lightning_level==1,"real Equip produces the exact preview including HP cap and ability")
	check(screen._selected_worn and screen._impact.text.contains("PREVIEW: UNEQUIP"),"after swap the panel clearly labels removal preview")
	await _capture("gear_after_equip")
	# A full backpack still allows swaps, but removing worn gear needs room.
	while not inventory.is_full():
		var filler:=Item.new();filler.slot="helm";filler.name="Spare hood";inventory.pickup(filler)
	screen._on_equipment_selected(ItemData.SLOTS.find("helm"))
	check(screen._equip_button.disabled and screen._impact.text.contains("Backpack full"),"full pack disables unequip with a visible reason")
	var count:=inventory.backpack.size();screen._on_equip_pressed()
	check(inventory.equipped["helm"]==candidate and inventory.backpack.size()==count,"duplicate/direct blocked action changes nothing")
	screen._on_backpack_selected(0)
	check(not screen._equip_button.disabled,"full pack can still exchange a carried item")
	await _capture("gear_full_pack")
	screen._equip_button.pressed.emit()
	check(inventory.equipped["helm"]==old and inventory.backpack.size()==Inventory.BACKPACK_SIZE,"full-pack exchange preserves count and original identity")
	# Campaign keeps its existing no-combat-discard rule.
	screen._campaign_combat=true;screen._on_backpack_selected(0)
	check(screen._discard_button.disabled,"campaign combat still protects banked gear")
	await _action("ui_cancel")
	var snapshot: Dictionary = main.capture()
	check(RunSave.write(snapshot),"equipped result saves with the existing schema")
	var saved:=RunSave.read();main.queue_free()
	for i in 4:await process_frame
	RunSave.pending=saved;main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false)
	await process_frame
	check(main._player.inventory.equipped["helm"].to_dict()==old.to_dict() and main._player.inventory.backpack.size()==Inventory.BACKPACK_SIZE,"fresh scene restores the actual choice, not any preview")
	main.queue_free();for i in 4:await process_frame
	print("GEAR IMPACT: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
