extends SceneTree
var checks:=0
var failures:=0
var main: Node
var player: Player
var inv: Inventory
var loot: LootManager
var ui: InventoryScreen
var output:=""
var size:=Vector2i(1280,720)
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	Realm.in_title=false;Realm.daily=false;RunSave.pending={};RunSave.path="user://nearby-loot-test.run"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
		if arg=="--small":size=Vector2i(1024,576)
		if arg=="--large":size=Vector2i(1920,1080)
	_run.call_deferred()
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+why)
func action(id: String) -> void:
	var ev:=InputEventAction.new();ev.action=id;ev.pressed=true;Input.parse_input_event(ev);await process_frame
	ev=InputEventAction.new();ev.action=id;ev.pressed=false;Input.parse_input_event(ev);await process_frame
func capture_image(name: String) -> void:
	if output=="":return
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func choose_ground(node: LootDrop) -> void:
	ui._source_tabs.current_tab=1
	var index:=ui._nearby_drops.find(node)
	if index>=0:ui._nearby_list.select(index);ui._on_nearby_selected(index)
func _run() -> void:
	seed(41391);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main.set_process(false);await process_frame;root.size=size;await process_frame
	player=main._player;inv=player.inventory;loot=main._loot;ui=main._inventory_screen
	check(root.size==size,"verified window size "+str(size))
	var old:=ItemGenerator.generate_with(4,ItemData.Rarity.RARE,"weapon");inv.replace_worn(old)
	while not inv.is_full():inv.pickup(ItemGenerator.generate_with(3,ItemData.Rarity.MAGIC,"weapon"))
	var reward:=ItemGenerator.generate_with(12,ItemData.Rarity.LEGENDARY,"weapon")
	var node:=loot.drop(reward,player.pos2)
	main._process(0.0)
	var inventory_before:=inv.to_dict().duplicate(true)
	await action("inventory")
	check(paused and ui.is_open() and loot.drops.has(node),"normal inventory opens while full and leaves nearby loot on ground")
	ui._source_tabs.get_tab_bar().grab_focus();await action("ui_right")
	check(ui._source_tabs.current_tab==1 and ui._selected==reward and ui._selected_drop==node,"keyboard opens Nearby and previews the selected drop")
	check(ui._equip_button.text=="Collect" and ui._equip_button.disabled and ui._discard_button.disabled,"full pack disables collection and ground discard")
	check(ui._impact.text.contains("Free one space") and ui._nearby_hint.text.contains("not saved"),"capacity action and ground-loot save limitation are explicit")
	check(inv.to_dict()==inventory_before and ui._impact.text.contains("IF EQUIPPED AFTER COLLECTION"),"preview explains future equip without changing gear")
	await capture_image("Nearby_Loot_Full")
	ui._on_equip_pressed();ui._on_discard_pressed()
	check(inv.to_dict()==inventory_before and loot.drops.has(node),"direct full/ground discard actions cannot lose items")
	await action("ui_cancel");check(not paused and loot.drops.has(node),"cancel resumes without taking or deleting the reward")
	await action("inventory");check(ui._source_tabs.current_tab==1 and ui._nearby_list.has_focus(),"reopen restores visible Nearby focus")
	ui._source_tabs.current_tab=0
	ui._on_backpack_selected(0);var discarded: Item=inv.backpack[0]
	ui._on_discard_pressed()
	check(inv.backpack.size()==23 and not inv.backpack.has(discarded) and loot.drops.has(node),"only explicitly selected carried item is discarded")
	choose_ground(node)
	check(not ui._equip_button.disabled and ui._impact.text.contains("stores it in your backpack"),"free space allows chosen pickup without promising automatic equip")
	await capture_image("Nearby_Loot_Ready")
	var reentry:=[]
	var callback:=func() -> void:reentry.append(loot.collect(node,player.pos2,player.stats.pickup_radius,inv));ui._on_equip_pressed();ui._on_discard_pressed();ui._on_upgrades_pressed()
	inv.changed.connect(callback)
	ui._equip_button.grab_focus();await action("ui_accept")
	inv.changed.disconnect(callback)
	check(inv.backpack.size()==24 and inv.backpack.count(reward)==1 and inv.equipped.weapon==old and not is_instance_valid(node),"selected loot enters backpack once, leaving worn item unchanged")
	check(reentry==["gone"] and ui._equip_button.disabled and ui._selected==null,"signal reentry and repeated action cannot collect twice or auto-equip")
	ui._on_equip_pressed();check(inv.equipped.weapon==old and inv.backpack.count(reward)==1,"second Collect gesture cannot turn into Equip")
	await capture_image("Nearby_Loot_Collected")
	ui._source_tabs.current_tab=0;ui._on_backpack_selected(inv.backpack.find(reward))
	var predicted:=inv.preview_swap("weapon",reward)
	ui._on_equip_pressed()
	check(inv.equipped.weapon==reward and inv.backpack.has(old) and is_equal_approx(player.stats.bolt_damage,predicted.bolt_damage),"separate explicit equip matches existing build preview and preserves old weapon")
	# Reach, empty-slot pickup at capacity, stale/trimmed handles, and campaign protection.
	var helm:=ItemGenerator.generate_with(3,ItemData.Rarity.RARE,"helm");var helmet:=loot.drop(helm,player.pos2)
	ui._refresh();choose_ground(helmet)
	check(not ui._equip_button.disabled and ui._impact.text.contains("equips this empty slot"),"empty slot retains normal auto-equip rule even with a full pack")
	ui._on_equip_pressed();check(inv.equipped.helm==helm and inv.backpack.size()==24,"empty-slot collection doesn't consume or lose a backpack item")
	var far:=loot.drop(ItemGenerator.generate_with(1,0,"weapon"),player.pos2+Vector2(30,0))
	check(not loot.nearby(player.pos2,player.stats.pickup_radius).has(far) and loot.collect(far,player.pos2,player.stats.pickup_radius,inv)=="far","out-of-range loot cannot be inspected or remotely collected")
	inv.discard(inv.backpack[0])
	var gone:=loot.drop(ItemGenerator.generate_with(1,0,"weapon"),player.pos2)
	ui._refresh();choose_ground(gone);var count:=inv.backpack.size();loot.drops.erase(gone);gone.queue_free()
	await process_frame;ui._on_equip_pressed()
	check(inv.backpack.size()==count and ui._selected==null,"freed/trimmed selected drop cannot mutate inventory")
	var shifted:=loot.drop(ItemGenerator.generate_with(1,0,"weapon"),player.pos2)
	ui._refresh();choose_ground(shifted);player.position.x+=20;ui._on_equip_pressed()
	check(loot.drops.has(shifted) and inv.backpack.size()==count and ui._selected==null,"position revalidation rejects stale nearby selection")
	player.position.x-=20;ui._refresh();choose_ground(shifted);player.dead=true;ui._on_equip_pressed();player.dead=false
	check(loot.drops.has(shifted) and inv.backpack.size()==count,"death interruption cannot collect")
	ui._campaign_combat=true;ui._source_tabs.current_tab=0;ui._on_backpack_selected(0)
	var protected_item: Item=ui._selected;ui._on_discard_pressed()
	check(ui._discard_button.disabled and inv.backpack.has(protected_item),"campaign retains banked-item discard protection")
	ui._refresh();choose_ground(shifted)
	check(ui._nearby_hint.text.contains("successful return"),"campaign loot terms do not promise rewards on failure")
	ui._campaign_combat=false
	# A real capped pile supports long names and scrolling without changing drop limits.
	for i in 45:
		var item:=ItemGenerator.generate_with(3,i%4,"weapon")
		item.name="Long Forgotten Relic of the Northern Ashen Kingdom %02d" % i
		loot.drop(item,player.pos2)
	ui._refresh();ui._source_tabs.current_tab=1
	check(loot.drops.size()==loot.max_drops and ui._nearby_list.item_count<=loot.max_drops,"Nearby remains bounded by existing forty-drop cap")
	var sorted:=loot.nearby(player.pos2,player.stats.pickup_radius)
	for i in range(1,sorted.size()):check(sorted[i-1].item.rarity>=sorted[i].item.rarity,"higher rarities listed first without promising better fit")
	ui._nearby_list.grab_focus()
	for i in 45:await action("ui_down")
	check(ui._nearby_list.get_selected_items().size()==1 and ui._nearby_list.get_selected_items()[0]==ui._nearby_list.item_count-1,"keyboard reaches the end of a crowded nearby pile")
	await capture_image("Nearby_Loot_Crowded")
	check(ui._equip_button.get_global_rect().end.x<=root.get_visible_rect().size.x and ui._equip_button.get_global_rect().end.y<=root.get_visible_rect().size.y,"long names keep collection actions within viewport")
	var long_selected: Item=ui._selected
	ui._on_equip_pressed();await process_frame
	check(inv.backpack.has(long_selected) and ui._selection_meta.text=="Collected · Backpack","long-name collection uses a short receipt label")
	check(ui._selection_meta.get_global_rect().end.x<=root.get_visible_rect().size.x,"long-name collection receipt cannot widen the screen")
	# Nearby sort is bounded/read-only; automatic pickup order and RNG stay intact.
	seed(77);var next:=randi();seed(77);var before_drops:=loot.drops.duplicate();var before_ids:=Item._next_uid
	for i in 100:loot.nearby(player.pos2,player.stats.pickup_radius)
	check(randi()==next and Item._next_uid==before_ids and loot.drops==before_drops,"browsing cannot change RNG, IDs or automatic pickup order")
	await action("ui_cancel")
	var final_gear:=inv.to_dict().duplicate(true)
	check(RunSave.write(main.capture()),"chosen collected gear saves through normal snapshot")
	var saved:=RunSave.read();main.queue_free();for i in 4:await process_frame
	Elements.player=null;Elements.swarms.clear();RunSave.pending=saved
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false);await process_frame
	check(main._player.inventory.to_dict()==final_gear,"disk resume preserves every collected and original item exactly once")
	check(main._loot.drops.is_empty(),"existing transient ground-loot rule is unchanged and disclosed")
	main.queue_free();for i in 4:await process_frame
	RunSave.clear();print("NEARBY LOOT: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
