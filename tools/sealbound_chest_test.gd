extends SceneTree
## Real Main/event/UI contracts; controlled damage is limited to this regression.
var checks := 0
var failures := 0
var main: Node
var events: EventDirector
var player: Player
var output := ""
var grants := 0
func _initialize() -> void:
	MetaProgress.disabled=true; MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;MetaProgress.settings["shake"]=false
	Realm.in_title=false;Realm.daily=false;Realm.current="graveyard";RunSave.pending={};RunSave.path="user://sealbound-test.run"
	root.size=Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func capture_image(name: String) -> void:
	if output=="":return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func fresh() -> Dictionary:
	for e: Dictionary in events._events:e["node"].queue_free()
	events._events.clear();events.chest_hint="";events.shards=0
	for swarm: EnemySwarm in main._swarms:swarm.despawn_all()
	player.dead=false;player.position=Vector3.ZERO;player.stats.hp=player.stats.max_hp
	events._start_chest(Vector2.ZERO,true)
	return events._events[-1]
func inspect() -> bool:
	Input.action_release("interact");Input.action_press("interact")
	var opened:=events.offer_chest()
	Input.action_release("interact")
	return opened
func select_action(index: int) -> void:
	events._chest_panel.action_button(["hunt","seal","leave"][index]).pressed.emit()
func slay(e: Dictionary) -> void:
	for g: Array in e["guards"]:
		var swarm: EnemySwarm=g[0]
		for i in swarm.count:
			if swarm.ids[i]==g[1] and swarm.hp[i]>0:swarm.damage(i,1.0e9);break
