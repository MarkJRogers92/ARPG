extends SceneTree
## Presentation and focus contracts; no player-state mutation or balance fixtures.
var checks:=0
var failures:=0
var main: Node
var output:=""
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;Realm.in_title=false;Realm.daily=false;RunSave.pending={};Realm.current="graveyard"
	root.size=Vector2i(1280,720);seed(51178)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func action(id: String) -> void:
	var e:=InputEventAction.new();e.action=id;e.pressed=true;Input.parse_input_event(e)
	await process_frame;await process_frame
	e=InputEventAction.new();e.action=id;e.pressed=false;Input.parse_input_event(e);await process_frame
func inside(control: Control) -> bool:
	var r:=control.get_global_rect();var v:=root.get_visible_rect()
	return r.position.x>=0 and r.position.y>=0 and r.end.x<=v.end.x+1 and r.end.y<=v.end.y+1
func capture_image(name: String) -> void:
	if output=="":return
	await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func offer() -> void:
	Input.action_press("interact");main._events.offer_chest();Input.action_release("interact")
func _run() -> void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false);await process_frame
	var player: Player=main._player;var hud: Hud=main._hud;var screen: InventoryScreen=main._inventory_screen;var events: EventDirector=main._events
	Obstacles.clear();events._start_chest(player.pos2,true);var chest: Dictionary=events._events[-1]
	var item:=ItemGenerator.generate_with(4,ItemData.Rarity.LEGENDARY,"helm");player.inventory.backpack.append(item)
	var baseline:=player.stats._mods.duplicate(true);var hp:=player.stats.hp
	for size: Vector2i in [Vector2i(1024,576),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;for i in 4:await process_frame
		print("UI SIZE ",size," logical ",root.get_visible_rect().size)
		main._open_screen(screen);screen._on_backpack_selected(0);for i in 3:await process_frame
		check(inside(screen._equip_button) and inside(screen._discard_button) and inside(screen._upgrades_button),"gear actions in bounds at "+str(size))
		check(inside(screen._equipment_list) and inside(screen._backpack_list) and inside(screen._impact),"gear content in bounds at "+str(size))
		screen._detail_tabs.get_tab_bar().grab_focus();await action("ui_right")
		check(screen._detail_tabs.current_tab==1,"item roll tab keyboard access")
		await action("ui_left");check(screen._detail_tabs.current_tab==0,"build tab keyboard return")
		await capture_image("Equipment_"+str(size.x))
		await action("ui_cancel");check(not paused and not screen.is_open(),"gear closes and resumes")
		offer();await process_frame;await process_frame
		var panel: WagerPanel=events._chest_panel
		check(panel.is_open() and paused and panel._cards.get_child_count()==2,"choice has two cards and pauses combat")
		for id: String in ["hunt","seal","leave"]:check(inside(panel.action_button(id)),"choice "+id+" in bounds at "+str(size))
		check(root.gui_get_focus_owner()==panel.action_button("hunt"),"original challenge gets default focus")
		await action("ui_right");check(root.gui_get_focus_owner()==panel.action_button("seal"),"right selects optional challenge")
		await action("ui_down");check(root.gui_get_focus_owner()==panel.action_button("leave"),"down reaches Leave")
		await capture_image("Chest_"+str(size.x))
		var stale:=panel.action_button("seal")
		await action("ui_accept");check(not paused and not chest["opened"],"keyboard Leave changes no encounter")
		stale.pressed.emit();check(not chest["opened"],"late click after closing is ignored")
		for i in 3:offer();events._choose_chest("leave")
		await process_frame;check(not paused and events._chest_offer.is_empty(),"rapid open/close leaves no modal owner")
	check(player.stats._mods==baseline and player.stats.hp==hp and chest["guards"].is_empty(),"view-only interactions preserve all stats and spawn nothing")
	root.size=Vector2i(1280,720);await process_frame
	var original_name:=item.name;item.name="A Very Long Relic Name ".repeat(12)
	main._open_screen(screen);screen._on_backpack_selected(0);await process_frame;await process_frame
	check(screen._selection_name.max_lines_visible==2 and screen._selection_name.tooltip_text==item.name and inside(screen._equip_button),"long item name is bounded with full detail and accessible actions")
	await action("ui_cancel");item.name=original_name
	# Long external/event copy scrolls within the modal; focus follows the action.
	offer();var panel: WagerPanel=events._chest_panel
	panel.show_state({"prize":"Long reward preview", "cards":{"hunt":{"title":"Hunt","challenge":"A very long event description with explicit terms. ".repeat(45)},"seal":{"title":"Sealbound","challenge":"A second long description. ".repeat(50)}},"odds":"Shared terms. ".repeat(50),"result":"Save & Quit ends unfinished rituals.","actions":[["hunt","Choose Hunt",true],["seal","Choose Sealbound",true],["leave","Leave",true]]})
	await process_frame;await process_frame
	var scroll: ScrollContainer=panel._root.find_children("*","ScrollContainer",true,false)[0]
	check(inside(scroll) and scroll.get_v_scroll_bar().max_value>scroll.size.y,"long choice content scrolls inside viewport")
	panel.action_button("leave").grab_focus();await process_frame;await process_frame
	check(inside(panel.action_button("leave")),"keyboard focus scrolls long modal to Leave")
	await action("ui_cancel");check(not paused and not panel.is_open(),"long modal cancels cleanly")
	# Congestion is bounded; routine loot cannot evict save failures.
	for n in hud._toasts.get_children():hud._toasts.remove_child(n);n.queue_free()
	hud.toast("Save failed. Your run is still open. Try again before quitting.",RunUi.LOSS,"",true)
	for i in 20:hud.toast("Found item %d" % i,Color(1,0.2,1))
	await process_frame;await process_frame
	check(hud._toasts.get_child_count()==3,"only three notices occupy combat space")
	check(hud._toasts.get_children().any(func(n: Label) -> bool:return n.text.begins_with("Save failed")),"save failure survives loot congestion")
	for n: Label in hud._toasts.get_children():check(n.get_theme_color("font_color")==RunUi.TEXT and inside(n),"notice has restrained readable text and stays on-screen")
	paused=true;await process_frame;await process_frame
	check(hud._toasts.get_children().filter(func(n: Label) -> bool:return n.visible).size()==1,"only crucial notices remain visible over a paused menu")
	check((hud._toasts.get_parent().get_parent() as CanvasLayer).layer>main._pause.layer,"save failure is not hidden behind pause backdrop")
	paused=false;await process_frame
	hud.toast("Long notice. ".repeat(40),Color.WHITE)
	await process_frame;await process_frame
	var notice:=hud._toasts.get_child(-1) as Label
	check(notice.max_lines_visible==3 and notice.tooltip_text==notice.text and inside(notice),"long notices remain bounded and retain full hover detail")
	# Reward reveal is a compact side card, does not consume combat inputs.
	hud.reveal_reward("THE CURSE BREAKS","Stormstride Boots · Legendary dropped. +5 base shards.",Color(1,0.5,0.1));await process_frame;await process_frame
	check(inside(hud._title_card) and hud._title_card.get_global_rect().position.x>root.get_visible_rect().size.x*0.6,"reward sits beside combat, inside viewport")
	check(hud._title_card.scale==Vector2.ONE,"Calm reward has no scale pop")
	hud.reveal_reward("SECOND REWARD","Latest reward survives the previous card's lifecycle.",RunUi.GOLD)
	await process_frame;check(hud._title_main.text=="Second Reward","new reward replaces title without stale completion")
	paused=true;var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true;hud._input(enter)
	check(hud._reward_reveal_shown,"menu Enter cannot dismiss a combat reward")
	paused=false;hud._input(enter);check(not hud._reward_reveal_shown,"combat Enter dismisses presentation only")
	check(player.stats._mods==baseline and player.stats.hp==hp,"notification and reward styling grants no gameplay effects")
	main.queue_free();for i in 4:await process_frame
	print("RUN UI POLISH: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
