extends SceneTree
## Controlled early-game chest placement; normal enemies and real combat.
## Existing upgrade cards form an explicit mid-run build fixture, no invulnerability.
var main: Node
var player: Player
var events: EventDirector
var chest: Dictionary
var frame:=0
var phase:=0
var wait_frames:=0
var done:=false
var output:=""
var base_grants:=0
var bonus_grants:=0
var stepped_out:=false
var saw_decay:=false
var previous_charge:=0.0
var accepted_count:=0
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;MetaProgress.settings["shake"]=false
	Realm.in_title=false;Realm.daily=false;Realm.current="graveyard";RunSave.pending={}
	root.size=Vector2i(1280,720);seed(71139)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	_start.call_deferred()
func _start() -> void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	player=main._player;events=main._events
	for id: String in ["aura","aura","lightning","lightning","nova","bolt_damage","bolt_damage","bolt_rate"]:Upgrades.apply(id,player.stats)
	player.stats.level=9;player.stats.xp=0;player.stats.xp_to_next=player.xp_for_level(9)
	var at:=events._clear_spot(6,9,EventDirector.SEAL_RADIUS+0.5)
	if at==Vector2.INF:push_error("No clear chest fixture");quit(1);return
	events._start_chest(at,true);chest=events._events[-1]
	events.reward_revealed.connect(func(title: String,_detail: String,_color: Color) -> void:
		if title=="THE CURSE BREAKS":base_grants+=1)
	events.announced.connect(func(text: String,_c: Color) -> void:
		if text.begins_with("Sealbound complete!"):bonus_grants+=1)
func _walk(at: Vector2) -> void:
	var d:=at-player.pos2
	if absf(d.x)>0.4:Input.action_press("move_right" if d.x>0 else "move_left")
	if absf(d.y)>0.4:Input.action_press("move_down" if d.y>0 else "move_up")
func _process(_delta: float) -> bool:
	if main==null or done:return false
	frame+=1
	for action: String in ["move_left","move_right","move_up","move_down","interact","dash"]:Input.action_release(action)
	if main._hud._upgrade_root.visible:main._hud._choose(0)
	match phase:
		0:
			if frame>80:_walk(chest["at"])
			if player.pos2.distance_to(chest["at"])<2.3:
				Input.action_press("interact");phase=1
		1:
			if events._chest_panel!=null and events._chest_panel.is_open():
				wait_frames+=1
				if wait_frames==60:_capture.call_deferred("Sealbound_Offer_Gameplay")
				if wait_frames==240:
					var buttons:=events._chest_panel._buttons.get_children().filter(func(n: Node) -> bool:return not n.is_queued_for_deletion())
					(buttons[1] as Button).pressed.emit();phase=2;accepted_count=chest["guards"].size()
		2:
			if not chest.get("opened",false):push_error("Chest acceptance failed");_finish.call_deferred();return false
			if chest["charge"]<4.0 and not stepped_out:
				_walk(chest["at"]+Vector2(1.7,0))
			elif not stepped_out:
				_walk(chest["at"]+Vector2(6.2,0))
				if player.pos2.distance_to(chest["at"])>5.5:stepped_out=true
			elif not saw_decay:
				if chest["charge"]<previous_charge:saw_decay=true;_capture.call_deferred("Sealbound_Return_To_Seal")
			else:
				# Small grounded kite within the five-metre area while weapons fire.
				_walk(chest["at"]+Vector2.from_angle(float(frame)*0.015)*2.5)
			if frame%120==0:_capture.call_deferred("Sealbound_Active_Gameplay")
			previous_charge=chest["charge"]
			if chest.get("finished",false):phase=3;wait_frames=0;_capture.call_deferred("Sealbound_Reward_Gameplay")
		3:
			_walk(chest["at"]);wait_frames+=1
			if wait_frames>=150:_finish.call_deferred()
	if frame>=3000 or player.dead:_finish.call_deferred()
	return false
func _capture(name: String) -> void:
	if output=="" or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func _finish() -> void:
	if done:return
	done=true;paused=false
	for action: String in ["move_left","move_right","move_up","move_down","interact"]:Input.action_release(action)
	var passed: bool=not player.dead and base_grants==1 and bonus_grants==1 and accepted_count==7 and saw_decay and chest.get("finished",false)
	var report:={"passed":passed,"frames":frame,"combat_seconds":main.elapsed,"guardians":accepted_count,"base_grants":base_grants,"bonus_grants":bonus_grants,"stepped_out":stepped_out,"decay_seen":saw_decay,"hero_hp":player.stats.hp,"kills":main.kills,"invulnerable":player.invulnerable,"fixture":"early chest plus eight existing upgrade cards / level9; no injected damage"}
	print("SEALBOUND MAIN SMOKE: ",JSON.stringify(report))
	if output!="":
		DirAccess.make_dir_recursive_absolute(output);var file:=FileAccess.open(output.path_join("sealbound_smoke.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.queue_free();for i in 4:await process_frame
	quit(0 if passed else 1)
