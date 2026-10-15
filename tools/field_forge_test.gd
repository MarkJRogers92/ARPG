extends SceneTree
## Actual Main/Landmarks transactions and UI; disposable profile only.
var checks := 0
var failures := 0
var main: Node
var player: Player
var forge: Landmarks
var output := ""
var physical := Vector2i(1280,720)
var video := false
var serial := 0
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;MetaProgress.settings["shake"]=false
	Realm.in_title=false;Realm.daily=false;Realm.current="ember"
	RunSave.pending={};RunSave.path="user://field-forge-test.run"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
		if arg=="--small":physical=Vector2i(1024,576)
		if arg=="--large":physical=Vector2i(1920,1080)
		if arg=="--video":video=true
	root.size=physical
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func action(id: String) -> void:
	var ev:=InputEventAction.new();ev.action=id;ev.pressed=true;Input.parse_input_event(ev);await process_frame
	ev=InputEventAction.new();ev.action=id;ev.pressed=false;Input.parse_input_event(ev);await process_frame
func capture_image(name: String) -> void:
	if output=="":return
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func hold(seconds: float) -> void:
	if not video:return
	for i in roundi(seconds*30):await process_frame
func original_weapon() -> Item:
	var item:=Item.new();item.name="Stormcaller's Scepter";item.base_name="Scepter";item.rarity=ItemData.Rarity.LEGENDARY;item.ilvl=12;item.power="stormcaller"
	item.implicit.assign([{"stat":"bolt_count","op":PlayerStats.Op.ADD,"value":1.0},{"stat":"bolt_damage","op":PlayerStats.Op.ADD,"value":8.0}])
	return item
func fresh() -> Item:
	paused=false;forge._cancel_forge();forge.campaign_mode=false;player.dead=false
	player.position=Vector3.ZERO;main._run_shards=24
	serial+=1
	# Real placed-record lookup and reach checks; location is controlled for regression.
	forge._decor.placed.clear()
	forge._decor.placed["forge"]=[Transform3D(Basis.IDENTITY,Vector3(float(serial % 8)*0.25,0,2+float(serial/8)*0.25))]
	var item:=original_weapon();player.inventory.replace_worn(item);player.stats.hp=player.stats.max_hp
	forge._rescan()
	return item
func inspect() -> bool:
	var queued:=forge.use_nearest()
	return queued and forge.offer_forge()
func press(id: String) -> void:forge._forge_panel.action_button(id).pressed.emit()
func new_main(saved: Dictionary={}) -> void:
	if main!=null:
		paused=false;main.queue_free()
		for i in 4:await process_frame
	Elements.player=null;Elements.swarms.clear();RunSave.pending=saved
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false)
	root.size=physical
	await process_frame
	check(root.size==physical,"actual window size matches "+str(physical))
	player=main._player;forge=main._landmarks;Obstacles.clear()
	for swarm: EnemySwarm in main._swarms:swarm.despawn_all()
