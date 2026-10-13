extends SceneTree
## Controlled gear drop; real Main pickup, menu, equip and resumed combat.
## Starting items/HP are fixtures. No injected enemy damage or invulnerability.
var main: Node
var candidate: Item
var predicted: PlayerStats
var player: Player
var screen: InventoryScreen
var frame := 0
var failures := 0
var output := ""
var finishing := false
var exact_equip := false
var lightning_captured := false
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	MetaProgress.settings["calm"]=true;MetaProgress.settings["shake"]=false
	Realm.in_title=false;Realm.daily=false;RunSave.pending={};RunSave.path="user://gear-impact-smoke.run"
	root.size=Vector2i(1280,720);seed(917173)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	_start.call_deferred()
func _start() -> void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	player=main._player;screen=main._inventory_screen
	var old:=Item.new();old.slot="helm";old.name="Gravekeeper Cap";old.base_name="Cap";old.rarity=ItemData.Rarity.MAGIC
	old.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":60.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":20.0}])
	player.inventory.pickup(old);player.stats.hp=145.0
	candidate=Item.new();candidate.slot="helm";candidate.name="Eye of the Storm";candidate.base_name="Circlet";candidate.rarity=ItemData.Rarity.LEGENDARY;candidate.power="storm_eye"
	candidate.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":20.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":5.0}])
	main._loot.drop(candidate,player.pos2+Vector2(2,0))
func _action(name: String) -> void:
	var ev:=InputEventAction.new();ev.action=name;ev.pressed=true;Input.parse_input_event(ev)
	ev=InputEventAction.new();ev.action=name;ev.pressed=false;Input.parse_input_event.call_deferred(ev)
func _process(_delta: float) -> bool:
	if main==null or finishing:return false
	frame+=1
	Input.action_release("move_right")
	if frame<45:Input.action_press("move_right")
	if main._hud._upgrade_root.visible:main._hud._choose(0)
	match frame:
		150:_action("inventory")
		155:
			if not screen.is_open() or not player.inventory.backpack.has(candidate):failures+=1;_finish.call_deferred();return false
			var index:=player.inventory.backpack.find(candidate)
			screen._backpack_list.select(index);screen._backpack_list.item_selected.emit(index)
			predicted=player.inventory.preview_swap(candidate.slot,candidate)
			_capture.call_deferred("gear_preview_in_run")
		360:
			screen._impact.grab_focus();_action("ui_down")
		390:_action("ui_down")
		420:
			screen._equip_button.pressed.emit()
			exact_equip=player.stats.values==predicted.values and player.stats.powers==predicted.powers and player.stats.hp==predicted.hp
		450:_action("inventory")
	if frame>450 and not player._lightning._arcs.is_empty() and not lightning_captured:
		lightning_captured=true;_capture.call_deferred("gear_lightning_in_combat")
	if frame>=1200 or player.dead:_finish.call_deferred()
	return false
func _capture(name: String) -> void:
	if output=="" or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output);root.get_texture().get_image().save_png(output.path_join(name+".png"))
func _finish() -> void:
	if finishing:return
	finishing=true;Input.action_release("move_right");paused=false
	var damage: float=Elements.metrics.sources.get("Chain Lightning",{}).get("damage",0.0)
	var passed: bool = failures==0 and exact_equip and damage>0.0 and not player.dead and player.inventory.equipped.get("helm")==candidate and not screen.is_open()
	var report:={"passed":passed,"frames":frame,"combat_seconds":main.elapsed,"exact_equip":exact_equip,"lightning_damage":damage,"lightning_visual_seen":lightning_captured,"kills":main.kills,"hero_hp":player.stats.hp,"invulnerable":player.invulnerable,"controlled_drop_fixture":true,"save_version":RunSave.VERSION}
	print("GEAR MAIN SMOKE: ",JSON.stringify(report))
	if output!="":
		DirAccess.make_dir_recursive_absolute(output);var file:=FileAccess.open(output.path_join("gear_smoke.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.queue_free();for i in 4:await process_frame
	quit(0 if passed else 1)