func _run() -> void:
	seed(71139);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false)
	await process_frame
	player=main._player;events=main._events;Obstacles.clear()
	events.reward_revealed.connect(func(_t: String,_d: String,_c: Color) -> void:grants+=1)
	var e:=fresh()
	for i in 3:events._update_events(1.0)
	check(not e["opened"] and e["guards"].is_empty(),"walking onto a chest never opts in")
	check(events.discovery_prompt.contains("Inspect chest"),"nearby prompt offers inspection")
	check(inspect() and paused and events._chest_panel.is_open(),"explicit inspect pauses and opens actual panel")
	check(e["guards"].is_empty() and not e["opened"],"inspection spawns nothing")
	check(events._chest_panel._detail.text.contains("(+2)") and events._chest_panel._odds.text.contains("Timeout loses only"),"panel states extra enemies and timeout terms")
	await capture_image("Sealbound_Choice")
	var age: float=e["age"]
	for i in 3:await process_frame
	check(e["age"]==age,"paused inspection does not spend event time")
	var cancel:=InputEventAction.new();cancel.action="ui_cancel";cancel.pressed=true;Input.parse_input_event(cancel)
	await process_frame
	check(not paused and not events._chest_panel.is_open() and not e["opened"],"Escape/cancel declines without consumption")
	events._choose_chest("seal")
	check(e["guards"].is_empty(),"stale selection after decline is inert")
	player.position=Vector3(10,0,0)
	check(not inspect(),"distant chest cannot open")
	player.position=Vector3.ZERO
	check(inspect(),"returning can inspect the unconsumed chest")
	select_action(0)
	check(not paused and e["opened"] and not e["seal"] and e["guards"].size()==5,"ordinary route keeps five guardians")
	var count: int=main._enemy_count();events._choose_chest("seal")
	check(main._enemy_count()==count,"double selection cannot add champions")
	slay(e);var drops: int=main._loot.drops.size();events._update_events(0.1)
	check(events._events.is_empty() and events.shards==5 and main._loot.drops.size()==drops+1 and grants==1,"ordinary route pays one base Legendary and five shards")
	check(main._loot.drops[-1].item.rarity==ItemData.Rarity.LEGENDARY,"base rarity unchanged")
	check(events._update_choice_chest(e,Vector2.ZERO,20) and grants==1 and events.shards==5,"stale completed ordinary event cannot repay")
	await process_frame
	# Seal: partial progress, departure, return, success; reward waits for guards.
	e=fresh();inspect();select_action(1)
	check(e["seal"] and e["guards"].size()==7,"Sealbound explicitly adds exactly two champions")
	check(is_equal_approx(e["seal_ring"].mesh.size.x * 0.82 * 0.5,5.0),"ritual radius is five metres")
	check(e["seal_ring"].material_override.get_shader_parameter("pulse_speed")==0.0,"ritual outline is steady in Calm")
	events._update_events(4.0);check(is_equal_approx(e["charge"],4.0),"inside charges in seconds")
	player.position=Vector3(8,0,0);events._update_events(2.0)
	check(is_equal_approx(e["charge"],3.0) and is_equal_approx(e["left"],29.0),"leaving drains half speed while deadline advances")
	check(events.chest_hint.contains("3.0 / 12") and e["seal_label"].text.contains("Return"),"away hint reports charge and return")
	player.position=Vector3.ZERO;events._update_events(9.0)
	check(is_equal_approx(e["charge"],12.0) and events.shards==0 and not e["paid"],"return completes charge but cannot bypass champions")
	check(events.chest_hint.contains("BONUS SECURED"),"secured bonus is readable")
	main._process(0.0);await capture_image("Sealbound_Secured")
	slay(e);drops=main._loot.drops.size();events._update_events(0.01)
	check(events._events.is_empty() and events.shards==10 and main._loot.drops.size()==drops+1 and grants==2,"victory pays exactly one base item and ten total shards")
	for i in 4:events._update_choice_chest(e,Vector2.ZERO,10.0)
	check(events.shards==10 and grants==2,"stale bonus completion is idempotent")
	# Timeout never loses the base reward; repeated reentry never resets deadline.
	for repeat in 3:
		e=fresh();inspect();select_action(1);player.position=Vector3(12,0,0)
		events._update_events(34.5);check(e["left"]==0.5 and e["charge"]==0,"outside waits without any reward")
		player.position=Vector3.ZERO;events._update_events(1.0)
		check(e["left"]==0 and e["charge"]==0.5 and not e["paid"],"deadline clamps charge to remaining half second")
		check(events.chest_hint.contains("EXPIRED") and not e["seal_ring"].visible,"timeout removes optional circle and says expired")
		check(not inspect(),"opened chest cannot be opted into again")
		slay(e);events._update_events(0.0)
		check(events.shards==5 and events._events.is_empty(),"timeout still pays original base reward once")
		var paid_grants:=grants;events._update_choice_chest(e,Vector2.ZERO,50)
		check(events.shards==5 and grants==paid_grants,"expired reentry cannot duplicate base or revive bonus")
	# Slaying early pays base immediately; the optional seal may still be finished.
	e=fresh();inspect();select_action(1);slay(e);events._update_events(2.0)
	check(e["paid"] and events.shards==5 and events._events.size()==1,"early kills pay base without waiting for ritual")
	var base_grants:=grants;events._update_events(10.0)
	check(events.shards==10 and grants==base_grants and events._events.is_empty(),"later charge pays only bonus, not another item")
	# Stable IDs survive compaction and unrelated enemies do not become guardians.
	e=fresh();inspect();select_action(0)
	var first_guard: Array=e["guards"][0];var guard_swarm: EnemySwarm=first_guard[0]
	for i in guard_swarm.count:
		if guard_swarm.ids[i]==first_guard[1]:guard_swarm.damage(i,1e9);break
	guard_swarm.step(0.0,Vector2.ZERO);guard_swarm.spawn(Vector2(20,20));var unrelated:=guard_swarm.ids[guard_swarm.count-1]
	events._update_events(0.0);check(not e["paid"],"one compacted guardian death cannot unlock base")
	slay(e);events._update_events(0.0)
	check(events.shards==5 and guard_swarm.ids.find(unrelated)>=0,"unrelated stable ID does not block or substitute for guards")
	# All realm counts and full swarm capacity obey the posted offer.
	for realm: String in Realm.ORDER:
		Realm.current=realm;e=fresh();inspect();select_action(1)
		check(e["guards"].size()==7+Realm.index(realm),"posted guardian count in "+realm)
	Realm.current="graveyard"
	e=fresh();var capacities:=[]
	for swarm: EnemySwarm in events._swarms:capacities.append(swarm.capacity);swarm.capacity=swarm.count
	inspect();select_action(0)
	check(not e["opened"] and e["guards"].is_empty(),"full capacities cannot spawn a partial encounter")
	for i in events._swarms.size():events._swarms[i].capacity=capacities[i]
	# No room -> no partial spawns / consumption. Circle obstruction disables option.
	e=fresh();var saved_types:=events._swarms.duplicate();events._swarms.clear();inspect();select_action(1)
	check(not e["opened"] and e["guards"].is_empty() and not paused,"no capacity safely leaves chest unconsumed")
	events._swarms.assign(saved_types);Obstacles.set_circles([[Vector2(4,0),1.0]],Rect2(-15,-15,30,30))
	inspect()
	check(events._chest_panel.action_button("seal").disabled and not events._chest_panel.action_button("hunt").disabled,"blocked five-metre circle disables only Sealbound")
	events._choose_chest("seal");check(not e["opened"],"programmatic blocked choice also rejected")
	Obstacles.clear()
	# Unused expiry and death cannot grant, including stale callbacks.
	e=fresh();player.position=Vector3(20,0,0);e["age"]=90.1;events._update_events(0.0)
	check(events._events.is_empty(),"unused offer retains ninety-second expiry")
	e=fresh();inspect();player.dead=true;select_action(1)
	check(not e["opened"] and not paused,"death during selection cannot spawn or strand paused tree")
	player.dead=false;inspect();select_action(1);slay(e);player.dead=true;base_grants=grants
	events._update_events(50.0);events._update_choice_chest(e,Vector2.ZERO,50.0)
	check(not e["paid"] and grants==base_grants and events.shards==0,"dead player cannot complete either payout")
	# Fresh-scene resume follows existing transient-chest semantics explicitly.
	player.dead=false;player.stats.hp=player.stats.max_hp
	var snapshot: Dictionary=main.capture();check(RunSave.write(snapshot),"active ritual can save without schema changes")
	var saved:=RunSave.read();check(saved["version"]==1,"save remains version one")
	main.queue_free();for i in 4:await process_frame
	RunSave.pending=saved;main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false);await process_frame
	check(main._events._events.is_empty() and main._events.shards==0,"fresh resume neither resurrects ritual nor replays rewards")
	check(main._run_shards==snapshot["run_shards"],"banked run shards survive exact resume")
	# Unmodified authored chest constructor still follows original campaign/test route.
	events=main._events;player=main._player;Obstacles.clear();events._start_chest(player.pos2)
	check(not events._events[-1]["choice"],"authored/default chest route is unchanged")
	events._update_events(0.1);check(events._events[-1]["opened"],"original chest proximity opening still works")
	main.queue_free();for i in 4:await process_frame
	RunSave.clear();print("SEALBOUND CHEST: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