func _run() -> void:
	seed(41391);await new_main()
	var old:=fresh();var uid:=Item._next_uid
	seed(99);var expected:=randi();seed(99)
	check(inspect() and paused,"explicit interaction queues and opens paused inspection")
	check(main._run_shards==24 and player.inventory.equipped.weapon==old and Item._next_uid==uid and randi()==expected,"inspection costs nothing, keeps item/IDs and consumes no RNG")
	await process_frame
	check(forge._forge_panel.action_button("leave").has_focus(),"free inspection defaults to Leave")
	check(forge._forge_panel._result.text.contains("8 Soul Shards") and forge._forge_panel._odds.text.contains("worsen"),"cost and risk appear before payment")
	await capture_image("Field_Forge_Inspect");await hold(2)
	await action("ui_cancel")
	check(not paused and not forge.is_used("forge",Vector2(float(serial % 8)*0.25,2+float(serial/8)*0.25)) and main._run_shards==24,"Escape before payment is free and reusable")
	forge._choose_forge("roll");check(main._run_shards==24,"stale closed action cannot charge")
	forge._rescan();check(inspect(),"inspection can be reopened before payment")
	var stale:=forge._forge_panel.action_button("roll")
	press("roll")
	var rolled: Item=forge._forge_offer.rolled
	uid=Item._next_uid
	check(main._run_shards==16 and forge.used_forges().size()==1 and forge.uses_made.forge==1,"one payment consumes eight shards and one forge")
	check(player.inventory.equipped.weapon==old and player.stats.hp==player.stats.max_hp,"paid roll does not mutate the original or live health")
	stale.pressed.emit()
	check(main._run_shards==16 and Item._next_uid==uid and forge._forge_offer.rolled==rolled,"old Roll button cannot charge or roll twice")
	check(not forge.use_nearest() and not forge.offer_forge(),"interaction cannot reopen an active paid offer")
	await process_frame
	check(forge._forge_panel.action_button("keep").has_focus(),"paid choice defaults to keeping the original")
	await action("ui_cancel")
	check(not paused and player.inventory.equipped.weapon==old and main._run_shards==16,"Escape after payment keeps original without refund")
	forge._rescan();check(not forge.use_nearest(),"return to spent forge cannot reroll")
	# Full pack acceptance + effective power/HP preview; controlled candidate makes losses explicit.
	old=fresh();inspect();press("roll")
	var candidate:=Item.new();candidate.name="Hydra Rod";candidate.base_name="Rod";candidate.rarity=ItemData.Rarity.LEGENDARY;candidate.power="splitting";candidate.ilvl=4
	candidate.implicit.assign([{"stat":"bolt_damage","op":PlayerStats.Op.ADD,"value":20.0},{"stat":"bolt_speed","op":PlayerStats.Op.INCREASED,"value":0.2}])
	forge._forge_offer.rolled=candidate
	forge._forge_panel.compare_weapon(player.inventory,player.stats,old,candidate)
	while not player.inventory.is_full():
		var filler:=Item.new();filler.slot="weapon";filler.name="Spare rod";player.inventory.pickup(filler)
	var bag:=player.inventory.backpack.duplicate();var predicted:=player.inventory.preview_swap("weapon",candidate)
	var rich:=forge._forge_panel._comparison
	check(rich.text.contains("Loses a power") and rich.text.contains("Bolt Count"),"actual impact warns about power loss and fewer projectiles")
	await process_frame
	check(forge._forge_panel.action_button("take").get_global_rect().end.y<root.get_visible_rect().size.y,"choice actions remain on-screen")
	await capture_image("Field_Forge_Choice");await hold(3)
	rich.grab_focus();for i in 8:await action("ui_down")
	check(rich.get_v_scroll_bar().max_value<=rich.size.y or rich.get_v_scroll_bar().value>0,"long impact details are keyboard scrollable")
	forge._forge_panel.action_button("take").grab_focus();await action("ui_accept")
	check(player.inventory.equipped.weapon==candidate and player.inventory.backpack==bag,"real accept input replaces only worn gear despite a full pack")
	check(is_equal_approx(player.stats.hp,predicted.hp) and is_equal_approx(player.stats.bolt_damage,predicted.bolt_damage) and player.stats.powers==predicted.powers,"acceptance matches effective stats, powers and HP preview")
	forge._choose_forge("take");check(main._run_shards==16 and player.inventory.backpack==bag,"duplicate accept cannot charge or duplicate gear")
	await hold(1)
	# Invalidated inspections cannot spend. Invalidated paid choices cannot overwrite a changed weapon.
	for invalid in ["shards","weapon","range"]:
		old=fresh();inspect()
		if invalid=="shards":main._run_shards=7
		if invalid=="weapon":player.inventory.replace_worn(original_weapon())
		if invalid=="range":player.position=Vector3(100,0,100)
		var balance: int=main._run_shards;uid=Item._next_uid;press("roll")
		check(main._run_shards==balance and Item._next_uid==uid and not paused,"invalid "+invalid+" inspection has no payment or roll")
	old=fresh();inspect();press("roll");var replacement:=original_weapon();player.inventory.replace_worn(replacement);press("take")
	check(player.inventory.equipped.weapon==replacement and main._run_shards==16,"invalidated paid result cannot overwrite a new equipped item")
	old=fresh();forge.campaign_mode=true;check(not forge.use_nearest(),"campaign continues to use its town forge")
	old=fresh();check(forge.use_nearest(),"request queues without mid-frame pause");paused=true
	check(not forge.offer_forge() and not forge._forge_request.is_empty(),"other modal delays inspection without stacking")
	paused=false;check(forge.offer_forge(),"queued inspection opens when other modal closes");press("leave")
	# Main's actual input/end-of-frame route, insufficient funds and modal ownership.
	old=fresh();main._run_shards=7;check(inspect(),"free inspection works even without enough shards")
	check(forge._forge_panel.action_button("roll").disabled,"insufficient funds disable the paid action")
	press("roll");check(main._run_shards==7 and forge._forge_offer.phase=="inspect","disabled button cannot spend or close inspection")
	press("leave")
	old=fresh();Input.action_press("interact");main._process(0.0);Input.action_release("interact")
	check(paused and forge._forge_panel.is_open(),"normal Main interact opens forge only after end-of-frame arbitration")
	await action("inventory");check(forge._forge_panel.is_open() and not main._inventory_screen.is_open(),"inventory input cannot stack another modal over the choice")
	press("roll");var accepted: Item=forge._forge_offer.rolled;press("take")
	var accepted_data:=accepted.to_dict().duplicate(true);var accepted_keys: Array[String]=forge.used_forges()
	check(RunSave.write(main.capture()),"accepted choice saves normally");await new_main(RunSave.read())
	check(main._run_shards==16 and player.inventory.equipped.weapon.to_dict()==accepted_data and forge.used_forges()==accepted_keys,"accepted weapon, fee and spent keys survive a fresh scene")
	# Integrated flow: paid forge, Nearby collection/equip, then one shared disk snapshot.
	var forged: Item=player.inventory.equipped.weapon
	var loot_reward:=ItemGenerator.generate_with(18,ItemData.Rarity.LEGENDARY,"weapon")
	var ground: LootDrop=main._loot.drop(loot_reward,player.pos2)
	await action("inventory")
	var gear: InventoryScreen=main._inventory_screen
	check(paused and gear.is_open() and (forge._forge_panel==null or not forge._forge_panel.is_open()),"completed forge transitions cleanly into Nearby inventory")
	gear._source_tabs.current_tab=1;gear._on_nearby_selected(gear._nearby_drops.find(ground))
	check(gear._equip_button.disabled and player.inventory.equipped.weapon==forged,"full-pack Nearby comparison preserves accepted forge weapon")
	gear._source_tabs.current_tab=0;gear._on_backpack_selected(0);gear._on_discard_pressed()
	gear._source_tabs.current_tab=1;gear._on_nearby_selected(gear._nearby_drops.find(ground));gear._on_equip_pressed()
	check(player.inventory.backpack.count(loot_reward)==1 and player.inventory.equipped.weapon==forged,"Nearby collects once after forge without silently replacing forged gear")
	gear._source_tabs.current_tab=0;gear._on_backpack_selected(player.inventory.backpack.find(loot_reward));gear._on_equip_pressed()
	check(player.inventory.equipped.weapon==loot_reward and player.inventory.backpack.count(forged)==1,"explicit Nearby equip retains the forged weapon once in the backpack")
	await action("ui_cancel")
	var combined_gear:=player.inventory.to_dict().duplicate(true)
	check(not paused and RunSave.write(main.capture()),"combined gear and paid forge save together after modal closes")
	await new_main(RunSave.read())
	check(player.inventory.to_dict()==combined_gear and main._run_shards==16 and forge.used_forges()==accepted_keys,"combined disk resume preserves all gear, one fee and spent forge identities")
	# Long names preserve visible, reachable choices rather than widening the panel.
	old=fresh();inspect();press("roll")
	var long_item: Item=forge._forge_offer.rolled
	long_item.name="Emberglass Rod of the Long Forgotten Keepers Beneath the Ashen Mountain"
	forge._forge_panel.compare_weapon(player.inventory,player.stats,old,long_item)
	await process_frame
	forge._forge_panel.action_button("take").grab_focus();await process_frame
	var button:=forge._forge_panel.action_button("take").get_global_rect()
	check(button.position.x>=0 and button.end.x<=root.get_visible_rect().size.x and button.end.y<=root.get_visible_rect().size.y,"long item names leave action fully visible at physical "+str(physical))
	await capture_image("Field_Forge_Long_Text")
	press("keep")
	# Paid-but-undecided snapshot is safe even for an external interruption: original + fee + spent key.
	old=fresh();inspect();press("roll");var paid_key: String=forge._forge_offer.key
	var snapshot: Dictionary=main.capture();check(RunSave.write(snapshot),"paid pending transaction writes via normal run schema")
	var saved:=RunSave.read();var old_data:=old.to_dict().duplicate(true)
	await new_main(saved)
	check(main._run_shards==16 and player.inventory.equipped.weapon.to_dict()==old_data and forge.used_forges().has(paid_key),"disk resume retains original, single fee and spent forge")
	var parts:=paid_key.split("|");var at:=Vector2(float(parts[1])/4.0,float(parts[2])/4.0)
	check(forge.is_used("forge",at) and forge._forge_offer.is_empty(),"resume cannot regenerate a paid roll")
	forge.restore_used_forges([paid_key,paid_key,"bell|1|2","forge|x|2",42]);check(forge.used_forges()==[paid_key],"optional save data rejects duplicates and malformed forge keys")
	forge.restore_used_forges([]);check(not forge.is_used("forge",at),"fresh/legacy restore clears previous forge-only state")
	saved.erase("used_field_forges");await new_main(saved);check(forge.used_forges().is_empty(),"legacy v1 snapshot still loads")
	# Real death signal cancels the offer and never equips the unaccepted roll.
	old=fresh();inspect();press("roll");player.stats.hp=1;player.invulnerable=false;player.shield_left=0
	player.take_damage(1.0e6,"Forge test")
	check(player.dead and main._game_over and not paused and not forge._forge_panel.is_open() and forge._forge_offer.is_empty(),"fatal interruption closes pending UI through real player death")
	forge._choose_forge("take");check(player.inventory.equipped.weapon==old and main._run_shards==16,"death cannot accept a stale rolled item or refund fee")
	paused=false;Engine.time_scale=1.0;main.queue_free();for i in 4:await process_frame
	RunSave.clear()
	print("FIELD FORGE: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
