extends SceneTree
## Rendered Main input proof at a naturally placed Ember forge. Fixture starting
## level, shards and worn weapon; no forced roll outcome, invulnerable for capture.
var main: Node
var output := ""
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;MetaProgress.settings["shake"]=false
	Realm.in_title=false;Realm.current="ember";Realm.daily=false;RunSave.pending={}
	root.size=Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func hold(n: int) -> void:
	for i in n:await process_frame
func action(id: String) -> void:
	var ev:=InputEventAction.new();ev.action=id;ev.pressed=true;Input.parse_input_event(ev);await process_frame
	ev=InputEventAction.new();ev.action=id;ev.pressed=false;Input.parse_input_event(ev);await process_frame
func capture_image(name: String) -> void:
	if output=="":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func require(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func _run() -> void:
	seed(143217);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await process_frame
	root.size=Vector2i(1280,720)
	main._process(0.0)
	var player: Player=main._player;var forge: Landmarks=main._landmarks
	player.invulnerable=true;player.stats.level=8;main._run_shards=24
	var rng:=RandomNumberGenerator.new();rng.seed=771
	var original:=ItemGenerator.generate_with(10,ItemData.Rarity.LEGENDARY,"weapon",rng)
	player.inventory.replace_worn(original)
	if not require(forge._decor.placed.get("forge",[]).size()>0,"No naturally placed forge in starting Ember view"):return
	var xf: Transform3D=forge._decor.placed.forge[0]
	var at:=Vector2(xf.origin.x,xf.origin.z)
	# Choose a collision-free approach where the real nearest-site rule selects this forge.
	var approach := at + Vector2(0,3.0)
	var found := false
	for i in 32:
		var point := at + Vector2.from_angle(TAU * float(i)/32.0) * 2.8
		if Obstacles.blocked(point,Player.RADIUS):continue
		player.position=Vector3(point.x,0,point.y);forge._rescan()
		if forge._near_use=="forge" and forge._near_key==Landmarks.key_of("forge",at):approach=point;found=true;break
	if not require(found,"Collision-free natural forge approach"):return
	player.position=Vector3(approach.x,0,approach.y)
	main.get_node("CameraRig").position=player.position
	await hold(60)
	forge._rescan()
	print("APPROACH ",at," hero ",player.pos2," key ",forge._near_key," use ",forge._near_use)
	if not require(forge._near_use=="forge" and forge._near_key!="","Natural forge approach in range"):return
	await capture_image("Field_Forge_In_World")
	await action("interact");await hold(45)
	if not require(paused and forge._forge_panel.is_open(),"Real interact opens free inspection"):return
	await capture_image("Field_Forge_Real_Inspect")
	forge._forge_panel.action_button("roll").grab_focus();await action("ui_accept");await hold(75)
	if not require(main._run_shards==16 and player.inventory.equipped.weapon==original,"Real roll charges once and preserves original"):return
	await capture_image("Field_Forge_Real_Roll")
	var rolled: Item=forge._forge_offer.rolled
	print("NATURAL FORGE ",at," ORIGINAL ",original.to_dict()," ROLLED ",rolled.to_dict())
	forge._forge_panel._comparison.grab_focus();for i in 5:await action("ui_down")
	await hold(30)
	forge._forge_panel.action_button("keep").grab_focus();await action("ui_accept");await hold(60)
	if not require(not paused and player.inventory.equipped.weapon==original and main._run_shards==16 and forge.is_used("forge",at),"Keep returns to Main combat with one charge and spent forge"):return
	await capture_image("Field_Forge_Kept")
	print("FIELD FORGE REVIEW PASS: natural placement / Main interact / generated roll / keep / combat resumed")
	main.queue_free();await hold(4);quit()
